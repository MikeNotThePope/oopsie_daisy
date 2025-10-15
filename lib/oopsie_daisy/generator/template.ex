defmodule OopsieDaisy.Generator.Template do
  @moduledoc """
  Renders Phoenix.Component module code from specifications.

  Internal module. Takes a ComponentSpec and generates the complete Elixir module code.
  """

  alias OopsieDaisy.Generator.ComponentBuilder
  alias OopsieDaisy.Generator.Analyzer.ComponentSpec

  @doc """
  Generates complete module code from ComponentSpec.
  """
  def render_module(%ComponentSpec{} = spec) do
    component_name = Macro.underscore(spec.name)
    example = build_example(spec, component_name)

    """
    defmodule #{spec.module_name} do
      @moduledoc \"\"\"
      #{spec.name} component with DaisyUI styling.

      Generated from: #{Path.relative_to_cwd(spec.source_path)}

      ## Examples

          #{example}
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

  defp build_example(%ComponentSpec{base_class: base_class}, component_name) do
    html_tag = infer_html_tag(base_class)

    if ComponentBuilder.is_void_element?(html_tag) do
      case base_class do
        "input" -> ~s(<.#{component_name} type="text" placeholder="Type here" />)
        _ -> ~s(<.#{component_name} />)
      end
    else
      ~s(<.#{component_name}>Content</.#{component_name}>)
    end
  end

  defp infer_html_tag(base_class) do
    case base_class do
      "btn" -> "button"
      "input" -> "input"
      "textarea" -> "textarea"
      "select" -> "select"
      _ -> "div"
    end
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
