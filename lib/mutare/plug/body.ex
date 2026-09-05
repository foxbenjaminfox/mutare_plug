defmodule Mutare.Plug.Body do
  @moduledoc """
  `:resp_body` — blanks the response body: the body argument of `Plug.Conn.send_resp/3`
  and `Plug.Conn.resp/3` becomes `""`. A surviving mutant means no test reads the
  response body — the response was sent, with the right status, and nothing checked
  what it said.

      send_resp(conn, 200, Jason.encode!(payload))  # → send_resp(conn, 200, "")
      conn |> resp(:ok, body)                       # → conn |> resp(:ok, "")

  Matches both calls written directly (`Plug.Conn.send_resp(conn, ...)`), aliased, or
  bare-imported. A body that is already a literal `""` is left alone (the mutant would
  change nothing). The status argument stays with `:http_status` (atoms) and the built-in
  literal families (integers); `send_file/3,4,5` is out of scope because its third
  argument is a path, not a body — blanking it would crash rather than answer a question.

  Because the mutation is the original call with exactly the body argument substituted,
  `Mutare.Transform.Overlap` treats it as covering that node: on a *literal* body the
  built-in `:string` leaves (`""`/`"mutare"`) are pruned automatically, so this family
  supersedes them rather than double-firing on the same range.
  """
  @behaviour Mutare.Mutator

  alias Mutare.AST
  alias Mutare.Calls

  # The `Plug.Conn` calls that carry a blankable body. In both, the body sits at effective
  # argument index 2 — the third positional argument: `send_resp(conn, status, body)`,
  # `resp(conn, status, body)`. The arity guard keeps a wrong-arity call (which would not
  # be the real `Plug.Conn` function) from contributing a mutant.
  @body_calls MapSet.new([
                {:send_resp, 3},
                {:resp, 3}
              ])

  @body_index 2

  @impl Mutare.Mutator
  @spec name() :: :resp_body
  def name, do: :resp_body

  # No `mutate/1`: the body's position depends on the call's effective arity, which isn't
  # knowable without pipe context — so this family produces only through the context-aware
  # `mutate/2`.
  @impl Mutare.Mutator
  @spec mutate(Macro.t(), Mutare.Mutator.context()) :: :skip | [Macro.t()]
  def mutate(node, %{pipe_mode: pipe_mode}) do
    case Calls.resolved_call(node) do
      {[:Plug, :Conn], call, args, rebuild} ->
        body_mutations(call, args, pipe_mode, rebuild)

      _other ->
        :skip
    end
  end

  @spec body_mutations(
          atom(),
          [Macro.t()],
          Mutare.Mutator.pipe_mode(),
          (atom(), [Macro.t()] -> Macro.t())
        ) :: :skip | [Macro.t()]
  defp body_mutations(call, args, pipe_mode, rebuild) do
    with effective_arity when is_integer(effective_arity) <-
           Mutare.Mutator.effective_arity(args, pipe_mode),
         true <- MapSet.member?(@body_calls, {call, effective_arity}),
         vis when is_integer(vis) <- Mutare.Mutator.visible_index(@body_index, pipe_mode),
         body = Enum.at(args, vis),
         false <- blank?(body) do
      [rebuild.(call, List.replace_at(args, vis, blank_body(body)))]
    else
      _other -> :skip
    end
  end

  # Already-blank bodies produce nothing: replacing `""` with `""` is a no-op mutant.
  @spec blank?(Macro.t()) :: boolean()
  defp blank?(node), do: AST.literal_value(node) == {:ok, ""}

  # Blank the body inside the original node, keeping its Sourceror metadata when the body
  # is a wrapped string literal — the clean-meta rule: change the value, keep the position,
  # so the call re-renders inline. Anything else (a variable, a call, an interpolated
  # string) is replaced wholesale by a fresh `""` literal.
  @spec blank_body(Macro.t()) :: Macro.t()
  defp blank_body({:__block__, meta, [body]}) when is_binary(body), do: {:__block__, meta, [""]}
  defp blank_body(_node), do: AST.literal("")
end
