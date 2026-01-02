# Implementation Plan: SHA_B Forward-Port (SHA_A Guarantees)

## Objective
Restore all behavioral guarantees from SHA_A while **keeping SHA_B's split buy/sell architecture intact**.

This is not a revert. This is completing the redesign.

---

## Change Summary

| Change | Impact | Complexity | Priority |
|--------|--------|-----------|----------|
| Both revisions in broadcasts | Atomicity | Low | **1st** |
| Buy modifiers in sync | Transparency | Medium | **2nd** |
| SyncInitialComplete handshake | Completeness | Medium | **3rd** |
| Composite-state helpers | Clarity | Low | **4th** |

---

## Change 1: Both Revisions in Every Broadcast

### Goal
Clients always know whether they are viewing complete pricing state.

### Locations to Modify

#### Server-side Protocol (`Shops/42.13.1/media/lua/server/network/ShopNetworkSync.lua`)

**For `SyncBuyPrices` broadcast:**
```lua
-- Current state (INCOMPLETE):
local cmd = ShopNetworkSync.createCommand("SyncBuyPrices", {
    shopId = shopId,
    buyRevision = self.buyRevision,
    items = buyItems,
    isInitialSync = isInitialSync
})

-- Required state (COMPLETE):
local cmd = ShopNetworkSync.createCommand("SyncBuyPrices", {
    shopId = shopId,
    buyRevision = self.buyRevision,
    sellRevision = self.sellRevision,  -- ADD THIS
    items = buyItems,
    isInitialSync = isInitialSync
})
```

**For `SyncSellRules` broadcast:**
```lua
-- Current state (INCOMPLETE):
local cmd = ShopNetworkSync.createCommand("SyncSellRules", {
    shopId = shopId,
    sellRevision = self.sellRevision,
    rules = sellRules,
    isInitialSync = isInitialSync
})

-- Required state (COMPLETE):
local cmd = ShopNetworkSync.createCommand("SyncSellRules", {
    shopId = shopId,
    buyRevision = self.buyRevision,      -- ADD THIS
    sellRevision = self.sellRevision,
    rules = sellRules,
    isInitialSync = isInitialSync
})
```

#### Client-side State (`Shops/42.13.1/media/lua/client/ShopClientState.lua`)

**Extend ShopData structure:**
```lua
ShopData = {
    shopId = ...,
    buyRevision = nil,      -- EXISTING
    sellRevision = nil,     -- EXISTING
    buyRevisionAtSync = nil,    -- ADD THIS
    sellRevisionAtSync = nil,   -- ADD THIS
    items = {},
    rules = {},
    _lastKnownBuyRevision = nil,   -- ADD THIS
    _lastKnownSellRevision = nil   -- ADD THIS
}
```

**Handler for `SyncBuyPrices`:**
```lua
-- Track both revisions from incoming broadcast
ShopClientState.handleSyncBuyPrices = function(cmd)
    local shop = ShopClientState.shops[cmd.shopId]
    if not shop then return end
    
    -- Store both revisions
    shop.buyRevision = cmd.buyRevision
    shop.sellRevision = cmd.sellRevision  -- ADD THIS
    shop.items = cmd.items
    
    -- Mark state completeness
    shop.buyRevisionAtSync = cmd.buyRevision
    shop.sellRevisionAtSync = cmd.sellRevision
    
    -- Notify listeners
    ShopClientState:dispatchStateChanged(cmd.shopId, "buy")
end
```

**Handler for `SyncSellRules`:**
```lua
-- Track both revisions from incoming broadcast
ShopClientState.handleSyncSellRules = function(cmd)
    local shop = ShopClientState.shops[cmd.shopId]
    if not shop then return end
    
    -- Store both revisions
    shop.buyRevision = cmd.buyRevision  -- ADD THIS
    shop.sellRevision = cmd.sellRevision
    shop.rules = cmd.rules
    
    -- Mark state completeness
    shop.buyRevisionAtSync = cmd.buyRevision
    shop.sellRevisionAtSync = cmd.sellRevision
    
    -- Notify listeners
    ShopClientState:dispatchStateChanged(cmd.shopId, "sell")
end
```

### Validation Checklist

- [ ] `SyncBuyPrices` includes both `buyRevision` and `sellRevision`
- [ ] `SyncSellRules` includes both `buyRevision` and `sellRevision`
- [ ] Client state tracks both revisions separately
- [ ] Both handlers update both revision fields
- [ ] No ordering assumptions between broadcasts

### Testing

```lua
-- Verify mixed broadcast scenario
-- 1. Send SyncBuyPrices with buyRev=5, sellRev=3
-- 2. Client should record both
-- 3. Send SyncSellRules with buyRev=5, sellRev=4
-- 4. Client should update sellRev to 4, keep buyRev=5
-- 5. Both should match final server state
```

---

## Change 2: Buy Modifiers in Sync

### Goal
Restore transparency so clients and external mods can see *why* prices changed.

### What Are Buy Modifiers?

Buy modifiers affect the base price calculation. They include:
- Dynamic supply/demand adjusters
- Quality-of-life adjusters
- Server-specific multipliers
- Configurable rules

### Locations to Modify

#### Server-side Calculation (`Shops/42.13.1/media/lua/server/ShopBuyPrices.lua`)

**Extract modifier state from price calculation:**
```lua
-- When computing buy prices, also compute modifiers
ShopBuyPrices.computeItemPrice = function(item, modifiers)
    -- EXISTING: compute base price
    local basePrice = item:getBasePrice()
    
    -- EXISTING: apply modifiers
    local finalPrice = basePrice
    for _, mod in ipairs(modifiers) do
        finalPrice = finalPrice * mod.multiplier
    end
    
    -- NEW: return both price AND modifier breakdown
    return {
        price = finalPrice,
        basePrice = basePrice,
        modifiers = modifiers,  -- ADD THIS
        modifierCount = #modifiers
    }
end
```

#### Server-side Broadcast (`Shops/42.13.1/media/lua/server/network/ShopNetworkSync.lua`)

**Include modifiers in sync payload:**
```lua
-- Current state (INCOMPLETE):
local buyItems = {
    { itemId = "Weapon_Pistol", price = 100 },
    { itemId = "Weapon_Rifle", price = 250 }
}

-- Required state (COMPLETE):
local buyItems = {
    {
        itemId = "Weapon_Pistol",
        price = 100,
        basePrice = 80,            -- ADD THIS
        modifiers = {              -- ADD THIS
            { name = "supply", multiplier = 1.1 },
            { name = "quality", multiplier = 1.05 }
        }
    },
    {
        itemId = "Weapon_Rifle",
        price = 250,
        basePrice = 200,
        modifiers = {
            { name = "supply", multiplier = 1.2 }
        }
    }
}
```

#### Client-side State (`Shops/42.13.1/media/lua/client/ShopClientState.lua`)

**Extend item data structure:**
```lua
-- Extend item schema
ShopClientState.ShopItem = {
    itemId = nil,
    price = nil,
    basePrice = nil,        -- ADD THIS
    modifiers = {},         -- ADD THIS (array of {name, multiplier})
    modifierCount = 0       -- ADD THIS
}
```

**Handler update:**
```lua
ShopClientState.handleSyncBuyPrices = function(cmd)
    local shop = ShopClientState.shops[cmd.shopId]
    if not shop then return end
    
    shop.items = cmd.items  -- Now includes modifiers
    
    -- Store modifier metadata for debugging/ui
    if not shop._modifierMetadata then
        shop._modifierMetadata = {}
    end
    for _, item in ipairs(cmd.items) do
        if item.modifiers then
            shop._modifierMetadata[item.itemId] = item.modifiers
        end
    end
end
```

### Validation Checklist

- [ ] `ShopBuyPrices.computeItemPrice` returns modifiers
- [ ] `SyncBuyPrices` includes `basePrice` and `modifiers` for each item
- [ ] Client state stores modifier metadata
- [ ] Modifiers are human-readable (e.g., "supply", "quality")
- [ ] No performance impact on server price computation

### Testing

```lua
-- Verify modifier visibility
-- 1. Set up a shop with dynamic supply modifier
-- 2. Change supply level
-- 3. Sync should show: basePrice=100, modifiers={supply=1.2}
-- 4. Client can compute finalPrice = basePrice * 1.2 = 120
-- 5. Verify it matches server finalPrice
```

---

## Change 3: SyncInitialComplete Handshake

### Goal
Eliminate ambiguity about when UI can safely render pricing data.

### Locations to Modify

#### Server-side Protocol (`Shops/42.13.1/media/lua/server/network/ShopNetworkSync.lua`)

**Add new command definition:**
```lua
-- NEW: Add to command registry
ShopNetworkSync.commands.SyncInitialComplete = {
    shopId = "string",
    buyRevision = "number",
    sellRevision = "number",
    timestamp = "number"
}

-- NEW: Handler to send completion signal
ShopNetworkSync.sendInitialSyncComplete = function(shopId, buyRev, sellRev)
    local cmd = ShopNetworkSync.createCommand("SyncInitialComplete", {
        shopId = shopId,
        buyRevision = buyRev,
        sellRevision = sellRev,
        timestamp = getGameTime()
    })
    ShopNetworkSync.sendToClients(cmd)
end
```

**Update initial sync sequence:**
```lua
-- In ShopServerState.initiateFullSync():
ShopServerState.initiateFullSync = function(shopId)
    local shop = ShopServerState.shops[shopId]
    if not shop then return end
    
    -- Step 1: Send shop metadata
    ShopNetworkSync.sendShopData(shopId, {
        -- ... existing fields
    })
    
    -- Step 2: Send buy prices
    ShopNetworkSync.sendBuyPrices(shopId, true)  -- isInitialSync=true
    
    -- Step 3: Send sell rules
    ShopNetworkSync.sendSellRules(shopId, true)  -- isInitialSync=true
    
    -- Step 4: Signal completion (NEW)
    ShopNetworkSync.sendInitialSyncComplete(
        shopId,
        shop.buyRevision,
        shop.sellRevision
    )
end
```

#### Client-side State (`Shops/42.13.1/media/lua/client/ShopClientState.lua`)

**Extend shop state tracking:**
```lua
ShopData = {
    shopId = ...,
    buyRevision = nil,
    sellRevision = nil,
    items = {},
    rules = {},
    _initialSyncComplete = false,  -- ADD THIS (critical)
    _syncStartTime = nil,
    _syncCompleteTime = nil
}
```

**Handler for `SyncInitialComplete`:**
```lua
-- NEW: Handler
ShopClientState.handleSyncInitialComplete = function(cmd)
    local shop = ShopClientState.shops[cmd.shopId]
    if not shop then return end
    
    -- Verify revision consistency
    if shop.buyRevision ~= cmd.buyRevision or
       shop.sellRevision ~= cmd.sellRevision then
        print("WARNING: Initial sync revision mismatch for shop " .. cmd.shopId)
        return
    end
    
    -- Mark as complete
    shop._initialSyncComplete = true
    shop._syncCompleteTime = getGameTime()
    
    -- Notify listeners (especially UI layer)
    ShopClientState:dispatchInitialSyncComplete(cmd.shopId)
end
```

**Add helper method:**
```lua
-- NEW: Semantic check
ShopClientState.isShopReady = function(shopId)
    local shop = ShopClientState.shops[shopId]
    if not shop then return false end
    return shop._initialSyncComplete == true
end
```

#### UI Layer (`Shops/42.13.1/media/lua/client/ShopUI.lua` or equivalent)

**Gate rendering on readiness:**
```lua
-- Before opening UI
ShopUI.openShop = function(shopId)
    -- Check readiness
    if not ShopClientState.isShopReady(shopId) then
        print("Shop not yet synced. Waiting...")
        -- Option 1: Queue and retry
        ShopUI.queueOpenRequest(shopId)
        return
    end
    
    -- Now safe to render
    ShopUI.renderShopWindow(shopId)
end

-- Listener for completion
ShopClientState:registerListener("initialSyncComplete", function(shopId)
    -- If UI was waiting, open it now
    if ShopUI.pendingOpenShop == shopId then
        ShopUI.openShop(shopId)
    end
end)
```

### Validation Checklist

- [ ] `SyncInitialComplete` command defined in protocol
- [ ] Server sends it after `SyncShopData` + `SyncBuyPrices` + `SyncSellRules`
- [ ] Client tracks `_initialSyncComplete` flag per shop
- [ ] Client verifies revision match before marking complete
- [ ] UI only renders when `isShopReady(shopId) == true`
- [ ] No UI flicker when prices update after initial sync

### Testing

```lua
-- Verify initial sync atomicity
-- 1. Client opens shop UI
-- 2. Before SyncInitialComplete: isShopReady() == false
-- 3. After SyncInitialComplete: isShopReady() == true
-- 4. Verify UI renders only in step 3
-- 5. Manually delay SyncInitialComplete by 1s, verify no rendering
```

---

## Change 4: Composite-State Helpers

### Goal
Provide semantic methods so code doesn't have to reason about revision pairs.

### Locations to Add

#### Client-side State Helpers (`Shops/42.13.1/media/lua/client/ShopClientState.lua`)

**Add composite-state methods:**
```lua
-- NEW: Composite version check
ShopClientState.isPricingStateComplete = function(shopId)
    local shop = ShopClientState.shops[shopId]
    if not shop then return false end
    
    -- Complete means: both revisions are set and initial sync is done
    return shop._initialSyncComplete and
           shop.buyRevision ~= nil and
           shop.sellRevision ~= nil
end

-- NEW: Composite change detection
ShopClientState.isPricingStateChanged = function(shopId, prevBuyRev, prevSellRev)
    local shop = ShopClientState.shops[shopId]
    if not shop then return false end
    
    -- Changed if either revision changed
    return shop.buyRevision ~= prevBuyRev or
           shop.sellRevision ~= prevSellRev
end

-- NEW: Get both revisions as tuple
ShopClientState.getPricingRevisions = function(shopId)
    local shop = ShopClientState.shops[shopId]
    if not shop then return nil, nil end
    return shop.buyRevision, shop.sellRevision
end

-- NEW: Store "last known" state for change detection
ShopClientState.capturePricingState = function(shopId)
    local shop = ShopClientState.shops[shopId]
    if not shop then return nil end
    
    return {
        buyRevision = shop.buyRevision,
        sellRevision = shop.sellRevision,
        timestamp = getGameTime()
    }
end
```

#### External API (`Shops/42.13.1/media/lua/shared/Shop.lua`)

**Expose semantic interface for mods:**
```lua
-- NEW: Public API for external consumers
Shop.getPricingState = function(shopId)
    return {
        isComplete = ShopClientState.isPricingStateComplete(shopId),
        buyRevision = select(1, ShopClientState.getPricingRevisions(shopId)),
        sellRevision = select(2, ShopClientState.getPricingRevisions(shopId)),
        shop = ShopClientState.shops[shopId]
    }
end

-- NEW: Check if specific item prices are available
Shop.itemPricesAvailable = function(shopId)
    return ShopClientState.isPricingStateComplete(shopId)
end
```

### Validation Checklist

- [ ] `isPricingStateComplete()` returns true only when initial sync finished
- [ ] `isPricingStateChanged()` works correctly with any revision pair
- [ ] `getPricingRevisions()` returns both values
- [ ] `capturePricingState()` can be used for change detection
- [ ] External API is documented (JSDoc or Lua comments)
- [ ] No logic duplication with internal state checks

### Testing

```lua
-- Verify composite helpers
-- 1. Before initial sync: isPricingStateComplete() == false
-- 2. After initial sync: isPricingStateComplete() == true
-- 3. On buy update: isPricingStateChanged(oldBuy, oldSell) == true if either changed
-- 4. External mod can call Shop.getPricingState(shopId) and get complete picture
```

---

## Implementation Order & Dependencies

### Phase 1: Core Revision Tracking (Change 1)
- **Duration:** ~2-3 hours
- **Blockers:** None
- **Files:**
  - `ShopNetworkSync.lua` (server broadcast)
  - `ShopClientState.lua` (client handlers)
- **Acceptance:** Both revisions present in every broadcast, client stores both

### Phase 2: Modifier Transparency (Change 2)
- **Duration:** ~2-3 hours
- **Blockers:** Phase 1 (minor - just needs both revisions in payload)
- **Files:**
  - `ShopBuyPrices.lua` (computation)
  - `ShopNetworkSync.lua` (broadcast payload)
  - `ShopClientState.lua` (storage)
- **Acceptance:** Modifiers visible in client state, can trace price calculation

### Phase 3: Initial Sync Handshake (Change 3)
- **Duration:** ~3-4 hours
- **Blockers:** Phase 1 & 2 (needs them for complete initial state)
- **Files:**
  - `ShopNetworkSync.lua` (new command + sequence)
  - `ShopClientState.lua` (completion flag + handlers)
  - `ShopUI.lua` (gating logic)
  - `ShopServerState.lua` (initial sync sequence)
- **Acceptance:** UI only opens when `_initialSyncComplete == true`

### Phase 4: Semantic Helpers (Change 4)
- **Duration:** ~1 hour
- **Blockers:** Phase 1-3 (needs all three to provide meaningful interface)
- **Files:**
  - `ShopClientState.lua` (helpers)
  - `Shop.lua` (public API)
- **Acceptance:** External mods can use semantic API without internal knowledge

---

## Code Review Checklist

- [ ] All broadcasts include both buyRevision and sellRevision
- [ ] Client state stores both revisions (separately and at sync time)
- [ ] Buy modifiers are included in SyncBuyPrices payload
- [ ] Modifiers can be traced back to their source (documented)
- [ ] SyncInitialComplete is sent after all initial data
- [ ] Client sets `_initialSyncComplete` only on this signal
- [ ] UI blocks rendering until `_initialSyncComplete == true`
- [ ] Composite helpers cover all state-checking patterns
- [ ] No code path assumes revision ordering
- [ ] No code path waits on implicit completion
- [ ] All new fields have nil-safety checks

---

## Testing Strategy

### Unit Tests
- Mock server state with known revisions
- Verify client handlers set all fields correctly
- Test composite helpers with edge cases (nil, mismatched revisions)

### Integration Tests
- Simulate full initial sync sequence
- Simulate partial updates (buy-only, sell-only)
- Verify UI gating prevents premature rendering
- Verify external API completeness

### Regression Tests
- Run existing shop tests (prices, rules, transactions)
- Verify no performance regression on broadcast size
- Verify multiplayer convergence

---

## Rollback Plan

If any phase fails:

1. **Phase 1 fails:** No architectural impact. Remove revision fields from broadcasts, revert handlers.
2. **Phase 2 fails:** Keep revision fields, remove modifiers. Does not affect other phases.
3. **Phase 3 fails:** Keep revisions + modifiers, remove completion signal. UI falls back to implicit readiness.
4. **Phase 4 fails:** Keep phases 1-3, remove semantic helpers. Internal code still works.

---

## Success Criteria

After all phases:

- ✅ Clients cannot observe partial state (atomicity)
- ✅ Buy logic is transparent (modifiers visible)
- ✅ Initial sync is atomic (completion handshake)
- ✅ Pricing state is semantically clear (composite helpers)
- ✅ SHA_B architecture unchanged (no revert)
- ✅ No breaking changes to external API
- ✅ Multiplayer state deterministic
- ✅ UI never renders incomplete data

---

## Notes for Contributor

This is **not** a revert to SHA_A. This is **completing SHA_B's design** by adding the enforcement logic that was inadvertently omitted during the split.

The guarantees you're restoring are not "new" — they're the ones clients expect because they existed in SHA_A. The split architecture is better, but it requires explicit coordination.

Think of it as: **SHA_B + Completeness = Better than SHA_A**.
