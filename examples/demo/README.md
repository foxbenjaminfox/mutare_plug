# Demo: a Plug request surface

A standalone mini-project modelling the **conn-transform surface** of a Plug app — an auth
plug and a few request handlers — over a tiny stand-in for `Plug.Conn` (so it needs no real
Plug). The custom mutators match calls by module *name*, so the mutations are exactly what
they'd be against a real app.

A plug or handler returns a *transformed conn*, so its whole contract is **which
conn-transforming call ran** — the status it sent, the body it wrote, whether it halted.
These are precisely the calls a suite tends to under-assert, and each gap becomes a
survivor.

From the repo root (compile the package once so its mutators are loadable):

```
mix compile
mix mutare examples/demo
```

It scans 11 mutants across 2 files and reports four survivors across the three visible gaps
below, for a mutation score of 63.6%:

```
lib/demo/api.ex:12  [http_status, in-place]  SURVIVED
-  def create(conn), do: Plug.Conn.send_resp(conn, :created, "created")
+  def create(conn), do: Plug.Conn.send_resp(conn, :ok, "created")

lib/demo/api.ex:12  [http_status, in-place]  SURVIVED
-  def create(conn), do: Plug.Conn.send_resp(conn, :created, "created")
+  def create(conn), do: Plug.Conn.send_resp(conn, :accepted, "created")

lib/demo/api.ex:15  [resp_body, in-place]  SURVIVED
-  def health(conn), do: Plug.Conn.send_resp(conn, :ok, "ok")
+  def health(conn), do: Plug.Conn.send_resp(conn, :ok, "")

lib/demo/auth.ex:17  [plug_halt, in-place]  SURVIVED
-      |> Plug.Conn.halt()
+      |> Elixir.Function.identity()

mutation score: 63.6%  (7 killed, 4 survived, 11 total)
```

Each survivor is a real test-quality gap. Grouped by family:

- **`:plug_halt` — the forgotten halt** (`Demo.Auth`). The auth plug sets `401` *and*
  halts. The test asserts the `401` (so the `:http_status` mutant `:unauthorized →
  :forbidden` is **killed**) but never asserts the pipeline *halted*. Drop the `halt` and
  an anonymous request still gets `401` set — yet now falls through to the guarded handler.
  The missing `assert conn.halted` is the gap; the classic authorization-bypass mutation.

- **`:http_status` — the unasserted status** (`Demo.Api.create`). `create` answers
  `201 Created`, but its test checks only the response *body* (`"created"`), never the
  status. So swapping `:created` for another success (`:ok`, `:accepted`) is invisible.
  Two survivors, one per plausible sibling. (Contrast `index`, which **does** assert `:ok`
  — its `:created`/`:no_content` mutants are killed.)

- **`:resp_body` — the unread body** (`Demo.Api.health`). `health` answers `200` with a
  fixed body, but its test checks only the *status*, never the body. So blanking the body
  to `""` is invisible: the response was sent, with the right status, and nothing checked
  what it said. (Contrast `index` and `create`, which **do** assert the body — their
  `:resp_body` mutants are killed.)

The lesson is the package's whole thesis: when a function's behaviour *is* its conn
transformation, asserting "something happened" isn't enough — you have to assert *which*
transformation, with *what* arguments. Mutare turns every place you didn't into a survivor.

> Why `:ok → :error` (or `:mutare`) doesn't already cover `:http_status`: in a status
> position both of Mutare's built-in atom swaps **crash** (`:error`/`:mutare` aren't valid
> statuses), an uninformative kill. `:http_status` swaps to a *valid* sibling so a survivor
> means a genuine missing assertion, not a crash — and Mutare's overlap pruning drops the
> redundant crashing leaves. `:resp_body` earns its place the same way: on a literal body
> its whole-call blank supersedes the built-in string family's `""`/`"mutare"` leaves, so one
> clean "is the body read?" mutant remains.
