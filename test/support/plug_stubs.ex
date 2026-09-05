# A minimal stand-in for the `Plug.Conn` surface, loaded only in the test environment.
# `mutare_plug` does not depend on `plug` (it matches on the module *name*), so this tiny
# module lets the test suite:
#
#   * resolve a **bare imported** call (`import Plug.Conn; put_status(conn, :ok)`) — the form
#     `use Plug.Builder` / `use Plug.Router` produces — which `Mutare.Transform.Imports`
#     resolves by reflecting on the imported module's exported arities, so the module must be
#     loadable;
#   * compile a generated metamutant without "undefined function" warnings.
#
# It carries no behaviour worth testing — the mutators operate on source AST, not a live
# conn — so the bodies are the smallest thing that type-checks as `conn -> conn`.
defmodule Plug.Conn do
  @moduledoc false
  defstruct status: nil,
            halted: false,
            assigns: %{},
            resp_headers: [],
            resp_body: nil,
            resp_cookies: %{}

  def put_status(%__MODULE__{} = conn, status), do: %{conn | status: status}
  def halt(%__MODULE__{} = conn), do: %{conn | halted: true}

  def assign(%__MODULE__{} = conn, key, value),
    do: %{conn | assigns: Map.put(conn.assigns, key, value)}

  def put_resp_content_type(%__MODULE__{} = conn, type),
    do: %{conn | resp_headers: [{"content-type", type} | conn.resp_headers]}

  def put_resp_content_type(%__MODULE__{} = conn, type, charset),
    do: put_resp_content_type(conn, "#{type}; charset=#{charset}")

  def send_resp(%__MODULE__{} = conn, status, body),
    do: %{conn | status: status, resp_body: body}

  def resp(%__MODULE__{} = conn, status, body),
    do: %{conn | status: status, resp_body: body}

  def send_chunked(%__MODULE__{} = conn, status), do: %{conn | status: status}

  def send_file(%__MODULE__{} = conn, status, path),
    do: %{conn | status: status, resp_body: path}

  def send_file(%__MODULE__{} = conn, status, path, _offset),
    do: %{conn | status: status, resp_body: path}

  def send_file(%__MODULE__{} = conn, status, path, _offset, _length),
    do: %{conn | status: status, resp_body: path}

  def put_session(%__MODULE__{} = conn, key, value),
    do: assign(conn, :session, Map.put(Map.get(conn.assigns, :session, %{}), key, value))

  def delete_session(%__MODULE__{} = conn, key),
    do: assign(conn, :session, Map.delete(Map.get(conn.assigns, :session, %{}), key))

  def clear_session(%__MODULE__{} = conn), do: assign(conn, :session, %{})

  def configure_session(%__MODULE__{} = conn, _opts), do: conn

  def delete_resp_header(%__MODULE__{} = conn, key),
    do: %{conn | resp_headers: List.keydelete(conn.resp_headers, key, 0)}

  def put_resp_header(%__MODULE__{} = conn, key, value),
    do: %{conn | resp_headers: [{key, value} | List.keydelete(conn.resp_headers, key, 0)]}

  def put_resp_cookie(%__MODULE__{} = conn, key, value),
    do: put_resp_cookie(conn, key, value, [])

  def put_resp_cookie(%__MODULE__{} = conn, key, value, opts),
    do: %{conn | resp_cookies: Map.put(conn.resp_cookies, key, {value, opts})}

  def delete_resp_cookie(%__MODULE__{} = conn, key), do: delete_resp_cookie(conn, key, [])

  def delete_resp_cookie(%__MODULE__{} = conn, key, opts),
    do: %{conn | resp_cookies: Map.put(conn.resp_cookies, key, {:delete, opts})}
end
