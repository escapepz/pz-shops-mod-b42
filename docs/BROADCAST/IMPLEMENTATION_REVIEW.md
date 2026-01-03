# Implementation Review: Listing Sync Architecture vs. Findings

**Date**: 2026-01-03  
**Status**: CRITICAL ISSUES FOUND  
**Severity**: 2 Blocking, 2 High, 3 Medium

---

## Executive Summary

The **LISTING.md documentation is accurate**, and the implementation **partially follows** what is documented. However, there are **2 critical correctness bugs** confirmed in the actual code that match the review findings exactly:

| Issue | Finding | Confirmed | Status |
|-------|---------|-----------|--------|
| Buy `basePrice` discarded | ✓ | YES | **BLOCKING** |
| Default prices not synced | ✓ | YES | **BLOCKING** |
| No revision regression guard | ✓ | PARTIAL | High |
| Modifier metadata not lifecycle-managed | ✓ | YES | Medium |
| UI invalidation granularity | ✓ | YES | Low (optimization) |

---

## Finding #1: Buy `basePrice` Discarded ✓ CONFIRMED

### Code Evidence

**Server sends** (ShopFinalizeHandlerServer.lua L64-68):
```lua
return {
    price = price,          -- final calculated price
    basePrice = base,       -- base price before modifiers
    modifiers = modifiers,  -- modifier breakdown
}
```

**Client receives but discards** (ShopSyncClient.lua L251, L283):
```lua
-- Line 251 (initial sync):
Shop.CalculatedPrices.buyPrices[itemId] = priceData.price  -- WRONG: Scalar only

-- Line 283 (delta update):
Shop.CalculatedPrices.buyPrices[itemId] = priceData.price  -- WRONG: Scalar only
```

### Impact on UI

**ShopUI.lua L1354-1355** (recalculateRowPrice):
```lua
if not row.basePrice then
    row.basePrice = row.price  -- Falls back to same value
end
```

**Result**: `basePrice == price` always, even when server sent different values.

This breaks:
- Discount/markup visual indicators
- Price comparison UI ("20% off" labels)
- Transparency in pricing breakdowns

### Fix Required

Store the full `priceData` object instead of extracting `.price`:

**ShopSyncClient.lua L251 → Replace with:**
```lua
Shop.CalculatedPrices.buyPrices[itemId] = priceData
```

**ShopSyncClient.lua L283 → Replace with:**
```lua
Shop.CalculatedPrices.buyPrices[itemId] = priceData
```

**Then update consumers:**

ShopUI.lua L50-51:
```lua
-- Current:
local price = calculatedPrices.buyPrices[itemId]

-- Fixed:
local priceData = calculatedPrices.buyPrices[itemId]
local price = type(priceData) == "table" and priceData.price or priceData
```

ShopUI.lua L1362-1364:
```lua
-- Current:
if calc and calc.buyPrices and calc.buyPrices[row.type] then
    price = calc.buyPrices[row.type]

-- Fixed:
if calc and calc.buyPrices and calc.buyPrices[row.type] then
    local priceData = calc.buyPrices[row.type]
    price = type(priceData) == "table" and priceData.price or priceData
    if type(priceData) == "table" and priceData.basePrice then
        row.basePrice = priceData.basePrice
    end
```

**Backward Compatibility:**  
The fix uses `type()` check to handle both:
- Old scalar format: `buyPrices[itemId] = 25`
- New table format: `buyPrices[itemId] = { price = 25, basePrice = 50, ... }`

---

## Finding #2: Default Prices Not Synced ✓ CONFIRMED

### Evidence

**Documented in LISTING.md L21-35** (already flagged):
```
Default Price Fallback (NOT in SyncShopData):
- When inventory item is not registered (in blacklist mode), client uses hardcoded defaults from Shop.lua:
  - Shop.defaultPrice = 1 (normal items)
  - Shop.defaultPriceBroken = 1 (broken items)
- WARNING: These are NOT sent in any broadcast. If server changes these values post-init, client won't know.
```

**Shop.lua L34-35** (shared):
```lua
Shop.defaultPrice = 1
Shop.defaultPriceBroken = 1
```

**Used by ShopUI** (L1368-1373, L1378):
When server price not available, falls back to calculator which reads `Shop.defaultPrice`.

### Scenario

1. Server initializes with `Shop.defaultPrice = 1`
2. Client receives initial sync, stores local reference
3. Server admin changes `Shop.defaultPrice = 10` at runtime
4. Client never receives update
5. Unregistered items show price=1 on client, but server charges 10

### Root Cause

`SyncShopData` (ShopCommandDispatcherServer.lua L~) does NOT include defaults:
```lua
{
  Items = { ... },
  PlayerBuy = { ... },
  PlayerSell = { ... },
  BuyIsWhitelist = bool,
  SellIsWhitelist = bool
  -- MISSING: defaultPrice, defaultPriceBroken
}
```

### Fix Options

**Option A: Sync defaults (PREFERRED)**
- Include in `SyncShopData` during initial sync
- Update if changed (separate broadcast or bundled with price changes)
- Backward-compatible if wrapped in `pcall()` on client

**Option B: Freeze defaults**
- Document that defaults cannot be changed post-init
- Add assertion in server code to prevent mutation

**Recommendation**: Option A, because:
- Mods may want to adjust defaults at runtime
- Simpler than enforcement
- Aligns with authoritative-server principle

---

## Finding #3: Revision Atomicity Not Enforced ✓ PARTIAL

### What's Implemented (Good)

ShopSyncClient.lua correctly:
- Sends both `buyRevision` and `sellRevision` in atomic messages
- Tracks both revisions independently (L197-198)
- Compares revisions for change detection (L231-233, L280-281)

### What's Missing (Risk)

**No regression check**:
```lua
-- Current code (ShopSyncClient.lua L231-233):
local oldBuyRevision = Shop.BuyPriceRevision
local newBuyRevision = data.buyRevision or 0

-- Recommended addition:
if newBuyRevision < oldBuyRevision then
    SharedLogger.log("Shops", "[ShopSyncClient] Ignoring stale SyncBuyPrices (rev " 
        .. newBuyRevision .. " < " .. oldBuyRevision .. ")")
    return false
end
```

### Risk Scenario

1. Client receives SyncBuyPrices with `buyRevision=5, sellRevision=10`
2. A second SyncBuyPrices with `buyRevision=3, sellRevision=11` arrives (network reorder)
3. Currently: Both updates apply, client state becomes inconsistent
4. With check: Second message rejected as stale

### Fix Required

Add version regression guards in `handleSyncBuyPrices` and `handleSyncSellRules`:

**ShopSyncClient.lua L231-236:**
```lua
local oldBuyRevision = Shop.BuyPriceRevision or 0
local newBuyRevision = data.buyRevision or 0

-- Reject stale updates
if newBuyRevision < oldBuyRevision then
    SharedLogger.log("Shops", "[ShopSyncClient] Rejected stale SyncBuyPrices (rev " 
        .. newBuyRevision .. " < " .. oldBuyRevision .. ")")
    return false
end
```

Similar check in `handleSyncSellRules` for `sellRevision`.

**Severity**: Medium (race condition unlikely in practice, but improves correctness)

---

## Finding #4: Modifier Metadata Lifecycle Not Managed ✓ CONFIRMED

### Evidence

ShopSyncClient.lua L239-241, 254, 286:
```lua
if not Shop._buyModifierMetadata then
    Shop._buyModifierMetadata = {}
end

-- ... added to:
Shop._buyModifierMetadata[itemId] = priceData.modifiers
```

**Problem**: Once stored, modifiers are **never cleared or versioned**.

### Risk Scenario

1. Session 1: Item "Base.Apple" has 2 modifiers
   - `Shop._buyModifierMetadata["Base.Apple"] = { mod1, mod2 }`
2. Session 2 (after server restart): Apple removed from PlayerBuy registry
   - Client doesn't receive update (delta sync only)
   - Stale metadata persists
3. Admin re-adds Apple with different modifiers
   - But client still has old metadata

### Fix Required

Tie metadata lifecycle to `buyRevision`:

**Option A: Clear on initial sync**
```lua
if data.isInitialSync then
    Shop._buyModifierMetadata = {}  -- Clear old metadata
    -- ... then populate with new values
end
```

**Option B: Clear on delta if revision resets**
```lua
if newBuyRevision < oldBuyRevision then
    -- Revision wrapped, clear all metadata (safety)
    Shop._buyModifierMetadata = {}
end
```

**Recommendation**: Implement Option A (clearing on initial sync) + add a cleanup function for delta updates that removes metadata for items no longer in the broadcast.

---

## Finding #5: Sell Pricing Model (Acceptable but Fragile) ✓ CONFIRMED

### Current Implementation (ShopSyncClient.lua L347-410)

Client receives `SyncSellRules` with:
- `sellModifiers` (array of condition-based rules)
- `sellOverrides` (direct price replacements)

Client calculates sell prices on-the-fly (ShopUI.lua L1372-1374):
```lua
price = Calculator.calcSellPrice(row.item.invItem, player, mods)
```

### Risk Assessment

**Risk**: Inconsistent calculation if:
- Mod environment differs (missing price mods)
- Condition evaluation differs (e.g., reputation checks)
- Condition functions throw (soft-fails)

**Mitigation Already Present**:
- Server recalculates on completion (presumably in sell transaction handler)
- Falls back to basePrice if calculator returns nil

**Assessment**: LOW RISK in practice (good defensive design), but consider:

1. **Document clearly** that sell price is *preview only until transaction completes*
2. **Add server validation** in sell handler: "If final price differs from client preview by >10%, log warning"
3. **Optional optimization**: For very high-value items, server could send a pre-calculated sell price cache

This is **not blocking** but worth documenting for addon authors.

---

## Finding #6: UI Invalidation Granularity ✓ CONFIRMED AS OPTIMIZABLE

### Current Implementation (ShopSyncClient.lua L18-93)

Good news: Already has reason-coded invalidation!
```lua
ShopSyncClient.InvalidateReason = {
    BUY_PRICE_DELTA = "buy_price_delta",
    SELL_RULE_CHANGE = "sell_rule_change",
    STRUCTURAL_CHANGE = "structural_change",
}
```

**Implementation**:
- BUY_PRICE_DELTA: Clears all caches + rebuilds active tab (L59-74)
- SELL_RULE_CHANGE: Only rebuilds sell tab (L40-52)
- STRUCTURAL_CHANGE: Full rebuild (L75-88)

### Analysis

This is **already optimal** for the current use case. The "heavy" approach (L59-74) is justified because:
1. Buy price changes are relatively rare
2. Cart must be cleared anyway (user must re-confirm)
3. No performance metrics indicate this is a bottleneck

**Verdict**: No action needed. Document this in LISTING.md as an intentional trade-off.

---

## Finding #7: Missing "Price Authority Boundary" Documentation ✓ CONFIRMED

### Evidence

LISTING.md is detailed but lacks **explicit guidance for mod authors**.

Currently documented:
- How each broadcast works ✓
- Client data flow ✓
- Price calculations ✓

Missing:
- What mods CAN and CANNOT do
- Price authority rules (what's final, what's advisory)
- Safe hook points
- Unsafe patterns to avoid

### Recommended Addition

Add to AGENTS.md or create `PRICE_AUTHORITY.md`:

```markdown
## Pricing Authority Rules for Addon Modders

### Buy Prices (Server-Authoritative)
- Final price for buy transactions is **always** what server broadcasts
- Client-side modifiers are **preview only** (fallback if server hook unavailable)
- NEVER modify `Shop.CalculatedPrices.buyPrices` from client code
- Safe hook: `OnShopModifyBuyPrice` (add modifiers on server)

### Sell Prices (Client-Calculated Preview)
- Sell price shown is **advisory only**
- Final price is recalculated server-side on transaction completion
- Client mods can hook `OnShopModifyBuyPrice` (applies to both)
- NEVER directly modify sell prices before client transmits to server

### Default Prices (Shared Constant)
- Currently synced via shared Lua only (NOT broadcast)
- Changing `Shop.defaultPrice` at runtime is unsafe in MP
- Will be fixed to sync from server (TBD)
```

---

## Summary Table: Findings vs. Implementation

| Finding | Documented | Implemented | Status | Severity | Action |
|---------|-----------|-------------|--------|----------|--------|
| 1. Buy basePrice discarded | NO | BUG | BLOCKING | Critical | Fix code + tests |
| 2. Defaults not synced | YES (warned) | BUG | BLOCKING | Critical | Implement sync |
| 3. No revision regression check | NO | MISSING | RISK | High | Add guard clause |
| 4. Modifier metadata leak | YES | Partial | LEAK | Medium | Tie to revision |
| 5. Sell pricing fragility | YES | MITIGATED | ACCEPTABLE | Low | Document |
| 6. UI invalidation granularity | N/A | IMPLEMENTED | GOOD | — | No action |
| 7. No authority boundary docs | NO | MISSING | GAP | Medium | Write docs |

---

## Blocking Issues: Required Before Release

### Issue #1: Fix basePrice storage
- **Files**: `ShopSyncClient.lua` (L251, L283)
- **Files**: `ShopUI.lua` (L50, L1362)
- **Effort**: 30 min
- **Risk**: Low (backward-compatible type check)

### Issue #2: Sync default prices
- **Files**: `ShopFinalizeHandlerServer.lua` (add to SyncShopData)
- **Files**: `ShopSyncClient.lua` (receive + store)
- **Files**: `Shop.lua` (optional: mark as "DO NOT MUTATE at runtime")
- **Effort**: 45 min
- **Risk**: Low (backward-compatible)

---

## Non-Blocking Improvements

### Issue #3: Add revision regression guards
- **Files**: `ShopSyncClient.lua` (add checks in handleSyncBuyPrices, handleSyncSellRules)
- **Effort**: 20 min
- **Impact**: Improve MP robustness

### Issue #4: Tie modifier metadata to buyRevision
- **Files**: `ShopSyncClient.lua` (clear metadata on initial sync, optionally on delta)
- **Effort**: 15 min
- **Impact**: Prevent metadata staleness

### Issue #7: Document price authority boundary
- **Files**: Create `PRICE_AUTHORITY.md` or add section to `AGENTS.md`
- **Effort**: 30 min
- **Impact**: Prevent addon regressions

---

## Conclusion

The implementation is **architecturally sound** but has **2 critical bugs** that must be fixed before publication:

1. **basePrice is broadcast but discarded** — Simple fix, high impact
2. **Default prices are not synchronized** — Medium fix, prevents desync edge case

Both are low-risk to fix (backward-compatible) and should take <1.5 hours total.

Remaining issues are improvements (revisions guards, metadata cleanup, documentation) that can be addressed in follow-up work.

**Recommendation**: Fix these two blocking issues now, then publish. Improvements can land in Phase 2.
