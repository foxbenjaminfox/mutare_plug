defmodule Mutare.Plug.Halt do
  @moduledoc """
  `:plug_halt` — removes `Plug.Conn.halt/1`. A plug that fails to `halt` lets the request
  flow on to the action it meant to block, so a surviving `:plug_halt` mutant means no test
  depends on this plug halting.

      halt(conn)        # → conn
      conn |> halt()    # → conn |> Function.identity()

  Matches `halt` written directly (`Plug.Conn.halt(conn)`), aliased, or bare-imported
  (`halt(conn)`, the form `use Plug.Builder` / `use Plug.Router` — or Phoenix's
  `use MyAppWeb, :controller` — produces), and only `Plug.Conn.halt/1`; a `halt` at any
  other arity is a different call and is left untouched.
  """
  @behaviour Mutare.Mutator

  alias Mutare.Plug.ConnCall

  @removable MapSet.new([{[:Plug, :Conn], :halt, 1}])

  @impl Mutare.Mutator
  @spec name() :: :plug_halt
  def name, do: :plug_halt

  # No `mutate/1`: whether removal returns the first arg (non-piped) or
  # `Function.identity()` (piped) depends on pipe context, unknowable from the node
  # alone — so this family produces only through the context-aware `mutate/2`.
  @impl Mutare.Mutator
  @spec mutate(Macro.t(), Mutare.Mutator.context()) :: :skip | [Macro.t()]
  def mutate(node, %{pipe_mode: pipe_mode}), do: ConnCall.remove(node, pipe_mode, @removable)
end
