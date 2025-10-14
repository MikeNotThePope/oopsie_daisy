defmodule OopsieDaisy.Parser do
  @moduledoc """
  Parses HTML examples from DaisyUI markdown documentation.

  Internal module. Extracts HTML code blocks from markdown files and converts
  them to structured data for the generator.
  """

  defmodule PathGroup do
    @moduledoc false
    defstruct [:path, :title_groups]

    @type t :: %__MODULE__{
            path: String.t(),
            title_groups: [OopsieDaisy.Parser.TitleGroup.t()]
          }
  end

  defmodule TitleGroup do
    @moduledoc false
    defstruct [:title, :elements]

    @type t :: %__MODULE__{
            title: String.t(),
            elements: [OopsieDaisy.Parser.Element.t() | String.t()]
          }
  end

  defmodule Element do
    @moduledoc false
    defstruct [:tag, :attrs, :text, :children]

    @type t :: %__MODULE__{
            tag: String.t() | atom(),
            attrs: %{String.t() => String.t()},
            text: String.t() | nil,
            children: [t() | String.t()]
          }
  end

  @doc """
  Parses markdown lines and extracts HTML examples.
  """
  def parse_file_lines(lines, file_path) do
    parse_lines(lines, %{
      file_path: file_path,
      current_title: nil,
      in_code_block: false,
      current_html: [],
      examples: []
    })
    |> Map.get(:examples)
    |> Enum.reverse()
  end

  defp parse_lines([], state) do
    finalize_current_example(state)
  end

  defp parse_lines([line | rest], state) do
    cond do
      String.starts_with?(line, "### ~") ->
        title = String.trim_leading(line, "### ~")
        parse_lines(rest, %{state | current_title: title})

      String.trim(line) == "```html" ->
        parse_lines(rest, %{state | in_code_block: true, current_html: []})

      state.in_code_block and String.trim(line) == "```" ->
        new_state = finalize_current_example(state)
        parse_lines(rest, new_state)

      state.in_code_block ->
        parse_lines(rest, %{state | current_html: [line | state.current_html]})

      true ->
        parse_lines(rest, state)
    end
  end

  defp finalize_current_example(%{current_title: nil} = state) do
    state
  end

  defp finalize_current_example(%{current_html: []} = state) do
    state
  end

  defp finalize_current_example(state) do
    html_string =
      state.current_html
      |> Enum.reverse()
      |> Enum.join("\n")

    parsed_html = Floki.parse_document!(html_string)

    cleaned_html =
      parsed_html
      |> Enum.map(&clean_class_attributes/1)
      |> Enum.map(&element_to_map/1)

    new_example = %{
      path: state.file_path,
      title: state.current_title,
      elements: cleaned_html
    }

    %{
      state
      | examples: [new_example | state.examples],
        in_code_block: false,
        current_html: []
    }
  end

  defp clean_class_attributes({tag, attrs, children}) when is_list(children) do
    cleaned_attrs =
      Enum.map(attrs, fn
        {"class", value} -> {"class", String.replace(value, "$$", "")}
        other -> other
      end)

    cleaned_children = Enum.map(children, &clean_class_attributes/1)
    {tag, cleaned_attrs, cleaned_children}
  end

  defp clean_class_attributes(other), do: other

  defp element_to_map({tag, attrs, children}) when is_list(children) do
    %Element{
      tag: tag,
      attrs: Map.new(attrs),
      children: Enum.map(children, &element_to_map/1)
    }
  end

  defp element_to_map({:comment, text}) do
    %Element{tag: :comment, text: text}
  end

  defp element_to_map(text) when is_binary(text), do: text
end
