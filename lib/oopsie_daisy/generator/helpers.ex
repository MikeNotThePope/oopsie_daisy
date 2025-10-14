defmodule OopsieDaisy.Generator.Helpers do
  @moduledoc """
  Internal utility functions for component generation.

  String manipulation, class analysis, HEEx formatting, etc.
  """

  alias OopsieDaisy.Parser.Element

  @doc """
  Extracts component name from file path.

  ## Examples

      iex> extract_component_name("/path/to/button/+page.md")
      "Button"

      iex> extract_component_name("/path/to/file-input/+page.md")
      "FileInput"
  """
  def extract_component_name(path) do
    path
    |> Path.dirname()
    |> Path.basename()
    |> String.replace("-", "_")
    |> Macro.camelize()
  end

  @doc """
  Converts component name to module name.

  ## Examples

      iex> to_module_name("Button")
      "OopsieDaisy.Components.Button"

      iex> to_module_name("Button", "MyApp.Components")
      "MyApp.Components.Button"
  """
  def to_module_name(component_name, base_module \\ "OopsieDaisy.Components") do
    "#{base_module}.#{component_name}"
  end

  @doc """
  Converts component name to file name.

  ## Examples

      iex> to_file_name("Button")
      "button"

      iex> to_file_name("FileInput")
      "file_input"
  """
  def to_file_name(component_name) do
    component_name
    |> Macro.underscore()
  end

  @doc """
  Converts title to function name.

  ## Examples

      iex> title_to_function_name("Button sizes")
      "sizes"

      iex> title_to_function_name("Button with Icon")
      "with_icon"

      iex> title_to_function_name("Wide button")
      "wide"
  """
  def title_to_function_name(title) do
    # Map common Unicode symbols to ASCII names
    title = replace_unicode_symbols(title)

    # Remove component name prefix if present
    name =
      title
      |> String.downcase()
      |> String.replace(~r/^(button|badge|card|alert)\s+/i, "")
      |> String.replace(~r/\s+(button|badge|card|alert)$/i, "")
      # Only keep ASCII word characters, spaces, and underscores
      |> String.replace(~r/[^a-z0-9\s_]/, "")
      |> String.replace(~r/\s+/, "_")
      |> String.trim("_")

    case name do
      "" ->
        "example"

      # If name starts with a number, prefix with underscore
      <<first::utf8, _rest::binary>> when first in ?0..?9 ->
        "_#{name}"

      name ->
        name
    end
  end

  # Replaces common Unicode symbols with ASCII-safe names.
  defp replace_unicode_symbols(text) do
    text
    |> String.replace("⌘", "cmd")
    |> String.replace("⌥", "opt")
    |> String.replace("⇧", "shift")
    |> String.replace("⌃", "ctrl")
    |> String.replace("▲", "up")
    |> String.replace("▼", "down")
    |> String.replace("◀︎", "left")
    |> String.replace("◀", "left")
    |> String.replace("▶︎", "right")
    |> String.replace("▶", "right")
  end

  @doc """
  Recursively extracts all class attributes from an element tree.
  """
  def extract_all_classes(elements) when is_list(elements) do
    elements
    |> Enum.flat_map(&extract_classes_from_element/1)
    |> Enum.uniq()
  end

  def extract_classes_from_element(%Element{attrs: attrs, children: children})
      when is_map(attrs) do
    class_list =
      case Map.get(attrs, "class") do
        nil -> []
        class_str -> String.split(class_str, " ", trim: true)
      end

    child_classes = if is_list(children), do: extract_all_classes(children), else: []
    class_list ++ child_classes
  end

  def extract_classes_from_element(%Element{children: children}) when is_list(children) do
    extract_all_classes(children)
  end

  def extract_classes_from_element(%Element{}), do: []

  def extract_classes_from_element(text) when is_binary(text), do: []

  @doc """
  Detects base class from a list of classes.
  Returns the most common prefix (e.g., "btn" from ["btn", "btn-primary", "btn-lg"]).
  """
  def detect_base_class(classes) do
    classes
    |> Enum.map(&extract_base/1)
    |> Enum.frequencies()
    |> Enum.max_by(fn {_class, count} -> count end, fn -> {nil, 0} end)
    |> elem(0)
  end

  defp extract_base(class) do
    case String.split(class, "-", parts: 2) do
      [base, _suffix] -> base
      [base] -> base
    end
  end

  @doc """
  Categorizes a class into variant type (size, color, style, modifier) or :base.
  """
  def categorize_class(class, base_class) do
    cond do
      class == base_class ->
        :base

      # Size variants: btn-xs, btn-sm, btn-md, btn-lg, btn-xl
      match_variant?(class, base_class, ~w(xs sm md lg xl)) ->
        {:size, extract_variant_value(class, base_class)}

      # Color variants
      match_variant?(class, base_class, color_variants()) ->
        {:color, extract_variant_value(class, base_class)}

      # Style variants
      match_variant?(class, base_class, style_variants()) ->
        {:style, extract_variant_value(class, base_class)}

      # Modifier variants
      match_variant?(class, base_class, modifier_variants()) ->
        {:modifier, extract_variant_value(class, base_class)}

      true ->
        :unknown
    end
  end

  defp match_variant?(class, base_class, variants) do
    pattern = "^#{base_class}-(#{Enum.join(variants, "|")})$"
    Regex.match?(~r/#{pattern}/, class)
  end

  defp extract_variant_value(class, base_class) do
    class
    |> String.replace_prefix("#{base_class}-", "")
    |> String.to_atom()
  end

  @doc """
  Known color variant suffixes.
  """
  def color_variants do
    ~w(primary secondary accent neutral info success warning error)
  end

  @doc """
  Known style variant suffixes.
  """
  def style_variants do
    ~w(outline soft ghost link dash)
  end

  @doc """
  Known modifier suffixes.
  """
  def modifier_variants do
    ~w(wide block square circle active disabled loading)
  end

  @doc """
  Escapes HEEx special characters in text.
  """
  def escape_heex(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  @doc """
  Formats attributes for HEEx template.
  """
  def format_attrs(attrs) when is_map(attrs) and map_size(attrs) == 0, do: ""

  def format_attrs(attrs) when is_map(attrs) do
    attrs
    |> Enum.map(fn {key, value} -> ~s(#{key}="#{value}") end)
    |> Enum.join(" ")
    |> then(&(" " <> &1))
  end

  @doc """
  Indents text by specified number of spaces.
  """
  def indent(text, spaces \\ 2) do
    indent_str = String.duplicate(" ", spaces)

    text
    |> String.split("\n")
    |> Enum.map(&(indent_str <> &1))
    |> Enum.join("\n")
  end
end
