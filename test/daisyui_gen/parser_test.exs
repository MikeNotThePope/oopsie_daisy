defmodule DaisyuiGen.ParserTest do
  use ExUnit.Case, async: true
  alias DaisyuiGen.Parser
  alias DaisyuiGen.Parser.Element

  describe "parse_file_lines/2" do
    test "parses simple HTML example with title" do
      lines = [
        "### ~Button",
        "```html",
        ~s(<button class="btn">Click me</button>),
        "```"
      ]

      examples = Parser.parse_file_lines(lines, "/path/to/button.md")

      assert length(examples) == 1
      [example] = examples

      assert example.title == "Button"
      assert example.path == "/path/to/button.md"
      assert length(example.elements) == 1

      [element] = example.elements
      assert %Element{tag: "button"} = element
      assert element.attrs["class"] == "btn"
      assert length(element.children) == 1
      assert Enum.at(element.children, 0) == "Click me"
    end

    test "parses multiple examples from same file" do
      lines = [
        "### ~Primary Button",
        "```html",
        ~s(<button class="btn btn-primary">Primary</button>),
        "```",
        "### ~Secondary Button",
        "```html",
        ~s(<button class="btn btn-secondary">Secondary</button>),
        "```"
      ]

      examples = Parser.parse_file_lines(lines, "/path/to/button.md")

      assert length(examples) == 2
      [example1, example2] = examples

      assert example1.title == "Primary Button"
      assert example2.title == "Secondary Button"
    end

    test "removes $$ from class attributes" do
      lines = [
        "### ~Button",
        "```html",
        ~s(<button class="btn $$btn-primary">Click</button>),
        "```"
      ]

      examples = Parser.parse_file_lines(lines, "/path/to/button.md")
      [example] = examples
      [element] = example.elements

      assert element.attrs["class"] == "btn btn-primary"
      refute String.contains?(element.attrs["class"], "$$")
    end

    test "handles empty file" do
      examples = Parser.parse_file_lines([], "/path/to/empty.md")
      assert examples == []
    end
  end
end
