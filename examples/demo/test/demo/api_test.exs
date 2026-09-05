defmodule Demo.ApiTest do
  use ExUnit.Case

  alias Demo.Api

  # index is pinned down: it asserts the exact 200 *and* the body, so every mutant there —
  # a swapped status, a blanked body — is killed.
  test "index answers 200 with the welcome body" do
    conn = Api.index(%Plug.Conn{})
    assert conn.status == :ok
    assert conn.resp_body == "welcome"
  end

  # create asserts only the *body*, never the status — so swapping :created for another
  # success (:ok / :accepted) is invisible. A missing status assertion: `:http_status`
  # survives.
  test "create answers with the created body" do
    conn = Api.create(%Plug.Conn{})
    assert conn.resp_body == "created"
  end

  # health asserts only the *status*, never the body — so blanking the body to "" is
  # invisible. A missing body assertion: `:resp_body` survives.
  test "health answers 200" do
    conn = Api.health(%Plug.Conn{})
    assert conn.status == :ok
  end
end
