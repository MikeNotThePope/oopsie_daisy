defmodule DaisyuiGen.Generator.Analyzer do
  @moduledoc """
  Analyzes PathGroup data to extract component metadata for code generation.
  """

  alias DaisyuiGen.Parser.{PathGroup, TitleGroup}
  alias DaisyuiGen.Generator.Helpers

  defmodule ComponentSpec do
    @moduledoc """
    Specification for a component to be generated.
    """
    defstruct [
      :name,
      :module_name,
      :file_name,
      :base_class,
      :variants,
      :title_groups,
      :source_path
    ]

    @type variant_map :: %{
            size: [atom()],
            color: [atom()],
            style: [atom()],
            modifier: [atom()]
          }

    @type t :: %__MODULE__{
            name: String.t(),
            module_name: String.t(),
            file_name: String.t(),
            base_class: String.t() | nil,
            variants: variant_map(),
            title_groups: [TitleGroup.t()],
            source_path: String.t()
          }
  end

  @doc """
  Analyzes a PathGroup and returns a ComponentSpec with metadata.
  """
  def analyze_path_group(%PathGroup{path: path, title_groups: title_groups}, opts \\ []) do
    name = Helpers.extract_component_name(path)
    base_module = Keyword.get(opts, :base_module, "DaisyuiGen.Components")
    all_elements = collect_all_elements(title_groups)
    all_classes = Helpers.extract_all_classes(all_elements)
    base_class = Helpers.detect_base_class(all_classes)
    variants = extract_variants(all_classes, base_class)

    %ComponentSpec{
      name: name,
      module_name: Helpers.to_module_name(name, base_module),
      file_name: Helpers.to_file_name(name),
      base_class: base_class,
      variants: variants,
      title_groups: title_groups,
      source_path: path
    }
  end

  @doc """
  Collects all elements from all title groups.
  """
  def collect_all_elements(title_groups) do
    title_groups
    |> Enum.flat_map(& &1.elements)
  end

  @doc """
  Extracts and categorizes variants from classes.
  """
  def extract_variants(_classes, base_class) when is_nil(base_class), do: %{}

  def extract_variants(classes, base_class) do
    classes
    |> Enum.map(&Helpers.categorize_class(&1, base_class))
    |> Enum.reject(&(&1 == :base or &1 == :unknown))
    |> Enum.group_by(
      fn {type, _value} -> type end,
      fn {_type, value} -> value end
    )
    |> Enum.into(%{}, fn {type, values} -> {type, Enum.uniq(values)} end)
  end

  @doc """
  Determines the default variant value for a given type based on frequency.
  Returns the most common value, or a sensible default.
  """
  def default_variant(variants, type) do
    case Map.get(variants, type) do
      nil ->
        nil

      values when type == :size ->
        # For size, default to :md if present, otherwise most common
        if :md in values, do: :md, else: most_common(values)

      _values when type == :color ->
        # For color, default to nil (no color class)
        nil

      _values when type == :style ->
        # For style, default to nil (solid/default style)
        nil

      _values when type == :modifier ->
        # For modifier, default to nil
        nil

      values ->
        most_common(values)
    end
  end

  defp most_common(values) do
    values
    |> Enum.frequencies()
    |> Enum.max_by(fn {_val, count} -> count end, fn -> {nil, 0} end)
    |> elem(0)
  end

  @doc """
  Checks if a component has any variants.
  """
  def has_variants?(%ComponentSpec{variants: variants}) do
    map_size(variants) > 0
  end

  @doc """
  Gets all variants of a specific type.
  """
  def get_variants(%ComponentSpec{variants: variants}, type) do
    Map.get(variants, type, [])
  end
end
