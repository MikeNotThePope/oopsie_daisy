defmodule OopsieDaisy.Generator.AnalyzerTest do
  use ExUnit.Case, async: true

  alias OopsieDaisy.Generator.Analyzer
  alias OopsieDaisy.Generator.Analyzer.ComponentSpec
  alias OopsieDaisy.Parser.{PathGroup, TitleGroup, Element}

  describe "analyze_path_group/2" do
    test "analyzes path group and creates component spec" do
      path_group = %PathGroup{
        path: "/path/to/button/+page.md",
        title_groups: [
          %TitleGroup{
            title: "Button",
            elements: [
              %Element{
                tag: "button",
                attrs: %{"class" => "btn"},
                children: ["Click"]
              }
            ]
          }
        ]
      }

      spec = Analyzer.analyze_path_group(path_group)

      assert %ComponentSpec{} = spec
      assert spec.name == "Button"
      assert spec.module_name == "OopsieDaisy.Components.Button"
      assert spec.file_name == "button"
      assert spec.base_class == "btn"
    end

    test "extracts variants from component classes" do
      path_group = %PathGroup{
        path: "/path/to/button/+page.md",
        title_groups: [
          %TitleGroup{
            title: "Button sizes",
            elements: [
              %Element{tag: "button", attrs: %{"class" => "btn btn-xs"}, children: []},
              %Element{tag: "button", attrs: %{"class" => "btn btn-sm"}, children: []}
            ]
          }
        ]
      }

      spec = Analyzer.analyze_path_group(path_group)
      assert spec.variants[:size] == [:xs, :sm]
    end
  end

  describe "has_variants?/1" do
    test "returns true when component has variants" do
      spec = %ComponentSpec{name: "Button", variants: %{size: [:xs, :sm]}}
      assert Analyzer.has_variants?(spec) == true
    end

    test "returns false when component has no variants" do
      spec = %ComponentSpec{name: "Button", variants: %{}}
      assert Analyzer.has_variants?(spec) == false
    end
  end
end
