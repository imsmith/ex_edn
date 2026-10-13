defmodule EDN.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_edn,
      version: "0.1.0",
      elixir: "~> 1.20",
      # The 1.20 type checker reports violations as warnings; fail the build on them.
      elixirc_options: [warnings_as_errors: true],
      deps: [{:dialyxir, "~> 1.4", only: :dev, runtime: false}],
      dialyzer: [flags: [:unmatched_returns, :error_handling, :extra_return, :missing_return]],
      description:
        "EDN (extensible data notation) reader and writer for Elixir. No dependencies.",
      package: [licenses: ["AGPL-3.0-only"], links: %{}]
    ]
  end

  def application, do: [extra_applications: []]
end
