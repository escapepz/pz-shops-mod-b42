# Phase 1.2: Pricing Audit Results

## Summary
Audit of existing pricing code for non-deterministic calls and server-only dependencies.

---

## Files Analyzed

### ✅ ShopPriceUtils.lua
**Status**: SAFE (Deterministic)

**Analysis**:
- Only performs arithmetic (multiply, add, floor)
- No time, RNG, or global state reads
- Pure function: `applyModifiers(base, modifiers)`

**Recommendation**: Can be used in PricingContract directly.

---

### ✅ ShopPriceEvents.lua
**Status**: SAFE (Event Dispatcher Only)

**Analysis**:
- Only registers and triggers callbacks
- No pricing logic itself
- Callbacks are user-defined (auditing them is modder responsibility)

**Recommendation**: 
- Document that all callbacks registered must be deterministic
- Add assertion to Phase 5 (Determinism Validator)

---

### ⚠️ ShopPriceCalculatorShared.lua
**Status**: PARTIALLY SAFE (Deterministic, but server-only conditions)

**Lines 22-45**: `evaluateCondition()` function
- Line 24: `getCore():getDifficulty()` — ✅ SAFE (immutable game setting)
- Line 30: `item:getCondition()` — ⚠️ CONDITIONAL (safe for SELL, not for BUY)
  - Context: Used to evaluate condition ≥ X%
  - Issue: BUY pricing should not depend on item condition (client doesn't have item)
  - Mitigation: Already handled correctly (BUY call passes `nil` for item, returns `true`)
- Line 40: `player:HasTrait(traitName)` — ✅ SAFE (immutable trait)
- Line 42: `kind == "server_only"` returns `false` — ✅ SAFE (conservative default)

**Lines 73-118**: `calcBuyPrice()` function
- Uses `evaluateCondition()` with item=nil — ✅ SAFE
- No RNG, time, or mutable globals

**Lines 122-173**: `calcSellPrice()` function
- Uses `evaluateCondition()` with item object — ✅ SAFE
- Safe because sell operations happen on actual items

**Recommendation**: 
- Rename to indicate data-driven nature (or leave as-is)
- Document that modifiers must be pre-built by caller
- Already safe for both client and server use

---

### ⚠️ ShopPriceBuy.lua
**Status**: REQUIRES REFACTOR (Mixed server/client logic)

**Issues**:
1. **Line 24-52**: `Shop.resolvePlayerBuyPrice()` mixes concerns:
   - Reads from `Shop.Items[itemId]` — ✅ SAFE
   - Calls `ShopPriceEvents.triggerOnShopModifyBuyPrice()` — ⚠️ Callback is user-defined
   - Calls `ShopPriceEvents.triggerOnShopOverrideBuyPrice()` — ⚠️ Callback is user-defined
   - Uses `PriceUtils.applyModifiers()` — ✅ SAFE

2. **Determinism Problem**:
   - Hooks can contain non-deterministic code
   - Example: A hook could call `ZombRand()`, `os.time()`, or read mutable game state
   - Client cannot safely use this for preview pricing

3. **Solution (Phase 2)**:
   - Separate hook execution (server-only, can use any logic)
   - Use `PricingContract.calculateBuyPrice()` for client preview
   - Server validates via same `PricingContract` at transaction time

**Recommendation**: 
- Keep hooks flexible (modders need power)
- Create client-only path using PricingContract (no hooks)
- Server path remains hook-based (full power)

---

### ⚠️ ShopPriceSell.lua
**Status**: REQUIRES REFACTOR (Same as Buy)

**Issues**:
- Same mixed server/client logic as ShopPriceBuy.lua
- Calls user-defined hooks that may not be deterministic

**Recommendation**: 
- Same solution as ShopPriceBuy
- Separate client preview (PricingContract) from server execution (hooks)

---

## Non-Deterministic Operations Found

### ❌ Explicitly Forbidden (None Found in Core)
Good news: Core pricing files don't contain:
- `ZombRand()` — No random pricing
- `os.time()` — No time-based pricing
- `GameTime.*` — No world time dependencies
- Mutable globals like `Economy.*`
- Inventory/container access in pricing

### ⚠️ Potential Issues in User Hooks

Hook callbacks could contain:
1. **RNG-based pricing** (e.g., `ZombRand() * 0.5 + 1`)
2. **Time-based pricing** (e.g., `os.time() % 1000`)
3. **State mutations** (e.g., `Economy.setPrice()` during calculation)
4. **Unordered iteration** (e.g., `pairs(modifierTable)` instead of `ipairs()`)

These will be caught in **Phase 5 (Determinism Validator)**.

---

## Audit Checklist

- [x] No RNG calls in core pricing
- [x] No time-based logic in core pricing
- [x] No mutable global reads in core pricing
- [x] No inventory access in buy pricing
- [x] Item condition only used safely (sell only)
- [x] Modifier stacking is deterministic
- [x] Player trait checks are immutable
- [x] PricingContract provides safe baseline
- [ ] Hook callbacks documented as must-be-deterministic
- [ ] Phase 5 validator will catch violations

---

## Next Steps (Phase 1.3)

Build shared shop catalog with:
1. Static NPC shop definitions
2. Base prices per item
3. Stock (-1 = infinite)
4. UI metadata (category, icon, etc.)
5. Immutable structure

See: `docs/PHASE_1_SHOP_CATALOG.md` (to be created)

---

## Validation Commands

**When complete, verify:**
```bash
npm run build        # Compile all Lua
npm run test         # Run test suite (if available)
```

**Manual verification in-game:**
1. Load a vanilla NPC shop
2. Verify prices display correctly
3. Purchase an item with correct price deduction
4. Sell an item with correct payout

