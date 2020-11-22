defmodule Gaffer.MixProject do
  use Mix.Project

  def project do
    [
      app: :gaffer,
      version: "0.1.0",
      elixir: "~> 1.11",
      elixirc_options: [warnings_as_errors: true],
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Gaffer.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    []
  end
end
