# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0 - Unreleased

Initial release.

### Added

- `Mutare.Plug.Halt` (`:plug_halt`) — removes `Plug.Conn.halt/1`, pipe-aware
  (`halt(conn)` → `conn`; a piped stage → `Function.identity()`).
- `Mutare.Plug.Status` (`:http_status`) — swaps the atom status of
  `Plug.Conn.put_status/2`, `send_resp/3`, `resp/3`, `send_chunked/2`, and
  `send_file/3,4,5` for a curated same-family sibling; per-instance configurable
  via `{module, swaps: %{...}}`.
- `Mutare.Plug.Session` (`:plug_session`) — removes `Plug.Conn.put_session/3`,
  `delete_session/2`, `clear_session/1`, and `configure_session/2` (removing
  `configure_session(conn, renew: true)` on login is the classic
  session-fixation bypass).
- `Mutare.Plug.Header` (`:resp_header`) — removes `Plug.Conn.put_resp_header/3`,
  `delete_resp_header/2`, and `put_resp_content_type/2,3`.
- `Mutare.Plug.Cookie` (`:resp_cookie`) — removes `Plug.Conn.put_resp_cookie/3,4`
  and `delete_resp_cookie/2,3`, flips/drops explicit string `same_site:` cookie
  policy options, and drops the `max_age:` option of `put_resp_cookie/4`
  (persistent cookie → session cookie).
- `Mutare.Plug.Body` (`:resp_body`) — blanks the body argument of
  `Plug.Conn.send_resp/3` and `resp/3` to `""` ("does any test read the
  response body?"); on a literal body its whole-call rewrite supersedes the
  built-in string family's sentinel leaves via Mutare's overlap pruning.
- `Mutare.Plug.all/0` for splicing all six families into a `:mutators` list.
