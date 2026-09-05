defmodule Mutare.Plug.SessionTest do
  @moduledoc """
  `:plug_session` — removes `Plug.Conn.put_session/3`, `delete_session/2`,
  `clear_session/1`, and `configure_session/2`, pipe-aware.
  """
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Plug.Session

  defp session_diffs(source), do: diffs_for(source, [Session], :plug_session)

  defp plug(body), do: "defmodule MyPlug do\n  import Plug.Conn\n\n#{body}\nend\n"

  describe "removal across written forms" do
    test "qualified put_session/3 collapses to the conn" do
      source = """
      defmodule P do
        def call(conn), do: Plug.Conn.put_session(conn, :user_id, 1)
      end
      """

      assert session_diffs(source) == [{"Plug.Conn.put_session(conn, :user_id, 1)", "conn"}]
    end

    test "qualified delete_session/2 collapses to the conn" do
      source = """
      defmodule P do
        def call(conn), do: Plug.Conn.delete_session(conn, :user_id)
      end
      """

      assert session_diffs(source) == [{"Plug.Conn.delete_session(conn, :user_id)", "conn"}]
    end

    test "qualified clear_session/1 collapses to the conn" do
      source = """
      defmodule P do
        def call(conn), do: Plug.Conn.clear_session(conn)
      end
      """

      assert session_diffs(source) == [{"Plug.Conn.clear_session(conn)", "conn"}]
    end

    test "qualified configure_session/2 collapses to the conn — the session-fixation bypass" do
      source = """
      defmodule P do
        def call(conn), do: Plug.Conn.configure_session(conn, renew: true)
      end
      """

      assert session_diffs(source) == [
               {"Plug.Conn.configure_session(conn, renew: true)", "conn"}
             ]
    end

    test "bare imported put_session/3 is recognised" do
      assert session_diffs(plug("  def call(conn), do: put_session(conn, :user_id, 1)")) ==
               [{"put_session(conn, :user_id, 1)", "conn"}]
    end

    test "aliased C.delete_session/2 is recognised" do
      source = """
      defmodule P do
        alias Plug.Conn, as: C
        def call(conn), do: C.delete_session(conn, :user_id)
      end
      """

      assert session_diffs(source) == [{"C.delete_session(conn, :user_id)", "conn"}]
    end
  end

  describe "pipe awareness" do
    test "piped put_session/3 becomes an identity stage" do
      source = plug("  def call(conn), do: conn |> put_session(:user_id, 1)")

      assert session_diffs(source) == [
               {"put_session(:user_id, 1)", "Elixir.Function.identity()"}
             ]
    end

    test "piped clear_session/1 becomes an identity stage" do
      source = plug("  def call(conn), do: conn |> clear_session() |> assign(:next, true)")

      assert session_diffs(source) == [{"clear_session()", "Elixir.Function.identity()"}]
    end

    test "piped configure_session/2 becomes an identity stage" do
      source = plug("  def call(conn), do: conn |> configure_session(drop: true)")

      assert session_diffs(source) == [
               {"configure_session(drop: true)", "Elixir.Function.identity()"}
             ]
    end
  end

  describe "scope" do
    test "wrong arities and non-mutating Plug.Conn calls are left alone" do
      wrong_arity = """
      defmodule P do
        def call(conn), do: Plug.Conn.put_session(conn, :user_id)
      end
      """

      non_mutating = """
      defmodule P do
        def call(conn), do: Plug.Conn.get_session(conn, :user_id)
      end
      """

      assert session_diffs(wrong_arity) == []
      assert session_diffs(non_mutating) == []
    end
  end

  describe "pure-AST node path (mutations/3)" do
    test "qualified put_session/3 removes to its first argument" do
      assert node_mutations("Plug.Conn.put_session(conn, :user_id, 1)", Session) == ["conn"]
    end
  end

  test "every embedded mutant compiles" do
    source = """
    defmodule SessionCompileDemo do
      import Plug.Conn

      def call(conn) do
        conn
        |> put_session(:user_id, 1)
        |> delete_session(:legacy)
        |> configure_session(renew: true)
        |> clear_session()
      end
    end
    """

    assert_metamutant_compiles(source, [Session])
  end
end
