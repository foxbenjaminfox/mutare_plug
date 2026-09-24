defmodule Mutare.Plug.ConnCall do
  # The shared "remove a conn-transforming call" mutation for the removal families
  # (`Plug`, `Session`, `Header`, `Cookie`): match a resolved call against a
  # `{module, function, arity}` set, then collapse it to its first argument. Every
  # removable call takes the conn as its first argument and returns the transformed conn,
  # which is what makes the removal compile-safe. A pipe stage arrives as the direct call
  # it is sugar for (`conn |> halt()` is offered as `halt(conn)`), so the same collapse
  # serves both spellings; the report keeps the pipe the user wrote.
  @moduledoc false

  alias Mutare.Calls

  @typep removable_call :: {Calls.module_key(), atom(), arity()}

  @doc false
  @spec remove(Macro.t(), MapSet.t(removable_call())) :: :skip | [Macro.t()]
  def remove(node, removable) do
    with {module, call, [conn | _rest] = args, _rebuild} <- Calls.resolved_call(node),
         true <- MapSet.member?(removable, {module, call, length(args)}) do
      [conn]
    else
      _other -> :skip
    end
  end
end
