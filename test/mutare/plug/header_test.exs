defmodule Mutare.Plug.HeaderTest do
  @moduledoc """
  `:resp_header` — removes `Plug.Conn.put_resp_header/3`, `delete_resp_header/2`, and
  `put_resp_content_type/2,3`, pipe-aware.
  """
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Plug.Header

  defp header_diffs(source), do: diffs_for(source, [Header], :resp_header)

  defp plug(body), do: "defmodule MyPlug do\n  import Plug.Conn\n\n#{body}\nend\n"

  describe "removal across written forms" do
    test "qualified put_resp_header/3 collapses to the conn" do
      source = """
      defmodule P do
        def call(conn), do: Plug.Conn.put_resp_header(conn, "cache-control", "no-store")
      end
      """

      assert header_diffs(source) == [
               {"Plug.Conn.put_resp_header(conn, \"cache-control\", \"no-store\")", "conn"}
             ]
    end

    test "qualified delete_resp_header/2 collapses to the conn" do
      source = """
      defmodule P do
        def call(conn), do: Plug.Conn.delete_resp_header(conn, "x-legacy")
      end
      """

      assert header_diffs(source) == [
               {"Plug.Conn.delete_resp_header(conn, \"x-legacy\")", "conn"}
             ]
    end

    test "qualified put_resp_content_type/2 collapses to the conn" do
      source = """
      defmodule P do
        def call(conn), do: Plug.Conn.put_resp_content_type(conn, "application/json")
      end
      """

      assert header_diffs(source) == [
               {"Plug.Conn.put_resp_content_type(conn, \"application/json\")", "conn"}
             ]
    end

    test "qualified put_resp_content_type/3 with a charset collapses to the conn" do
      source = """
      defmodule P do
        def call(conn), do: Plug.Conn.put_resp_content_type(conn, "text/html", "latin1")
      end
      """

      assert header_diffs(source) == [
               {"Plug.Conn.put_resp_content_type(conn, \"text/html\", \"latin1\")", "conn"}
             ]
    end

    test "bare imported and aliased calls are recognised" do
      imported = plug(~s/  def call(conn), do: put_resp_header(conn, "x-a", "1")/)

      aliased = """
      defmodule P do
        alias Plug.Conn, as: C
        def call(conn), do: C.delete_resp_header(conn, "x-a")
      end
      """

      assert header_diffs(imported) == [{"put_resp_header(conn, \"x-a\", \"1\")", "conn"}]
      assert header_diffs(aliased) == [{"C.delete_resp_header(conn, \"x-a\")", "conn"}]
    end
  end

  describe "pipe awareness" do
    test "piped header calls become identity stages" do
      source =
        plug(
          ~s/  def call(conn), do: conn |> put_resp_header("cache-control", "no-store") |> delete_resp_header("x-a")/
        )

      assert header_diffs(source) == [
               {"put_resp_header(\"cache-control\", \"no-store\")", "Elixir.Function.identity()"},
               {"delete_resp_header(\"x-a\")", "Elixir.Function.identity()"}
             ]
    end

    test "piped put_resp_content_type/2 becomes an identity stage" do
      source = plug(~s/  def call(conn), do: conn |> put_resp_content_type("text\/plain")/)

      assert header_diffs(source) == [
               {"put_resp_content_type(\"text/plain\")", "Elixir.Function.identity()"}
             ]
    end
  end

  describe "scope" do
    test "wrong arities and header readers are left alone" do
      wrong_arity = """
      defmodule P do
        def call(conn), do: Plug.Conn.put_resp_header(conn, "x-a")
      end
      """

      reader = """
      defmodule P do
        def call(conn), do: Plug.Conn.get_resp_header(conn, "x-a")
      end
      """

      assert header_diffs(wrong_arity) == []
      assert header_diffs(reader) == []
    end
  end

  describe "pure-AST node path (mutations/3)" do
    test "qualified put_resp_header/3 removes to its first argument" do
      assert node_mutations("Plug.Conn.put_resp_header(conn, \"x-a\", \"1\")", Header) == [
               "conn"
             ]
    end
  end

  test "every embedded mutant compiles" do
    source = """
    defmodule HeaderCompileDemo do
      import Plug.Conn

      def call(conn) do
        conn
        |> put_resp_header("cache-control", "no-store")
        |> put_resp_content_type("application/json")
        |> put_resp_content_type("text/html", "latin1")
        |> delete_resp_header("x-legacy")
      end
    end
    """

    assert_metamutant_compiles(source, [Header])
  end
end
