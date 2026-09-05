defmodule Mutare.Plug.BodyTest do
  @moduledoc """
  `:resp_body` — blanks the body argument of `Plug.Conn.send_resp/3` and `resp/3` to
  `""`, pipe-aware, and it supersedes the built-in `:string` leaves on a literal body.
  """
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Plug.Body

  defp body_diffs(source), do: diffs_for(source, [Body], :resp_body)

  defp plug(body), do: "defmodule MyPlug do\n  import Plug.Conn\n\n#{body}\nend\n"

  describe "blanking across written forms" do
    test "qualified send_resp/3 blanks a dynamic body" do
      source = """
      defmodule P do
        def call(conn, payload), do: Plug.Conn.send_resp(conn, 200, payload)
      end
      """

      assert body_diffs(source) == [
               {"Plug.Conn.send_resp(conn, 200, payload)", "Plug.Conn.send_resp(conn, 200, \"\")"}
             ]
    end

    test "qualified resp/3 blanks a literal body" do
      source = """
      defmodule P do
        def call(conn), do: Plug.Conn.resp(conn, :ok, "pong")
      end
      """

      assert body_diffs(source) == [
               {"Plug.Conn.resp(conn, :ok, \"pong\")", "Plug.Conn.resp(conn, :ok, \"\")"}
             ]
    end

    test "a call-valued body is blanked" do
      source = """
      defmodule P do
        def call(conn, payload), do: Plug.Conn.send_resp(conn, 200, Jason.encode!(payload))
      end
      """

      assert body_diffs(source) == [
               {"Plug.Conn.send_resp(conn, 200, Jason.encode!(payload))",
                "Plug.Conn.send_resp(conn, 200, \"\")"}
             ]
    end

    test "bare imported send_resp/3 is recognised and stays bare" do
      assert body_diffs(plug(~s/  def call(conn), do: send_resp(conn, 200, "ok")/)) ==
               [{"send_resp(conn, 200, \"ok\")", "send_resp(conn, 200, \"\")"}]
    end

    test "aliased C.resp/3 is recognised" do
      source = """
      defmodule P do
        alias Plug.Conn, as: C
        def call(conn, payload), do: C.resp(conn, 200, payload)
      end
      """

      assert body_diffs(source) == [
               {"C.resp(conn, 200, payload)", "C.resp(conn, 200, \"\")"}
             ]
    end
  end

  describe "pipe awareness" do
    test "piped send_resp/3 blanks the visible body argument" do
      source = plug(~s/  def call(conn, payload), do: conn |> send_resp(:ok, payload)/)

      assert body_diffs(source) == [
               {"send_resp(:ok, payload)", "send_resp(:ok, \"\")"}
             ]
    end
  end

  describe "scope" do
    test "an already-blank literal body is left alone — the mutant would change nothing" do
      source = """
      defmodule P do
        def call(conn), do: Plug.Conn.send_resp(conn, 204, "")
      end
      """

      assert body_diffs(source) == []
    end

    test "wrong arities and path-carrying calls are left alone" do
      wrong_arity = """
      defmodule P do
        def call(conn), do: Plug.Conn.send_resp(conn, 200)
      end
      """

      send_file = """
      defmodule P do
        def call(conn, path), do: Plug.Conn.send_file(conn, 200, path)
      end
      """

      assert body_diffs(wrong_arity) == []
      assert body_diffs(send_file) == []
    end
  end

  describe "superseding the literal body's string leaves (Overlap)" do
    test "with :string also enabled, only the blank rewrite remains — no leaf mutants" do
      source = "defmodule C do\n  def show(c), do: Plug.Conn.send_resp(c, 200, \"ok\")\nend\n"
      pairs = diffs_for(source, [Body, :string], :resp_body)
      string_pairs = diffs_for(source, [Body, :string], :string)

      assert pairs == [
               {"Plug.Conn.send_resp(c, 200, \"ok\")", "Plug.Conn.send_resp(c, 200, \"\")"}
             ]

      # The rewrite covers the body node, so both `:string` leaves there — the sentinel
      # `"mutare"` and the duplicate `""` — are pruned.
      assert string_pairs == []
    end

    test "a bare imported call stays bare in the rewrite, so the pruning still applies" do
      source = plug(~s/  def call(conn), do: send_resp(conn, 200, "ok")/)
      pairs = diffs_for(source, [Body, :string], :resp_body)
      string_pairs = diffs_for(source, [Body, :string], :string)

      # Requalifying the call would make the rewrite a two-node change (form + argument),
      # a whole-host footprint that no longer covers the body node (see
      # `Mutare.Transform.Overlap`) — the bare form is what keeps the leaves pruned.
      assert pairs == [{"send_resp(conn, 200, \"ok\")", "send_resp(conn, 200, \"\")"}]
      assert string_pairs == []
    end

    test "a dynamic body's interior literals keep their own leaf mutants" do
      source = """
      defmodule C do
        def show(c, name), do: Plug.Conn.send_resp(c, 200, name <> "!")
      end
      """

      string_pairs = diffs_for(source, [Body, :string], :string)

      # The rewrite covers the whole `name <> "!"` body expression, not its descendants,
      # so the `"!"` literal inside keeps both of its `:string` leaves.
      assert {"\"!\"", "\"\""} in string_pairs
      assert {"\"!\"", "\"mutare\""} in string_pairs
    end
  end

  describe "pure-AST node path (mutations/3)" do
    test "qualified send_resp/3 blanks its body argument" do
      assert node_mutations("Plug.Conn.send_resp(conn, 200, body)", Body) == [
               "Plug.Conn.send_resp(conn, 200, \"\")"
             ]
    end
  end

  test "every embedded mutant compiles" do
    source = """
    defmodule BodyCompileDemo do
      import Plug.Conn

      def call(conn, payload) do
        conn
        |> resp(:ok, payload)
        |> send_resp(200, "done")
      end
    end
    """

    assert_metamutant_compiles(source, [Body])
  end
end
