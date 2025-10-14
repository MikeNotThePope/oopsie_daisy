# OopsieDaisy

Generate type-safe Phoenix components from DaisyUI documentation.

## What is this?

OopsieDaisy automatically creates `Phoenix.Component` modules for DaisyUI components. Point it at DaisyUI's docs, and it generates clean, production-ready Phoenix components with proper attributes, variants, and type safety.

Instead of manually writing components and keeping them in sync with DaisyUI updates, generate them automatically.

## Quick Start

Add to your Phoenix project:

```elixir
# mix.exs
def deps do
  [
    {:oopsie_daisy, "~> 0.1.0", only: :dev, runtime: false}
  ]
end
```

Generate components:

```bash
# From your Phoenix project root
mix oopsie_daisy.gen

# Or generate specific components
mix oopsie_daisy.gen --components button,badge,card
```

Components are generated in `lib/oopsie_daisy_components/` with your app's namespace (e.g., `MyAppWeb.Components.Button`).

Use in your templates:

```heex
<.button variant={:primary} size={:lg}>
  Click me
</.button>

<.badge variant={:success}>
  New
</.badge>
```

## How It Works

1. **Clones DaisyUI repo** (automatically, once)
2. **Parses markdown documentation** to extract HTML examples
3. **Analyzes CSS classes** to detect variants (colors, sizes, styles)
4. **Generates Phoenix.Component modules** with proper `attr` declarations
5. **Creates helper functions** for class composition

## Generated Components

Every generated component includes:

- Type-safe attributes with allowed values
- Smart defaults based on DaisyUI
- Helper functions for class composition
- Support for custom classes via `class` attribute
- Pass-through for HTML attributes via `@rest`

Example generated component:

```elixir
defmodule MyAppWeb.Components.Button do
  use Phoenix.Component

  attr :variant, :atom, default: nil,
    values: [nil, :primary, :secondary, :accent, :neutral, :info, :success, :warning, :error]
  attr :size, :atom, default: :md,
    values: [:xs, :sm, :md, :lg, :xl]
  attr :style, :atom, default: nil,
    values: [nil, :outline, :ghost, :link]
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(disabled type)
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button class={["btn", variant_class(@variant), size_class(@size), style_class(@style), @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  defp variant_class(nil), do: nil
  defp variant_class(:primary), do: "btn-primary"
  # ... etc
end
```

## Usage Examples

### Basic components

```heex
<.button>Default</.button>
<.button variant={:primary}>Primary</.button>
<.button variant={:error} size={:lg}>Large Error</.button>
```

### With custom classes

```heex
<.button variant={:primary} class="mt-4 shadow-xl">
  Custom styled
</.button>
```

### With HTML attributes

```heex
<.button variant={:primary} type="submit" disabled={@is_submitting}>
  Submit
</.button>
```

### Dynamic variants

```heex
<.badge variant={@status}>
  <%= @status_text %>
</.badge>
```

## Configuration

### Auto-detection

By default, the generator detects your app name and uses the appropriate namespace:

- Phoenix app `my_app` → `MyAppWeb.Components.*`
- Other Elixir apps → `MyApp.Components.*`

### Override defaults

```bash
# Custom output directory
mix oopsie_daisy.gen --output-dir lib/my_app_web/custom_components

# Custom module namespace
mix oopsie_daisy.gen --base-module MyApp.UI.Components

# Preview without writing files
mix oopsie_daisy.gen --dry-run

# Skip cloning DaisyUI (if already cloned)
mix oopsie_daisy.gen --skip-clone
```

## Requirements

**Your Phoenix app needs:**

- Phoenix 1.7+ (for `Phoenix.Component`)
- Tailwind CSS configured
- DaisyUI plugin installed and configured

**To run the generator:**

- Elixir ~> 1.18
- Git (for cloning DaisyUI repo)

The generator itself requires Floki for HTML parsing, but it's only needed at dev time.

## DaisyUI Setup

If you haven't set up DaisyUI yet:

```bash
# Install DaisyUI
cd assets
npm install -D daisyui@latest
```

```javascript
// assets/tailwind.config.js
module.exports = {
  plugins: [
    require("daisyui")
  ],
  daisyui: {
    themes: ["light", "dark"], // or your custom themes
  },
}
```

## When to Use This

**Good fit:**
- You're building a Phoenix app with DaisyUI
- You want type-safe component APIs
- You want to keep components in sync with DaisyUI updates
- You prefer Phoenix.Component patterns over raw HTML/CSS classes

**Not needed if:**
- You're happy writing DaisyUI classes directly in HEEx
- You only use a handful of components
- You have highly customized component APIs

## Programmatic API

Generate components from Elixir code:

```elixir
# Generate all components
{:ok, results} = OopsieDaisy.generate()

# Generate specific components
{:ok, results} = OopsieDaisy.generate(
  components: ["button", "badge"],
  output_dir: "lib/my_app_web/components"
)

# Override module namespace
{:ok, results} = OopsieDaisy.generate(
  base_module: "MyApp.Components"
)
```

## Updating Components

When DaisyUI updates:

```bash
# Remove cloned repo
rm -rf tmp/daisyui

# Re-generate components
mix oopsie_daisy.gen
```

The generator will clone the latest DaisyUI and regenerate all components.

## License

[CC0 1.0 Universal](https://creativecommons.org/public-domain/cc0/) - Public Domain

Use this however you want.

## Credits

- Built with [Claude Code](https://claude.com/claude-code)
- Extracted from [Boxy](https://github.com/MikeNotThePope/boxy)
- Generates components for [DaisyUI](https://daisyui.com/)
