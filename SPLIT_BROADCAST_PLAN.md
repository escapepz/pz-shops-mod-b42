# Implementation Plan: Split BUY/SELL Broadcast

## Overview

Split single `SyncPriceModifiers` broadcast into two independent signals:
- **`SyncBuyPrices`** — Pre-calculated buy prices + buy revision
- **`SyncSellRules`** — Serializable sell modifier rules + sell revision

This eliminates false cache invalidation and improves scalability.

---

## Phase 1: Server State (Shop namespace)

### 1.1 Add independent revision counters

**File:** `Shops/42.13.1/media/lua/server/nshopsb42/transactions/ShopFinalizeHandlerServer.lua`

Replace:
```lua
Shop.PriceHookRevision = Shop.PriceHookRevision + 1
```

With:
```lua
Shop.BuyPriceRevision = Shop.BuyPriceRevision or 0
Shop.SellRuleRevision = Shop.SellRuleRevision or 0
```

Initialize in `finalizeNow()`:
```lua
Shop.BuyPriceRevision = 0
Shop.SellRuleRevision = 0
```

### 1.2 Track previous states separately

Add to `ShopFinalizeHandler`:
```lua
ShopFinalizeHandler._previousBuyPrices = {}
ShopFinalizeHandler._previousSellRules = {
    sellModifiers = {},
    sellOverrides = {},
}
```

---

## Phase 2: Finalization Handler Refactor

### 2.1 Split `onPriceHooksChanged()` into two paths

**File:** `Shops/42.13.1/media/lua/server/nshopsb42/transactions/ShopFinalizeHandlerServer.lua`

Current `onPriceHooksChanged()` does:
1. Build modifiers (buy + sell)
2. Calculate buy prices
3. Broadcast all as one

**New behavior:**

```
onPriceHooksChanged()
  ├─ shouldInvalidateBuyPrices()
  │  └─ Yes? → broadcastBuyPrices()
  └─ shouldInvalidateSellRules()
     └─ Yes? → broadcastSellRules()
```

### 2.2 Implement `shouldInvalidateBuyPrices()`

Condition: Buy hook count > 0 OR buy override changed

**Logic:**
```lua
function ShopFinalizeHandler.shouldInvalidateBuyPrices()
    local ShopPriceEvents = SHOPSB42.ShopPriceEvents
    local buyHookCount = (#ShopPriceEvents.OnShopModifyBuyPrice or 0) 
                       + (#ShopPriceEvents.OnShopOverrideBuyPrice or 0)
    return buyHookCount > 0
end
```

### 2.3 Implement `broadcastBuyPrices()`

**Logic:**
```lua
function ShopFinalizeHandler.broadcastBuyPrices()
    Shop.BuyPriceRevision = Shop.BuyPriceRevision + 1
    
    local modifiers = Builder.buildPriceModifiers()
    Shop.PriceModifiers = modifiers
    
    local calculatedPrices = buildCalculatedPrices()
    local changedPrices = detectPriceChanges(calculatedPrices, ShopFinalizeHandler._previousBuyPrices)
    ShopFinalizeHandler._previousBuyPrices = calculatedPrices.buyPrices or {}
    
    Utilities.SendServerCommandToAll("Shops", "SyncBuyPrices", {
        revision = Shop.BuyPriceRevision,
        buyPrices = changedPrices,  -- Delta: only changed items
    })
    
    SharedLogger.log("Shops", "[ShopFinalizeHandler] BUY prices broadcast (rev=" .. Shop.BuyPriceRevision .. ")")
end
```

### 2.4 Implement `shouldInvalidateSellRules()`

Condition: Sell hook count > 0 OR sell rules changed

**Logic:**
```lua
function ShopFinalizeHandler.shouldInvalidateSellRules()
    local ShopPriceEvents = SHOPSB42.ShopPriceEvents
    local sellHookCount = (#ShopPriceEvents.OnShopModifySellPrice or 0)
                       + (#ShopPriceEvents.OnShopOverrideSellPrice or 0)
    return sellHookCount > 0
end
```

### 2.5 Implement `broadcastSellRules()`

**Logic:**
```lua
function ShopFinalizeHandler.broadcastSellRules()
    Shop.SellRuleRevision = Shop.SellRuleRevision + 1
    
    local modifiers = Builder.buildPriceModifiers()
    
    -- Extract sell-specific data
    local sellData = {
        sellModifiers = modifiers.sellModifiers or {},
        sellOverrides = modifiers.sellOverrides or {},
    }
    
    -- Delta detection (compare with previous rules)
    if not ruleSetsEqual(sellData, ShopFinalizeHandler._previousSellRules) then
        ShopFinalizeHandler._previousSellRules = deepCopy(sellData)
        
        Utilities.SendServerCommandToAll("Shops", "SyncSellRules", {
            revision = Shop.SellRuleRevision,
            sellModifiers = sellData.sellModifiers,
            sellOverrides = sellData.sellOverrides,
        })
        
        SharedLogger.log("Shops", "[ShopFinalizeHandler] SELL rules broadcast (rev=" .. Shop.SellRuleRevision .. ")")
    end
end
```

### 2.6 Helper: `ruleSetsEqual()`

```lua
local function ruleSetsEqual(a, b)
    -- Simple check: if JSON strings match, rules are same
    local aJson = tostring(a.sellModifiers) .. tostring(a.sellOverrides)
    local bJson = tostring(b.sellModifiers) .. tostring(b.sellOverrides)
    return aJson == bJson
end
```

### 2.7 Update `resyncPriceModifiers()`

Call both broadcast functions:
```lua
function ShopFinalizeHandler.resyncPriceModifiers()
    if ShopFinalizeHandler.shouldInvalidateBuyPrices() then
        ShopFinalizeHandler.broadcastBuyPrices()
    end
    if ShopFinalizeHandler.shouldInvalidateSellRules() then
        ShopFinalizeHandler.broadcastSellRules()
    end
end
```

### 2.8 Update `sendShopDataToPlayer()`

Send both broadcasts on player join:
```lua
function ShopFinalizeHandler.sendShopDataToPlayer(player)
    -- ... existing shop data send ...
    
    -- Send buy prices (initial sync)
    local buyData = buildCalculatedPrices()
    Utilities.SendServerCommandTo(player, "Shops", "SyncBuyPrices", {
        revision = Shop.BuyPriceRevision,
        buyPrices = buyData.buyPrices,
        isInitialSync = true,
    })
    
    -- Send sell rules (initial sync)
    local modifiers = Builder.buildPriceModifiers()
    Utilities.SendServerCommandTo(player, "Shops", "SyncSellRules", {
        revision = Shop.SellRuleRevision,
        sellModifiers = modifiers.sellModifiers or {},
        sellOverrides = modifiers.sellOverrides or {},
        isInitialSync = true,
    })
end
```

---

## Phase 3: Client Sync Handler

### 3.1 Update initialization

**File:** `Shops/42.13.1/media/lua/client/nshopsb42/sync/ShopSyncClient.lua`

Replace:
```lua
Shop.PriceHookRevision = nil
```

With:
```lua
Shop.BuyPriceRevision = nil
Shop.SellRuleRevision = nil
Shop.CalculatedPrices = { buyPrices = {}, sellPrices = {} }
Shop.SellModifiers = {}
Shop.SellOverrides = {}
```

### 3.2 Split command handler

Replace single `SyncPriceModifiers` with two handlers:

```lua
function ShopSyncClient.handleServerCommand(module, command, data)
    if module ~= "Shops" then
        return
    end
    
    if command == "SyncBuyPrices" then
        ShopSyncClient.handleSyncBuyPrices(data)
    elseif command == "SyncSellRules" then
        ShopSyncClient.handleSyncSellRules(data)
    else
        SharedLogger.log("Shops", "[ShopSyncClient] Unknown command: " .. command)
    end
end
```

### 3.3 Implement `handleSyncBuyPrices()`

```lua
function ShopSyncClient.handleSyncBuyPrices(data)
    SharedLogger.log("Shops", "[ShopSyncClient] Received SyncBuyPrices from server")
    
    local Shop = SHOPSB42.Shop
    local oldRevision = Shop.BuyPriceRevision
    local newRevision = data.revision or 0
    
    Shop.BuyPriceRevision = newRevision
    
    if data.isInitialSync then
        -- Initial sync: store all prices
        Shop.CalculatedPrices.buyPrices = data.buyPrices or {}
        SharedLogger.log("Shops", "[ShopSyncClient] Initial BUY price sync (rev=" .. newRevision .. ")")
    elseif data.buyPrices then
        -- Delta update: merge changed prices
        for itemId, price in pairs(data.buyPrices) do
            Shop.CalculatedPrices.buyPrices[itemId] = price
        end
        SharedLogger.log("Shops", "[ShopSyncClient] Delta BUY price update (rev=" .. oldRevision .. "->" .. newRevision .. ")")
    end
    
    -- Trigger UI refresh if revision changed
    if oldRevision ~= nil and newRevision ~= oldRevision then
        ShopSyncClient.onBuyPricesChanged()
    end
end
```

### 3.4 Implement `handleSyncSellRules()`

```lua
function ShopSyncClient.handleSyncSellRules(data)
    SharedLogger.log("Shops", "[ShopSyncClient] Received SyncSellRules from server")
    
    local Shop = SHOPSB42.Shop
    local oldRevision = Shop.SellRuleRevision
    local newRevision = data.revision or 0
    
    Shop.SellRuleRevision = newRevision
    Shop.SellModifiers = data.sellModifiers or {}
    Shop.SellOverrides = data.sellOverrides or {}
    
    SharedLogger.log("Shops", "[ShopSyncClient] SELL rules updated (rev=" .. oldRevision .. "->" .. newRevision .. ")")
    
    -- Trigger UI refresh if revision changed
    if oldRevision ~= nil and newRevision ~= oldRevision then
        ShopSyncClient.onSellRulesChanged()
    end
end
```

### 3.5 Split refresh handlers

```lua
function ShopSyncClient.onBuyPricesChanged()
    SharedLogger.log("Shops", "[ShopSyncClient] Buy prices changed, refreshing UI")
    ShopSyncClient.refreshUIForPriceChange()
end

function ShopSyncClient.onSellRulesChanged()
    SharedLogger.log("Shops", "[ShopSyncClient] Sell rules changed, refreshing UI")
    ShopSyncClient.refreshUIForPriceChange()
end
```

---

## Phase 4: Client Price Calculator Updates

### 4.1 Update `calcSellPrice()` to use separate modifiers

**File:** `Shops/42.13.1/media/lua/client/nshopsb42/ui/ShopUI.lua`

Replace:
```lua
local modifiers = Shop.PriceModifiers or {}
```

With:
```lua
local modifiers = {
    sellModifiers = Shop.SellModifiers or {},
    sellOverrides = Shop.SellOverrides or {},
    requiresServer = Shop.PriceModifiers.requiresServer or false,
}
```

---

## Phase 5: Testing

### 5.1 Test buy price changes

```
testapple(2.0)
→ Server: BUY revision increments
→ Client: Receives SyncBuyPrices (not SyncSellRules)
→ UI: Buy tab updates, sell tab untouched
```

### 5.2 Test sell rule changes

```
testBatSell(2.0)
→ Server: SELL revision increments
→ Client: Receives SyncSellRules (not SyncBuyPrices)
→ UI: Sell tab updates, buy tab untouched
```

### 5.3 Test independent revisions

Verify logs show:
```
BUY revision: 1, 2, 3, ...
SELL revision: 1, 2, 3, ... (independent)
```

### 5.4 Test initial player sync

New player connects:
- Receives both `SyncBuyPrices` (isInitialSync=true)
- Receives both `SyncSellRules` (isInitialSync=true)

---

## Files to Modify

| File | Changes |
|------|---------|
| `ShopFinalizeHandlerServer.lua` | Split `onPriceHooksChanged()`, add revision counters, implement broadcast functions |
| `ShopSyncClient.lua` | Split command handler, add `handleSyncBuyPrices()` and `handleSyncSellRules()` |
| `ShopUI.lua` | Update `calcSellPrice()` to use separate `Shop.SellModifiers` and `Shop.SellOverrides` |
| `ShopPriceModifierBuilder.lua` | No changes needed (already returns `sellModifiers` + `sellOverrides`) |

---

## Success Criteria

- [ ] Two independent broadcasts sent
- [ ] Two independent revisions tracked
- [ ] Buy price changes don't invalidate sell cache
- [ ] Sell rule changes don't recalculate buy prices
- [ ] Client logs show separate revision counters
- [ ] UI updates only affected tab on each broadcast
- [ ] Test commands verify isolation
