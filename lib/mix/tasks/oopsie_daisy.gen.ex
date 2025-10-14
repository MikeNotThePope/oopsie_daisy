defmodule Mix.Tasks.OopsieDaisy.Gen do
  @moduledoc """
  Generates Phoenix.Component modules from DaisyUI documentation.

  ## Quick Start

      $ mix oopsie_daisy.gen

  This generates all DaisyUI components as Phoenix.Component modules in your app,
  automatically using your app's module namespace.

  ## Common Usage

      # Generate all components
      $ mix oopsie_daisy.gen

      # Generate specific components only
      $ mix oopsie_daisy.gen --components button,badge,card

      # Preview what would be generated
      $ mix oopsie_daisy.gen --dry-run

      # Custom output directory
      $ mix oopsie_daisy.gen --output-dir lib/my_app_web/components

  ## Options

    * `--components` - Comma-separated list of components to generate (default: all)
    * `--output-dir` - Where to write files (default: `lib/oopsie_daisy_components`)
    * `--base-module` - Module namespace (default: auto-detected from app name)
    * `--dry-run` - Show what would be generated without writing files
    * `--skip-clone` - Don't clone DaisyUI (use existing clone in `tmp/daisyui`)

  ## Auto-Detection

  Your app name is automatically detected and used for module namespaces:

    * Phoenix app `my_app` → `MyAppWeb.Components.Button`
    * Other app `my_lib` → `MyLib.Components.Button`

  Override with `--base-module` if needed.

  ## First Run

  The first time you run this, it will:
  1. Clone the DaisyUI repository to `tmp/daisyui`
  2. Parse component documentation
  3. Generate Phoenix.Component modules

  Subsequent runs use the existing clone. To update DaisyUI:

      $ rm -rf tmp/daisyui
      $ mix oopsie_daisy.gen

  ## Requirements

  - Git must be available (for cloning DaisyUI)
  - Your Phoenix app should have Tailwind CSS and DaisyUI configured
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
    base_module = opts[:base_module] || detect_base_module()
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

  # Ensures DaisyUI repo is available, cloning if needed
  defp ensure_daisyui_available do
    case Cloner.ensure_available(output_callback: &Mix.shell().info/1) do
      {:ok, _path} ->
        :ok

      {:error, reason} ->
        Mix.shell().error("❌ Failed to clone DaisyUI repository: #{reason}")
        exit({:shutdown, 1})
    end
  end

  # Loads and parses DaisyUI documentation files
  defp load_extracted_data do
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

  # Generates a single component file
  defp generate_component(spec, output_dir, dry_run) do
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

  # Detects base module namespace from app name
  # Phoenix app `my_app` → "MyAppWeb.Components"
  # Other app → "MyApp.Components"
  defp detect_base_module do
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
