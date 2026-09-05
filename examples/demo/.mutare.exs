# Mutare configuration for the demo.
#
# In a real project, `mutare_plug` is a dependency, so its mutators are already on the code
# path and the line below is unnecessary. Here the demo lives *inside* the `mutare_plug`
# repo, where the package is the **root** project — which the `mutare` task does not add to
# its code path — so we add the compiled package `ebin` ourselves (run `mix compile` in the
# repo root first).
for ebin <- Path.wildcard(Path.expand("_build/*/lib/mutare_plug/ebin")),
    do: Code.append_path(String.to_charlist(ebin))

# Scope mutation to `lib/demo` (the app code), leaving the tiny `Plug.Conn` stand-in at
# `lib/plug_surface.ex` unmutated, and enable only this package's families (`all/0`) so
# every survivor is a conn-transform gap. A real project would keep Mutare's built-ins on
# too, by adding the `:builtins` family:
#
#     [mutators: [:builtins] ++ Mutare.Plug.all()]
[
  paths: ["lib/demo"],
  mutators: Mutare.Plug.all()
]
