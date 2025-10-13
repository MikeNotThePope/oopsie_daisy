defmodule DaisyuiGen do
  @moduledoc """
  Automatically generates Phoenix.Component modules from DaisyUI documentation.

  DaisyuiGen parses DaisyUI's markdown documentation, extracts HTML examples,
  analyzes CSS classes to detect variants, and generates type-safe Phoenix LiveView
  components with proper attributes and helper functions.

  ## Features

  - **Automatic Variant Detection**: Detects size, color, style, and modifier variants
  - **Type-Safe Attributes**: Generates proper `attr` declarations with defaults
  - **Smart Class Composition**: Builds helper functions for class merging
  - **Example Preservation**: All DaisyUI examples become example functions
  - **HEEx Templates**: Properly formatted HEEx with nested elements

  ## Usage

  The primary interface is through Mix tasks:

      # Generate all components
      mix daisyui.gen

      # Generate specific components
      mix daisyui.gen --components button,badge

      # Custom output directory
      mix daisyui.gen --output-dir lib/my_components

  ## Programmatic API

  You can also use DaisyuiGen programmatically:

      # Ensure DaisyUI repository is available
      {:ok, path} = DaisyuiGen.Cloner.ensure_available()

      # Parse documentation
      path_groups = DaisyuiGen.Parser.parse_file_lines(lines, file_path)

      # Analyze and generate
      spec = DaisyuiGen.Generator.Analyzer.analyze_path_group(path_group)
      code = DaisyuiGen.Generator.Template.render_module(spec)
  """

  alias DaisyuiGen.{Cloner, Parser}
  alias DaisyuiGen.Generator.{Analyzer, Template}

  @doc """
  Generates Phoenix.Component code from DaisyUI documentation.

  ## Options

    * `:components` - List of component names to generate (default: all)
    * `:output_dir` - Output directory path (default: "lib/daisyui_gen_components")
    * `:base_module` - Base module namespace (default: "DaisyuiGen.Components")
    * `:base_dir` - Base directory for DaisyUI clone (default: current directory)

  ## Examples

      # Generate all components
      DaisyuiGen.generate()

      # Generate specific components
      DaisyuiGen.generate(components: ["button", "badge"])

      # Custom module namespace
      DaisyuiGen.generate(base_module: "MyApp.Components")

  ## Returns

  Returns `{:ok, results}` where results is a list of `{:ok, file_path}` or
  `{:error, reason}` tuples for each component.
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
    output_dir = Keyword.get(opts, :output_dir, "lib/daisyui_gen_components")
    base_module = Keyword.get(opts, :base_module, "DaisyuiGen.Components")
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
end
