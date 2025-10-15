defmodule OopsieDaisy.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/MikeNotThePope/oopsie_daisy"

  def project do
    [
      app: :oopsie_daisy,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "OopsieDaisy",
      source_url: @source_url
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib/oopsie_daisy", "lib/mix"]

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
    Generates type-safe Phoenix.Component modules from DaisyUI documentation.
    Parses DaisyUI docs, detects variants, and creates production-ready components.
    """
  end

  defp package do
    [
      licenses: ["CC0-1.0"],
      links: %{
        "GitHub" => @source_url
      },
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
