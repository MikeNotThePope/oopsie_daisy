defmodule DaisyuiGen.Generator.HelpersTest do
  use ExUnit.Case, async: true

  alias DaisyuiGen.Generator.Helpers

  describe "extract_component_name/1" do
    test "extracts and camelizes component name from path" do
      assert Helpers.extract_component_name("/path/to/button/+page.md") == "Button"
      assert Helpers.extract_component_name("/path/to/file-input/+page.md") == "FileInput"
    end
  end

  describe "title_to_function_name/1" do
    test "converts title to function name" do
      assert Helpers.title_to_function_name("Button sizes") == "sizes"
      assert Helpers.title_to_function_name("Button with Icon") == "with_icon"
    end

    test "prefixes with underscore if starts with number" do
      assert Helpers.title_to_function_name("3 divs in a stack") == "_3_divs_in_a_stack"
    end
  end

  describe "categorize_class/2" do
    test "categorizes size variants" do
      assert Helpers.categorize_class("btn-xs", "btn") == {:size, :xs}
      assert Helpers.categorize_class("btn-sm", "btn") == {:size, :sm}
    end

    test "categorizes color variants" do
      assert Helpers.categorize_class("btn-primary", "btn") == {:color, :primary}
      assert Helpers.categorize_class("btn-secondary", "btn") == {:color, :secondary}
    end
  end
end
