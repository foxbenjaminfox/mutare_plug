defmodule Mutare.Plug.Header do
  @moduledoc """
  `:resp_header` — removes explicit response-header mutations. A surviving mutant means no
  test depends on this code setting or deleting that response header.

      put_resp_header(conn, "cache-control", "no-store")  # → conn
      conn |> delete_resp_header("x-legacy")              # → conn |> Function.identity()
      put_resp_content_type(conn, "application/json")     # → conn

  Removing `put_resp_content_type/2,3` leaves the response on the upstream (or default)
  content type, so a survivor means no test pins the response's `content-type` header —
  the charset-carrying arity 3 included.

  Matches `Plug.Conn.put_resp_header/3`, `Plug.Conn.delete_resp_header/2`, and
  `Plug.Conn.put_resp_content_type/2,3` written directly, aliased, or bare-imported. String
  values themselves are left to Mutare's built-in string mutators.
  """
  @behaviour Mutare.Mutator

  alias Mutare.Plug.ConnCall

  @removable MapSet.new([
               {[:Plug, :Conn], :put_resp_header, 3},
               {[:Plug, :Conn], :delete_resp_header, 2},
               {[:Plug, :Conn], :put_resp_content_type, 2},
               {[:Plug, :Conn], :put_resp_content_type, 3}
             ])

  @impl Mutare.Mutator
  @spec name() :: :resp_header
  def name, do: :resp_header

  # No `mutate/1`: removal shape depends on pipe context.
  @impl Mutare.Mutator
  @spec mutate(Macro.t(), Mutare.Mutator.context()) :: :skip | [Macro.t()]
  def mutate(node, %{pipe_mode: pipe_mode}), do: ConnCall.remove(node, pipe_mode, @removable)
end
