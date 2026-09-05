# Mutare Plug

Custom [Mutare](https://hex.pm/packages/mutare) mutators for the **Plug request surface** —
the `Plug.Conn` calls a plug, router, or controller action performs on the conn.

A plug returns a *transformed conn*, so its whole contract is **which conn-transforming call
ran** — the status/header/session/cookie it set, the body it sent, whether it halted. These
are exactly the calls a suite tends to under-assert: a test that checks "something happened"
but not *which* transformation leaves a gap. `mutare_plug` turns each such gap into a located
[Mutare](https://hex.pm/packages/mutare) survivor.

## The families

`Mutare.Plug.all/0` returns six mutator families:

| Family | Name | Mutation | The gap a survivor exposes |
| --- | --- | --- | --- |
| `Mutare.Plug.Halt` | `:plug_halt` | removes `Plug.Conn.halt/1` | no test depends on this plug *halting* — the classic authorization-bypass |
| `Mutare.Plug.Status` | `:http_status` | swaps the atom status of `Plug.Conn.put_status/2`, `send_resp/3`, `resp/3`, `send_chunked/2`, and `send_file/3,4,5` for a same-family sibling (`:ok → :created`, `:unauthorized → :forbidden`) | no test pins the exact status |
| `Mutare.Plug.Session` | `:plug_session` | removes `Plug.Conn.put_session/3`, `delete_session/2`, `clear_session/1`, and `configure_session/2` | no test depends on the session mutation — removing `configure_session(conn, renew: true)` on login is the classic session-fixation bypass |
| `Mutare.Plug.Header` | `:resp_header` | removes `Plug.Conn.put_resp_header/3`, `delete_resp_header/2`, and `put_resp_content_type/2,3` | no test depends on the response header — or pins the content type |
| `Mutare.Plug.Cookie` | `:resp_cookie` | removes `Plug.Conn.put_resp_cookie/3,4` and `delete_resp_cookie/2,3`, flips explicit string `same_site:` values, and drops the `max_age:` option (persistent cookie → session cookie) | no test depends on the response cookie, its SameSite policy, or its lifetime |
| `Mutare.Plug.Body` | `:resp_body` | blanks the body argument of `Plug.Conn.send_resp/3` and `resp/3` to `""` | no test reads the response body |

Each family matches its call written directly (`Plug.Conn.halt(conn)`), aliased, or
bare-imported (`halt(conn)`, the form `use Plug.Builder` / `use Plug.Router` — or Phoenix's
`use MyAppWeb, :controller` — produces). Integer statuses (`put_status(conn, 200)`) are left
to Mutare's built-in literal family; `:http_status` only swaps *atom* statuses.

## Usage

`mutare_plug` rides on the [Mutare](https://hex.pm/packages/mutare) engine, so add both as
`:dev`/`:test` dependencies:

```elixir
# mix.exs
defp deps do
  [
    {:mutare, "~> 0.1", only: [:dev, :test], runtime: false},
    {:mutare_plug, "~> 0.1", only: [:dev, :test], runtime: false}
  ]
end
```

Then list the families in `.mutare.exs`. Setting `:mutators` **replaces** Mutare's default
set, so include the `:builtins` family to keep the built-ins on:

```elixir
# .mutare.exs
[mutators: [:builtins] ++ Mutare.Plug.all()]
```

Run it the usual way:

```
mix mutare
```

A Phoenix app adds the companion [`mutare_phoenix`](https://hex.pm/packages/mutare_phoenix)
on top for the `Phoenix.Controller` surface (see "Scope").

## Configuring a family

`:http_status`'s swap table is tunable. Give the family `{module, opts}` with a `:swaps`
map — a status you list **replaces** its built-in siblings, an empty list **disables** it,
and any status you omit keeps its built-in siblings. Configuring a family means listing it
yourself, so expand `Mutare.Plug.all/0` into its members and replace that one entry:

```elixir
# .mutare.exs — narrow :ok to one sibling, stop mutating :no_content, add a teapot
[
  mutators: [
    :builtins,
    Mutare.Plug.Halt,
    {Mutare.Plug.Status, swaps: %{ok: [:created], no_content: [], im_a_teapot: [:bad_request]}},
    Mutare.Plug.Session,
    Mutare.Plug.Header,
    Mutare.Plug.Cookie,
    Mutare.Plug.Body
  ]
]
```

Configured siblings must be valid `Plug.Conn.Status` reason atoms — trusted, not checked: a
sibling that isn't a real status produces a crashing mutant rather than the built-in table's
valid-but-wrong swap. See `Mutare.Plug.Status` for the full table.

## Why not the built-in atom mutators?

In a status position, Mutare's built-in atom swaps (`:ok → :error` / `:mutare`) produce a
value that **crashes** — an uninformative kill that tells you nothing about test quality.
`:http_status` swaps to *valid* siblings, so a survivor means a genuine missing assertion
rather than a crash, and Mutare's overlap pruning drops the redundant crashing leaves at the
same range. `:resp_body` works the same way for a literal body: its whole-call blank covers
the string node, so the built-in string family's sentinel leaves there are pruned
automatically and one clean "is the body read?" mutant remains.

## Example

[`examples/demo`](https://github.com/foxbenjaminfox/mutare_plug/tree/HEAD/examples/demo) is
a standalone mini-project — an auth plug and a few request handlers over a tiny `Plug.Conn`
stand-in — with deliberate test gaps that surface survivors in the halt/status/body
families. From the repo root:

```
mix compile
mix mutare examples/demo
```

## Scope

This package owns the `Plug.Conn` surface only. The `Phoenix.Controller` surface
(`redirect/2`'s status, and the defensive `:skip` routing for Phoenix's compile-time
macros) is the companion `mutare_phoenix`, which depends on this package the way `phoenix`
depends on `plug`; LiveView is `mutare_phoenix_live_view` on top of that.

## License

MIT — see [LICENSE](LICENSE).
