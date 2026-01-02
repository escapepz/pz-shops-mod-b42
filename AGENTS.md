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
- **Logging**: Always use `SharedLogger.log()` for centralized logging. Never use `writeLog()` or other logging functions
  - `SharedLogger` is defined in `shared/nshopsb42/utils/SharedLogger.lua` and extends the SHOPSB42 namespace
  - Access via `SHOPSB42.SharedLogger.log()` or local reference: `local SharedLogger = SHOPSB42.SharedLogger`
  - Requires local require in files that don't have SHOPSB42 available: `local SharedLogger = require("nshopsb42/utils/SharedLogger")`
  - Usage: `SharedLogger.log(modName, message)` where modName is typically "Shops"
  - SharedLogger automatically adds `[SERVER]` or `[CLIENT]` context to all messages
  - Only SharedLogger.lua is permitted to call the global `writeLog()` function internally

## Checking Game Logs

When debugging, check the Shops mod logs in the `Logs/` directory:

**Server logs:** `Logs/Server/*_Shops.txt` - Find the most recent file with `_Shops.txt` suffix
**Client logs:** `Logs/Client/*_Shops.txt` - Find the most recent file with `_Shops.txt` suffix

Example:
- `Logs/Server/2026-01-02_17-23_Shops.txt`
- `Logs/Client/2026-01-02_17-29_Shops.txt`

These files contain SharedLogger output for the Shops mod only (clean, structured logs).
