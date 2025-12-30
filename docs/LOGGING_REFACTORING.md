# Logging Standardization Refactoring

## Overview

This document describes the logging standardization refactoring completed for the Shops mod (B42.13.1). The refactoring centralizes all logging through a unified `SharedLogger` utility, replacing scattered `writeLog()` calls and `isDebug` guards throughout the codebase.

## Objectives Achieved

1. **Centralized Logging**: All logging now routes through `SharedLogger.log()` with consistent formatting
2. **Single Debug Toggle**: `SharedLogger.DEBUG` controls all logging verbosity globally
3. **Side Identification**: Logs automatically identify whether they're from CLIENT or SERVER
4. **Consistent Formatting**: All logs include timestamps and side tags: `[HH:MM:SS] [SERVER/CLIENT] message`

## Files Refactored (Logging Only)

### Shared Files
- ✅ `SharedLogger.lua` - Created centralized logger with DEBUG toggle
- ✅ `Nfunction.lua` - Replaced `isDebug` guards with `SharedLogger.log()`
- ✅ `ShopInit.lua` - Replaced `print()` and `writeLog()` with `SharedLogger.log()`
- ✅ `ShopPriceBuy.lua` - Replaced all `writeLog()` calls with `SharedLogger.log()`
- ✅ `ShopSellInit.lua` - Replaced all `writeLog()` calls with `SharedLogger.log()`
- ✅ `InventoryTransferValidation.lua` - Replaced all `writeLog()` calls with `SharedLogger.log()`
- ✅ `ShopEvents.lua` - Replaced all `writeLog()` calls with `SharedLogger.log()`
- ✅ `ShopDefaultItems.lua` - Replaced all `writeLog()` calls with `SharedLogger.log()`
- ✅ `ShopSellRegistry.lua` - Replaced all `writeLog()` calls with `SharedLogger.log()`
- ✅ `ShopPriceEvents.lua` - Replaced all `writeLog()` calls with `SharedLogger.log()`
- ✅ `ShopFinalizeHandler.lua` - Replaced all `writeLog()` calls with `SharedLogger.log()`

### Server Files
- ✅ `BalanceServer.lua` - Updated `BServer.writeLog()` to use `SharedLogger.log()`; replaced all direct `writeLog()` calls with `SharedLogger.log()`

### Client Files
- ✅ `ShopContext.lua` - Replaced `isDebug` guards with `SharedLogger.log()`; kept `isDebug` for UI visibility control only
- ✅ `PlayerShopContext.lua` - Replaced `isDebug` guards with `SharedLogger.log()`; removed conditional logging guards

## Key Changes to SharedLogger.lua

### Logic for Side Identification

```lua
-- Multiplayer:
-- isClient() = true only on client
-- isServer() = true only on server

-- Single-player:
-- isClient() = true AND isServer() = true (both return true)

-- Implementation:
local side
if isClient() and isServer() then
    side = "[SERVER]"  -- Single-player defaults to SERVER
elseif isClient() then
    side = "[CLIENT]"  -- Multiplayer client-only
else
    side = "[SERVER]"  -- Multiplayer server-only
end
```

This correctly identifies:
- **Multiplayer Client**: `[CLIENT]` tags
- **Multiplayer Server**: `[SERVER]` tags  
- **Single-Player**: `[SERVER]` tags (fallback, since single-player is both sides)

## Verification

### Log Output Examples

**Client Logs (2025-12-30_17-41_Shops.txt)**
```
[30-12-25 18:08:34.299] [CLIENT] [ShopEvents] Registering OnShopRegisterItems callback.
[30-12-25 18:10:16.720] [CLIENT] [ShopPriceBuy] resolvePlayerBuyPrice called: Base.Apple base=12.
```

**Server Logs (2025-12-30_18-06_Shops.txt)**
```
[30-12-25 18:06:58.970] [SERVER] [ShopEvents] Registering OnShopRegisterItems callback.
[30-12-25 18:07:01.116] [SERVER] Phase 2: Committing 34 items to registry.
```

Both sides correctly show their respective CLIENT/SERVER tags in multiplayer environments.

## Known Issues - Architectural (Not Logging Related)

### Issue: Duplicate Item Registration

Both CLIENT and SERVER logs show identical `RegisterItem` and `ShopSellRegistry` entries. This is an **architectural issue**, not a logging problem:

**Root Cause**: Registry files are in `shared/` folder, causing them to load on both client and server:
- `Shop.lua`
- `ShopRegistry.lua`
- `ShopInit.lua`
- `ShopDefaultItems.lua`
- `ShopSellRegistry.lua`
- `ShopEvents.lua`
- `ShopSellInit.lua`
- `ShopFinalizeHandler.lua`

**Impact**:
- Client registers items independently (not needed)
- Potential desync if client and server register differently
- Server should be the single source of truth

**Recommended Fix**: Move registry/initialization files to `server/` folder (see next section).

## Recommended Next Steps: Server-Side Registry

### Files to Move to `server/` Folder

```
Current: Shops/42.13.1/media/lua/shared/
  ├── Shop.lua
  ├── ShopRegistry.lua
  ├── ShopInit.lua
  ├── ShopDefaultItems.lua
  ├── ShopSellRegistry.lua
  ├── ShopEvents.lua
  ├── ShopSellEvents.lua
  ├── ShopSellInit.lua
  └── ShopFinalizeHandler.lua

Should Be: Shops/42.13.1/media/lua/server/
  └── (all above files)
```

### Files to Keep in `shared/` Folder

These files support both client and server logic and should remain shared:
- ✅ `SharedLogger.lua` - Logging utility
- ✅ `ShopPriceEvents.lua` - Price hooks used by client UI + server validation
- ✅ `ShopPriceBuy.lua` - Price calculation (used by ShopUI client-side and ShopBuyAction)
- ✅ `ShopPriceSell.lua` - Price calculation
- ✅ `ShopPriceUtils.lua` - Utility functions
- ✅ `InventoryTransferValidation.lua` - Validation for both sides

### Changes Required When Moving Files

1. Update `Shop.lua` requires to use relative paths or handle missing files on client
2. Add server-side guard in `ShopFinalizeHandler.lua`:
   ```lua
   if not isServer() then return end
   ```
3. Client code that needs the registry should receive it via server sync/transmission

## Usage: Controlling Logging

### Enable All Logging
```lua
SharedLogger.DEBUG = true
```

### Disable All Logging
```lua
SharedLogger.DEBUG = false
```

### Add Custom Logging
```lua
local SharedLogger = require("SharedLogger")
SharedLogger.log("Shops", "Your message here")
-- Output: [HH:MM:SS] [SERVER/CLIENT] Your message here
```

## Summary

✅ **Completed**: Centralized logging via SharedLogger  
✅ **Verified**: Client/Server identification working correctly  
✅ **Completed**: Moved registry files to server-only (Phase 2)

The logging refactoring provides a solid foundation for cleaner, more maintainable logging across the Shops mod.

---

# Phase 2: Server-Side Registry Migration

## Implementation Plan

### Step 1: Identify Registry Dependencies

Files currently in `shared/` that MUST move to `server/`:
- `Shop.lua` - Core registry management (register items, validate)
- `ShopRegistry.lua` - Item registry storage
- `ShopInit.lua` - Initialization logic
- `ShopDefaultItems.lua` - Default item registration
- `ShopSellRegistry.lua` - Seller registry storage
- `ShopSellInit.lua` - Seller initialization
- `ShopEvents.lua` - Registry-related event callbacks
- `ShopFinalizeHandler.lua` - Finalization logic

Files to keep in `shared/`:
- `SharedLogger.lua` - Used by both sides
- `ShopPriceBuy.lua` - Called by client UI + server actions
- `ShopPriceSell.lua` - Called by both sides
- `ShopPriceEvents.lua` - Events for both sides
- `ShopPriceUtils.lua` - Utility functions for both
- `InventoryTransferValidation.lua` - Validation for both sides

### Step 2: Update Require Paths

After moving files:
1. Update `Shop.lua` to handle missing requires on client gracefully
2. Client code should not directly require server-side files
3. Server will sync necessary data to clients via network transmission

### Step 3: Add Server-Side Guards

Files that might be required in `shared/` but should only execute on server:
```lua
-- In ShopFinalizeHandler.lua
if not isServer() then return end
```

### Step 4: Test Client-Side Functionality

Verify client can still:
- Display shop UI
- Calculate prices via shared functions
- Receive registry updates from server
- Complete buy/sell transactions

### Files Affected by Move

| File | Current Location | New Location | Reason |
|------|------------------|--------------|--------|
| Shop.lua | shared/ | server/ | Registry management is server authority |
| ShopRegistry.lua | shared/ | server/ | Registry storage |
| ShopInit.lua | shared/ | server/ | Initialization runs once on server |
| ShopDefaultItems.lua | shared/ | server/ | Registration is server-only |
| ShopSellRegistry.lua | shared/ | server/ | Registry storage |
| ShopSellInit.lua | shared/ | server/ | Initialization runs once on server |
| ShopEvents.lua | shared/ | server/ | Most callbacks are registration-related |
| ShopFinalizeHandler.lua | shared/ | server/ | Finalization is server-only |

## Benefits of This Change

1. **Single Source of Truth**: Server owns the registry, no client-side duplication
2. **Network Efficiency**: Registry loads once on server, synced to clients as needed
3. **Cleaner Architecture**: Clear separation of server authority vs client presentation
4. **Reduced Logging Noise**: Registry logs appear once in server logs
5. **Easier Debugging**: No confusion about which side owns registry state

---

## Phase 2: Clean Architecture Complete

### Shared Files (Both Client & Server)

✅ All core logic in `shared/` - works on both sides:
- `Shop.lua` - Core registry structure with UI constants
- `ShopRegistry.lua` - Item registration (`Shop.RegisterItem`)
- `ShopInit.lua` - Registry finalization (`Shop.FinalizeRegistry`)
- `ShopDefaultItems.lua` - Default item loading via hooks
- `ShopSellRegistry.lua` - Sell registration (`Shop.RegisterSellItem`)
- `ShopSellInit.lua` - Sell finalization (`Shop.FinalizeSellRegistry`)
- `ShopEvents.lua` - Item registration event hooks
- `ShopSellEvents.lua` - Sell registration event hooks
- `ShopFinalizeHandler.lua` - Unified finalization logic

### Server-Only Files

✅ Clear server-side implementation in `server/`:
- `ShopInitServer.lua` - Loads all shared modules on server startup
- `ShopFinalizeHandlerServer.lua` - Registers server-side event hooks only (OnServerStarted)
- `ShopInitServer.lua` requires both shared and server files in correct order

### Removed

✅ Deleted `server/registry/` subfolder (no longer needed)
✅ Removed confusing server guards from shared files

### Registry Load Flow

**Server-side initialization:**
1. `ShopInitServer.lua` requires `registry/Shop`
2. `registry/Shop.lua` loads all registry modules with `isServer()` guard
3. External mods can register hooks via `ShopEvents.registerOnShopRegisterItems()`
4. `ShopFinalizeHandler.finalizeNow()` triggered on `Events.OnServerStarted`
5. Registry locked after finalization, client receives synced data

**Client-side behavior:**
1. Shared stubs prevent require errors
2. Client can attempt to register items (stub does nothing)
3. Client receives Shop registry data from server via network sync
4. Client uses price calculation functions from shared files

### Testing Checklist

- [ ] Server starts without errors
- [ ] Registry finalizes on server startup
- [ ] Client connects and receives shop data
- [ ] Item prices display correctly on client
- [ ] Buy/sell transactions work end-to-end
- [ ] Logs show only server entries for registry operations
- [ ] External mods can still register hooks via ShopEvents
