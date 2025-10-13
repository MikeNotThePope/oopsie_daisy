defmodule DaisyuiGen.Generator.ComponentBuilder do
  @moduledoc """
  Builds Phoenix.Component code from ComponentSpec.
  """

  alias DaisyuiGen.Generator.Analyzer.ComponentSpec
  alias DaisyuiGen.Generator.{Analyzer, Helpers}

  @doc """
  Generates component attributes based on variants.
  """
  def build_attrs(%ComponentSpec{variants: variants}) do
    attrs = []

    # Add variant attrs if present
    attrs =
      if Enum.any?(Map.get(variants, :size, [])) do
        size_values = Map.get(variants, :size, [])
        default_size = Analyzer.default_variant(variants, :size) || :md

        [
          build_attr(
            :size,
            :atom,
            default_size,
            "Button size",
            [:md | size_values] |> Enum.uniq()
          )
          | attrs
        ]
      else
        attrs
      end

    attrs =
      if Enum.any?(Map.get(variants, :color, [])) do
        color_values = Map.get(variants, :color, [])

        [
          build_attr(
            :variant,
            :atom,
            nil,
            "Color variant",
            [nil | color_values] |> Enum.uniq()
          )
          | attrs
        ]
      else
        attrs
      end

    attrs =
      if Enum.any?(Map.get(variants, :style, [])) do
        style_values = Map.get(variants, :style, [])

        [
          build_attr(
            :style,
            :atom,
            nil,
            "Style variant",
            [nil | style_values] |> Enum.uniq()
          )
          | attrs
        ]
      else
        attrs
      end

    attrs =
      if Enum.any?(Map.get(variants, :modifier, [])) do
        modifier_values = Map.get(variants, :modifier, [])

        [
          build_attr(
            :modifier,
            :atom,
            nil,
            "Modifier classes",
            [nil | modifier_values] |> Enum.uniq()
          )
          | attrs
        ]
      else
        attrs
      end

    # Always add class and rest attrs
    attrs =
      attrs ++
        [
          build_simple_attr(:class, :string, "", "Additional CSS classes"),
          "  attr :rest, :global, include: ~w(disabled form name value type)"
        ]

    # Reverse to get correct order (variant, size, style, modifier, class, rest)
    Enum.reverse(attrs) |> Enum.join("\n")
  end

  defp build_attr(name, type, default, doc, values) do
    values_str = values |> Enum.map(&inspect/1) |> Enum.join(", ")

    default_str =
      if is_nil(default), do: "nil", else: inspect(default)

    """
      @doc "#{doc}"
      attr :#{name}, :#{type}, default: #{default_str}, values: [#{values_str}]
    """
    |> String.trim()
  end

  defp build_simple_attr(name, type, default, doc) do
    default_str = inspect(default)

    """
      @doc "#{doc}"
      attr :#{name}, :#{type}, default: #{default_str}
    """
    |> String.trim()
  end

  @doc """
  Generates the main component function.
  """
  def build_component_function(%ComponentSpec{name: name, base_class: base_class} = spec) do
    fn_name = Helpers.to_file_name(name)
    has_variants = Analyzer.has_variants?(spec)

    class_expr =
      if has_variants do
        build_class_composition(spec)
      else
        if base_class do
          ~s(["#{base_class}", @class])
        else
          "@class"
        end
      end

    """
      @doc \"\"\"
      Renders a #{name} component.
      \"\"\"
      slot :inner_block, required: true

      def #{fn_name}(assigns) do
        ~H\"\"\"
        <#{infer_html_tag(base_class)} class={#{class_expr}} {@rest}>
          <%= render_slot(@inner_block) %>
        </#{infer_html_tag(base_class)}>
        \"\"\"
      end
    """
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
  Builds class composition expression.
  """
  def build_class_composition(%ComponentSpec{
        base_class: base_class,
        variants: variants
      }) do
    parts = []

    # Base class
    parts = if base_class, do: [~s("#{base_class}") | parts], else: parts

    # Variant classes
    parts =
      if Map.has_key?(variants, :color) do
        ["variant_class(@variant)" | parts]
      else
        parts
      end

    parts =
      if Map.has_key?(variants, :size) do
        ["size_class(@size)" | parts]
      else
        parts
      end

    parts =
      if Map.has_key?(variants, :style) do
        ["style_class(@style)" | parts]
      else
        parts
      end

    parts =
      if Map.has_key?(variants, :modifier) do
        ["modifier_class(@modifier)" | parts]
      else
        parts
      end

    # Extra class
    parts = ["@class" | parts]

    # Build expression
    parts_str = Enum.reverse(parts) |> Enum.join(", ")
    "[#{parts_str}]"
  end

  @doc """
  Builds helper functions for class composition.
  """
  def build_class_helpers(%ComponentSpec{variants: variants} = spec) do
    helpers = []

    helpers =
      if Map.has_key?(variants, :color) do
        [build_variant_helper(:variant, Map.get(variants, :color), spec.base_class) | helpers]
      else
        helpers
      end

    helpers =
      if Map.has_key?(variants, :size) do
        [build_variant_helper(:size, Map.get(variants, :size), spec.base_class) | helpers]
      else
        helpers
      end

    helpers =
      if Map.has_key?(variants, :style) do
        [build_variant_helper(:style, Map.get(variants, :style), spec.base_class) | helpers]
      else
        helpers
      end

    helpers =
      if Map.has_key?(variants, :modifier) do
        [build_variant_helper(:modifier, Map.get(variants, :modifier), spec.base_class) | helpers]
      else
        helpers
      end

    if Enum.any?(helpers) do
      """

        # Helper functions for class composition

      """ <>
        (Enum.reverse(helpers) |> Enum.join("\n"))
    else
      ""
    end
  end

  defp build_variant_helper(type, values, base_class) do
    nil_clause = "  defp #{type}_class(nil), do: nil\n"

    value_clauses =
      values
      |> Enum.map(fn value ->
        class_name = "#{base_class}-#{value}"
        "  defp #{type}_class(:#{value}), do: \"#{class_name}\""
      end)
      |> Enum.join("\n")

    nil_clause <> value_clauses
  end
end
