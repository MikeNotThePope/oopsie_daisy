defmodule OopsieDaisy.Generator.ExampleBuilder do
  @moduledoc """
  Converts TitleGroups and Elements to example functions with HEEx templates.
  """

  alias OopsieDaisy.Parser.{Element, TitleGroup}
  alias OopsieDaisy.Generator.Helpers

  @doc """
  Builds an example function from a TitleGroup.

  If the TitleGroup contains multiple sibling elements with the same tag,
  splits them into separate example functions.
  """
  def build_example_function(%TitleGroup{title: title, elements: elements}) do
    if should_split_elements?(elements) do
      elements
      |> Enum.map(&build_single_element_example(&1, title))
      |> Enum.join("\n")
    else
      fn_name = Helpers.title_to_function_name(title)
      elements_heex = elements_to_heex(elements, 2)

      """
        @doc "Example: #{title}"
        def #{fn_name}_example(assigns) do
          ~H\"\"\"
      #{elements_heex}
          \"\"\"
        end
      """
    end
  end

  @doc """
  Determines if elements should be split into separate example functions.

  Returns true if there are multiple top-level Element structs with the same tag.
  """
  def should_split_elements?(elements) do
    element_tags =
      elements
      |> Enum.filter(&is_struct(&1, Element))
      |> Enum.map(& &1.tag)
      |> Enum.reject(&(&1 == :comment))

    length(element_tags) > 1 and length(Enum.uniq(element_tags)) == 1
  end

  @doc """
  Builds a single example function from one element.
  """
  def build_single_element_example(element, _base_title) when is_binary(element) do
    # Skip text nodes
    ""
  end

  def build_single_element_example(%Element{tag: :comment}, _base_title) do
    # Skip comments
    ""
  end

  def build_single_element_example(%Element{} = element, base_title) do
    fn_name = generate_element_function_name(element, base_title)
    doc_title = generate_element_doc_title(element, base_title)
    element_heex = element_to_heex(element, 2)

    """
      @doc "Example: #{doc_title}"
      def #{fn_name}_example(assigns) do
        ~H\"\"\"
    #{element_heex}
        \"\"\"
      end
    """
  end

  @doc """
  Generates a unique function name for an element based on its attributes or content.
  """
  def generate_element_function_name(%Element{attrs: attrs, children: children}, _base_title) do
    cond do
      # Try to extract variant from class attribute
      variant = extract_variant_from_class(attrs["class"]) ->
        Helpers.title_to_function_name(variant)

      # Try to use first text child
      text = extract_first_text(children) ->
        Helpers.title_to_function_name(text)

      # Fallback to "example"
      true ->
        "example"
    end
  end

  @doc """
  Generates a doc title for an element.
  """
  def generate_element_doc_title(%Element{attrs: attrs, children: children}, base_title) do
    cond do
      variant = extract_variant_from_class(attrs["class"]) ->
        String.capitalize(variant)

      text = extract_first_text(children) ->
        text

      true ->
        base_title
    end
  end

  defp extract_variant_from_class(nil), do: nil

  defp extract_variant_from_class(class_str) do
    # Look for common variant patterns: btn-primary, badge-secondary, etc.
    class_str
    |> String.split(" ", trim: true)
    |> Enum.find_value(fn class ->
      case String.split(class, "-", parts: 2) do
        [_base, variant] when variant != "" -> variant
        _ -> nil
      end
    end)
  end

  defp extract_first_text(children) when is_list(children) do
    children
    |> Enum.find_value(fn
      text when is_binary(text) -> String.trim(text)
      _ -> nil
    end)
    |> case do
      "" -> nil
      text -> text
    end
  end

  defp extract_first_text(_), do: nil

  @doc """
  Converts a list of elements to HEEx string with indentation.
  """
  def elements_to_heex(elements, indent_level \\ 0) do
    elements
    |> Enum.map(&element_to_heex(&1, indent_level))
    |> Enum.join("\n")
  end

  @doc """
  Converts an Element struct to HEEx string.
  """
  def element_to_heex(%Element{tag: :comment, text: text}, indent_level) do
    indent_str = String.duplicate("  ", indent_level)
    "#{indent_str}<!-- #{text} -->"
  end

  def element_to_heex(%Element{tag: tag, attrs: attrs, children: children}, indent_level) do
    indent_str = String.duplicate("  ", indent_level)
    attrs_str = Helpers.format_attrs(attrs)

    case children do
      [] ->
        # Self-closing tag
        "#{indent_str}<#{tag}#{attrs_str} />"

      children ->
        # Check if children are all text (inline)
        if all_text?(children) do
          # Inline children
          children_str = children |> Enum.map(&text_to_heex/1) |> Enum.join("")
          "#{indent_str}<#{tag}#{attrs_str}>#{children_str}</#{tag}>"
        else
          # Block children (nested elements)
          children_heex =
            children
            |> Enum.map(&element_to_heex(&1, indent_level + 1))
            |> Enum.join("\n")

          """
          #{indent_str}<#{tag}#{attrs_str}>
          #{children_heex}
          #{indent_str}</#{tag}>
          """
          |> String.trim_trailing()
        end
    end
  end

  def element_to_heex(text, indent_level) when is_binary(text) do
    indent_str = String.duplicate("  ", indent_level)
    "#{indent_str}#{text}"
  end

  @doc """
  Converts text node to HEEx, escaping if necessary.
  """
  def text_to_heex(text) when is_binary(text) do
    # Check if text contains special HEEx/HTML characters
    if String.contains?(text, ["<", ">", "&"]) or String.contains?(text, "\"") do
      Helpers.escape_heex(text)
    else
      text
    end
  end

  def text_to_heex(%Element{} = element) do
    element_to_heex(element, 0)
  end

  defp all_text?(children) do
    Enum.all?(children, &is_binary/1)
  end

  @doc """
  Generates all example functions for a component.
  """
  def build_all_examples(title_groups) do
    title_groups
    |> Enum.map(fn title_group ->
      build_example_function(title_group)
    end)
    |> Enum.join("\n")
  end
end
