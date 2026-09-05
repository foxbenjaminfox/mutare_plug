defmodule Mutare.Plug.HaltTest do
  @moduledoc """
  `:plug_halt` — removes `Plug.Conn.halt/1` (the "forgot to halt" authorization mutation),
  pipe-aware: non-piped → the conn, piped → `Function.identity()`. Matches direct, aliased,
  and bare-imported (`use`-style) forms; touches nothing else.
  """
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Plug.Halt

  defp halt_diffs(source), do: diffs_for(source, [Halt], :plug_halt)

  # Wrap a plug body in a module that imports `Plug.Conn`, the `use Plug.Builder` form.
  defp plug(body), do: "defmodule MyPlug do\n  import Plug.Conn\n\n#{body}\nend\n"

  describe "removal across written forms" do
    test "a qualified Plug.Conn.halt(conn) collapses to the conn" do
      source = "defmodule P do\n  def call(conn, _o), do: Plug.Conn.halt(conn)\nend\n"
      assert halt_diffs(source) == [{"Plug.Conn.halt(conn)", "conn"}]
    end

    test "a bare imported halt(conn) (use-style) collapses to the conn" do
      assert halt_diffs(plug("  def call(conn, _o), do: halt(conn)")) ==
               [{"halt(conn)", "conn"}]
    end

    test "an aliased C.halt(conn) collapses to the conn" do
      source = """
      defmodule P do
        alias Plug.Conn, as: C
        def call(conn, _o), do: C.halt(conn)
      end
      """

      assert halt_diffs(source) == [{"C.halt(conn)", "conn"}]
    end
  end

  describe "pipe awareness" do
    test "a piped stage becomes the identity no-op (the only compile-safe removal)" do
      assert halt_diffs(plug("  def call(conn, _o), do: conn |> authorize() |> halt()")) ==
               [{"halt()", "Elixir.Function.identity()"}]
    end

    test "halt mid-chain is still removed" do
      body = "  def call(conn, _o), do: conn |> halt() |> log()"
      assert halt_diffs(plug(body)) == [{"halt()", "Elixir.Function.identity()"}]
    end

    test "a piped qualified Plug.Conn.halt() is also an identity stage" do
      source = "defmodule P do\n  def call(conn, _o), do: conn |> Plug.Conn.halt()\nend\n"

      assert halt_diffs(source) ==
               [{"Plug.Conn.halt()", "Elixir.Function.identity()"}]
    end
  end

  describe "scope" do
    test "leaves other Plug.Conn calls untouched" do
      source =
        "defmodule P do\n  def call(conn, _o), do: Plug.Conn.assign(conn, :ok, true)\nend\n"

      assert halt_diffs(source) == []
    end

    test "does not remove a same-named local halt (no import, no qualifier)" do
      source = """
      defmodule P do
        def call(conn, _o), do: halt(conn)
        def halt(c), do: c
      end
      """

      assert halt_diffs(source) == []
    end

    test "a wrong-arity halt (not Plug.Conn.halt/1) is left alone" do
      source = "defmodule P do\n  def call(conn, _o), do: Plug.Conn.halt(conn, :extra)\nend\n"
      assert halt_diffs(source) == []
    end
  end

  describe "pure-AST node path (mutations/3)" do
    test "qualified halt removes to its first argument" do
      assert node_mutations("Plug.Conn.halt(conn)", Halt) == ["conn"]
    end

    test "a piped stage node yields the identity no-op" do
      assert node_mutations("Plug.Conn.halt()", Halt, :piped) == [
               "Elixir.Function.identity()"
             ]
    end
  end

  test "every embedded mutant compiles" do
    source = """
    defmodule HaltCompileDemo do
      import Plug.Conn

      def call(conn, _o) do
        conn
        |> assign(:checked, true)
        |> halt()
      end
    end
    """

    assert_metamutant_compiles(source, [Halt])
  end
end
