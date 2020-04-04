defmodule ExUnited.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_united,
      version: "0.1.0",
      elixir: ">= 1.6.0",
      elixirc_options: [warnings_as_errors: true],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: dialyzer(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp aliases do
    [
      doctor: [
        "format",
        "credo --strict",
        "dialyzer",
        fn _ ->
          Mix.env(:test)
          Mix.Task.run("coveralls", [])
        end
      ]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.3", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.12.3", only: [:dev, :test]}
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
