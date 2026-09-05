defmodule Demo.AuthTest do
  use ExUnit.Case

  alias Demo.Auth

  # The gaps below are deliberate — the *ordinary* gaps a competent-but-not-paranoid suite
  # leaves, each of which becomes a Mutare survivor.

  test "lets an authenticated request through unchanged" do
    conn = %Plug.Conn{assigns: %{current_user: %{id: 1}}}
    assert Auth.call(conn, []) == conn
  end

  # Asserts the 401 status — so swapping it to :forbidden is killed — but never asserts that
  # the pipeline *halted*. Drop the `halt` and an anonymous request still gets 401 set, yet
  # would now fall through to the guarded handler. The missing `assert conn.halted` is exactly
  # the gap `:plug_halt` surfaces.
  test "responds 401 to an anonymous request" do
    conn = Auth.call(%Plug.Conn{}, [])
    assert conn.status == :unauthorized
  end
end
