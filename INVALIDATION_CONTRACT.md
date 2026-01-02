# UI Invalidation Contract (Formal Specification)

**Purpose**: Prevent future changes from accidentally blurring asymmetrical tab refresh behavior (Sell vs All).

**Status**: Implemented in `ShopSyncClient.lua`

---

## Principle

| Tab | Change Type | UI Action | Rationale |
|-----|-------------|-----------|-----------|
| **Sell** | Sell rule change | **Always rebuild** | Inventory rows don't self-heal; must recompute prices per item |
| **All** | Buy price delta | **Invalidate prices only** | Registry rows self-heal via lazy `onRowBecameVisible()` recalculation |
| **All** | Structural change | **Rebuild** | Items added/removed or membership changed; list itself is stale |

---

## API Contract

### 1. Invalidation Reasons (Constants)

```lua
ShopSyncClient.InvalidateReason = {
    BUY_PRICE_DELTA = "buy_price_delta",
    SELL_RULE_CHANGE = "sell_rule_change",
    STRUCTURAL_CHANGE = "structural_change",
}
```

These constants **must be used** for all UI invalidation calls. Do not pass arbitrary strings.

---

### 2. Single Entry Point

All UI invalidation must go through:

```lua
function ShopSyncClient.invalidateUI(reason)
```

**Never call UI methods directly from sync handlers.**

---

### 3. Dispatch Behavior (Enforced by Code)

#### `BUY_PRICE_DELTA`

- Updates price data
- Invalidates non-active tab caches
- Does **not** rebuild active tab
- Allows visible rows to recalculate lazily

```lua
ShopSyncClient.invalidateUI(ShopSyncClient.InvalidateReason.BUY_PRICE_DELTA)
```

**Called by**: `handleSyncBuyPrices()` on revision change

---

#### `SELL_RULE_CHANGE`

- Invalidates Sell tab cache (or rebuilds if active)
- Does **not** touch All/Food tabs
- Intentionally asymmetrical from buy prices

```lua
ShopSyncClient.invalidateUI(ShopSyncClient.InvalidateReason.SELL_RULE_CHANGE)
```

**Called by**: `handleSyncSellRules()` on revision change

---

#### `STRUCTURAL_CHANGE`

- Rebuilds active tab
- Clears all cached tabs
- Full registry/membership refresh

```lua
ShopSyncClient.invalidateUI(ShopSyncClient.InvalidateReason.STRUCTURAL_CHANGE)
```

**Called by**: Future handlers (admin tools, item registry changes, etc.)

---

## What This Prevents

### ❌ Not Allowed

```lua
-- Wrong: Direct UI access from sync
ShopSyncClient.handleSyncBuyPrices = function(data)
    ...
    ui:rebuildActiveTab()  -- VIOLATION: UI decides rebuild, not sync
end

-- Wrong: Mixing reasons
ShopSyncClient.invalidateUI("buy_changed")  -- No constant defined

-- Wrong: Different behavior per handler
handleSyncBuyPrices() → rebuilds
handleSyncSellRules() → lazy invalidates
-- (inconsistent contract)
```

### ✅ Correct Pattern

```lua
ShopSyncClient.handleSyncBuyPrices = function(data)
    ...
    ShopSyncClient.invalidateUI(ShopSyncClient.InvalidateReason.BUY_PRICE_DELTA)
end

ShopSyncClient.handleSyncSellRules = function(data)
    ...
    ShopSyncClient.invalidateUI(ShopSyncClient.InvalidateReason.SELL_RULE_CHANGE)
end
```

---

## Extension: Structural Changes (Future)

When server detects structural changes (item added, whitelist mode flipped):

```lua
-- In ShopFinalizeHandlerServer.lua or future handler
Utilities.SendServerCommandToAll("Shops", "SyncStructuralChange", {
    isWhitelistModeChange = true,  -- or itemsAdded = {}, etc.
    ... data ...
})

-- In ShopSyncClient.lua
function ShopSyncClient.handleSyncStructuralChange(data)
    -- Update registries
    ...
    ShopSyncClient.invalidateUI(ShopSyncClient.InvalidateReason.STRUCTURAL_CHANGE)
end
```

---

## Lock-In Statement

> **After this change, the next person editing ShopSyncClient cannot reintroduce the Sell/All refresh bug without explicitly violating this contract and adding a code comment explaining why.**

This is intentional.

---

## Testing Checklist

- [ ] Sell rules change → Sell tab rebuilds (if active)
- [ ] Sell rules change → All/Food tabs lazy-update (if active)
- [ ] Buy prices change → All/Food tabs lazy-invalidate (if active)
- [ ] Buy prices change → Sell tab caches clear (if inactive)
- [ ] Scroll position preserved on price delta
- [ ] Scroll position reset on rebuild (expected)
- [ ] No UI flicker on buy price deltas
- [ ] No stale prices after rule changes
