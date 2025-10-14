defmodule OopsieDaisy do
  @moduledoc """
  Generates Phoenix.Component modules from DaisyUI documentation.

  ## Quick Start

      # Generate all components (auto-detects your app name)
      {:ok, results} = OopsieDaisy.generate()

      # Generate specific components
      {:ok, results} = OopsieDaisy.generate(components: ["button", "badge"])

  Most Phoenix developers will use the mix task instead: `mix oopsie_daisy.gen`

  ## What It Does

  OopsieDaisy:
  1. Clones the DaisyUI repository
  2. Parses component documentation (markdown files)
  3. Extracts HTML examples
  4. Analyzes CSS classes to detect variants (colors, sizes, styles)
  5. Generates type-safe Phoenix.Component modules

  ## Generated Components

  Every component includes:
  - Type-safe `attr` declarations with allowed values
  - Helper functions for class composition
  - Support for custom classes and HTML attributes
  - Proper Phoenix.Component patterns

  ## Options

  See `generate/1` for all available options.
  """

  alias OopsieDaisy.{Cloner, Parser}
  alias OopsieDaisy.Generator.{Analyzer, Template}

  @doc """
  Generates Phoenix.Component modules from DaisyUI documentation.

  ## Options

    * `:components` - List of component names (default: all). Example: `["button", "badge"]`
    * `:output_dir` - Where to write files (default: `"lib/oopsie_daisy_components"`)
    * `:base_module` - Module namespace (default: auto-detected from your app name)
    * `:base_dir` - Where DaisyUI is cloned (default: current directory)

  ## Auto-Detection

  If you don't provide `:base_module`, it's detected from your Phoenix app name:

    * Phoenix app `my_app` → `MyAppWeb.Components.*`
    * Non-Phoenix app → `MyApp.Components.*`
    * Falls back to `OopsieDaisy.Components`

  ## Examples

      # Generate all components
      {:ok, results} = OopsieDaisy.generate()

      # Generate specific components
      {:ok, results} = OopsieDaisy.generate(components: ["button", "badge"])

      # Custom module namespace
      {:ok, results} = OopsieDaisy.generate(base_module: "MyApp.UI")

      # Custom output directory
      {:ok, results} = OopsieDaisy.generate(output_dir: "lib/my_app_web/components")

  ## Returns

  `{:ok, results}` where `results` is a list of `{:ok, file_path}` or `{:error, reason}` tuples.
  """
  def generate(opts \\ []) do
    with {:ok, _path} <- ensure_daisyui(opts),
         {:ok, path_groups} <- load_components(opts),
         {:ok, results} <- generate_components(path_groups, opts) do
      {:ok, results}
    end
  end

  defp ensure_daisyui(opts) do
    base_dir = Keyword.get(opts, :base_dir, File.cwd!())
    Cloner.ensure_available(base_dir: base_dir)
  end

  defp load_components(opts) do
    base_dir = Keyword.get(opts, :base_dir, File.cwd!())
    component_filter = Keyword.get(opts, :components)

    components_dir =
      Path.join([
        base_dir,
        "tmp",
        "daisyui",
        "packages",
        "docs",
        "src",
        "routes",
        "(routes)",
        "components"
      ])

    unless File.dir?(components_dir) do
      {:error, "Components directory not found: #{components_dir}"}
    else
      markdown_files =
        Path.join(components_dir, "**/*.md")
        |> Path.wildcard()
        |> Enum.sort()

      path_groups =
        markdown_files
        |> Enum.map(&extract_from_file/1)
        |> Enum.reject(&is_nil/1)
        |> filter_components(component_filter)

      {:ok, path_groups}
    end
  end

  defp extract_from_file(file_path) do
    content = File.read!(file_path)
    lines = String.split(content, "\n")
    examples = Parser.parse_file_lines(lines, file_path)

    if Enum.empty?(examples) do
      nil
    else
      title_groups =
        examples
        |> Enum.map(fn example ->
          %Parser.TitleGroup{
            title: example.title,
            elements: example.elements
          }
        end)

      %Parser.PathGroup{
        path: file_path,
        title_groups: title_groups
      }
    end
  end

  defp filter_components(path_groups, nil), do: path_groups

  defp filter_components(path_groups, component_names) do
    path_groups
    |> Enum.filter(fn path_group ->
      component_name =
        path_group.path
        |> Path.dirname()
        |> Path.basename()
        |> String.downcase()

      component_name in component_names
    end)
  end

  defp generate_components(path_groups, opts) do
    output_dir = Keyword.get(opts, :output_dir, "lib/oopsie_daisy_components")
    base_module = Keyword.get(opts, :base_module) || detect_base_module()
    File.mkdir_p!(output_dir)

    results =
      path_groups
      |> Enum.map(&Analyzer.analyze_path_group(&1, base_module: base_module))
      |> Enum.map(&write_component(&1, output_dir))

    {:ok, results}
  end

  defp write_component(spec, output_dir) do
    code = Template.render_module(spec)
    file_path = Path.join(output_dir, "#{spec.file_name}.ex")

    case File.write(file_path, code) do
      :ok -> {:ok, file_path}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Detects the base module namespace from your app's name.

  Used automatically by `generate/1` when `:base_module` is not provided.

  ## How It Works

  1. Gets app name from `Mix.Project.config()`
  2. Converts to PascalCase (e.g., `my_app` → `MyApp`)
  3. Checks if `MyAppWeb` module exists (indicates Phoenix app)
  4. Returns appropriate namespace

  ## Examples

      # In Phoenix app "my_app"
      OopsieDaisy.detect_base_module()
      #=> "MyAppWeb.Components"

      # In non-Phoenix app "my_lib"
      OopsieDaisy.detect_base_module()
      #=> "MyLib.Components"

  Returns `"OopsieDaisy.Components"` if detection fails.
  """
  def detect_base_module do
    try do
      config = Mix.Project.config()
      app_name = config[:app]

      if app_name do
        # Convert app name to PascalCase module name
        base_module_name =
          app_name
          |> to_string()
          |> String.split("_")
          |> Enum.map(&String.capitalize/1)
          |> Enum.join()

        cond do
          # Check if AppWeb module exists (indicates Phoenix app)
          Code.ensure_loaded?(Module.concat([base_module_name <> "Web"])) ->
            "#{base_module_name}Web.Components"

          # Fall back to App.Components
          true ->
            "#{base_module_name}.Components"
        end
      else
        "OopsieDaisy.Components"
      end
    rescue
      _ -> "OopsieDaisy.Components"
    end
  end
end
