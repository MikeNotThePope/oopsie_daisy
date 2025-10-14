# Production-Ready Component Usage

The generated components are now production-ready and can be used directly in your Phoenix LiveView applications without modification.

## Example: Using the Button Component

```elixir
# In your Phoenix template or component:

# Basic button
<.button>Click me</.button>

# Button with variant (color)
<.button variant={:primary}>Primary Button</.button>

# Button with size
<.button size={:lg}>Large Button</.button>

# Button with multiple properties
<.button variant={:success} size={:sm} style={:outline}>
  Success Outline
</.button>

# Button with custom classes
<.button variant={:primary} class="mt-4 shadow-lg">
  Custom Styled
</.button>

# Button with modifiers
<.button modifier={:wide}>Wide Button</.button>
<.button modifier={:circle}>O</.button>

# Button with HTML attributes
<.button variant={:primary} type="submit" disabled={false}>
  Submit Form
</.button>
```

## Example: Using the Badge Component

```elixir
# Basic badge
<.badge>Default</.badge>

# Badge with variants
<.badge variant={:primary}>Primary</.badge>
<.badge variant={:success}>Success</.badge>

# Badge with size
<.badge size={:lg}>Large Badge</.badge>

# Badge with style
<.badge variant={:warning} style={:outline}>Warning</.badge>
```

## Available Properties

All generated components support:

- **`variant`**: Color variants (`:primary`, `:secondary`, `:accent`, `:neutral`, `:info`, `:success`, `:warning`, `:error`)
- **`size`**: Size variants (`:xs`, `:sm`, `:md`, `:lg`, `:xl`)
- **`style`**: Style variants (`:soft`, `:outline`, `:dash`, `:ghost`, `:link`)
- **`modifier`**: Component-specific modifiers (varies by component)
- **`class`**: Additional custom CSS classes
- **`@rest`**: Pass-through for standard HTML attributes

## Installation

1. Generate the components you need:
   ```bash
   mix daisyui.gen --components button,badge,card
   ```

2. Copy the generated files from `lib/daisyui_gen_components/` to your Phoenix project's component directory

3. Use them in your templates and LiveView components

## No Modification Required!

These components are ready to use as-is. They:
- ✅ Accept dynamic props
- ✅ Support all DaisyUI variants automatically
- ✅ Allow custom classes and HTML attributes
- ✅ Use proper Phoenix.Component patterns
- ✅ Include full type safety with `attr` declarations
