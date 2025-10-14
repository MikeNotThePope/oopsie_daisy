defmodule DaisyuiGen.Generator.Template do
  @moduledoc """
  Templates for generating complete Phoenix.Component modules.
  """

  alias DaisyuiGen.Generator.ComponentBuilder
  alias DaisyuiGen.Generator.Analyzer.ComponentSpec

  @doc """
  Generates complete module code from ComponentSpec.
  """
  def render_module(%ComponentSpec{} = spec) do
    """
    defmodule #{spec.module_name} do
      @moduledoc \"\"\"
      #{spec.name} component with DaisyUI styling.

      Generated from: #{Path.relative_to_cwd(spec.source_path)}

      ## Examples

          <.#{Macro.underscore(spec.name)}>Content</.#{Macro.underscore(spec.name)}>
      \"\"\"

      use Phoenix.Component

    #{build_component_section(spec)}
    end
    """
    |> format_code()
  end

  defp build_component_section(spec) do
    attrs = ComponentBuilder.build_attrs(spec)
    component_fn = ComponentBuilder.build_component_function(spec)
    class_helpers = ComponentBuilder.build_class_helpers(spec)

    """
      # Component
    #{indent(attrs, 2)}

    #{indent(component_fn, 2)}
    #{if class_helpers != "", do: indent(class_helpers, 2), else: ""}
    """
    |> String.trim_trailing()
  end


  @doc """
  Formats generated code using mix format.
  """
  def format_code(code) do
    # Basic cleanup
    code
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim()
    |> then(&(&1 <> "\n"))
  end

  defp indent(text, spaces) do
    indent_str = String.duplicate(" ", spaces)

    text
    |> String.split("\n")
    |> Enum.map(fn
      "" -> ""
      line -> indent_str <> line
    end)
    |> Enum.join("\n")
  end
end
