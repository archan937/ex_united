defmodule ExUnited.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_united,
      version: "0.1.0",
      elixir: ">= 1.6.0",
      elixirc_options: [warnings_as_errors: true],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),
      preferred_cli_env: [
        credo: :credo,
        dialyzer: :dialyzer,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        inch: :inch,
        "inch.report": :inch
      ],
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.3", only: [:credo], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dialyzer], runtime: false},
      {:excoveralls, "~> 0.12.3", only: [:test]},
      {:inch_ex, "~> 2.0", only: [:inch], runtime: false}
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, ".ex_united.plt"},
      plt_add_apps: [:mix, :ex_unit, :eex],
      ignore_warnings: ".dialyzer-ignore.exs"
    ]
  end
end
