defmodule Demo.Auth do
  @moduledoc """
  A Plug that blocks unauthenticated requests. Omitting `halt` allows execution to
  continue to the protected handler.
  """

  @doc """
  Let an authenticated request through unchanged; otherwise set `401` and **halt** the
  pipeline so the guarded handler never runs.
  """
  def call(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> Plug.Conn.put_status(:unauthorized)
      |> Plug.Conn.halt()
    end
  end
end
