defmodule ExUnited.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_united,
      version: "0.1.0",
      elixir: ">= 1.5.0",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.3", only: [:dev, :test], runtime: false}
    ]
  end
end
