defmodule Mutare.Plug.Status do
  @moduledoc """
  `:http_status` — swaps the atom status of `Plug.Conn.put_status/2`, `send_resp/3`,
  `resp/3`, `send_chunked/2`, and `send_file/3,4,5` for a plausible sibling in the same
  status family. A surviving mutant means no test pins the exact status code.

      put_status(conn, :ok)            # → :created / :no_content
      put_status(conn, :unauthorized)  # → :forbidden
      send_resp(conn, :not_found, "")  # → :gone / :forbidden

  Integer statuses (`put_status(conn, 200)`, `send_resp(conn, 200, body)`) are left to the
  built-in literal family. Matches each call written directly, aliased, or bare-imported
  (from `use Plug.Builder` / `use Plug.Router`, or Phoenix's `use MyAppWeb, :controller`).

  ## Configurable

  The swap table is tunable per instance. Give the family `{module, opts}` with a `:swaps`
  map: a status you list **replaces** its built-in siblings, an empty list **disables** it,
  and any status you omit keeps its built-in siblings. Configured siblings must be valid
  `Plug.Conn.Status` reason atoms — trusted, not checked: the built-in table guarantees this
  for its own entries, but a sibling you add that isn't a real status produces a crashing,
  uninformative mutant rather than the valid-but-wrong swap the table is built to give.

  Configuring a family means listing it yourself, so expand `Mutare.Plug.all/0` into its
  members and replace the `Status` entry:

      # .mutare.exs — narrow :ok to one sibling, stop mutating :no_content, add a teapot
      [
        mutators: [
          :builtins,
          Mutare.Plug.Halt,
          {Mutare.Plug.Status,
           swaps: %{ok: [:created], no_content: [], im_a_teapot: [:bad_request]}},
          Mutare.Plug.Session,
          Mutare.Plug.Header,
          Mutare.Plug.Cookie,
          Mutare.Plug.Body
        ]
      ]

  An unconfigured instance — `Mutare.Plug.Status`, or the one in `Mutare.Plug.all/0`
  — uses the built-in table unchanged.
  """
  @behaviour Mutare.Mutator

  alias Mutare.AST
  alias Mutare.Calls

  # A status-swap table: each reason atom mapped to its plausible same-family siblings.
  @typep swaps :: %{optional(atom()) => [atom()]}

  # Curated "plausible wrong status in the same family" map. Keys and values are all real
  # `Plug.Conn.Status` reason atoms, so every swap is a valid-but-wrong response (never a
  # crash). At most two siblings per status — the literal families' `{n-1, n+1}` analogue.
  #
  # The map is deliberately *directional*, not symmetric: a status points only at the
  # siblings worth confusing it with from its own position, so a swap need not have a mirror
  # (`created` offers `accepted`; `accepted` offers only `ok`). Keep it that way.
  @status_swaps %{
    # 2xx — which exact success was promised?
    ok: [:created, :no_content],
    created: [:ok, :accepted],
    accepted: [:ok],
    no_content: [:ok],
    # 3xx — redirect kind / permanence
    moved_permanently: [:found],
    found: [:moved_permanently, :see_other],
    see_other: [:found],
    temporary_redirect: [:permanent_redirect],
    permanent_redirect: [:temporary_redirect],
    not_modified: [:ok],
    # 4xx — the authorization and validation distinctions
    bad_request: [:unprocessable_entity],
    unauthorized: [:forbidden],
    forbidden: [:unauthorized, :not_found],
    not_found: [:gone, :forbidden],
    gone: [:not_found],
    method_not_allowed: [:not_found],
    not_acceptable: [:bad_request],
    conflict: [:unprocessable_entity],
    unprocessable_entity: [:bad_request, :conflict],
    too_many_requests: [:service_unavailable],
    # 5xx — server failure kind
    internal_server_error: [:bad_gateway, :service_unavailable],
    not_implemented: [:internal_server_error],
    bad_gateway: [:service_unavailable, :internal_server_error],
    service_unavailable: [:bad_gateway, :internal_server_error],
    gateway_timeout: [:service_unavailable]
  }

  # The `Plug.Conn` calls that carry a swappable atom status. In every supported call, the
  # status sits at effective argument index 1 — the second positional argument:
  # `put_status(conn, status)`, `send_resp(conn, status, body)`, `send_file(conn, status,
  # path)`, and so on. The arity is call-specific so a wrong-arity call
  # (`put_status(c, :ok, :extra)`, `send_resp(c, :ok)`) resolves but contributes no
  # mutation.
  @status_calls MapSet.new([
                  {:put_status, 2},
                  {:send_resp, 3},
                  {:resp, 3},
                  {:send_chunked, 2},
                  {:send_file, 3},
                  {:send_file, 4},
                  {:send_file, 5}
                ])

  @impl Mutare.Mutator
  @spec name() :: :http_status
  def name, do: :http_status

  # No `mutate/1`: the status atom's position depends on the call's effective arity,
  # which isn't knowable without pipe context — so this family produces only through
  # the context-aware `mutate/2`.
  @impl Mutare.Mutator
  @spec mutate(Macro.t(), Mutare.Mutator.context()) :: :skip | [Macro.t()]
  def mutate(node, %{pipe_mode: pipe_mode} = context) do
    case Calls.resolved_call(node) do
      {[:Plug, :Conn], call, args, rebuild} ->
        status_mutations(call, args, pipe_mode, rebuild, swaps_table(context))

      _other ->
        :skip
    end
  end

  # The status is the second positional argument of every matched call — effective index 1
  # of `put_status(conn, status)`, `send_resp(conn, status, body)`, `resp(conn, status,
  # body)`. Recover the visible index from the pipe context and, when the call is at its
  # expected arity and that argument holds a swappable atom status, emit one rebuilt call per
  # sibling. Anything else (an integer status, a variable, an unrecognised atom, or the wrong
  # arity) contributes nothing.
  #
  # The swap touches exactly the status atom, so `Mutare.Transform.Overlap` auto-prunes the
  # redundant crashing leaves at that range (`AtomLiteral` `:mutare`, `ConventionAtom`
  # `:error`) — no declaration needed.
  @spec status_mutations(
          atom(),
          [Macro.t()],
          Mutare.Mutator.pipe_mode(),
          (atom(), [Macro.t()] -> Macro.t()),
          swaps()
        ) :: :skip | [Macro.t()]
  defp status_mutations(call, args, pipe_mode, rebuild, swaps) do
    with effective_arity when is_integer(effective_arity) <-
           Mutare.Mutator.effective_arity(args, pipe_mode),
         true <- MapSet.member?(@status_calls, {call, effective_arity}),
         vis when is_integer(vis) <- Mutare.Mutator.visible_index(1, pipe_mode),
         status_node = Enum.at(args, vis),
         atom when not is_nil(atom) <- status_atom(status_node),
         [_ | _] = siblings <- Map.get(swaps, atom) do
      Enum.map(siblings, fn sibling ->
        rebuild.(call, List.replace_at(args, vis, swap_status(status_node, sibling)))
      end)
    else
      _ -> :skip
    end
  end

  # Swap the atom inside the original status node, keeping its Sourceror metadata — the
  # clean-meta rule: change the value, keep the position. A position-bearing swap re-renders
  # inline even for a multi-argument call (`send_resp(conn, :gone, "")`), where a fresh
  # `AST.literal` — carrying no line — would make Sourceror expand the call across lines. A
  # bare atom (the pure-AST node path, no metadata to keep) falls back to a fresh literal.
  @spec swap_status(Macro.t(), atom()) :: Macro.t()
  defp swap_status({:__block__, meta, [_atom]}, sibling), do: {:__block__, meta, [sibling]}
  defp swap_status(_bare_atom, sibling), do: AST.literal(sibling)

  # The effective swap table: the built-in `@status_swaps` with any per-instance `:swaps`
  # overrides merged over it (a listed status replaces its siblings; `[]` disables it). An
  # unconfigured instance carries `opts: []`, so the built-in table passes through untouched.
  @spec swaps_table(Mutare.Mutator.context()) :: swaps()
  defp swaps_table(context), do: Map.merge(@status_swaps, user_swaps(Map.get(context, :opts)))

  # The override map from a `{Status, swaps: %{…}}` configuration, keeping only structurally
  # well-formed entries (an atom status mapped to a list of atom siblings). A missing,
  # non-keyword, or non-map `:swaps` — and any malformed entry within it — contributes
  # nothing. The siblings are *trusted* to be valid statuses, not checked against one: that is
  # the same name-only stance the package takes toward `Plug.Conn`
  # everywhere else, and judging an atom's validity would mean reaching into the target
  # project's `Plug.Conn.Status` — a runtime coupling to plug no other call here has.
  @spec user_swaps(term()) :: swaps()
  defp user_swaps(opts) do
    overrides = if Keyword.keyword?(opts), do: Keyword.get(opts, :swaps), else: %{}

    if is_map(overrides) do
      for {status, siblings} <- overrides,
          is_atom(status) and is_list(siblings) and Enum.all?(siblings, &is_atom/1),
          into: %{},
          do: {status, siblings}
    else
      %{}
    end
  end

  # The atom carried by an argument node, if it is an atom literal (Sourceror's
  # block-wrapped form or a bare atom). `true`/`false`/`nil` are never statuses.
  @spec status_atom(Macro.t()) :: atom() | nil
  defp status_atom({:__block__, _meta, [a]}) when is_atom(a) and a not in [true, false, nil],
    do: a

  defp status_atom(a) when is_atom(a) and a not in [true, false, nil], do: a
  defp status_atom(_node), do: nil
end
