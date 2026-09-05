defmodule Mutare.Plug do
  @moduledoc """
  Custom [Mutare](https://hex.pm/packages/mutare) mutators for the Plug request surface —
  the `Plug.Conn` calls a plug, router, or controller action performs on the conn.

  ## Usage

  Add `mutare_plug` to your deps, then list its families in `.mutare.exs`. Setting
  `:mutators` replaces Mutare's default set, so include the `:builtins` family to keep the
  built-ins on:

      # .mutare.exs
      [mutators: [:builtins] ++ Mutare.Plug.all()]

  `all/0` returns this package's six families:

    * `Mutare.Plug.Halt` — `:plug_halt`, removes `Plug.Conn.halt/1`.
    * `Mutare.Plug.Status` — `:http_status`, swaps the atom status of
      `Plug.Conn.put_status/2`, `send_resp/3`, `resp/3`, `send_chunked/2`, and
      `send_file/3,4,5` for a same-family sibling.
    * `Mutare.Plug.Session` — `:plug_session`, removes session mutations,
      `configure_session/2` included.
    * `Mutare.Plug.Header` — `:resp_header`, removes response-header mutations,
      `put_resp_content_type/2,3` included.
    * `Mutare.Plug.Cookie` — `:resp_cookie`, removes response-cookie mutations,
      flips explicit `:same_site` values, and drops explicit `:max_age` options.
    * `Mutare.Plug.Body` — `:resp_body`, blanks the body of `Plug.Conn.send_resp/3`
      and `resp/3` to `""`.

  Each family matches its call written directly (`Plug.Conn.halt(conn)`), aliased, or
  bare-imported (`halt(conn)`, the form `use Plug.Builder` / `use Plug.Router` — or
  Phoenix's `use MyAppWeb, :controller` — produces).

  A Phoenix app composes these with the companion `mutare_phoenix`, which adds the
  `Phoenix.Controller` families on top the way `phoenix` builds on `plug`.
  """

  # Mutators pattern-match module *names* (`Plug.Conn`), so this package does not depend
  # on `plug` — resolution happens in the target project, where it is present. The
  # `Phoenix.Controller` surface is out of scope; it is the companion `mutare_phoenix`.
  @families [
    Mutare.Plug.Halt,
    Mutare.Plug.Status,
    Mutare.Plug.Session,
    Mutare.Plug.Header,
    Mutare.Plug.Cookie,
    Mutare.Plug.Body
  ]

  @doc """
  This package's six mutator families, for splicing into `:mutators` (see the module
  docs for the `:builtins` pairing).

      iex> Mutare.Plug.all() == [
      ...>   Mutare.Plug.Halt,
      ...>   Mutare.Plug.Status,
      ...>   Mutare.Plug.Session,
      ...>   Mutare.Plug.Header,
      ...>   Mutare.Plug.Cookie,
      ...>   Mutare.Plug.Body
      ...> ]
      true
  """
  @spec all() :: [module()]
  def all, do: @families
end
