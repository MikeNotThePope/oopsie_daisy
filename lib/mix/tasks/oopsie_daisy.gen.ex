defmodule Mix.Tasks.OopsieDaisy.Gen do
  @moduledoc """
  Generates Phoenix.Component modules from DaisyUI documentation.

  This task will automatically ensure the DaisyUI repository is available by cloning it
  if necessary. If the repository already exists at tmp/daisyui, it will be used as-is.

  ## Usage

      $ mix oopsie_daisy.gen
      $ mix oopsie_daisy.gen --components button,badge
      $ mix oopsie_daisy.gen --dry-run
      $ mix oopsie_daisy.gen --output-dir lib/my_components

  ## Options

    * `--components` - Only generate specific components (comma-separated)
    * `--output-dir` - Output directory (default: lib/oopsie_daisy_components)
    * `--base-module` - Base module namespace (default: OopsieDaisy.Components)
    * `--dry-run` - Print what would be generated without writing files
    * `--skip-examples` - Skip generating example functions
    * `--skip-clone` - Skip cloning DaisyUI (assumes repository already exists)

  ## Examples

      # Generate all components (clones DaisyUI if needed)
      $ mix oopsie_daisy.gen

      # Generate only button and badge components
      $ mix oopsie_daisy.gen --components button,badge

      # Preview without writing files
      $ mix oopsie_daisy.gen --dry-run

      # Generate to custom directory with custom module namespace
      $ mix oopsie_daisy.gen --output-dir lib/ui/components --base-module MyApp.Components

      # Skip cloning step (use existing repository)
      $ mix oopsie_daisy.gen --skip-clone
  """

  use Mix.Task

  alias OopsieDaisy.{Cloner, Parser}
  alias OopsieDaisy.Generator.{Analyzer, Template}

  @shortdoc "Generates Phoenix components from DaisyUI documentation"

  @impl Mix.Task
  def run(args) do
    # Check if Floki is available
    case Code.ensure_loaded(Floki) do
      {:module, Floki} ->
        :ok

      {:error, _} ->
        Mix.shell().error("""
        ❌ Error: Floki dependency not available.

        Please add Floki to your dependencies:

            {:floki, "~> 0.36.0"}

        Then run: mix deps.get
        """)

        exit({:shutdown, 1})
    end

    # Ensure application is started
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          components: :string,
          output_dir: :string,
          base_module: :string,
          dry_run: :boolean,
          skip_examples: :boolean,
          skip_clone: :boolean
        ]
      )

    output_dir = opts[:output_dir] || "lib/oopsie_daisy_components"
    base_module = opts[:base_module] || "OopsieDaisy.Components"
    dry_run = opts[:dry_run] || false
    skip_clone = opts[:skip_clone] || false
    component_filter = parse_component_filter(opts[:components])

    Mix.shell().info("🎨 DaisyUI Component Generator")
    Mix.shell().info("")

    # Ensure DaisyUI repository is available
    unless skip_clone do
      ensure_daisyui_available()
    end

    # Get extracted data
    path_groups = load_extracted_data()
    Mix.shell().info("📦 Loaded #{length(path_groups)} component(s) from extraction")

    # Filter if requested
    path_groups =
      if component_filter do
        filtered = filter_components(path_groups, component_filter)

        Mix.shell().info(
          "🔍 Filtered to #{length(filtered)} component(s): #{Enum.join(component_filter, ", ")}"
        )

        filtered
      else
        path_groups
      end

    if Enum.empty?(path_groups) do
      Mix.shell().error("❌ No components to generate")
      exit({:shutdown, 1})
    end

    # Analyze and generate
    Mix.shell().info("")
    Mix.shell().info("🔧 Generating components...")
    Mix.shell().info("")

    results =
      path_groups
      |> Enum.map(&Analyzer.analyze_path_group(&1, base_module: base_module))
      |> Enum.map(&generate_component(&1, output_dir, dry_run))

    # Summary
    Mix.shell().info("")
    successful = Enum.count(results, &(&1 == :ok))

    if dry_run do
      Mix.shell().info("✨ Dry run complete - #{successful} component(s) would be generated")
      Mix.shell().info("   Run without --dry-run to write files")
    else
      Mix.shell().info("✨ Generated #{successful} component(s) in #{output_dir}/")
      Mix.shell().info("")
      Mix.shell().info("📝 Next steps:")
      Mix.shell().info("   1. Run `mix format` to format the generated files")
      Mix.shell().info("   2. Review the generated components")
      Mix.shell().info("   3. Import components in your views/layouts")
    end
  end

  @doc """
  Ensures the DaisyUI repository is available, cloning it if necessary.
  """
  def ensure_daisyui_available do
    case Cloner.ensure_available(output_callback: &Mix.shell().info/1) do
      {:ok, _path} ->
        :ok

      {:error, reason} ->
        Mix.shell().error("❌ Failed to clone DaisyUI repository: #{reason}")
        exit({:shutdown, 1})
    end
  end

  @doc """
  Loads extracted data by parsing DaisyUI documentation files.
  """
  def load_extracted_data do
    original_dir = File.cwd!()

    components_dir =
      Path.join([
        original_dir,
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
      Mix.shell().error(
        "Components directory not found: #{components_dir}\n" <>
          "The DaisyUI repository may be missing or incomplete."
      )

      exit({:shutdown, 1})
    end

    markdown_files =
      Path.join(components_dir, "**/*.md")
      |> Path.wildcard()
      |> Enum.sort()

    markdown_files
    |> Enum.map(&extract_from_file/1)
    |> Enum.reject(&is_nil/1)
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

  @doc """
  Generates a single component file.
  """
  def generate_component(spec, output_dir, dry_run \\ false) do
    code = Template.render_module(spec)
    file_path = Path.join(output_dir, "#{spec.file_name}.ex")

    if dry_run do
      Mix.shell().info("Would generate: #{file_path}")
      Mix.shell().info("  Module: #{spec.module_name}")
      Mix.shell().info("  Base class: #{spec.base_class || "none"}")

      if map_size(spec.variants) > 0 do
        Mix.shell().info("  Variants: #{inspect(Map.keys(spec.variants))}")
      end

      Mix.shell().info("  Examples: #{length(spec.title_groups)}")
    else
      # Ensure output directory exists
      File.mkdir_p!(output_dir)

      # Write file
      File.write!(file_path, code)

      Mix.shell().info("✓ #{spec.name} → #{Path.relative_to_cwd(file_path)}")
    end

    :ok
  catch
    kind, reason ->
      Mix.shell().error("✗ Failed to generate #{spec.name}: #{inspect(kind)} #{inspect(reason)}")
      :error
  end

  defp parse_component_filter(nil), do: nil

  defp parse_component_filter(filter_str) do
    filter_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.downcase/1)
    |> Enum.reject(&(&1 == ""))
  end

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
end
