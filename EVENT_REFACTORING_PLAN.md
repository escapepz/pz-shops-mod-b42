# Event Listener Refactoring Implementation Plan

**Goal**: Enforce EVENTS_RULE.md compliance across all server and client event handlers.

**Outcome**: Single dispatcher per event type, idempotent registration, centralized logging, zero redundant handlers.

---

## Phase 1: Server-Side OnClientCommand Consolidation

### Files to Consolidate
- `server/nshopsb42/transactions/ShopCommandHandlerServer.lua` (line 92)
- `server/nshopsb42/PlayerShopServer.lua` (line 130)
- `server/nshopsb42/balance/BalanceServer.lua` (line 760)
- `server/nshopsb42/logging/LogsServer.lua` (line 37)

### New File: `server/nshopsb42/ShopCommandDispatcherServer.lua`

```lua
if not isServer() then return end

local Dispatcher = {}
local Commands = {}

-- Command handlers extracted from all 4 consolidated files
function Commands.ClearShopSpriteDrag(player, args) end
function Commands.SetItemPrice(player, args) end
function Commands.BuyItemShop(player, args) end
function Commands.SellItemShop(player, args) end
function Commands.CreatePlayerShop(player, args) end
-- ... etc (map all existing handlers here)

function Dispatcher.onClientCommand(module, command, player, args)
    if module ~= "nshopsb42" then return end
    
    local SharedLogger = require("nshopsb42/utils/SharedLogger")
    SharedLogger.log("Shops", "[ShopCommandDispatcher:onClientCommand] module=" .. module .. " command=" .. command .. " player=" .. player:getUsername())
    
    local handler = Commands[command]
    if handler then
        handler(player, args)
    else
        SharedLogger.log("Shops", "[ShopCommandDispatcher:onClientCommand] UNKNOWN command: " .. command)
    end
end

-- Idempotent registration
if not Dispatcher._registered then
    Dispatcher._registered = true
    Events.OnClientCommand.Add(Dispatcher.onClientCommand)
end

return Dispatcher
```

### Migration Steps
1. Extract all handler functions from 4 files into Commands table
2. Remove all `Events.OnClientCommand.Add()` from original files
3. Add `require("nshopsb42/ShopCommandDispatcherServer")` to main server init
4. Test each command invocation path

---

## Phase 2: Client-Side OnServerCommand Consolidation

### Files to Consolidate
- `client/nshopsb42/sync/ShopSyncClient.lua` (line 212)
- `client/nshopsb42/transactions/ShopSpriteCursorUI.lua` (line 157)
- `client/nshopsb42/PlayerShopClient.lua` (line 26)
- `client/nshopsb42/balance/BalanceClient.lua` (line 53)

### New File: `client/nshopsb42/ShopCommandDispatcherClient.lua`

```lua
if not isClient() then return end

local Dispatcher = {}
local Commands = {}

-- Command handlers extracted from all 4 consolidated files
function Commands.SyncShopData(args) end
function Commands.SyncBuyPrices(args) end
function Commands.SyncSellRules(args) end
function Commands.SyncInitialComplete(args) end
function Commands.ClearShopSpriteDrag(args) end
function Commands.SyncPlayerShopStatus(args) end
function Commands.SyncBalance(args) end
-- ... etc (map all existing handlers here)

function Dispatcher.onServerCommand(module, command, args)
    if module ~= "nshopsb42" then return end
    
    local SharedLogger = require("nshopsb42/utils/SharedLogger")
    SharedLogger.log("Shops", "[ShopCommandDispatcher:onServerCommand] module=" .. module .. " command=" .. command)
    
    local handler = Commands[command]
    if handler then
        handler(args)
    else
        SharedLogger.log("Shops", "[ShopCommandDispatcher:onServerCommand] UNKNOWN command: " .. command)
    end
end

-- Idempotent registration
if not Dispatcher._registered then
    Dispatcher._registered = true
    Events.OnServerCommand.Add(Dispatcher.onServerCommand)
end

return Dispatcher
```

### Migration Steps
1. Extract all handler functions from 4 files into Commands table
2. Remove all `Events.OnServerCommand.Add()` from original files
3. Add `require("nshopsb42/ShopCommandDispatcherClient")` to main client init
4. Test each command reception path

---

## Phase 3: Client-Side OnPreFillWorldObjectContextMenu Consolidation

### Files to Consolidate
- `client/nshopsb42/context/ShopContext.lua` (lines 125-126)

### New File: `client/nshopsb42/context/WorldObjectContextMenuDispatcher.lua`

```lua
if not isClient() then return end

local Dispatcher = {}

function Dispatcher.onPreFillWorldObjectContextMenu(object, context)
    if not object then return end
    
    -- ShopContext handlers
    if SHOPSB42.Shop.ShopContextMenu then
        SHOPSB42.Shop.ShopContextMenu(object, context)
    end
    if SHOPSB42.Shop.ShopUIContextMenu then
        SHOPSB42.Shop.ShopUIContextMenu(object, context)
    end
    
    -- PlayerShop handlers
    if SHOPSB42.PlayerShop.PlayerShopContextMenu then
        SHOPSB42.PlayerShop.PlayerShopContextMenu(object, context)
    end
end

function Dispatcher.onFillWorldObjectContextMenu(object, context)
    if not object then return end
    
    -- ShopContext handlers
    if SHOPSB42.Shop.ShopViewContextMenu then
        SHOPSB42.Shop.ShopViewContextMenu(object, context)
    end
end

-- Idempotent registration
if not Dispatcher._registered then
    Dispatcher._registered = true
    Events.OnPreFillWorldObjectContextMenu.Add(Dispatcher.onPreFillWorldObjectContextMenu)
    Events.OnFillWorldObjectContextMenu.Add(Dispatcher.onFillWorldObjectContextMenu)
end

return Dispatcher
```

### Migration Steps
1. Remove duplicate `Events.OnPreFillWorldObjectContextMenu.Add()` from ShopContext.lua
2. Consolidate into single dispatcher
3. Add require to client init
4. Test context menu construction

---

## Phase 4: Client-Side OnPreFillInventoryObjectContextMenu Consolidation

### Files to Consolidate
- `client/nshopsb42/context/CurrencyContext.lua` (lines 273-276)
- `client/nshopsb42/context/PlayerShopContext.lua` (line 328)

### New File: `client/nshopsb42/context/InventoryObjectContextMenuDispatcher.lua`

```lua
if not isClient() then return end

local Dispatcher = {}

function Dispatcher.onPreFillInventoryObjectContextMenu(item, context)
    if not item then return end
    
    local SharedLogger = require("nshopsb42/utils/SharedLogger")
    
    -- Currency context handlers
    if SHOPSB42.Currency.LootCoinsObjectContextMenu then
        SHOPSB42.Currency.LootCoinsObjectContextMenu(item, context)
    end
    if SHOPSB42.Currency.LinkWalletObjectContextMenu then
        SHOPSB42.Currency.LinkWalletObjectContextMenu(item, context)
    end
    if SHOPSB42.Currency.UnlinkWalletObjectContextMenu then
        SHOPSB42.Currency.UnlinkWalletObjectContextMenu(item, context)
    end
    if SHOPSB42.Currency.CoinsToAccountObjectContextMenu then
        SHOPSB42.Currency.CoinsToAccountObjectContextMenu(item, context)
    end
    
    -- PlayerShop context handlers
    if SHOPSB42.PlayerShop.ItemsSellPrice then
        SHOPSB42.PlayerShop.ItemsSellPrice(item, context)
    end
end

function Dispatcher.onFillInventoryObjectContextMenu(item, context)
    if not item then return end
    -- Future: add fill handlers if needed
end

-- Idempotent registration
if not Dispatcher._registered then
    Dispatcher._registered = true
    Events.OnPreFillInventoryObjectContextMenu.Add(Dispatcher.onPreFillInventoryObjectContextMenu)
    Events.OnFillInventoryObjectContextMenu.Add(Dispatcher.onFillInventoryObjectContextMenu)
end

return Dispatcher
```

### Migration Steps
1. Remove all 4 individual `Events.OnPreFillInventoryObjectContextMenu.Add()` calls
2. Consolidate into single dispatcher
3. Add require to client init
4. Test context menu construction

---

## Phase 5: Client-Side OnReceiveGlobalModData Consolidation

### Files to Consolidate
- `client/nshopsb42/ui/TransferUI.lua` (line 417)
- `client/nshopsb42/balance/BalanceClient.lua` (line 11)

### New File: `client/nshopsb42/sync/ModDataDispatcherClient.lua`

```lua
if not isClient() then return end

local Dispatcher = {}

function Dispatcher.onReceiveGlobalModData()
    local SharedLogger = require("nshopsb42/utils/SharedLogger")
    SharedLogger.log("Shops", "[ModDataDispatcher:onReceiveGlobalModData] Received global modData")
    
    -- Balance client handlers
    if SHOPSB42.BalanceClient.OnReceiveGlobalModData then
        SHOPSB42.BalanceClient.OnReceiveGlobalModData()
    end
    
    -- Transfer UI handlers
    if SHOPSB42.TransferUI.onReceiveTransferUpdate then
        SHOPSB42.TransferUI.onReceiveTransferUpdate()
    end
end

-- Idempotent registration
if not Dispatcher._registered then
    Dispatcher._registered = true
    Events.OnReceiveGlobalModData.Add(Dispatcher.onReceiveGlobalModData)
end

return Dispatcher
```

### Migration Steps
1. Remove both `Events.OnReceiveGlobalModData.Add()` calls
2. Consolidate into single dispatcher
3. Add require to client init
4. Test modData sync

---

## Phase 6: Add Explicit Side Gates

### Files to Update
- All new dispatcher files: confirm `if not isClient() then return end` or `if not isServer() then return end` at top
- All modified handler files: add explicit gate before requiring dispatcher

### Template
```lua
-- At top of any file that uses events
if not isClient() then return end  -- or isServer()
```

---

## Phase 7: Update Init Files

### Server Init: `server/nshopsb42/ShopInitServer.lua`

Add after other requires:
```lua
require("nshopsb42/ShopCommandDispatcherServer")
```

### Client Init: `client/nshopsb42/AClientInit.lua`

Add after other requires:
```lua
require("nshopsb42/ShopCommandDispatcherClient")
require("nshopsb42/context/WorldObjectContextMenuDispatcher")
require("nshopsb42/context/InventoryObjectContextMenuDispatcher")
require("nshopsb42/sync/ModDataDispatcherClient")
```

---

## Testing Checklist

### Unit Test Each Phase
- [ ] Phase 1: Invoke each server command, verify log output
- [ ] Phase 2: Send each client command from server, verify reception
- [ ] Phase 3: Open world object context menu, verify options appear
- [ ] Phase 4: Open inventory context menu, verify options appear
- [ ] Phase 5: Connect to server, verify modData sync completes
- [ ] Phase 6: Verify side gates prevent SP/MP conflicts
- [ ] Phase 7: Full integration test in both SP and MP

### Log Validation
- [ ] Check `Logs/Server/*_Shops.txt` for dispatcher entry logs only
- [ ] Check `Logs/Client/*_Shops.txt` for no "UNKNOWN command" warnings
- [ ] Verify no duplicate event handler execution

### Regression Checks
- [ ] Buy from shop
- [ ] Sell to shop
- [ ] Create player shop
- [ ] Set prices in player shop
- [ ] Link/unlink wallets
- [ ] Transfer coins
- [ ] Verify income tracking

---

## Rollback Plan

If issues arise:
1. Keep original handler files untouched during Phase 1-5
2. Only remove `Events.*.Add()` calls, not function definitions
3. If dispatcher fails, comment out require in init, restore event listeners
4. Re-run tests

---

## Success Criteria

✅ All 7 phases complete
✅ Zero duplicate event listeners
✅ All handlers accessible from dispatcher command tables
✅ Idempotent registration guards in place
✅ Explicit side gates on all dispatchers
✅ Centralized logging at dispatcher entry only
✅ All regression tests pass
✅ No "UNKNOWN command" or "duplicate handler" warnings in logs
