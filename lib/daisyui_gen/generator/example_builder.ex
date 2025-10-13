defmodule DaisyuiGen.Generator.ExampleBuilder do
  @moduledoc """
  Converts TitleGroups and Elements to example functions with HEEx templates.
  """

  alias DaisyuiGen.Parser.{Element, TitleGroup}
  alias DaisyuiGen.Generator.Helpers

  @doc """
  Builds an example function from a TitleGroup.
  """
  def build_example_function(%TitleGroup{title: title, elements: elements}) do
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
