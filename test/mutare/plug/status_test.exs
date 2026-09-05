defmodule Mutare.Plug.StatusTest do
  @moduledoc """
  `:http_status` — swaps the *atom* status of `Plug.Conn.put_status/2`, `send_resp/3`,
  `resp/3`, `send_chunked/2`, and `send_file/3,4,5` for a plausible same-family sibling
  (atoms only; integers stay with `Literal`). Pipe-aware, and it supersedes the crashing
  `AtomLiteral` `:mutare` leaf.
  """
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Mutator.Dispatch
  alias Mutare.Plug.Status

  defp status_diffs(source), do: diffs_for(source, [Status], :http_status)

  # The same, for a `{Status, opts}` configured instance (see "configurable :swaps table").
  defp configured_diffs(source, opts), do: diffs_for(source, [{Status, opts}], :http_status)

  # Wrap a controller body in a module importing `Plug.Conn`, the `use ..., :controller` form.
  defp controller(body), do: "defmodule MyController do\n  import Plug.Conn\n\n#{body}\nend\n"

  # The node path fed a *bare* (non-`:__block__`-wrapped) atom status — the shape a hand-built
  # `quote`/`Macro` AST carries. `Mutare.AST.parse!` (so `node_mutations/2` too) always wraps
  # atom literals in `:__block__`, so this is the only way to reach the bare-atom fallbacks in
  # `status_atom/1` (the second clause) and `swap_status/2` (the `AST.literal/1` branch).
  defp bare_node_mutations(node, mutators) do
    for %Dispatch.Result{node: mutated} <-
          Dispatch.mutations(node, List.wrap(mutators), %{pipe_mode: :unpiped}),
        do: Mutare.AST.to_string(mutated)
  end

  describe "the curated swap table" do
    test "2xx success granularity (:ok → :created / :no_content)" do
      source = "defmodule C do\n  def show(c), do: Plug.Conn.put_status(c, :ok)\nend\n"

      assert status_diffs(source) == [
               {"Plug.Conn.put_status(c, :ok)", "Plug.Conn.put_status(c, :created)"},
               {"Plug.Conn.put_status(c, :ok)", "Plug.Conn.put_status(c, :no_content)"}
             ]
    end

    test "the authorization distinction (:unauthorized → :forbidden)" do
      source = "defmodule C do\n  def show(c), do: Plug.Conn.put_status(c, :unauthorized)\nend\n"

      assert status_diffs(source) ==
               [{"Plug.Conn.put_status(c, :unauthorized)", "Plug.Conn.put_status(c, :forbidden)"}]
    end

    test "a bare imported put_status(...) (use-style) swaps the atom status" do
      source = controller("  def show(conn), do: put_status(conn, :unauthorized)")

      assert status_diffs(source) ==
               [{"put_status(conn, :unauthorized)", "put_status(conn, :forbidden)"}]
    end

    test "an aliased C.put_status(...) swaps the atom status" do
      source = """
      defmodule C do
        alias Plug.Conn, as: PC
        def show(c), do: PC.put_status(c, :unauthorized)
      end
      """

      assert status_diffs(source) ==
               [{"PC.put_status(c, :unauthorized)", "PC.put_status(c, :forbidden)"}]
    end

    test "the validation distinction (:bad_request → :unprocessable_entity)" do
      source = "defmodule C do\n  def show(c), do: Plug.Conn.put_status(c, :bad_request)\nend\n"

      assert status_diffs(source) ==
               [
                 {"Plug.Conn.put_status(c, :bad_request)",
                  "Plug.Conn.put_status(c, :unprocessable_entity)"}
               ]
    end

    test "each known status yields non-empty swaps, never the original and never :mutare" do
      for key <- [:ok, :created, :not_found, :forbidden, :internal_server_error] do
        source =
          "defmodule C do\n  def show(c), do: Plug.Conn.put_status(c, #{inspect(key)})\nend\n"

        diffs = status_diffs(source)
        assert diffs != []
        refute Enum.any?(diffs, fn {_o, m} -> String.contains?(m, ":mutare") end)
        refute Enum.any?(diffs, fn {o, m} -> o == m end)
      end
    end
  end

  describe "send_resp/3 and resp/3 — the same status seam" do
    test "send_resp/3 swaps its atom status (the second positional argument)" do
      source =
        "defmodule C do\n  def show(c), do: Plug.Conn.send_resp(c, :not_found, \"\")\nend\n"

      assert status_diffs(source) == [
               {"Plug.Conn.send_resp(c, :not_found, \"\")",
                "Plug.Conn.send_resp(c, :gone, \"\")"},
               {"Plug.Conn.send_resp(c, :not_found, \"\")",
                "Plug.Conn.send_resp(c, :forbidden, \"\")"}
             ]
    end

    test "resp/3 swaps its atom status" do
      source = "defmodule C do\n  def show(c), do: Plug.Conn.resp(c, :unauthorized, \"\")\nend\n"

      assert status_diffs(source) ==
               [{"Plug.Conn.resp(c, :unauthorized, \"\")", "Plug.Conn.resp(c, :forbidden, \"\")"}]
    end

    test "an integer status is left to Literal (no http_status mutation)" do
      source = "defmodule C do\n  def show(c), do: Plug.Conn.send_resp(c, 404, \"\")\nend\n"
      assert status_diffs(source) == []
    end

    test "a send_resp of an unexpected arity is left alone" do
      source = "defmodule C do\n  def show(c), do: Plug.Conn.send_resp(c, :ok)\nend\n"
      assert status_diffs(source) == []
    end
  end

  describe "send_chunked/2 and send_file/3,4,5 — the same status seam" do
    test "send_chunked/2 swaps its atom status" do
      source = """
      defmodule C do
        def show(c), do: Plug.Conn.send_chunked(c, :not_found)
      end
      """

      assert status_diffs(source) == [
               {"Plug.Conn.send_chunked(c, :not_found)", "Plug.Conn.send_chunked(c, :gone)"},
               {"Plug.Conn.send_chunked(c, :not_found)", "Plug.Conn.send_chunked(c, :forbidden)"}
             ]
    end

    test "send_file/3 swaps its atom status" do
      source = """
      defmodule C do
        def show(c), do: Plug.Conn.send_file(c, :ok, "/tmp/a")
      end
      """

      assert status_diffs(source) == [
               {"Plug.Conn.send_file(c, :ok, \"/tmp/a\")",
                "Plug.Conn.send_file(c, :created, \"/tmp/a\")"},
               {"Plug.Conn.send_file(c, :ok, \"/tmp/a\")",
                "Plug.Conn.send_file(c, :no_content, \"/tmp/a\")"}
             ]
    end

    test "send_file/4 swaps its atom status" do
      source = """
      defmodule C do
        def show(c), do: Plug.Conn.send_file(c, :unauthorized, "/tmp/a", 0)
      end
      """

      assert status_diffs(source) == [
               {"Plug.Conn.send_file(c, :unauthorized, \"/tmp/a\", 0)",
                "Plug.Conn.send_file(c, :forbidden, \"/tmp/a\", 0)"}
             ]
    end

    test "send_file/5 swaps its atom status" do
      source = """
      defmodule C do
        def show(c), do: Plug.Conn.send_file(c, :unauthorized, "/tmp/a", 0, 10)
      end
      """

      assert status_diffs(source) == [
               {"Plug.Conn.send_file(c, :unauthorized, \"/tmp/a\", 0, 10)",
                "Plug.Conn.send_file(c, :forbidden, \"/tmp/a\", 0, 10)"}
             ]
    end

    test "piped send_file/3 finds the status at visible index 0" do
      source = controller("  def show(conn), do: conn |> send_file(:not_found, \"/tmp/a\")")

      assert status_diffs(source) == [
               {"send_file(:not_found, \"/tmp/a\")", "send_file(:gone, \"/tmp/a\")"},
               {"send_file(:not_found, \"/tmp/a\")", "send_file(:forbidden, \"/tmp/a\")"}
             ]
    end
  end

  describe "configurable :swaps table" do
    @ok "defmodule C do\n  def show(c), do: Plug.Conn.put_status(c, :ok)\nend\n"

    test "a listed status replaces its built-in siblings" do
      assert configured_diffs(@ok, swaps: %{ok: [:accepted]}) ==
               [{"Plug.Conn.put_status(c, :ok)", "Plug.Conn.put_status(c, :accepted)"}]
    end

    test "an empty sibling list disables a status" do
      assert configured_diffs(@ok, swaps: %{ok: []}) == []
    end

    test "a status absent from the built-in table can be added" do
      source = "defmodule C do\n  def show(c), do: Plug.Conn.put_status(c, :im_a_teapot)\nend\n"

      assert configured_diffs(source, swaps: %{im_a_teapot: [:bad_request]}) ==
               [
                 {"Plug.Conn.put_status(c, :im_a_teapot)",
                  "Plug.Conn.put_status(c, :bad_request)"}
               ]
    end

    test "a status the config omits keeps its built-in siblings" do
      source = "defmodule C do\n  def show(c), do: Plug.Conn.put_status(c, :unauthorized)\nend\n"

      assert configured_diffs(source, swaps: %{ok: [:accepted]}) ==
               [{"Plug.Conn.put_status(c, :unauthorized)", "Plug.Conn.put_status(c, :forbidden)"}]
    end

    test "a malformed entry is dropped while well-formed entries still apply" do
      # Per-entry filtering, not all-or-nothing: `bad: :nope` (siblings not a list) is
      # ignored, while `ok: [:accepted]` still replaces the built-in siblings.
      assert configured_diffs(@ok, swaps: %{ok: [:accepted], bad: :nope}) ==
               [{"Plug.Conn.put_status(c, :ok)", "Plug.Conn.put_status(c, :accepted)"}]
    end

    test "a malformed :swaps option falls back to the built-in table" do
      # value not a list, a non-map :swaps, and a non-keyword opts — each ignored.
      assert configured_diffs(@ok, swaps: %{ok: :not_a_list}) == status_diffs(@ok)
      assert configured_diffs(@ok, swaps: "nonsense") == status_diffs(@ok)
      assert configured_diffs(@ok, %{not: :keyword}) == status_diffs(@ok)
    end

    test "configured siblings are trusted as-is, not checked against real statuses" do
      # The package matches Plug.Conn by name and never calls into it;
      # a configured sibling is likewise trusted to be a valid status (an invalid one is the
      # user's own crashing mutant), so a well-formed atom is emitted exactly as written.
      assert configured_diffs(@ok, swaps: %{ok: [:totally_made_up]}) ==
               [{"Plug.Conn.put_status(c, :ok)", "Plug.Conn.put_status(c, :totally_made_up)"}]
    end

    test "true/false/nil are never treated as statuses, even when configured as swap keys" do
      # `status_atom/1`'s `a not in [true, false, nil]` guard refuses boolean/nil literals, so
      # `put_status(c, true)` / `put_status(c, false)` stay untouched even when the swap table
      # maps those atoms — guarding against treating a `put_status(conn, true)` typo as a status.
      true_src = "defmodule C do\n  def show(c), do: Plug.Conn.put_status(c, true)\nend\n"
      false_src = "defmodule C do\n  def show(c), do: Plug.Conn.put_status(c, false)\nend\n"

      assert configured_diffs(true_src, swaps: %{true: [:ok]}) == []
      assert configured_diffs(false_src, swaps: %{false: [:ok]}) == []
    end
  end

  describe "pipe awareness" do
    test "a piped put_status finds the status as its lone visible argument" do
      source = controller("  def show(conn), do: conn |> put_status(:not_found)")

      assert status_diffs(source) == [
               {"put_status(:not_found)", "put_status(:gone)"},
               {"put_status(:not_found)", "put_status(:forbidden)"}
             ]
    end

    test "a piped send_resp finds the status at visible index 0 (conn is the pipe head)" do
      source = controller("  def show(conn), do: conn |> send_resp(:not_found, \"\")")

      assert status_diffs(source) == [
               {"send_resp(:not_found, \"\")", "send_resp(:gone, \"\")"},
               {"send_resp(:not_found, \"\")", "send_resp(:forbidden, \"\")"}
             ]
    end
  end

  describe "scope — left to the literal families or skipped" do
    test "an integer status is left to Literal (no http_status mutation)" do
      source = "defmodule C do\n  def show(c), do: Plug.Conn.put_status(c, 404)\nend\n"
      assert status_diffs(source) == []
    end

    test "a variable status is not swapped" do
      source = "defmodule C do\n  def show(c, s), do: Plug.Conn.put_status(c, s)\nend\n"
      assert status_diffs(source) == []
    end

    test "an unrecognised status atom is not swapped" do
      source = "defmodule C do\n  def show(c), do: Plug.Conn.put_status(c, :im_a_teapot)\nend\n"
      assert status_diffs(source) == []
    end

    test "a put_status of an unexpected arity is left alone" do
      source = "defmodule C do\n  def show(c), do: Plug.Conn.put_status(c, :ok, :extra)\nend\n"
      assert status_diffs(source) == []
    end

    test "a non-put_status Plug.Conn call is untouched" do
      source = "defmodule C do\n  def show(c), do: Plug.Conn.assign(c, :status, :ok)\nend\n"
      assert status_diffs(source) == []
    end
  end

  describe "superseding the crashing atom leaves (Overlap)" do
    test "with :atom also enabled, only the valid swaps remain — no :mutare leaf" do
      source = "defmodule C do\n  def show(c), do: Plug.Conn.put_status(c, :ok)\nend\n"
      pairs = diffs_for(source, [Status, :atom], :http_status)
      atom_pairs = diffs_for(source, [Status, :atom], :atom)

      assert pairs == [
               {"Plug.Conn.put_status(c, :ok)", "Plug.Conn.put_status(c, :created)"},
               {"Plug.Conn.put_status(c, :ok)", "Plug.Conn.put_status(c, :no_content)"}
             ]

      # The redundant crashing `:ok -> :mutare` leaf is pruned at that range.
      refute Enum.any?(atom_pairs, fn {_o, m} -> String.contains?(m, ":mutare") end)
    end

    test "the ConventionAtom :ok -> :error leaf is also superseded (it crashes as a status)" do
      # `:ok` is a convention atom, so the built-in swap is `:ok -> :error` (not `:mutare`) —
      # but `:error` is not a valid status either, so it crashes. http_status covers the same
      # range, so Overlap prunes it: no surviving `put_status(c, :error)` mutant.
      source = "defmodule C do\n  def show(c), do: Plug.Conn.put_status(c, :ok)\nend\n"
      convention_pairs = diffs_for(source, [Status, :convention], :convention)

      assert convention_pairs == []
    end
  end

  describe "pure-AST node path (mutations/3)" do
    test "qualified put_status swaps the atom status" do
      assert node_mutations("Plug.Conn.put_status(conn, :ok)", Status) == [
               "Plug.Conn.put_status(conn, :created)",
               "Plug.Conn.put_status(conn, :no_content)"
             ]
    end

    test "qualified send_resp swaps the atom status" do
      assert node_mutations("Plug.Conn.send_resp(conn, :not_found, \"\")", Status) == [
               "Plug.Conn.send_resp(conn, :gone, \"\")",
               "Plug.Conn.send_resp(conn, :forbidden, \"\")"
             ]
    end

    test "a bare (non-block-wrapped) atom status swaps via the AST.literal fallback" do
      # `Plug.Conn.put_status(conn, :ok)` with `:ok` as a bare atom, not Sourceror's
      # `{:__block__, _, [:ok]}` — exercises `status_atom/1`'s second clause and
      # `swap_status/2`'s `AST.literal/1` branch, which parsed sources never hit.
      node =
        {{:., [], [{:__aliases__, [], [:Plug, :Conn]}, :put_status]}, [], [{:conn, [], nil}, :ok]}

      assert bare_node_mutations(node, Status) == [
               "Plug.Conn.put_status(conn, :created)",
               "Plug.Conn.put_status(conn, :no_content)"
             ]
    end
  end

  test "every embedded mutant compiles" do
    source = """
    defmodule StatusCompileDemo do
      import Plug.Conn

      def create(conn) do
        conn
        |> put_status(:created)
        |> put_status(:unauthorized)
      end

      def send_it(conn), do: send_resp(conn, :not_found, "")
      def resp_it(conn), do: resp(conn, :unauthorized, "")
      def chunk_it(conn), do: send_chunked(conn, :ok)
      def file_it(conn), do: send_file(conn, :not_found, "/tmp/a")
      def file_offset_it(conn), do: send_file(conn, :unauthorized, "/tmp/a", 0)
      def file_range_it(conn), do: send_file(conn, :unauthorized, "/tmp/a", 0, 10)
    end
    """

    assert_metamutant_compiles(source, [Status])
  end
end
