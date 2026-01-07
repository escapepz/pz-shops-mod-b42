# AGENTS.md - Shopsb42 Mod Project

## General Principles

- **Prefer serena tools**: Use serena tools first for all code operations (find, read, edit, insert, replace) to save tokens. Fall back to Amp tools only when serena cannot handle the task.

## Documentation & API Reference

- **Core Docs**: `./docs/B42.13_MP_Project_Zomboid_API_for_Inventory_Items.md` and `./docs/B42.13_MP_Migration_Guide.md`
- **PZ API Definitions**: `.libraries/library/lua/` - Contains PZ engine API type definitions and method signatures
  - Use when unsure about correct method names (e.g., `square:getObjects()` not `square:getTileObjects()`)
  - Check existing code in `Shops/` for working examples before relying on definitions
- **Vanilla Game Code**: `tmp/Vanilla/` - Extracted vanilla Project Zomboid Lua code for reference
  - Search here to understand how the game implements core features (building, containers, inventory, etc.)
  - Use as reference for proper API usage patterns and idioms
  -

## Documentation Governance

All documentation generated or modified by agents **MUST comply** with the
Documentation Linter Rule Set.

**Canonical rules:**  
-> `docs/architecture/documentation_linter_rules.md`

Failure to comply is considered a documentation error, not an implementation error.

If a generated document violates the Documentation Linter Rule Set,
the agent MUST:

1. Identify the violated rules
2. Relocate or rename the document
3. Rewrite only what is necessary to comply

## Build/Commands

- **Format code**: `stylua Shops\42.13.1\media\lua ShopsHooksExample\42.13.1\media\lua` (run `fmt.bat`)
- **Build**: `npm run build` - Cleans and builds project
- **Watch**: `npm run watch` - Continuous build mode
- **Clean**: `npm run clean` - Removes build artifacts

## Architecture & Key Info

- **Type**: Lua mod for Project Zomboid B42.13.1 (multiplayer support)
- **Structure**: `Shops/42.13.1/media/lua/` split into `shared/`, `client/`, `server/` directories
- **Core APIs**: `.libraries/library/lua/` (PZ engine type definitions); `tmp/Vanilla/` (reference vanilla code)
- **Docs**: `./docs/B42.13_MP_Project_Zomboid_API_for_Inventory_Items.md` and `B42.13_MP_Migration_Guide.md`

## Listing Data Contract (Phases 1-3)

This documents the versioned content distribution system for shop listings:

- **Listings are versioned content**: Every listing snapshot has a monotonically-increasing revision number
- **Listings are immutable per server session**: Revisions only change on server restart
- **Listings are cached client-side**: Persisted to `Lua/shops/listing_snapshot_<serverId>.lua` across client restarts
- **Listings are monotonic across disk, memory, and network**: 
  - Disk monotonicity: enforced in `ListingCache.saveSnapshot()` (rejects downgrades)
  - Memory monotonicity: enforced in `ShopCommandDispatcher.SyncShopData()` (rejects downgrades)
  - Network monotonicity: server increments revision on restart, no version reuse
- **Listings are never trusted for transactions**: 
  - Cache is preview-only (never read for transaction validation)
  - Server validates all prices and availability on purchase/sale
  - Client price calculations use `PricingContract` deterministically from listing data

**Bootstrap priority** (highest revision wins):
1. Shared `ShopCatalog` (Tier 0, revision 0) - always available
2. Disk cache (Tier 2, revision >= 1) - persisted from server
3. Network `SyncShopData` (upgrade-only) - server sends if revision mismatch detected

## Code Style

- **Language**: Lua (Kahlua JVM-based, not standard Lua)
- **Indent**: Tabs; CamelCase for classes/modules; lowercase for variables
- **Naming**: CamelCase for classes/modules, lowercase for variables
- **Comments**: `--` only; never use `->` or emoji in code
- **Logging**: Use `SHOPSB42.SharedLogger.log("Shops", message)` or local reference `local SharedLogger = require("nshopsb42/utils/SharedLogger")`
  - Never use `writeLog()` or log in `render()` functions (executes every frame, severe performance issues)
  - SharedLogger automatically adds `[SERVER]` or `[CLIENT]` context to all messages
  - Log only in event handlers, UI updates, or initialization code
- **Formatting**: Run `fmt.bat` after changes
- **Kahlua Lua Limitations**:
  - Avoid `next()` function (crashes unpredictably); use `for _ in pairs(table) do break end` instead to check if table is empty
  - Always check table existence before iteration (defensive nil checks prevent crashes)
- **Events**: Use `Events.OnConnected` for server-client data (fires on every connection/reconnection)
  - Do NOT rely solely on `Events.OnGameStart` as it only fires once per game session and will not re-trigger when client reconnects to a restarted server

## Debugging

When debugging, check logs in the root `Logs/` directory only (do NOT search in nested folders):

**Mod-specific logs:**

- **Server logs**: `Logs/Server/*_Shops.txt` - Most recent file with `_Shops.txt` suffix in the root Server folder
- **Client logs**: `Logs/Client/*_Shops.txt` - Most recent file with `_Shops.txt` suffix in the root Client folder
- These files contain SharedLogger output for the Shops mod only (clean, structured logs)

**Game runtime logs (for errors/file issues):**

- **Server debug**: `Logs/Server/*_DebugLog.txt` - Game console log for server-side errors
- **Client debug**: `Logs/Client/*_DebugLog.txt` - Game console log for client-side errors
- Check these if there are file loading errors or Lua errors from the game runtime

Do NOT look in:

- `Logs/Server/logs_YYYY-MM-DD/` (nested date folders)
- `Logs/Client/logs_YYYY-MM-DD/` (nested date folders)

## Environment

- **OS**: Windows only - no Unix tools
  - For getting latest file: Use `powershell -Command "Get-ChildItem ... | Sort-Object LastWriteTime -Descending | Select-Object -First 1"`
  - Do NOT pipe `dir /O:-D` output to `head` (Unix command, doesn't exist on Windows)
- **File paths**: Use Windows backslash separators (`\`) in bash commands or powershell
- **Lua files**: Use serena or Amp `create_file` tool (avoid PowerShell UTF-8 BOM)
