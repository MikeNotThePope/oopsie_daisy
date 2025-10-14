# OopsieDaisy

**Automatically generate Phoenix.Component modules from DaisyUI documentation.**

OopsieDaisy parses DaisyUI's markdown documentation, extracts HTML examples, analyzes CSS classes to detect variants, and generates type-safe Phoenix LiveView components with proper attributes and helper functions.

## Features

- **🤖 Automatic Variant Detection**: Detects size, color, style, and modifier variants from CSS classes
- **✨ Type-Safe Attributes**: Generates proper `attr` declarations with defaults and allowed values
- **🎨 Smart Class Composition**: Builds helper functions for intelligent class merging
- **📚 Example Preservation**: All DaisyUI examples become example functions in the generated module
- **🔧 HEEx Templates**: Properly formatted HEEx with nested elements and attributes
- **🎯 SVG Support**: Preserves complex SVG icons correctly
- **⚙️ Configurable**: Custom output directories and module namespaces

## Installation

Add `oopsie_daisy` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:oopsie_daisy, "~> 0.1.0"},
    {:floki, "~> 0.36.0"}  # Required for HTML parsing
  ]
end
```

Then run:

```bash
mix deps.get
```

## Usage

### Mix Task (Recommended)

The generator **automatically detects your app name** and uses the appropriate module namespace:

```bash
# Generate all components (auto-detects module name from your Phoenix app)
mix oopsie_daisy.gen

# In a Phoenix app called "my_app", this generates:
# MyAppWeb.Components.Button, MyAppWeb.Components.Badge, etc.

# Generate specific components
mix oopsie_daisy.gen --components button,badge

# Custom output directory
mix oopsie_daisy.gen --output-dir lib/my_app_web/components

# Override auto-detected module namespace
mix oopsie_daisy.gen --base-module MyApp.Components

# Preview without writing files
mix oopsie_daisy.gen --dry-run

# Skip cloning DaisyUI (if already cloned)
mix oopsie_daisy.gen --skip-clone
```

### Programmatic API

```elixir
# Generate all components (auto-detects module name)
{:ok, results} = OopsieDaisy.generate()

# Generate specific components with custom options
{:ok, results} = OopsieDaisy.generate(
  components: ["button", "badge"],
  output_dir: "lib/my_app_web/components"
)

# Override auto-detected module name
{:ok, results} = OopsieDaisy.generate(
  base_module: "MyApp.Components"
)
```

## Generated Component Example

```elixir
defmodule MyApp.Components.Button do
  use Phoenix.Component

  # Smart attributes based on detected variants
  @doc "Color variant"
  attr :variant, :atom, default: nil, values: [nil, :primary, :secondary, ...]

  @doc "Button size"
  attr :size, :atom, default: :md, values: [:xs, :sm, :md, :lg, :xl]

  @doc "Additional CSS classes"
  attr :class, :string, default: ""
  attr :rest, :global

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button class={["btn", variant_class(@variant), size_class(@size), @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  # Helper functions for class composition
  defp variant_class(nil), do: nil
  defp variant_class(:primary), do: "btn-primary"
  # ...
end
```

## Requirements

- Elixir ~> 1.18
- Floki ~> 0.36 (for HTML parsing)
- Git (for cloning DaisyUI repository)

## Credits

- Built with [Claude Code](https://claude.com/claude-code) 🤖
- Extracted from [Boxy](https://github.com/MikeNotThePope/boxy)
- Generates components for [DaisyUI](https://daisyui.com/)

## License

[CC0 1.0 Universal](https://creativecommons.org/public-domain/cc0/) - Public Domain

