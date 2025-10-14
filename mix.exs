defmodule DaisyuiGen.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/MikeNotThePope/daisyui_gen"

  def project do
    [
      app: :daisyui_gen,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "DaisyuiGen",
      source_url: @source_url
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib/daisyui_gen", "lib/mix"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:floki, "~> 0.36.0"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Automatically generates Phoenix.Component modules from DaisyUI documentation.
    Analyzes HTML examples, detects variants, and creates type-safe LiveView components.
    """
  end

  defp package do
    [
      licenses: ["CC0-1.0"],
      links: %{
        "GitHub" => @source_url
      },
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
