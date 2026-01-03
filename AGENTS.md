# Agent Guidelines for Shopsb42

## General Principles

- **Prefer serena tools**: Use serena tools first for all code operations (find, read, edit, insert, replace) to save tokens. Fall back to Amp tools only when serena cannot handle the task.

## Documentation & API Reference

- **Core Docs**: `./docs/B42.13_MP_Project_Zomboid_ API_for_Inventory_Items.md` and `./docs/B42.13_MP_Migration_Guide.md`
- **PZ API Definitions**: `.libraries/library/lua/` - Contains PZ engine API type definitions and method signatures
  - Use when unsure about correct method names (e.g., `square:getObjects()` not `square:getTileObjects()`)
  - Check existing code in `Shops/` for working examples before relying on definitions
- **Vanilla Game Code**: `tmp\Vanilla` - Extracted vanilla Project Zomboid Lua code for reference
  - Search here to understand how the game implements core features (building, containers, inventory, etc.)
  - Use as reference for proper API usage patterns and idioms

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
  - Never use `->` or emoji in code text or comments
- **Lua version**: Target Project Zomboid's Lua API (B42.13+)
- **File structure**: All shared code must be in `shared/`, separated by client/server when needed
- **Formatting**: Run `stylua Shops\42.13.1\media\lua` after making code changes to maintain consistent formatting
- **Logging**: Always use `SharedLogger.log()` for centralized logging. Never use `writeLog()` or other logging functions
  - `SharedLogger` is defined in `shared/nshopsb42/utils/SharedLogger.lua` and extends the SHOPSB42 namespace
  - Access via `SHOPSB42.SharedLogger.log()` or local reference: `local SharedLogger = SHOPSB42.SharedLogger`
  - Requires local require in files that don't have SHOPSB42 available: `local SharedLogger = require("nshopsb42/utils/SharedLogger")`
  - Usage: `SharedLogger.log(modName, message)` where modName is typically "Shops"
  - SharedLogger automatically adds `[SERVER]` or `[CLIENT]` context to all messages
  - Only SharedLogger.lua is permitted to call the global `writeLog()` function internally
  - **CRITICAL**: Never add logging inside `render()` functions or functions called by `render()` - they execute every frame and will cause severe performance issues. Log only in event handlers, UI updates, or initialization code.
- **Client Events**: Use `Events.OnConnected` for server-to-client data requests (fires on every connection/reconnection). Do NOT rely solely on `Events.OnGameStart` as it only fires once per game session and will not re-trigger when client reconnects to a restarted server.
- **Kahlua Lua Limitations**: Project Zomboid uses Kahlua (a Java-based Lua implementation) with some quirks:
  - **Avoid `next()` function**: The `next()` function can crash unpredictably in Kahlua. Replace with explicit iteration: `for _ in pairs(table) do break end` instead of `next(table)` to safely check if empty.
  - Always check table existence before iteration: defensive nil checks prevent crashes

## Environment

- **Development OS**: Windows (avoid all Unix tools - no `ls`, `grep`, `head`, `tail`, `cat`, etc. Use Windows CLI: `dir`, `findstr`, `type`, etc.)
  - For getting latest file: Use `powershell -Command "Get-ChildItem ... | Sort-Object LastWriteTime -Descending | Select-Object -First 1"`
  - Do NOT pipe `dir /O:-D` output to `head` (Unix command, doesn't exist on Windows)
- **File paths**: Use Windows backslash separators (`\`) in bash commands or powershell
- **File creation**: Avoid PowerShell for creating Lua files - it adds UTF-8 BOM which PZ cannot read. Use serena tools first (to save tokens), or Amp's `create_file` tool as fallback.

## Checking Game Logs

When debugging, check logs in the root `Logs/` directory only (do NOT search in nested folders):

**Mod-specific logs:**
- **Server logs:** `Logs/Server/*_Shops.txt` - Most recent file with `_Shops.txt` suffix in the root Server folder
- **Client logs:** `Logs/Client/*_Shops.txt` - Most recent file with `_Shops.txt` suffix in the root Client folder
- These files contain SharedLogger output for the Shops mod only (clean, structured logs)

**Game runtime logs (for errors/file issues):**
- **Server debug:** `Logs/Server/*_DebugLog.txt` - Game console log for server-side errors
- **Client debug:** `Logs/Client/*_DebugLog.txt` - Game console log for client-side errors
- Check these if there are file loading errors or Lua errors from the game runtime

Do NOT look in:
- `Logs/Server/logs_YYYY-MM-DD/` (nested date folders)
- `Logs/Client/logs_YYYY-MM-DD/` (nested date folders)

Example of correct paths:
- `Logs/Server/2026-01-02_17-23_Shops.txt` (Shops mod log)
- `Logs/Server/2026-01-02_17-23_DebugLog.txt` (Game debug log)
- `Logs/Client/2026-01-02_17-29_Shops.txt` (Shops mod log)
- `Logs/Client/2026-01-02_17-29_DebugLog.txt` (Game debug log)
