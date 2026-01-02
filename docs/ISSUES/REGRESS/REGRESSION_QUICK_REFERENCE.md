# Regression Quick Reference: SHA_A → SHA_B

## Critical Issues (Must Fix)

### ❌ REGRESSION #1: Buy Modifiers Not Sent
**File**: `Shops/42.13.1/media/lua/server/nshopsb42/transactions/ShopFinalizeHandlerServer.lua`
**Line**: 127-143 (broadcastBuyPrices)

**Problem**: 
```lua
-- CURRENT (SHA_B): Missing buy modifiers
Utilities.SendServerCommandToAll("Shops", "SyncBuyPrices", {
    revision = Shop.BuyPriceRevision,
    buyPrices = changedPrices,  -- ← Only prices, no modifiers!
})
```

**Should be**:
```lua
-- FIXED: Include buy overrides for transparency
Utilities.SendServerCommandToAll("Shops", "SyncBuyPrices", {
    revision = Shop.BuyPriceRevision,
    buyPrices = changedPrices,
    buyOverrides = modifiers.buyOverrides or {},  -- ← ADD THIS
})
```

**Impact**: External mods cannot audit server buy price calculations. Server authority is opaque.

---

### ❌ REGRESSION #2: No Atomic Sync Point
**File**: `Shops/42.13.1/media/lua/server/nshopsb42/transactions/ShopFinalizeHandlerServer.lua`
**Line**: 179-194 (onPriceHooksChanged)

**Problem**:
```lua
-- CURRENT: Two separate broadcasts
function ShopFinalizeHandler.onPriceHooksChanged()
    if ShopFinalizeHandler.shouldInvalidateBuyPrices() then
        ShopFinalizeHandler.broadcastBuyPrices()  -- Broadcast 1
    end
    if ShopFinalizeHandler.shouldInvalidateSellRules() then
        ShopFinalizeHandler.broadcastSellRules()  -- Broadcast 2
    end
end
```

**Scenario**: If server crashes/network fails between broadcasts:
- Client A gets buy prices (rev=5) but not sell rules (rev=4)
- Client B gets both (rev=5, rev=4 at same time)
- Clients disagree on effective catalog

**Should add**: Both revisions in each broadcast
```lua
Utilities.SendServerCommandToAll("Shops", "SyncBuyPrices", {
    revision = Shop.BuyPriceRevision,
    buyPrices = changedPrices,
    buyRevision = Shop.BuyPriceRevision,      -- ← ADD
    sellRevision = Shop.SellRuleRevision,     -- ← ADD
})
```

**Impact**: Multiplayer desync risk. Two players see different effective state.

---

### ❌ REGRESSION #3: Initial Sync Race Condition
**File**: `Shops/42.13.1/media/lua/server/nshopsb42/transactions/ShopFinalizeHandlerServer.lua`
**Line**: 268-330 (sendShopDataToPlayer)

**Problem**:
```lua
-- CURRENT: Three separate commands
function ShopFinalizeHandler.sendShopDataToPlayer(player)
    Utilities.SendServerCommandTo(player, "Shops", "SyncShopData", shopData)
    Utilities.SendServerCommandTo(player, "Shops", "SyncBuyPrices", {...})
    Utilities.SendServerCommandTo(player, "Shops", "SyncSellRules", {...})
    -- No way to know all three arrived!
end
```

**Race Window**: UI can open between command 2 and 3, displaying incomplete prices.

**Should add**: Explicit sync completion marker
```lua
-- After SyncSellRules
Utilities.SendServerCommandTo(player, "Shops", "SyncInitialComplete", {
    buyRevision = Shop.BuyPriceRevision,
    sellRevision = Shop.SellRuleRevision,
})
```

**Client** (ShopSyncClient.lua):
```lua
elseif command == "SyncInitialComplete" then
    ShopSyncClient._initialSyncComplete = true
    -- Safe to open UI now
```

**Impact**: Player sees incomplete prices on first join (sell prices show as base until third command arrives).

---

## Behavioral Invariant Violations

### INV-1: Atomicity ❌
**What was guaranteed**: Single revision number covers all price changes
**What changed**: Two independent revisions
**Risk**: Buy and sell state can diverge

### INV-2: Buy Modifiers ❌
**What was guaranteed**: Buy hooks/overrides sent in every broadcast
**What changed**: Not sent at all in SHA_B
**Risk**: Server-side buy logic is opaque to clients

### INV-3: Initial Sync ❌
**What was guaranteed**: One command with complete state
**What changed**: Three separate commands in sequence
**Risk**: UI opens with incomplete data

### INV-4: Revision Semantics ❌
**What was guaranteed**: Single `PriceHookRevision` to check for any change
**What changed**: Must check `BuyPriceRevision` AND `SellRuleRevision` separately
**Risk**: Existing client code expecting single revision misses sell updates

---

## Command Structure Changes

### SHA_A: Single Unified Command
```lua
SyncPriceModifiers = {
    revision = X,              -- Single revision for all changes
    modifiers = {
        buyOverrides = {},
        sellOverrides = {},
        -- Both types in one object
    },
    changed = {},              -- Changed prices
    calculatedPrices = {},     -- Full prices on initial sync
    isInitialSync = bool,
}
```

### SHA_B: Split Commands
```lua
SyncBuyPrices = {
    revision = X,              -- Independent buy revision
    buyPrices = {},            -- Changed buy prices only
    isInitialSync = bool,
}

SyncSellRules = {
    revision = Y,              -- Independent sell revision
    sellModifiers = {},        -- Sell modifier rules
    sellOverrides = {},        -- Sell price overrides
    isInitialSync = bool,
}
```

**Missing in SHA_B**:
- `buyOverrides` in `SyncBuyPrices` ← CRITICAL
- Sell revision in `SyncBuyPrices` (and vice versa) ← CRITICAL
- Explicit initial sync completion signal ← CRITICAL

---

## Code Locations to Check

| Issue | File | Lines |
|-------|------|-------|
| Buy modifiers missing | ShopFinalizeHandlerServer.lua | 127-143 |
| Split broadcasts | ShopFinalizeHandlerServer.lua | 179-194 |
| Initial sync | ShopFinalizeHandlerServer.lua | 268-330 |
| Client handler | ShopSyncClient.lua | 237-281 |
| ShopUI usage | ShopUI.lua | 96-100 |
| Price builder | ShopPriceModifierBuilder.lua | 17-90 |

---

## Verification Checklist

Before merging SHA_B, verify:

- [ ] Buy overrides included in `SyncBuyPrices`
- [ ] Both revisions (buy + sell) included in each broadcast
- [ ] Explicit sync completion signal sent
- [ ] Client checks for sync completion before opening UI
- [ ] Test: New player join doesn't show incomplete prices
- [ ] Test: Buy-only change doesn't send sell broadcast
- [ ] Test: Sell-only change doesn't send buy broadcast
- [ ] Test: Server crash mid-broadcast doesn't desync clients
- [ ] Multiplayer: Two players joining simultaneously see same state
- [ ] Documentation updated: Note that buy/sell are now independent

---

## References

- **Full Analysis**: `REGRESSION_ANALYSIS.md`
- **Testing Plan**: `PHASE_5_TESTING.md`
- **Implementation Plan**: `SPLIT_BROADCAST_IMPLEMENTATION_SUMMARY.md`

