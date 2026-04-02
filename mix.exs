defmodule PiEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :pi_ex,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {PiEx.Application, []}
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:jason, "~> 1.2"},
      {:plug, "~> 1.0", only: :test}
    ]
  end
end
