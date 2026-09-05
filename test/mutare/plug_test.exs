defmodule Mutare.PlugTest do
  @moduledoc """
  The package's preset and a cross-family integration check: a realistic plug + handler
  surface mutated by all families alongside Mutare's built-ins, recording the expected
  family names and compiling as a single metamutant.
  """
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Mutator.Dispatch

  doctest Mutare.Plug

  describe "all/0" do
    test "is the six families in order" do
      assert Mutare.Plug.all() == [
               Mutare.Plug.Halt,
               Mutare.Plug.Status,
               Mutare.Plug.Session,
               Mutare.Plug.Header,
               Mutare.Plug.Cookie,
               Mutare.Plug.Body
             ]
    end

    test "every entry resolves as a Mutare.Mutator" do
      for module <- Mutare.Plug.all() do
        assert Dispatch.implemented_by?(module)
      end
    end

    test "splices into a :mutators list after the built-ins and resolves" do
      # The usage idiom: `[:builtins] ++ Mutare.Plug.all()`. The `:builtins` token expands
      # to every built-in family in place, then this package's families follow in order.
      specs = Mutare.Mutators.resolve([:builtins] ++ Mutare.Plug.all())
      names = Enum.map(specs, & &1.name)

      assert Enum.take(names, -6) == [
               :plug_halt,
               :http_status,
               :plug_session,
               :resp_header,
               :resp_cookie,
               :resp_body
             ]

      # Spot-check the expansion across the built-in categories: an operator family,
      # and two of the per-kind value-literal families.
      assert :arithmetic in names
      assert :integer in names and :atom in names
    end

    test "a configured {module, opts} entry resolves under the same family name" do
      mutators = List.replace_at(Mutare.Plug.all(), 1, {Mutare.Plug.Status, swaps: %{}})
      specs = Mutare.Mutators.resolve(mutators)

      assert Enum.map(specs, & &1.name) == [
               :plug_halt,
               :http_status,
               :plug_session,
               :resp_header,
               :resp_cookie,
               :resp_body
             ]
    end
  end

  describe "integration across families" do
    @handlers """
    defmodule Demo.Api do
      import Plug.Conn

      def show(conn, payload) do
        conn
        |> put_status(:ok)
        |> send_resp(200, payload)
      end

      def block(conn) do
        conn
        |> put_status(:unauthorized)
        |> put_session(:blocked, true)
        |> put_resp_header("x-blocked", "true")
        |> put_resp_cookie("blocked", "true", same_site: "Strict")
        |> halt()
      end

      def health(conn), do: send_resp(conn, 200, "ok")
    end
    """

    test "each family fires on the conn transforms it owns" do
      names =
        @handlers
        |> diffs(Mutare.Plug.all())
        |> Enum.map(&elem(&1, 0))
        |> Enum.uniq()
        |> Enum.sort()

      assert names == [
               :http_status,
               :plug_halt,
               :plug_session,
               :resp_body,
               :resp_cookie,
               :resp_header
             ]
    end

    test "the whole surface compiles as one metamutant, built-ins included" do
      mutators = Mutare.Mutators.all() ++ Mutare.Plug.all()
      assert_metamutant_compiles(@handlers, mutators)
    end
  end
end
