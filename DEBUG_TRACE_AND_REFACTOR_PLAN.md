# Debug Trace & Refactor Plan: Client-Server Shop Sync Issue

## Executive Summary

**Problem**: Client logs show shop initialization code running in CLIENT context (should be server-only), and client never receives shop data from server despite requesting it.

**Root Causes**:
1. **Shared Init loading issue** - Items are being registered on BOTH client and server instead of server-only
2. **Missing server response** - Server handler exists but no evidence it's being called or responding
3. **Client-side initialization in wrong place** - Lines 1-26 of client log show `[CLIENT]` tags running server-side init code

---

## Log Trace Analysis

### Server Log (16:40) - CORRECT BEHAVIOR ✓
```
[02-01-26 16:41:06.454] [SERVER] RegisterItem: Base.HairDyeBlonde (tab: Event, price: 5).
[02-01-26 16:41:06.454] [SERVER] RegisterItem: Base.Bag_BigHikingBag (tab: Event, price: 5).
...
[02-01-26 16:41:08.567] [SERVER] [ShopBuyInit] Phase 1: Executing 1 hook(s) to gather buy items.
[02-01-26 16:41:08.567] [SERVER] [ShopBuyInit] Phase 2: Registering 8 items
[02-01-26 16:41:08.569] [SERVER] [ShopSellInit] Phase 2: Registering 4 items
[02-01-26 16:41:08.572] [SERVER] [ShopFinalizeHandler] Finalization complete - live price hook broadcasting ENABLED.
```

**Timeline**: 16:41:06-08 (initialization completes successfully)
- 8 buy items registered ✓
- 4 sell items registered ✓
- Price modifiers built ✓
- Finalization complete ✓

### Client Log (16:39-16:44) - BROKEN BEHAVIOR ✗

#### Phase 1: Initialization Lines 1-26 (16:42:46)
```
[02-01-26 16:42:46.070] [CLIENT] [ShopInitServer] All modules loaded. Beginning initialization....
[02-01-26 16:42:46.070] [CLIENT] [ShopBuyInit] Phase 1: Executing 0 hook(s) to gather buy items.
[02-01-26 16:42:46.071] [CLIENT] [ShopBuyInit] Phase 2: Registering 0 items
[02-01-26 16:42:46.072] [CLIENT] [ShopSellInit] Phase 2: Registering 0 items
```

**CRITICAL ISSUE**: These logs show `[CLIENT]` prefix but are running `ShopInitServer` code, which should ONLY run on server.
- 0 buy items (should be 8)
- 0 sell items (should be 4)
- No hooks registered
- Initialization code executing in wrong context

#### Phase 2: Client Startup Lines 27-31 (16:43:32)
```
[02-01-26 16:43:32.841] [CLIENT] [ShopCommandHandlerServer] Initialized.
[02-01-26 16:43:32.841] [CLIENT] [ShopSyncClient] Initialized - event listener registered for OnServerCommand.
[02-01-26 16:43:32.841] [Client Init] OnGameStart event triggered.
[02-01-26 16:43:32.843] [Client Init] Sent RequestShopData command to server.
```

**What should happen**: Client requests data from server
- Line 33: Client sends `RequestShopData` ✓

#### Phase 3: Server Missing Response (16:43:32-16:44:47)
```
[02-01-26 16:44:34.770] [ShopUI:show] Shop not yet synced from server. Waiting....
[02-01-26 16:44:38.539] [ShopUI:show] Shop not yet synced from server. Waiting....
[02-01-26 16:44:43.536] [ShopUI:show] Shop not yet synced from server. Waiting....
[02-01-26 16:44:47.819] [ShopUI:show] Shop not yet synced from server. Waiting....
```

**CRITICAL ISSUE**: ShopUI cannot open because `ShopSyncClient.isShopReady()` returns false.
- No `SyncShopData` received
- No `SyncBuyPrices` received  
- No `SyncSellRules` received
- No `SyncInitialComplete` received

---

## Root Cause Analysis

### Issue #1: Shared Init Loading Both Sides

**File**: `Shops/42.13.1/media/lua/shared/nshopsb42/Init.lua`

```lua
-- This file loads on BOTH client and server
require("nshopsb42/ShopDefaultItems")  -- Line 26
```

**Problem**: `ShopDefaultItems` contains item registration hooks that execute during its load.

**Evidence from logs**:
- Server log (16:41:06): Shows item registration happening
- Client log (16:42:46): Shows SAME initialization code with `[CLIENT]` prefix
- Client registers 0 items because it doesn't have the hooks, but it TRIES to initialize

**Code Flow**:
```
Shared Init.lua (lines 1-36)
├── require ShopDefaultItems (line 26)
│   └── Hooks registered (should be server only)
├── On SERVER: ShopInitServer.lua calls Initialize()
│   └── ShopDefaultItems.registerHooks() (line 43)
│       └── Items get registered ✓
│
└── On CLIENT: Also loading same code
    └── Hooks exist but not firing properly
        └── 0 items registered ✗
```

### Issue #2: Server Handler Not Being Called

**File**: `Shops/42.13.1/media/lua/server/nshopsb42/ShopInitServer.lua` (lines 57-78)

```lua
local function onClientCommand(module, command, player, data)
    if module ~= "Shops" then return end
    if command ~= "RequestShopData" then return end
    
    SharedLogger.log("Shops", "[ShopInitServer] Received RequestShopData...")
    ShopFinalizeHandler.sendShopDataToPlayer(player)
end

Events.OnClientCommand.Add(onClientCommand)
```

**Issue**: 
- Handler is registered ✓
- Handler logs indicate it should respond ✓
- **But no log output in either server or client logs showing handler execution**
- Client never receives the 4 required broadcasts:
  1. `SyncShopData`
  2. `SyncBuyPrices`
  3. `SyncSellRules`
  4. `SyncInitialComplete`

**Hypothesis**: 
- Handler might not be executing on server at all
- Or handler is executing but `Utilities.SendServerCommandTo()` is silently failing
- Time gap: Server init at 16:41:08, Client request at 16:43:32 (2.5 minutes later!)

### Issue #3: Client Initialization Code in Shared Context

**Problem Path**:
```
Client/Init.lua loads shared modules:
├── require("nshopsb42/core/Shop")
├── require("nshopsb42/ShopDefaultItems")  <- PROBLEM
└── Tries to run initialization code from shared/Init.lua
```

Lines 1-26 of client log show `[CLIENT]` + `[ShopInitServer]` tags together, meaning the shared initialization code is executing on client during normal load (not via OnGameStart).

---

## Code Structure Issues

### Current (Broken) Architecture:

```
shared/Init.lua (LOADS ON BOTH SIDES)
├── Requires ShopDefaultItems
├── Requires ShopInit (initializes registries)
├── Requires ShopSellInit
└── ← Items can register on client!

server/ShopInitServer.lua
├── Requires same modules again
├── Calls ShopDefaultItems.registerHooks() explicitly
└── Calls ShopFinalizeHandler.finalizeNow()

client/Init.lua
├── Requires shared code again
├── Tries to initialize ShopSyncClient
└── Requests data at OnGameStart
```

**Why This Is Broken**:
1. Shared Init loads `ShopDefaultItems` unconditionally
2. Client loads shared Init → items attempt to register on client too
3. No guard prevents client-side initialization
4. Server's `onClientCommand` handler exists but may not execute in MP context
5. No debug output confirms handler was called on server

---

## Refactor Plan

### Phase 1: Prevent Client-Side Item Registration

#### Step 1.1: Guard Shared Init Load
**File**: `Shops/42.13.1/media/lua/shared/nshopsb42/Init.lua`

```lua
-- Add at top
local Utilities = require("nshopsb42/utils/Utilities")

-- CHANGE: Only load item registration on server
if not Utilities.IsClientOnly() then
    require("nshopsb42/ShopDefaultItems")
end

-- Move sensitive loading to server only
if not Utilities.IsClientOnly() then
    require("nshopsb42/ShopInit")
    require("nshopsb42/sales/ShopSellInit")
end
```

#### Step 1.2: Remove Item Registration from Shared Init
**Recommendation**: Move these lines from shared to server only:
```lua
-- REMOVE from shared/Init.lua line 26
-- require("nshopsb42/ShopDefaultItems")
-- require("nshopsb42/ShopInit")  (line 12)
-- require("nshopsb42/sales/ShopSellInit")  (line 13)
```

### Phase 2: Debug Server Handler Execution

#### Step 2.1: Add Detailed Logging
**File**: `Shops/42.13.1/media/lua/server/nshopsb42/ShopInitServer.lua`

Add trace logging at every stage:

```lua
local function onClientCommand(module, command, player, data)
    -- Log BEFORE guard to confirm handler called
    writeLog("Shops", "[ShopInitServer.onClientCommand] ENTRY: module=" .. tostring(module) .. ", command=" .. tostring(command))
    
    if module ~= "Shops" then
        writeLog("Shops", "[ShopInitServer.onClientCommand] Module mismatch, returning")
        return
    end

    if command ~= "RequestShopData" then
        writeLog("Shops", "[ShopInitServer.onClientCommand] Command mismatch: " .. command)
        return
    end

    local username = player and player:getUsername() or "nil"
    writeLog("Shops", "[ShopInitServer.onClientCommand] PROCESSING RequestShopData from " .. username)

    -- Debug shop state BEFORE sending
    local shop = SHOPSB42.Shop
    writeLog("Shops", "[ShopInitServer.onClientCommand] Shop._finalized=" .. tostring(shop._finalized))
    writeLog("Shops", "[ShopInitServer.onClientCommand] Shop.Items count=" .. (shop.Items and #shop.Items or 0))
    writeLog("Shops", "[ShopInitServer.onClientCommand] Shop.PlayerBuy count=" .. (shop.PlayerBuy and #shop.PlayerBuy or 0))

    writeLog("Shops", "[ShopInitServer.onClientCommand] Calling ShopFinalizeHandler.sendShopDataToPlayer...")
    
    local success, err = pcall(function()
        ShopFinalizeHandler.sendShopDataToPlayer(player)
    end)
    
    if not success then
        writeLog("Shops", "[ShopInitServer.onClientCommand] ERROR in sendShopDataToPlayer: " .. tostring(err))
    else
        writeLog("Shops", "[ShopInitServer.onClientCommand] sendShopDataToPlayer completed successfully")
    end
end
```

#### Step 2.2: Verify Handler Registration
**File**: `Shops/42.13.1/media/lua/server/nshopsb42/ShopInitServer.lua` (line 78)

```lua
-- Add trace that handler was registered
writeLog("Shops", "[ShopInitServer] Registering onClientCommand handler for RequestShopData")
Events.OnClientCommand.Add(onClientCommand)
writeLog("Shops", "[ShopInitServer] onClientCommand handler registered")
```

### Phase 3: Verify Client Request Sends Properly

#### Step 3.1: Trace Client Request
**File**: `Shops/42.13.1/media/lua/client/nshopsb42/Init.lua` (line 63)

```lua
writeLog("Shops", "[Client Init] About to send RequestShopData")
writeLog("Shops", "[Client Init] isMultiplayer=" .. tostring(isMP))
writeLog("Shops", "[Client Init] sendClientCommand args: module='Shops', command='RequestShopData', data={}")

local success = pcall(function()
    sendClientCommand("Shops", "RequestShopData", {})
end)

if success then
    writeLog("Shops", "[Client Init] sendClientCommand executed successfully")
else
    writeLog("Shops", "[Client Init] ERROR: sendClientCommand failed")
end
```

### Phase 4: Verify Server Response Path

#### Step 4.1: Debug Utilities.SendServerCommandTo()
**File**: `Shops/42.13.1/media/lua/server/nshopsb42/transactions/ShopFinalizeHandlerServer.lua`

```lua
function ShopFinalizeHandler.sendShopDataToPlayer(player)
    -- ... existing validation ...
    
    writeLog("Shops", "[ShopFinalizeHandler.sendShopDataToPlayer] BEFORE SyncShopData send")
    writeLog("Shops", "[ShopFinalizeHandler.sendShopDataToPlayer] Player username=" .. player:getUsername())
    
    local success, err = pcall(function()
        Utilities.SendServerCommandTo(player, "Shops", "SyncShopData", shopData)
    end)
    
    if not success then
        writeLog("Shops", "[ShopFinalizeHandler.sendShopDataToPlayer] ERROR sending SyncShopData: " .. tostring(err))
    else
        writeLog("Shops", "[ShopFinalizeHandler.sendShopDataToPlayer] SyncShopData sent successfully")
    end
    
    -- Repeat for each broadcast...
end
```

#### Step 4.2: Debug Client Receiver
**File**: `Shops/42.13.1/media/lua/client/nshopsb42/sync/ShopSyncClient.lua` (line 331)

```lua
if command == "SyncShopData" then
    writeLog("Shops", "[ShopSyncClient] RECEIVED SyncShopData from server")
    -- ... existing code ...
    writeLog("Shops", "[ShopSyncClient] Stored items: " .. itemCount .. " total")
else
    writeLog("Shops", "[ShopSyncClient] Received unknown command: " .. command .. " (expected SyncShopData)")
end
```

### Phase 5: Structural Fix - Separate Server Init

#### Step 5.1: Create Server-Only Init
**File**: `Shops/42.13.1/media/lua/server/nshopsb42/Init.lua` (NEW)

```lua
-- Server-only initialization (not in shared/)
local SharedLogger = require("nshopsb42/utils/SharedLogger")
local Utilities = require("nshopsb42/utils/Utilities")

if not Utilities.IsServerOrSinglePlayer() then
    error("Server Init loaded on client! This is a configuration error.")
end

writeLog("Shops", "[Server Init] Starting server-specific initialization")

-- Server-only modules
require("nshopsb42/ShopDefaultItems")
require("nshopsb42/ShopInit")
require("nshopsb42/sales/ShopSellInit")
require("nshopsb42/ShopInitServer")

writeLog("Shops", "[Server Init] Server initialization complete")
```

#### Step 5.2: Update mod.xml to Load Correct Contexts
**File**: `Shops/mod.xml`

Ensure contexts are correct:
```xml
<module name="Shops">
    <!-- Shared modules (load on both) -->
    <import name="Shops" />
    
    <!-- Server-only modules -->
    <module name="ShopsServer">
        <import name="ShopsServer" />
    </module>
    
    <!-- Client-only modules -->
    <module name="ShopsClient">
        <import name="ShopsClient" />
    </module>
</module>
```

### Phase 6: Implementation Priority Order

**CRITICAL (Do First)**:
1. ✓ Add guard to shared/Init.lua to prevent loading ShopDefaultItems on client
2. ✓ Add trace logging to server handler to confirm execution
3. ✓ Add trace logging to client request to confirm send
4. ✓ Add trace logging to client receiver to confirm receipt

**HIGH (Do Second)**:
5. Verify Utilities.SendServerCommandTo() works in MP context
6. Create separate server/Init.lua for server-only code
7. Update mod.xml/manifest to clarify module contexts

**MEDIUM (Do Third)**:
8. Remove item registration from shared context entirely
9. Consolidate all server initialization into server/Init.lua
10. Add comprehensive comments about MP vs SP context

---

## Testing Checklist

After implementing fixes:

- [ ] Server log shows 8 buy items, 4 sell items registered
- [ ] Client log shows 0 items registered (client doesn't register)
- [ ] Client log shows handler execution message from server
- [ ] Client log shows "Received SyncShopData from server" message
- [ ] Client log shows "Initial sync COMPLETE" message
- [ ] Client log shows shop opens without "Waiting..." loop
- [ ] Admin shop UI displays items correctly
- [ ] Player shop interactions work

---

## Files to Modify

1. **shared/nshopsb42/Init.lua** - Add guards for ShopDefaultItems loading
2. **server/nshopsb42/ShopInitServer.lua** - Add detailed trace logging
3. **client/nshopsb42/Init.lua** - Add request trace logging
4. **server/nshopsb42/transactions/ShopFinalizeHandlerServer.lua** - Add response trace logging
5. **client/nshopsb42/sync/ShopSyncClient.lua** - Add receiver trace logging
6. **server/nshopsb42/Init.lua** (NEW) - Create server-only initialization
7. **mod.xml** (if exists) - Verify context declarations

---

## Expected Log Output After Fixes

### Server Log:
```
[02-01-26 16:41:06.454] [SERVER] RegisterItem: Base.HairDyeBlonde...
[02-01-26 16:41:08.572] [SERVER] [ShopFinalizeHandler] Finalization complete
[02-01-26 16:43:32.841] [ShopInitServer] Registering onClientCommand handler
[02-01-26 16:43:32.850] [ShopInitServer.onClientCommand] ENTRY: module=Shops, command=RequestShopData
[02-01-26 16:43:32.851] [ShopInitServer.onClientCommand] Shop._finalized=true
[02-01-26 16:43:32.852] [ShopInitServer.onClientCommand] Calling sendShopDataToPlayer...
[02-01-26 16:43:32.853] [ShopFinalizeHandler.sendShopDataToPlayer] Sending SyncShopData command...
[02-01-26 16:43:32.854] [ShopFinalizeHandler.sendShopDataToPlayer] Sending SyncBuyPrices...
[02-01-26 16:43:32.855] [ShopFinalizeHandler.sendShopDataToPlayer] Sending SyncSellRules...
[02-01-26 16:43:32.856] [ShopFinalizeHandler.sendShopDataToPlayer] Sending SyncInitialComplete...
```

### Client Log:
```
[02-01-26 16:42:46.070] [CLIENT] [ShopBuyInit] Phase 2: Registering 0 items (client doesn't register)
[02-01-26 16:43:32.843] [Client Init] Sent RequestShopData command to server
[02-01-26 16:43:32.850] [ShopSyncClient] RECEIVED SyncShopData from server
[02-01-26 16:43:32.851] [ShopSyncClient] Stored items: 8 total, 8 buy, 4 sell
[02-01-26 16:43:32.852] [ShopSyncClient] Received SyncBuyPrices from server
[02-01-26 16:43:32.853] [ShopSyncClient] Received SyncSellRules from server
[02-01-26 16:43:32.854] [ShopSyncClient] Received SyncInitialComplete from server
[02-01-26 16:43:32.855] [ShopSyncClient] Initial sync COMPLETE
[02-01-26 16:43:33.100] [ShopUI:show] Shop synced - displaying UI
```

This should replace all the "Shop not yet synced from server. Waiting...." messages.
