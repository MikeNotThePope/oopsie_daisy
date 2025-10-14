defmodule DaisyuiGen.Generator.ExampleBuilderTest do
  use ExUnit.Case, async: true

  alias DaisyuiGen.Generator.ExampleBuilder
  alias DaisyuiGen.Parser.{Element, TitleGroup}

  describe "should_split_elements?/1" do
    test "returns true for multiple elements with same tag" do
      elements = [
        %Element{tag: "button", attrs: %{"class" => "btn btn-primary"}, children: ["Primary"]},
        %Element{
          tag: "button",
          attrs: %{"class" => "btn btn-secondary"},
          children: ["Secondary"]
        },
        %Element{tag: "button", attrs: %{"class" => "btn btn-accent"}, children: ["Accent"]}
      ]

      assert ExampleBuilder.should_split_elements?(elements) == true
    end

    test "returns false for single element" do
      elements = [
        %Element{tag: "button", attrs: %{"class" => "btn"}, children: ["Click"]}
      ]

      assert ExampleBuilder.should_split_elements?(elements) == false
    end

    test "returns false for elements with different tags" do
      elements = [
        %Element{tag: "button", attrs: %{}, children: ["Click"]},
        %Element{tag: "div", attrs: %{}, children: ["Content"]}
      ]

      assert ExampleBuilder.should_split_elements?(elements) == false
    end

    test "ignores comments when determining split" do
      elements = [
        %Element{tag: :comment, text: "Comment"},
        %Element{tag: "button", attrs: %{}, children: ["Click"]}
      ]

      assert ExampleBuilder.should_split_elements?(elements) == false
    end
  end

  describe "build_example_function/1" do
    test "splits multiple buttons into separate functions" do
      title_group = %TitleGroup{
        title: "Buttons colors",
        elements: [
          %Element{tag: "button", attrs: %{"class" => "btn btn-neutral"}, children: ["Neutral"]},
          %Element{tag: "button", attrs: %{"class" => "btn btn-primary"}, children: ["Primary"]}
        ]
      }

      result = ExampleBuilder.build_example_function(title_group)

      assert result =~ "def neutral_example(assigns)"
      assert result =~ "def primary_example(assigns)"
      assert result =~ ~s(@doc "Example: Neutral")
      assert result =~ ~s(@doc "Example: Primary")
    end

    test "keeps single button as one function" do
      title_group = %TitleGroup{
        title: "Button",
        elements: [
          %Element{tag: "button", attrs: %{"class" => "btn"}, children: ["Click"]}
        ]
      }

      result = ExampleBuilder.build_example_function(title_group)

      assert result =~ "def button_example(assigns)"
      assert result =~ ~s(@doc "Example: Button")
      refute result =~ "def click_example"
    end

    test "keeps nested structure as one function" do
      title_group = %TitleGroup{
        title: "Card",
        elements: [
          %Element{
            tag: "div",
            attrs: %{"class" => "card"},
            children: [
              %Element{tag: "div", attrs: %{"class" => "card-body"}, children: ["Content"]}
            ]
          }
        ]
      }

      result = ExampleBuilder.build_example_function(title_group)

      assert result =~ "def card_example(assigns)"
      refute String.contains?(result, "\n\n  @doc")
    end
  end

  describe "generate_element_function_name/2" do
    test "generates name from class variant" do
      element = %Element{
        tag: "button",
        attrs: %{"class" => "btn btn-primary"},
        children: ["Click"]
      }

      assert ExampleBuilder.generate_element_function_name(element, "Button") == "primary"
    end

    test "generates name from text content if no variant" do
      element = %Element{
        tag: "button",
        attrs: %{"class" => "btn"},
        children: ["Submit Form"]
      }

      assert ExampleBuilder.generate_element_function_name(element, "Button") == "submit_form"
    end

    test "falls back to 'example' if no variant or text" do
      element = %Element{
        tag: "button",
        attrs: %{"class" => "btn"},
        children: []
      }

      assert ExampleBuilder.generate_element_function_name(element, "Button") == "example"
    end
  end

  describe "generate_element_doc_title/2" do
    test "generates title from class variant" do
      element = %Element{
        tag: "button",
        attrs: %{"class" => "btn btn-secondary"},
        children: ["Click"]
      }

      assert ExampleBuilder.generate_element_doc_title(element, "Button") == "Secondary"
    end

    test "generates title from text content if no variant" do
      element = %Element{
        tag: "button",
        attrs: %{"class" => "btn"},
        children: ["My Button"]
      }

      assert ExampleBuilder.generate_element_doc_title(element, "Button") == "My Button"
    end
  end

  describe "element_to_heex/2" do
    test "converts simple button element" do
      element = %Element{
        tag: "button",
        attrs: %{"class" => "btn"},
        children: ["Click"]
      }

      heex = ExampleBuilder.element_to_heex(element, 0)

      assert heex == ~s(<button class="btn">Click</button>)
    end
  end
end
