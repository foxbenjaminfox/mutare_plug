# A minimal stand-in for the slice of `Plug.Conn` the demo uses, so the project runs with no
# real Plug dependency. `mutare_plug` matches calls by module *name* (`Plug.Conn`), so the
# mutations against this stand-in are identical to what they would be against the real
# module. It lives outside `lib/demo`, so `.mutare.exs`'s `paths: ["lib/demo"]` leaves it
# unmutated.
defmodule Plug.Conn do
  @moduledoc "Tiny stand-in for `Plug.Conn`."
  defstruct status: nil, halted: false, assigns: %{}, resp_body: nil

  def put_status(%__MODULE__{} = conn, status), do: %{conn | status: status}
  def halt(%__MODULE__{} = conn), do: %{conn | halted: true}

  def send_resp(%__MODULE__{} = conn, status, body),
    do: %{conn | status: status, resp_body: body}
end
