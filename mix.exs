defmodule ExUnited.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_united,
      version: "0.1.0",
      elixir: ">= 1.5.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.3", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, ".ex_united.plt"},
      plt_add_apps: [:mix],
      ignore_warnings: ".dialyzer-ignore.exs"
    ]
  end
end
