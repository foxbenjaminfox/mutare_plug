defmodule Mutare.Plug.ConnCall do
  # The shared "remove a conn-transforming call" mutation for the removal families
  # (`Plug`, `Session`, `Header`, `Cookie`): match a resolved call against a
  # `{module, function, effective_arity}` set, then collapse it pipe-aware. Every
  # removable call takes the conn as its first effective argument and returns the
  # transformed conn, which is what makes both removal shapes compile-safe.
  @moduledoc false

  alias Mutare.AST
  alias Mutare.Calls

  @typep removable_call :: {Calls.module_key(), atom(), arity()}

  @doc false
  @spec remove(
          Macro.t(),
          Mutare.Mutator.pipe_mode(),
          MapSet.t(removable_call())
        ) :: :skip | [Macro.t()]
  def remove(node, pipe_mode, removable) do
    with {module, call, args, _rebuild} <- Calls.resolved_call(node),
         effective_arity when is_integer(effective_arity) <-
           Mutare.Mutator.effective_arity(args, pipe_mode),
         true <- MapSet.member?(removable, {module, call, effective_arity}) do
      removed_call(pipe_mode, args)
    else
      _other -> :skip
    end
  end

  # A piped stage (`conn |> put_session(:k, v)`) becomes `Function.identity()` — the only
  # compile-safe removal of a pipe stage. `absolute_call` emits the `Elixir.`-led alias,
  # which alias resolution never rewrites, so the no-op always names the real
  # `Function.identity/1`. A non-piped call collapses to its first argument, the conn.
  @doc false
  @spec removed_call(Mutare.Mutator.pipe_mode(), [Macro.t()]) :: :skip | [Macro.t()]
  def removed_call(:piped, _args), do: [AST.absolute_call([:Function], :identity, [])]
  def removed_call(:unpiped, []), do: :skip
  def removed_call(:unpiped, [conn | _rest]), do: [conn]
end
