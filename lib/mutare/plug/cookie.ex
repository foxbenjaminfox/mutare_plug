defmodule Mutare.Plug.Cookie do
  @moduledoc """
  `:resp_cookie` — removes response-cookie mutations, flips explicit `:same_site`
  cookie policy values, and drops explicit `:max_age` options. A survivor means no test
  depends on this code setting/deleting the response cookie, on the cookie's SameSite
  policy, or on its persistence.

      put_resp_cookie(conn, "sid", token)                    # → conn
      delete_resp_cookie(conn, "sid")                        # → conn
      put_resp_cookie(conn, "sid", token, same_site: "Lax")  # → "Strict" / "None"
      put_resp_cookie(conn, "sid", token, max_age: ttl)      # → put_resp_cookie(conn, "sid", token)

  Dropping `max_age:` turns a persistent cookie into a session cookie — an option-*presence*
  mutation the built-in literal families cannot produce (they mutate the duration's value,
  not the entry). It applies only to `put_resp_cookie/4`; `delete_resp_cookie/3` forces
  `max_age: 0` regardless of the option, so a drop there would be a no-op mutant.

  Matches `Plug.Conn.put_resp_cookie/3,4` and `Plug.Conn.delete_resp_cookie/2,3`
  written directly, aliased, or bare-imported. Boolean-valued cookie options such as
  `:secure`, `:http_only`, `:sign`, and `:encrypt` are left to Mutare's built-in boolean
  mutators (dropping one is equivalent to flipping it to its default).
  """
  @behaviour Mutare.Mutator

  alias Mutare.AST
  alias Mutare.Calls
  alias Mutare.Plug.ConnCall

  @removable MapSet.new([
               {[:Plug, :Conn], :put_resp_cookie, 3},
               {[:Plug, :Conn], :put_resp_cookie, 4},
               {[:Plug, :Conn], :delete_resp_cookie, 2},
               {[:Plug, :Conn], :delete_resp_cookie, 3}
             ])

  # The options argument for the arity-carrying forms:
  #   put_resp_cookie(conn, key, value, opts) => effective option index 3
  #   delete_resp_cookie(conn, key, opts)     => effective option index 2
  @option_calls %{
    put_resp_cookie: {4, 3},
    delete_resp_cookie: {3, 2}
  }

  @same_site_swaps %{
    "Lax" => ["Strict", "None"],
    "Strict" => ["Lax", "None"],
    "None" => ["Lax", "Strict"]
  }

  @impl Mutare.Mutator
  @spec name() :: :resp_cookie
  def name, do: :resp_cookie

  # No `mutate/1`: removal and option position both depend on pipe context.
  @impl Mutare.Mutator
  @spec mutate(Macro.t(), Mutare.Mutator.context()) :: :skip | [Macro.t()]
  def mutate(node, %{pipe_mode: pipe_mode}) do
    combine_mutations(
      ConnCall.remove(node, pipe_mode, @removable),
      option_mutations(node, pipe_mode)
    )
  end

  defp option_mutations(node, pipe_mode) do
    case Calls.resolved_call(node) do
      {[:Plug, :Conn], call, args, rebuild} when is_map_key(@option_calls, call) ->
        option_mutations(call, args, pipe_mode, rebuild)

      _other ->
        :skip
    end
  end

  defp option_mutations(call, args, pipe_mode, rebuild) do
    {expected_arity, option_index} = Map.fetch!(@option_calls, call)

    with ^expected_arity <- Mutare.Mutator.effective_arity(args, pipe_mode),
         vis when is_integer(vis) <- Mutare.Mutator.visible_index(option_index, pipe_mode),
         [_ | _] = options <- keyword_option_mutations(call, Enum.at(args, vis), args, vis) do
      Enum.map(options, fn mutated_args -> rebuild.(call, mutated_args) end)
    else
      _other -> :skip
    end
  end

  defp keyword_option_mutations(call, arg, args, option_visible_index) do
    case keyword_list(arg) do
      nil ->
        []

      {pairs, rewrap} ->
        for {{key, value}, i} <- Enum.with_index(pairs),
            mutation <-
              pair_mutations(
                call,
                AST.key_atom(key),
                pairs,
                i,
                value,
                rewrap,
                args,
                option_visible_index
              ) do
          mutation
        end
    end
  end

  # The per-key option mutations, in pair order: the `:same_site` drop + flips (both
  # option-carrying calls), and the `:max_age` drop (`put_resp_cookie/4` only —
  # `delete_resp_cookie/3` forces `max_age: 0` regardless, so a drop there is a no-op).
  # The `:max_age` drop fires whatever the value node is (literal or dynamic): it mutates
  # the option's *presence*, so the current value never matters.
  defp pair_mutations(_call, :same_site, pairs, i, value, rewrap, args, option_visible_index) do
    for current <- same_site_value(value),
        mutation <-
          same_site_pair_mutations(pairs, i, value, current, rewrap, args, option_visible_index),
        do: mutation
  end

  defp pair_mutations(:put_resp_cookie, :max_age, pairs, i, _value, rewrap, args, vis),
    do: drop_pair(pairs, i, rewrap, args, vis)

  defp pair_mutations(_call, _key, _pairs, _i, _value, _rewrap, _args, _vis), do: []

  defp same_site_pair_mutations(pairs, index, value, current, rewrap, args, option_visible_index) do
    maybe_drop_same_site(pairs, index, current, rewrap, args, option_visible_index) ++
      flipped_same_site(pairs, index, value, current, rewrap, args, option_visible_index)
  end

  # Dropping `same_site: "Lax"` is usually equivalent to Plug's default, so only remove an
  # explicit policy when the written value differs from that default.
  defp maybe_drop_same_site(_pairs, _index, "Lax", _rewrap, _args, _option_visible_index), do: []

  defp maybe_drop_same_site(pairs, index, _current, rewrap, args, option_visible_index),
    do: drop_pair(pairs, index, rewrap, args, option_visible_index)

  # Remove one keyword pair; when it was the last, drop the whole options argument down an
  # arity (`put_resp_cookie(conn, "sid", token, max_age: ttl)` → `/3`) rather than leave a
  # dangling `[]`.
  defp drop_pair(pairs, index, rewrap, args, option_visible_index) do
    case List.delete_at(pairs, index) do
      [] -> [List.delete_at(args, option_visible_index)]
      remaining -> [List.replace_at(args, option_visible_index, rewrap.(remaining))]
    end
  end

  defp flipped_same_site(pairs, index, value, current, rewrap, args, option_visible_index) do
    for sibling <- Map.get(@same_site_swaps, current, []) do
      pairs
      |> List.replace_at(index, replace_value(pairs, index, value, sibling))
      |> then(&List.replace_at(args, option_visible_index, rewrap.(&1)))
    end
  end

  defp replace_value(pairs, index, value, sibling) do
    {key, _old_value} = Enum.at(pairs, index)
    {key, swap_literal(value, sibling)}
  end

  defp keyword_list({:__block__, meta, [inner]}) when is_list(inner) do
    with pairs when pairs != nil <- keyword_pairs(inner),
         do: {pairs, fn new -> {:__block__, meta, [new]} end}
  end

  defp keyword_list(list) when is_list(list) do
    with pairs when pairs != nil <- keyword_pairs(list), do: {pairs, & &1}
  end

  defp keyword_list(_arg), do: nil

  defp keyword_pairs(list) when is_list(list) and list != [] do
    if Enum.all?(list, &match?({_key, _value}, &1)), do: list, else: nil
  end

  defp keyword_pairs(_list), do: nil

  defp same_site_value(node) do
    case AST.literal_value(node) do
      {:ok, value} when is_binary(value) -> [value]
      _other -> []
    end
  end

  defp swap_literal({:__block__, meta, [_old]}, value), do: {:__block__, meta, [value]}
  defp swap_literal(_old, value), do: AST.literal(value)

  defp combine_mutations(left, right) do
    case mutation_list(left) ++ mutation_list(right) do
      [] -> :skip
      mutations -> mutations
    end
  end

  defp mutation_list(:skip), do: []
  defp mutation_list(mutations) when is_list(mutations), do: mutations
end
