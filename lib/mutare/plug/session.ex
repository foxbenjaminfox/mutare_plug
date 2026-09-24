defmodule Mutare.Plug.Session do
  @moduledoc """
  `:plug_session` — removes `Plug.Conn` session mutations. A surviving mutant means no test
  depends on this code writing, deleting, clearing, or reconfiguring session state.

      put_session(conn, :user_id, user.id)      # → conn
      conn |> delete_session(:user_id)          # → conn
      clear_session(conn)                       # → conn
      configure_session(conn, renew: true)      # → conn

  Removing `configure_session(conn, renew: true)` on login is the classic session-fixation
  bypass (the session id remains unchanged after authentication). Removing
  `configure_session(conn, drop: true)` on logout leaves the session in place after
  sign-out. A survivor here means no test pins that lifecycle behaviour.

  Matches `put_session/3`, `delete_session/2`, `clear_session/1`, and `configure_session/2`
  written directly (`Plug.Conn.put_session(conn, ...)`), aliased, or bare-imported. The
  boolean option *values* inside `configure_session/2` are still left to Mutare's built-in
  boolean mutators; this family only removes the call.
  """
  @behaviour Mutare.Mutator

  alias Mutare.Plug.ConnCall

  @removable MapSet.new([
               {[:Plug, :Conn], :put_session, 3},
               {[:Plug, :Conn], :delete_session, 2},
               {[:Plug, :Conn], :clear_session, 1},
               {[:Plug, :Conn], :configure_session, 2}
             ])

  @impl Mutare.Mutator
  @spec name() :: :plug_session
  def name, do: :plug_session

  @impl Mutare.Mutator
  @spec mutate(Macro.t()) :: :skip | [Macro.t()]
  def mutate(node), do: ConnCall.remove(node, @removable)
end
