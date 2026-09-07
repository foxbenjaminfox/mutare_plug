defmodule Mutare.Plug.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/foxbenjaminfox/mutare_plug"

  def project do
    [
      app: :mutare_plug,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      aliases: aliases(),
      dialyzer: dialyzer(),
      docs: docs()
    ]
  end

  def application do
    [extra_applications: []]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description do
    "Mutare mutators for Plug"
  end

  # Hex package metadata. Only runtime and doc artifacts
  # ship — never the test suite, fixtures, or the examples app.
  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Benjamin Fox"],
      links: %{
        "GitHub" => @source_url,
        "Mutare" => "https://hexdocs.pm/mutare",
        "Changelog" => "https://hexdocs.pm/mutare_plug/changelog.html"
      },
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE)
    ]
  end

  defp deps do
    [
      # The host mutation-testing engine. `mutare_plug` implements `Mutare.Mutator`
      # and rides only its public extension points (`Mutare.Calls`, `Mutare.AST`).
      # Tests use `Mutare.Test` and `Mutare.AST` for AST parse/render, so no direct
      # `:sourceror` dep is needed. A consuming project depends on both as
      # `:dev`/`:test` deps.
      {:mutare, "~> 0.1"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  # Cache the PLTs outside `_build` so CI (and a `mix clean`) can reuse them. The
  # directory is git-ignored.
  defp dialyzer do
    [
      plt_local_path: "priv/plts",
      plt_core_path: "priv/plts"
    ]
  end

  # ExDoc configuration. `mix docs` renders to `doc/` (gitignored). README is the
  # landing page; `Mutare.Plug.ConnCall` is `@moduledoc false` plumbing and never
  # appears.
  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      # `Mutare.Plug.Body`'s moduledoc names core's hidden overlap pass in prose (the
      # reference is worth keeping — it explains the literal-body supersession); don't
      # autolink to it, which also silences the "references hidden" warning.
      skip_code_autolink_to: ["Mutare.Transform.Overlap"],
      groups_for_modules: [
        "Mutator front": [Mutare.Plug],
        "Mutator families": [
          Mutare.Plug.Halt,
          Mutare.Plug.Status,
          Mutare.Plug.Session,
          Mutare.Plug.Header,
          Mutare.Plug.Cookie,
          Mutare.Plug.Body
        ]
      ]
    ]
  end

  # `mix check` is the single quality gate: formatting, lint, and type analysis.
  # Any non-zero step aborts the rest, so a green run means all three passed.
  defp aliases do
    [check: ["format --check-formatted", "credo", "dialyzer"]]
  end
end
