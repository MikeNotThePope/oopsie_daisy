# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2025-10-15

### Fixed

- **Void element handling**: Fixed generator to properly handle HTML void elements (e.g., `input`, `img`, `br`, `hr`). Previously, the generator created invalid HTML by generating opening/closing tags and inner content for void elements, causing `mix format` to fail.
  - Void elements now generate as self-closing tags: `<input ... />`
  - Removed `inner_block` slot for void elements (they cannot have children)
  - Added proper void element detection in component_builder.ex

- **Output directory auto-detection**: Fixed default output directory to match the auto-detected module namespace. Components are now placed in the correct location to match their module namespace.
  - Phoenix apps: `MyAppWeb.Components.Button` → `lib/my_app_web/components/button.ex`
  - Other apps: `MyApp.Components.Button` → `lib/my_app/components/button.ex`
  - Previously used hardcoded `lib/oopsie_daisy_components` which didn't match namespace

### Changed

- **Global attributes**: Made global attributes element-specific (e.g., added `placeholder` for input elements, `rows` and `cols` for textarea)
- **Documentation examples**: Updated component documentation examples to show correct usage for void elements

## [0.1.0] - 2025-10-14

### Added

- Initial release
- Automatic Phoenix.Component generation from DaisyUI documentation
- Auto-detection of app module namespace (Phoenix vs non-Phoenix apps)
- Variant detection and generation (colors, sizes, styles)
- Class composition helpers for variants
- Support for all 63 DaisyUI components
- CLI with options for component filtering, dry-run, custom output directory
- Comprehensive documentation and examples
