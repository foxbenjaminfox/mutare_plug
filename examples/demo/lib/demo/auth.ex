defmodule Demo.Auth do
  @moduledoc """
  A Plug that blocks unauthenticated requests — the canonical place a forgotten `halt`
  lets a request fall through to the handler it was meant to guard.
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
