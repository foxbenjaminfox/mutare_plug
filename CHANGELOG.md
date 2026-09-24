# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **Breaking: Mutare 0.4.0 or newer is required** (`{:mutare, "~> 0.4.0"}`). Mutare now
  offers a pipe stage to a mutator as the direct call it is sugar for, and this package
  reads every call that way; it no longer compiles against an older core.
- **A removed pipe stage collapses to what flows into it.** Every removal family
  (`:plug_halt`, `:plug_session`, `:resp_header`, `:resp_cookie`) used to replace a piped
  stage with `Function.identity()`; the mutant now reads as the stage removed, diffed over
  the pipe it shortens — `conn |> authorize() |> halt()` → `conn |> authorize()`, and
  `conn |> halt() |> log()` → `conn |> log()` shows as `conn |> halt()` → `conn`. The
  mutants themselves are unchanged. An option or status mutation on a piped stage
  (`:http_status`, `:resp_body`, the `:resp_cookie` option mutants) is still diffed at
  the stage alone.

## [0.1.0] - 2026-09-07

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

[Unreleased]: https://github.com/foxbenjaminfox/mutare_plug/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/foxbenjaminfox/mutare_plug/releases/tag/v0.1.0
