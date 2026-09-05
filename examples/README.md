# Examples

A **standalone mini-project** used as a target for Mutare, demonstrating the `mutare_plug`
families. Run it from the repo root (compile the package first so its mutators are on the
code path):

```
mix compile
mix mutare examples/demo
```

| Example | Surface | What it demonstrates |
| --- | --- | --- |
| [`demo`](demo/) | Plug + request handlers | A forgotten `halt` (`:plug_halt`), an unasserted status (`:http_status`), and an unread body (`:resp_body`) — survivors in three families, plus the kills that prove the families catch what *is* asserted. |

The project has **partial test coverage on purpose**: each run surfaces real survivors, and
the `README.md` walks through the test-quality gap behind each one. The recurring lesson is
the package's thesis — when a function's behaviour *is* its conn transformation, a test that
asserts "something happened" but not *which* transformation leaves a gap Mutare will find.
