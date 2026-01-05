# AGENTS.md - Shopsb42 Mod Project

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

## Code Style
- **Language**: Lua (Kahlua JVM-based, not standard Lua)
- **Indent**: Tabs; CamelCase for classes/modules; lowercase for variables
- **Logging**: Use `SHOPSB42.SharedLogger.log("Shops", message)` - never use `writeLog()` or log in `render()` functions
- **Formatting**: Run `fmt.bat` after changes
- **Avoid**: `next()` function (crashes in Kahlua); use `for _ in pairs(table) do break end` instead
- **Events**: Use `Events.OnConnected` for server-client data (not just `OnGameStart`)
- **Comments**: `--` only; no emoji or `->` in code

## Debugging
- **Server logs**: `Logs/Server/*_Shops.txt` (mod-specific) or `*_DebugLog.txt` (game errors)
- **Client logs**: `Logs/Client/*_Shops.txt` (mod-specific) or `*_DebugLog.txt` (game errors)

## Environment
- **OS**: Windows only - no Unix tools
- **Lua files**: Use serena or Amp `create_file` tool (avoid PowerShell UTF-8 BOM)
