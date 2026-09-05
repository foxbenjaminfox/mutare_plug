defmodule Demo.Api do
  @moduledoc """
  A few request handlers — the functions a `Plug.Router` dispatches to — each performing
  one response transformation whose correctness lives entirely in *which* call ran with
  *what* arguments: the status it sent, the body it wrote.
  """

  @doc "Answer the welcome payload with an explicit 200."
  def index(conn), do: Plug.Conn.send_resp(conn, :ok, "welcome")

  @doc "Create a record and answer 201 Created."
  def create(conn), do: Plug.Conn.send_resp(conn, :created, "created")

  @doc "Report liveness with a 200 and a fixed body."
  def health(conn), do: Plug.Conn.send_resp(conn, :ok, "ok")
end
