# Phase 4: Composite-State Helpers - COMPLETE

## Objective
Provide semantic methods for reasoning about pricing state without manually tracking two revision counters, reducing external code complexity.

## Changes Made

### Client-side (ShopSyncClient.lua)

**New Helper: `isPricingStateComplete()` (line 386)**
- Returns `true` only when initial sync is complete AND both revisions are set
- Single boolean check instead of "is BuyPriceRevision set? is SellRuleRevision set? is _initialSyncComplete true?"
- Semantic clarity: "Is pricing state ready to use?"

**New Helper: `isPricingStateChanged(prevBuyRev, prevSellRev)` (line 396)**
- Compares previous state with current state
- Handles nil comparisons gracefully
- Returns `true` if either revision changed
- Useful for change detection without explicit revision tracking

**New Helper: `getPricingRevisions()` (line 410)**
- Returns both revisions as a tuple: `buyRev, sellRev`
- Cleaner than accessing `Shop.BuyPriceRevision` and `Shop.SellRuleRevision` separately

**New Helper: `capturePricingState()` (line 418)**
- Captures a snapshot of current state including:
  - Both revisions
  - Timestamp
  - Completion flag
- Useful for later comparison with `isPricingStateDifferent()`

**New Helper: `isPricingStateDifferent(capturedState)` (line 431)**
- Compares a captured state snapshot with current state
- Returns `true` if either revision has changed
- Pairs with `capturePricingState()` for before/after analysis

### Public API Exports (ShopSyncClient.lua, line 495)

All five helpers are also exported to the `SHOPSB42.Shop` namespace:

```lua
Shop.isPricingStateComplete()
Shop.isPricingStateChanged(prevBuyRev, prevSellRev)
Shop.getPricingRevisions()
Shop.capturePricingState()
Shop.isPricingStateDifferent(capturedState)
```

This allows external mods to use a clean, discoverable API:
```lua
if SHOPSB42.Shop.isPricingStateComplete() then
    local price = SHOPSB42.Shop.BuyPrices["Base.Apple"]
end
```

## Usage Examples

### Example 1: Simple Readiness Check
```lua
-- Before (without helpers)
if Shop.BuyPriceRevision and Shop.SellRuleRevision and Shop._initialSyncComplete then
    -- Safe to use prices
end

-- After (with helpers)
if Shop.isPricingStateComplete() then
    -- Safe to use prices
end
```

### Example 2: Change Detection
```lua
-- Before
local oldBuy = Shop.BuyPriceRevision
local oldSell = Shop.SellRuleRevision
-- ... later ...
if Shop.BuyPriceRevision ~= oldBuy or Shop.SellRuleRevision ~= oldSell then
    -- Prices changed
end

-- After
if Shop.isPricingStateChanged(oldBuy, oldSell) then
    -- Prices changed
end
```

### Example 3: State Capture & Compare
```lua
-- Capture state before action
local stateBefore = Shop.capturePricingState()

-- ... perform some action ...

-- Check if state changed
if Shop.isPricingStateDifferent(stateBefore) then
    print("Pricing state changed during action")
end
```

### Example 4: Getting Revisions
```lua
-- Before
local buyRev = Shop.BuyPriceRevision
local sellRev = Shop.SellRuleRevision

-- After
local buyRev, sellRev = Shop.getPricingRevisions()
```

## Behavioral Impact

**External Mods**: Significantly improved
- No longer need to understand two-revision architecture
- Clean semantic API hides internal complexity
- Discoverable via Shop namespace
- Type-safe (helpers validate state)

**Existing Code**: No impact
- Direct access to `Shop.BuyPriceRevision` and `Shop.SellRuleRevision` still works
- Helpers are additions, not replacements

**Performance**: No impact
- Helpers are just thin wrappers around state access
- No additional data structures or calculations
- Same memory footprint

## Testing Checklist

### Unit Tests
- [ ] `isPricingStateComplete()` returns true only when all conditions met
- [ ] `isPricingStateComplete()` returns false during initial sync
- [ ] `isPricingStateChanged()` detects any revision change
- [ ] `getPricingRevisions()` returns correct values
- [ ] `capturePricingState()` captures all fields
- [ ] `isPricingStateDifferent()` compares correctly

### Integration Tests
- [ ] External mod can call `Shop.isPricingStateComplete()`
- [ ] State capture and comparison work correctly
- [ ] Change detection works with actual price updates
- [ ] Nil comparisons handled gracefully

### Regression Tests
- [ ] Existing code still accesses revisions directly
- [ ] No performance degradation
- [ ] All helpers work from external context

## Files Modified

1. `Shops/42.13.1/media/lua/client/nshopsb42/sync/ShopSyncClient.lua`
   - New: `isPricingStateComplete()` - check readiness
   - New: `isPricingStateChanged()` - detect changes
   - New: `getPricingRevisions()` - get tuple
   - New: `capturePricingState()` - snapshot state
   - New: `isPricingStateDifferent()` - compare snapshots
   - New: Public API exports to Shop namespace

## API Reference

### `Shop.isPricingStateComplete()`
**Returns**: `boolean`

Check if pricing state is complete and ready to use.

```lua
if Shop.isPricingStateComplete() then
    local price = Shop.BuyPrices[itemId]
end
```

---

### `Shop.isPricingStateChanged(prevBuyRev, prevSellRev)`
**Parameters**: 
- `prevBuyRev` (number): Previous buy revision
- `prevSellRev` (number): Previous sell revision

**Returns**: `boolean`

Check if pricing state has changed since a known previous state.

```lua
local oldBuy, oldSell = Shop.getPricingRevisions()
-- ... later ...
if Shop.isPricingStateChanged(oldBuy, oldSell) then
    print("Prices updated!")
end
```

---

### `Shop.getPricingRevisions()`
**Returns**: `buyRevision (number or nil), sellRevision (number or nil)`

Get both pricing revisions as a tuple.

```lua
local buyRev, sellRev = Shop.getPricingRevisions()
print("Buy revision: " .. tostring(buyRev))
print("Sell revision: " .. tostring(sellRev))
```

---

### `Shop.capturePricingState()`
**Returns**: `table` with fields: `buyRevision`, `sellRevision`, `timestamp`, `isComplete`

Capture a snapshot of current pricing state for later comparison.

```lua
local snapshot = Shop.capturePricingState()
-- ... do something ...
if Shop.isPricingStateDifferent(snapshot) then
    print("State changed!")
end
```

---

### `Shop.isPricingStateDifferent(capturedState)`
**Parameters**:
- `capturedState` (table): State snapshot from `capturePricingState()`

**Returns**: `boolean`

Check if current state differs from a captured snapshot.

```lua
local before = Shop.capturePricingState()
-- ... action ...
local changed = Shop.isPricingStateDifferent(before)
```

## Notes

- All helpers are client-only (pricing state is client-side only)
- Helpers work immediately after Phase 3 completion handshake
- Nil-safe: handles missing or uninitialized state gracefully
- Composable: helpers can be combined for complex checks

## Complete Forward-Port Summary

All four phases now complete. SHA_B forward-port restores SHA_A guarantees:

| Guarantee | Phase | Implementation |
|-----------|-------|-----------------|
| Atomicity | 1 | Both revisions in every broadcast |
| Transparency | 2 | Buy modifiers included in sync |
| Completeness | 3 | SyncInitialComplete handshake |
| Clarity | 4 | Composite-state semantic helpers |

External code can now reason about pricing with confidence.
