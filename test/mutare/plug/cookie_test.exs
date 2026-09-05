defmodule Mutare.Plug.CookieTest do
  @moduledoc """
  `:resp_cookie` — removes `Plug.Conn.put_resp_cookie/3,4` and
  `delete_resp_cookie/2,3`, flips explicit string `:same_site` values, and drops the
  `:max_age` option of `put_resp_cookie/4`.
  """
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Plug.Cookie

  defp cookie_diffs(source), do: diffs_for(source, [Cookie], :resp_cookie)

  defp plug(body), do: "defmodule MyPlug do\n  import Plug.Conn\n\n#{body}\nend\n"

  describe "response-cookie call removal" do
    test "qualified put_resp_cookie/3 collapses to the conn" do
      source = """
      defmodule P do
        def call(conn, token), do: Plug.Conn.put_resp_cookie(conn, "sid", token)
      end
      """

      assert cookie_diffs(source) == [
               {"Plug.Conn.put_resp_cookie(conn, \"sid\", token)", "conn"}
             ]
    end

    test "qualified delete_resp_cookie/2 collapses to the conn" do
      source = """
      defmodule P do
        def call(conn), do: Plug.Conn.delete_resp_cookie(conn, "sid")
      end
      """

      assert cookie_diffs(source) == [{"Plug.Conn.delete_resp_cookie(conn, \"sid\")", "conn"}]
    end

    test "bare imported and aliased calls are recognised" do
      imported = plug(~s/  def call(conn, token), do: put_resp_cookie(conn, "sid", token)/)

      aliased = """
      defmodule P do
        alias Plug.Conn, as: C
        def call(conn), do: C.delete_resp_cookie(conn, "sid")
      end
      """

      assert cookie_diffs(imported) == [{"put_resp_cookie(conn, \"sid\", token)", "conn"}]
      assert cookie_diffs(aliased) == [{"C.delete_resp_cookie(conn, \"sid\")", "conn"}]
    end

    test "piped cookie calls become identity stages" do
      source =
        plug(
          ~s/  def call(conn, token), do: conn |> put_resp_cookie("sid", token) |> delete_resp_cookie("old")/
        )

      assert cookie_diffs(source) == [
               {"put_resp_cookie(\"sid\", token)", "Elixir.Function.identity()"},
               {"delete_resp_cookie(\"old\")", "Elixir.Function.identity()"}
             ]
    end
  end

  describe "same_site option mutations" do
    test "put_resp_cookie/4 flips SameSite values and drops non-default explicit policy" do
      source = """
      defmodule P do
        def call(conn, token) do
          Plug.Conn.put_resp_cookie(conn, "sid", token, same_site: "Strict")
        end
      end
      """

      assert cookie_diffs(source) == [
               {"Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"Strict\")", "conn"},
               {"Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"Strict\")",
                "Plug.Conn.put_resp_cookie(conn, \"sid\", token)"},
               {"Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"Strict\")",
                "Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"Lax\")"},
               {"Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"Strict\")",
                "Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"None\")"}
             ]
    end

    test "put_resp_cookie/4 keeps other options when dropping same_site" do
      source = """
      defmodule P do
        def call(conn, token) do
          Plug.Conn.put_resp_cookie(conn, "sid", token, same_site: "None", path: "/")
        end
      end
      """

      assert cookie_diffs(source) == [
               {"Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"None\", path: \"/\")",
                "conn"},
               {"Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"None\", path: \"/\")",
                "Plug.Conn.put_resp_cookie(conn, \"sid\", token, path: \"/\")"},
               {"Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"None\", path: \"/\")",
                "Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"Lax\", path: \"/\")"},
               {"Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"None\", path: \"/\")",
                "Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"Strict\", path: \"/\")"}
             ]
    end

    test "explicit bracketed options list is recognised" do
      source = """
      defmodule P do
        def call(conn, token) do
          Plug.Conn.put_resp_cookie(conn, "sid", token, [same_site: "Strict"])
        end
      end
      """

      assert cookie_diffs(source) == [
               {"Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"Strict\")", "conn"},
               {"Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"Strict\")",
                "Plug.Conn.put_resp_cookie(conn, \"sid\", token)"},
               {"Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"Strict\")",
                "Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"Lax\")"},
               {"Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"Strict\")",
                "Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"None\")"}
             ]
    end

    test "same_site: Lax is flipped but not dropped as an equivalent default" do
      source = """
      defmodule P do
        def call(conn, token) do
          Plug.Conn.put_resp_cookie(conn, "sid", token, same_site: "Lax")
        end
      end
      """

      assert cookie_diffs(source) == [
               {"Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"Lax\")", "conn"},
               {"Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"Lax\")",
                "Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"Strict\")"},
               {"Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"Lax\")",
                "Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"None\")"}
             ]
    end

    test "piped put_resp_cookie/4 mutates the visible options argument" do
      source =
        plug(
          ~s/  def call(conn, token), do: conn |> put_resp_cookie("sid", token, same_site: "Strict")/
        )

      assert cookie_diffs(source) == [
               {"put_resp_cookie(\"sid\", token, same_site: \"Strict\")",
                "Elixir.Function.identity()"},
               {"put_resp_cookie(\"sid\", token, same_site: \"Strict\")",
                "put_resp_cookie(\"sid\", token)"},
               {"put_resp_cookie(\"sid\", token, same_site: \"Strict\")",
                "put_resp_cookie(\"sid\", token, same_site: \"Lax\")"},
               {"put_resp_cookie(\"sid\", token, same_site: \"Strict\")",
                "put_resp_cookie(\"sid\", token, same_site: \"None\")"}
             ]
    end

    test "delete_resp_cookie/3 same_site option is mutated too" do
      source = """
      defmodule P do
        def call(conn), do: Plug.Conn.delete_resp_cookie(conn, "sid", same_site: "Strict")
      end
      """

      assert cookie_diffs(source) == [
               {"Plug.Conn.delete_resp_cookie(conn, \"sid\", same_site: \"Strict\")", "conn"},
               {"Plug.Conn.delete_resp_cookie(conn, \"sid\", same_site: \"Strict\")",
                "Plug.Conn.delete_resp_cookie(conn, \"sid\")"},
               {"Plug.Conn.delete_resp_cookie(conn, \"sid\", same_site: \"Strict\")",
                "Plug.Conn.delete_resp_cookie(conn, \"sid\", same_site: \"Lax\")"},
               {"Plug.Conn.delete_resp_cookie(conn, \"sid\", same_site: \"Strict\")",
                "Plug.Conn.delete_resp_cookie(conn, \"sid\", same_site: \"None\")"}
             ]
    end
  end

  describe "max_age option drop" do
    test "put_resp_cookie/4 drops max_age, turning a persistent cookie into a session cookie" do
      source = """
      defmodule P do
        def call(conn, token) do
          Plug.Conn.put_resp_cookie(conn, "sid", token, max_age: 3600)
        end
      end
      """

      assert cookie_diffs(source) == [
               {"Plug.Conn.put_resp_cookie(conn, \"sid\", token, max_age: 3600)", "conn"},
               {"Plug.Conn.put_resp_cookie(conn, \"sid\", token, max_age: 3600)",
                "Plug.Conn.put_resp_cookie(conn, \"sid\", token)"}
             ]
    end

    test "other options are kept when dropping max_age" do
      source = """
      defmodule P do
        def call(conn, token) do
          Plug.Conn.put_resp_cookie(conn, "sid", token, max_age: 3600, path: "/")
        end
      end
      """

      assert cookie_diffs(source) == [
               {"Plug.Conn.put_resp_cookie(conn, \"sid\", token, max_age: 3600, path: \"/\")",
                "conn"},
               {"Plug.Conn.put_resp_cookie(conn, \"sid\", token, max_age: 3600, path: \"/\")",
                "Plug.Conn.put_resp_cookie(conn, \"sid\", token, path: \"/\")"}
             ]
    end

    test "a dynamic max_age value is dropped too — the mutation is the option's presence" do
      source = """
      defmodule P do
        def call(conn, token, ttl) do
          Plug.Conn.put_resp_cookie(conn, "sid", token, max_age: ttl)
        end
      end
      """

      assert cookie_diffs(source) == [
               {"Plug.Conn.put_resp_cookie(conn, \"sid\", token, max_age: ttl)", "conn"},
               {"Plug.Conn.put_resp_cookie(conn, \"sid\", token, max_age: ttl)",
                "Plug.Conn.put_resp_cookie(conn, \"sid\", token)"}
             ]
    end

    test "piped put_resp_cookie/4 drops max_age at the visible options argument" do
      source =
        plug(~s/  def call(conn, token), do: conn |> put_resp_cookie("sid", token, max_age: 60)/)

      assert cookie_diffs(source) == [
               {"put_resp_cookie(\"sid\", token, max_age: 60)", "Elixir.Function.identity()"},
               {"put_resp_cookie(\"sid\", token, max_age: 60)", "put_resp_cookie(\"sid\", token)"}
             ]
    end

    test "same_site and max_age mutations combine in pair order" do
      source = """
      defmodule P do
        def call(conn, token) do
          Plug.Conn.put_resp_cookie(conn, "sid", token, same_site: "Strict", max_age: 60)
        end
      end
      """

      original =
        "Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"Strict\", max_age: 60)"

      assert cookie_diffs(source) == [
               {original, "conn"},
               {original, "Plug.Conn.put_resp_cookie(conn, \"sid\", token, max_age: 60)"},
               {original,
                "Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"Lax\", max_age: 60)"},
               {original,
                "Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"None\", max_age: 60)"},
               {original,
                "Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: \"Strict\")"}
             ]
    end

    test "delete_resp_cookie/3 max_age is left alone — Plug forces max_age: 0 there anyway" do
      source = """
      defmodule P do
        def call(conn), do: Plug.Conn.delete_resp_cookie(conn, "sid", max_age: 0)
      end
      """

      assert cookie_diffs(source) == [
               {"Plug.Conn.delete_resp_cookie(conn, \"sid\", max_age: 0)", "conn"}
             ]
    end
  end

  describe "scope" do
    test "wrong arities and dynamic same_site values contribute only valid call removals" do
      wrong_arity = """
      defmodule P do
        def call(conn), do: Plug.Conn.put_resp_cookie(conn, "sid")
      end
      """

      dynamic_same_site = """
      defmodule P do
        def call(conn, token, mode) do
          Plug.Conn.put_resp_cookie(conn, "sid", token, same_site: mode)
        end
      end
      """

      assert cookie_diffs(wrong_arity) == []

      assert cookie_diffs(dynamic_same_site) == [
               {"Plug.Conn.put_resp_cookie(conn, \"sid\", token, same_site: mode)", "conn"}
             ]
    end
  end

  describe "pure-AST node path (mutations/3)" do
    test "qualified put_resp_cookie/3 removes to its first argument" do
      assert node_mutations("Plug.Conn.put_resp_cookie(conn, \"sid\", token)", Cookie) == [
               "conn"
             ]
    end
  end

  test "every embedded mutant compiles" do
    source = """
    defmodule CookieCompileDemo do
      import Plug.Conn

      def call(conn, token) do
        conn
        |> put_resp_cookie("sid", token, same_site: "Strict", max_age: 3600)
        |> put_resp_cookie("theme", "dark", max_age: 60)
        |> delete_resp_cookie("old", same_site: "None")
      end
    end
    """

    assert_metamutant_compiles(source, [Cookie])
  end
end
