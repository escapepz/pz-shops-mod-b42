# Broadcast Optimization Plan (Option C)

## Goal
Reduce broadcast size by optimizing price synchronization:
1. Only calculate prices for **defined items** (PlayerBuy + PlayerSell registries)
2. Only broadcast prices that **actually changed** (delta detection)
3. Keep modifiers in broadcasts (needed for client-side sell price calculations)

## Current Broadcast Flow

```
onPriceHooksChanged()
    ↓
buildCalculatedPrices() → {all 500 items, including undefined}
    ↓
SendServerCommandToAll(...SyncPriceModifiers, {
    revision = 1,
    modifiers = {...},           ← 1KB
    calculatedPrices = {...}     ← 15KB (includes unregistered items)
})
    ↓
Network overhead: ~16KB per broadcast
```

## New Broadcast Flow

```
onPriceHooksChanged()
    ↓
buildCalculatedPrices() → {ONLY defined items from PlayerBuy + PlayerSell}
    ↓
detectPriceChanges() → {only prices that changed from previous state}
    ↓
SendServerCommandToAll(...SyncPriceModifiers, {
    revision = 1,                          ← 10 bytes
    modifiers = {...},                     ← 1KB (needed for sell calculations)
    changed = {                            ← 100-500 bytes (only actual changes)
        ["Base.Apple"] = 30,
        ["Base.Orange"] = 25
    }
})
    ↓
Client receives modifiers, applies changed prices to affected items
```

## Implementation Steps

### Step 1: Track Previous Prices (Server-Side)

**File:** `ShopFinalizeHandlerServer.lua`

Add to module:
```lua
local ShopFinalizeHandler = SHOPSB42.ShopFinalizeHandler or {}

-- Track previous calculated prices for delta detection
ShopFinalizeHandler._previousBuyPrices = {}
ShopFinalizeHandler._previousSellPrices = {}
```

### Step 2: Update buildCalculatedPrices() - Only Defined Items

**File:** `ShopFinalizeHandlerServer.lua`

Replace `buildCalculatedPrices()`:
```lua
local function buildCalculatedPrices()
    local calculatedPrices = {
        buyPrices = {},
        sellPrices = {},
    }

    -- ONLY calculate prices for defined items in PlayerBuy
    if Shop.PlayerBuy then
        for itemId, config in pairs(Shop.PlayerBuy) do
            if config.enabled then
                local buyPrice = Shop.resolvePlayerBuyPrice(nil, itemId, { type = "sync" })
                if buyPrice then
                    calculatedPrices.buyPrices[itemId] = buyPrice
                end
            end
        end
    end

    -- ONLY calculate prices for defined items in PlayerSell
    -- (Note: Still need item objects for sell price hooks, may defer)
    if Shop.PlayerSell then
        for itemId, config in pairs(Shop.PlayerSell) do
            if config.enabled and not config.blacklisted then
                -- Sell price calculation deferred to client for now
                -- Client will use modifiers from this broadcast
            end
        end
    end

    return calculatedPrices
end
```

### Step 3: Detect Price Changes (Only Defined Items)

**File:** `ShopFinalizeHandlerServer.lua`

Add new function:
```lua
local function detectPriceChanges(newCalculatedPrices, previousPrices)
    local changed = {}
    
    -- Only check items in PlayerBuy registry (defined items)
    if newCalculatedPrices.buyPrices then
        for itemId, newPrice in pairs(newCalculatedPrices.buyPrices) do
            if Shop.PlayerBuy[itemId] then  -- ← Only registered items
                local oldPrice = previousPrices[itemId]
                if oldPrice ~= newPrice then
                    changed[itemId] = newPrice
                    SharedLogger.log("Shops", "[PriceDelta] Changed: " .. itemId .. " from " .. tostring(oldPrice) .. " to " .. newPrice)
                end
            end
        end
    end
    
    return changed
end
```

### Step 4: Update onPriceHooksChanged()

**File:** `ShopFinalizeHandlerServer.lua`

Modify the hook callback:

```lua
function ShopFinalizeHandler.onPriceHooksChanged()
    SharedLogger.log("Shops", "[ShopFinalizeHandler] onPriceHooksChanged() called")

    if not Shop._finalized then
        SharedLogger.log("Shops", "[ShopFinalizeHandler] Shop not finalized yet, aborting")
        return
    end

    Shop.PriceHookRevision = Shop.PriceHookRevision + 1
    SharedLogger.log("Shops", "[ShopFinalizeHandler] Incremented revision to: " .. tostring(Shop.PriceHookRevision or 0))

    -- Rebuild modifiers and calculate prices
    local modifiers = Builder.buildPriceModifiers()
    Shop.PriceModifiers = modifiers
    SharedLogger.log("Shops", "[ShopFinalizeHandler] Rebuilt modifiers, rebuilding calculated prices...")

    local calculatedPrices = buildCalculatedPrices()

    -- Detect which prices actually changed from previous state
    local changedPrices = detectPriceChanges(calculatedPrices.buyPrices, ShopFinalizeHandler._previousBuyPrices)
    
    local changeCount = 0
    for _ in pairs(changedPrices) do
        changeCount = changeCount + 1
    end
    SharedLogger.log("Shops", "[ShopFinalizeHandler] Detected " .. changeCount .. " price changes out of " .. countTable(Shop.PlayerBuy) .. " defined items")

    -- Store new prices for next comparison
    ShopFinalizeHandler._previousBuyPrices = calculatedPrices.buyPrices or {}

    -- Debug: Log sample changed prices
    if calculatedPrices.buyPrices["Base.Apple"] then
        SharedLogger.log("Shops", "[ShopFinalizeHandler] Base.Apple calculated buy price: " .. calculatedPrices.buyPrices["Base.Apple"])
    end

    -- Broadcast: Send modifiers (for sell calculations) + changed prices only
    Utilities.SendServerCommandToAll("Shops", "SyncPriceModifiers", {
        revision = Shop.PriceHookRevision,
        modifiers = modifiers,         -- ← KEEP (needed for sell price hooks)
        changed = changedPrices        -- ← OPTIMIZED: Only changed items
    })

    SharedLogger.log("Shops", "[ShopFinalizeHandler] Price hooks changed, revision: " .. tostring(Shop.PriceHookRevision or 0))
end
```

### Step 5: Update Initial Player Sync

**File:** `ShopFinalizeHandlerServer.lua`

Modify `sendShopDataToPlayer()` to send full prices on initial sync:

```lua
function ShopFinalizeHandler.sendShopDataToPlayer(player)
    -- ... existing code ...
    
    local priceModifiers = Shop.PriceModifiers or {}
    local calculatedPrices = buildCalculatedPrices()

    SharedLogger.log("Shops", "[ShopFinalizeHandler] Sending SyncPriceModifiers (revision: " .. tostring(Shop.PriceHookRevision or 0) .. ")")
    
    -- Initial sync: Send full prices + modifiers
    Utilities.SendServerCommandTo(player, "Shops", "SyncPriceModifiers", {
        revision = Shop.PriceHookRevision,
        modifiers = priceModifiers,       -- ← KEEP (needed for sell price calculations)
        calculatedPrices = calculatedPrices,  -- ← Full prices on initial sync only
        isInitialSync = true              -- ← Flag to client
    })
    
    SharedLogger.log("Shops", "[ShopFinalizeHandler] SyncPriceModifiers sent")
    SharedLogger.log("Shops", "[ShopFinalizeHandler] Synced all data to " .. player:getUsername())
end
```

### Step 6: Update Client Handler

**File:** `ShopSyncClient.lua`

Modify `handleServerCommand()` to handle both modifiers and delta updates:

```lua
elseif command == "SyncPriceModifiers" then
    SharedLogger.log("Shops", "[ShopSyncClient] Received SyncPriceModifiers from server")

    local newRevision = data.revision or 0
    local oldRevision = Shop.PriceHookRevision
    local revisionChanged = Shop.PriceHookRevision ~= nil and newRevision ~= Shop.PriceHookRevision

    Shop.PriceHookRevision = newRevision
    
    -- Always update modifiers (used for sell price calculations)
    if data.modifiers then
        Shop.PriceModifiers = data.modifiers
        SharedLogger.log("Shops", "[ShopSyncClient] Updated price modifiers for sell calculations")
    end

    -- Handle both full sync (initial) and delta updates
    local calculatedPricesUpdated = false
    
    if data.isInitialSync then
        -- Initial sync: full prices for all defined items
        SharedLogger.log("Shops", "[ShopSyncClient] Initial sync - storing full prices")
        Shop.CalculatedPrices = data.calculatedPrices or {buyPrices = {}, sellPrices = {}}
        calculatedPricesUpdated = true
    elseif data.changed then
        -- Delta update: only changed prices
        SharedLogger.log("Shops", "[ShopSyncClient] Delta update - updating changed prices")
        if not Shop.CalculatedPrices then
            Shop.CalculatedPrices = {buyPrices = {}, sellPrices = {}}
        end
        
        -- Update only changed items
        for itemId, newPrice in pairs(data.changed) do
            Shop.CalculatedPrices.buyPrices[itemId] = newPrice
            SharedLogger.log("Shops", "[ShopSyncClient] Updated price for " .. itemId .. " to " .. newPrice)
        end
        calculatedPricesUpdated = true
    end

    local modCount = 0
    if Shop.PriceModifiers then
        if Shop.PriceModifiers.buyModifiers then
            modCount = modCount + #Shop.PriceModifiers.buyModifiers
        end
        if Shop.PriceModifiers.sellModifiers then
            modCount = modCount + #Shop.PriceModifiers.sellModifiers
        end
    end

    SharedLogger.log("Shops", "[ShopSyncClient] Revision: " .. tostring(oldRevision) .. " → " .. newRevision .. ", modifiers: " .. modCount)

    -- Trigger UI refresh
    if revisionChanged or calculatedPricesUpdated then
        SharedLogger.log("Shops", "[ShopSyncClient] Price data changed, triggering onPriceHooksChanged()")
        ShopSyncClient.pricesChangedWhileClosed = true
        ShopSyncClient.onPriceHooksChanged()
    else
        SharedLogger.log("Shops", "[ShopSyncClient] Price hook revision same or first time, no reaction needed")
    end
end
```

### Step 7: Modifiers Sent Every Broadcast

**File:** `ShopFinalizeHandlerServer.lua`

Modifiers are sent in every broadcast because they're needed for client-side sell price calculations:

```lua
-- Every broadcast includes modifiers
Utilities.SendServerCommandToAll("Shops", "SyncPriceModifiers", {
    revision = Shop.PriceHookRevision,
    modifiers = priceModifiers,   -- ← Always included (~1KB)
    changed = changedPrices       -- ← Delta (optimized)
})

-- Initial sync sends full prices + modifiers
Utilities.SendServerCommandTo(player, "Shops", "SyncPriceModifiers", {
    revision = Shop.PriceHookRevision,
    modifiers = priceModifiers,   -- ← Needed for hooks
    calculatedPrices = calculatedPrices,
    isInitialSync = true
})
```

## Data Size Comparison

### Before (Per Broadcast)
```
revision:           ~10 bytes
modifiers:          ~1KB
calculatedPrices:   ~15KB (ALL 500 items, including unregistered)
─────────────────────────────
Total:              ~16KB per broadcast
```

### After (Per Broadcast)
```
revision:           ~10 bytes
modifiers:          ~1KB (always included, needed for sell calculations)
changed:            ~100-500 bytes (only defined items that changed)
─────────────────────────────
Total:              ~1.1-1.5KB per broadcast
```

### Savings
```
~16KB → ~1.2KB = 92% reduction ✅
(modifiers kept for sell price calculation correctness)
```

### Initial Sync vs. Runtime Updates
```
Initial Sync (per player):
  - revision, modifiers, calculatedPrices (all defined items) = ~5KB

Runtime Broadcasts (all players):
  - revision, modifiers, changed (delta) = ~1.2KB per update
```

## Testing Checklist

- [ ] Server startup: Initial sync sends full prices
- [ ] First price change: Broadcasts only changed items
- [ ] Multiple items changed: All changes included in broadcast
- [ ] New player connects: Receives full prices on initial sync
- [ ] UI updates correctly with delta prices
- [ ] No items missing from UI after delta update
- [ ] Revision increment works correctly
- [ ] Test hooks apply correctly (multiplier 2 → 3 → 0.5)
- [ ] No log spam on normal operation

## Implementation Scope

**Only defined items are processed:**
- Buy prices: items in `Shop.PlayerBuy` with `enabled = true`
- Sell prices: items in `Shop.PlayerSell` with `enabled = true` and not `blacklisted`

**Unregistered items:** Use base price, never broadcast

## Files to Modify

1. **ShopFinalizeHandlerServer.lua**
   - Add `_previousBuyPrices` tracking
   - Update `buildCalculatedPrices()` to iterate only `Shop.PlayerBuy`
   - Add `detectPriceChanges()` function
   - Modify `onPriceHooksChanged()` to use delta detection
   - Keep modifiers in all broadcasts (needed for sell calculations)

2. **ShopSyncClient.lua**
   - Update `handleServerCommand()` to always update modifiers
   - Handle both `isInitialSync` (full prices) and `changed` (delta) cases

3. **Optional: Performance logging**
   - Track change count per broadcast
   - Monitor modifiers count

## Rollback Plan

If issues arise, revert to sending full calculated prices (no delta), but keep modifiers.

## Performance Impact

- **Server:** +1-2ms for change detection (negligible, only defined items)
- **Network:** 92% reduction on runtime broadcasts (~16KB → ~1.2KB)
- **Client:** -2-3ms (less data to process on UI updates)
- **Correctness:** Sell price hooks work correctly (modifiers always synced)
- **Result:** Significantly reduced network overhead while maintaining price accuracy**
