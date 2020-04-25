defmodule ExUnited.MixProject do
  use Mix.Project

  @version "0.1.1"

  def project do
    [
      app: :ex_united,
      version: @version,
      elixir: ">= 1.6.0",
      elixirc_options: [warnings_as_errors: true],
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      dialyzer: dialyzer(),
      docs: docs(),
      name: "ExUnited",
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

  defp description do
    """
    Easily spawn Elixir nodes (supervising, Mix configured, easy asserted / refuted) within ExUnit tests
    """
  end

  defp package do
    [
      maintainers: ["Paul Engel"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/archan937/ex_united"}
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.3", only: :credo, runtime: false},
      {:dialyxir, "~> 1.0", only: :dialyzer, runtime: false},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:excoveralls, "~> 0.12.3", only: :test},
      {:inch_ex, "~> 2.0", only: :inch, runtime: false}
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, ".ex_united.plt"},
      plt_add_apps: [:mix, :ex_unit, :eex],
      ignore_warnings: ".dialyzer-ignore.exs"
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "CHANGELOG.md"
      ],
      source_ref: "v#{@version}",
      source_url: "https://github.com/archan937/ex_united",
      groups_for_modules: [
        Types: [
          ExUnited.Node,
          ExUnited.Spawn.State
        ]
      ]
    ]
  end
end
