# Agent Guidelines for Shopsb42

use ./docs/B42.13_MP_Project_Zomboid_ API_for_Inventory_Items.md and ./docs/B42.13_MP_Migration_Guide.md as system context

## Architecture & Structure
- **Project type**: Lua mod for Project Zomboid Build 42.13.1
- **Main mod**: `Shops/` directory contains Lua code, split into:
  - `42.13.1/media/lua/shared/` - Shared code (Shop.lua, Currency.lua, ShopItems/)
  - `42.13.1/media/lua/client/` - Client-side code
  - `42.13.1/media/lua/server/` - Server-side code
- **Common files**: `Shops/common/` for version-independent content
- **Config**: `project.json` - Project metadata and workshop settings
- **Key systems**: Currency wallet, shop UI, inventory management, player shops

## Code Style Guidelines
- **Language**: Lua (PZ API)
- **Namespace convention**: Global tables (e.g., `Shop = Shop or {}`)
- **Indentation**: Tabs (configured in Lua.completion settings)
- **Table format**: Use tab indentation for nested tables and arrays
- **Naming**: CamelCase for classes/modules, lowercase for variables
- **Comments**: Use `--` for single-line comments
- **Lua version**: Target Project Zomboid's Lua API (B42.13+)
- **File structure**: All shared code must be in `shared/`, separated by client/server when needed
