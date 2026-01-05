# Phase 1: Foundation (Deterministic Shared Pricing) — COMPLETE

## Overview
Phase 1 establishes the foundation for client-side listing and server-validated pricing without per-player sync broadcasts.

---

## Deliverables

### 1.1 ✅ PricingContract.lua (NEW)

**Location**: `Shops/42.13.1/media/lua/shared/nshopsb42/pricing/PricingContract.lua`

**Purpose**: Deterministic pricing baseline for shared calculation

**Key Functions**:
- `calculateBuyPrice(itemId, shopId, basePrice, playerSnapshot, modifiers)` — Pure pricing calculation
- `calculateSellPrice(itemId, shopId, basePrice, itemSnapshot, modifiers)` — Pure pricing calculation
- `getShopCatalogSnapshot(shopId)` — Fetch immutable shop snapshot
- `validatePriceConsistency(itemId, clientPrice, serverPrice, tolerance)` — Development aid

**Guarantees**:
- No RNG, time-based logic, or mutable globals
- Pure functions: same inputs → same outputs
- Both client (preview) and server (validation) can use
- Returns `{ finalPrice = number, revision = number }` (future-proofing for live pricing)

**Constraints Enforced**:
```lua
-- ALLOWED: Table lookups, arithmetic, static config, immutable player traits
-- FORBIDDEN: ZombRand, os.time, GameTime, mutable globals, inventory access

-- PricingContract inputs MUST be scalar snapshots only
-- NO inventory state, container reads, or world object access
```

---

### 1.2 ✅ Audit: Non-Deterministic Code (COMPLETE)

**Document**: `docs/PHASE_1_PRICING_AUDIT.md`

**Key Findings**:

| File | Status | Notes |
|------|--------|-------|
| ShopPriceUtils.lua | ✅ SAFE | Pure arithmetic only |
| ShopPriceEvents.lua | ✅ SAFE | Dispatcher only (callbacks audited by modders) |
| ShopPriceCalculatorShared.lua | ✅ SAFE | Uses immutable inputs; safe for client/server |
| ShopPriceBuy.lua | ⚠️ MIXED | Hook-based (flexible but not deterministic); Phase 2 separates paths |
| ShopPriceSell.lua | ⚠️ MIXED | Hook-based; Phase 2 separates paths |

**Conclusion**: 
- Core pricing code is deterministic ✅
- Hooks are powerful but flexible (modder responsibility to be deterministic)
- Phase 5 (Determinism Validator) will catch violations at load time

---

### 1.3 ✅ NPCShopCatalog.lua (NEW)

**Location**: `Shops/42.13.1/media/lua/shared/nshopsb42/pricing/NPCShopCatalog.lua`

**Purpose**: Immutable NPC shop definitions for client preview and server validation

**Key Functions**:
- `initialize()` — Build catalog from registered items
- `getShopSnapshot(shopId)` — Return immutable shop snapshot
- `getItemBasePrice(shopId, itemId)` — Get item base price
- `isItemAvailable(shopId, itemId)` — Check availability
- `listShopItems(shopId)` — List all items in shop
- `listShops()` — List all NPC shops
- `validate()` — Verify catalog consistency

**Structure**:
```lua
NPCShopCatalog["npc_general_store"] = {
    shopId = "npc_general_store",
    name = "General Store",
    items = {
        ["Base.Apple"] = {
            itemId = "Base.Apple",
            basePrice = 15,
            category = "Food",
            stock = -1,  -- Infinite
            available = true,
        },
        ...
    }
}
```

**Key Design**:
- Static, immutable structure (no mutations after initialize)
- Load-order independent (builds from Shop.Items registry)
- Supports future multi-shop model
- No time-based availability (future extension)

---

## Future-Proofing: Live Pricing Model

Per the refactor plan, Phase 1 includes architectural groundwork for Phase 7+ (live pricing):

### Revision Tracking (Phase 1.3)
All PricingContract returns include revision field:
```lua
return { finalPrice = 120, revision = 42 }
```

### Server Responses Include Revision
All Buy/Sell responses must include revision (Phase 3):
```lua
sendServerCommand(player, "Shop", "BuyResult", {
    success = true,
    finalPrice = 120,
    priceRevision = 42,  -- included always
})
```

### No Code Required Now
Live pricing (when added later) will use revision-based snapshots, not broadcasts.
This is purely architectural planning; zero additional implementation.

---

## Integration Checklist

- [x] PricingContract.lua exists and exports correct functions
- [x] PricingContract documented in inline comments
- [x] NPCShopCatalog.lua exists and initializes from Shop.Items
- [x] Audit document lists all non-deterministic findings
- [x] No RNG, time-based logic, or mutable globals in PricingContract
- [x] Item condition handled safely (sell-only, immutable snapshot)
- [x] Player traits are read-only (immutable)
- [x] Modifiers support stacking (sequential multiplication)
- [x] Future-proofing includes revision tracking
- [ ] PricingContract wired into shared init (Phase 2)
- [ ] NPCShopCatalog initialization called at startup (Phase 2)

---

## Testing (Manual)

1. **Load mod without errors**
   ```bash
   npm run build
   npm run watch  # Check console for any require() errors
   ```

2. **Verify catalog initializes**
   - Check logs for: `[NPCShopCatalog] Initialized default shop with X items`

3. **Test price calculation**
   - Call `PricingContract.calculateBuyPrice("Base.Apple", "npc_general_store", 15, nil, {})`
   - Should return `{ finalPrice = 15, revision = 1 }`

---

## Notes for Next Phase (Phase 2)

Phase 2 will implement client-side listing using PricingContract:

1. Client loads catalog via `NPCShopCatalog.getShopSnapshot()`
2. Client calculates preview prices via `PricingContract.calculateBuyPrice()`
3. No server messages during listing view
4. Server transaction path remains hook-based (full power retained)
5. Phase 2.3 separates ShopPriceBuy.lua into deterministic + hook paths

---

## Success Criteria (Phase 1)

✅ All met:
- [x] PricingContract defines determinism constraints
- [x] Audit identifies zero forbidden calls in core pricing
- [x] NPCShopCatalog provides immutable shop definitions
- [x] Revision tracking enables future live pricing
- [x] No changes required to existing hook API (backward compatible)
- [x] Documentation complete for Phase 2 onboarding

