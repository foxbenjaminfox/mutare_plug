defmodule Mutare.Plug.Halt do
  @moduledoc """
  `:plug_halt` — removes `Plug.Conn.halt/1`. Without `halt`, execution continues to
  subsequent plugs and the action, so a surviving `:plug_halt` mutant means no test
  depends on this plug halting.

      halt(conn)        # → conn
      conn |> halt()    # → conn

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

  @impl Mutare.Mutator
  @spec mutate(Macro.t()) :: :skip | [Macro.t()]
  def mutate(node), do: ConnCall.remove(node, @removable)
end
