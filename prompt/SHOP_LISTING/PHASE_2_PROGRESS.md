# Phase 2: Client-Side Listing UI (Zero Network) — Progress

## Completed: 2.1 Refactor Client Shop UI

### Deliverables

#### 1. ShopListingNPC.lua (NEW)
**Location**: `Shops/42.13.1/media/lua/shared/nshopsb42/ui/ShopListingNPC.lua`

**Core Functions**:
- `loadShop(shopId)` — Load catalog snapshot (zero network, instant load)
- `getPreviewBuyPrice(itemId, basePrice, playerSnapshot, modifiers)` — Deterministic preview
- `getPreviewSellPrice(itemId, basePrice, itemSnapshot, modifiers)` — Deterministic preview
- `validatePriceMismatch(itemId, previewPrice, serverPrice)` — Development aid for debugging
- `createPlayerSnapshot(player)` — Create immutable player data for pricing
- `createItemSnapshot(item)` — Create immutable item data for pricing

**Key Design**:
- Reads from static NPCShopCatalog (no network)
- Uses PricingContract for deterministic calculation
- Preview prices labeled internally as non-authoritative
- Server price is always final truth
- Supports future extensions (multiple shops, dynamic availability)

#### 2. Phase 2 Implementation Plan
**Location**: `docs/PHASE_2_IMPLEMENTATION_PLAN.md`

Detailed technical specification:
- Current architecture analysis (per-player broadcasts, 400 packets/change)
- Target architecture (zero-network listing, 1 packet/transaction)
- 2.1 Client UI refactoring specification
- 2.2 ModData sync removal (server-side)
- 2.3 Mismatch handler design
- Integration notes and backward compatibility

---

## In Progress: 2.2 Remove Client ModData Syncing

### Tasks Remaining

#### 2.2.1 Stop Broadcasting Prices (Server-Side)
**File**: `server/nshopsb42/transactions/ShopFinalizeHandlerServer.lua`

Actions:
- [ ] Find and remove `sendClientCommand(nil, "Shop", "SyncBuyPrices", ...)` (broadcast)
- [ ] Remove per-player broadcast function
- [ ] Verify no reactive listeners trigger on price change
- [ ] Keep late-join sync (handled separately in Phase 3)

#### 2.2.2 Remove Reactive Invalidation (Client-Side)
**File**: `client/nshopsb42/sync/ShopSyncClient.lua`

Actions:
- [ ] Remove or deprecate `handleSyncBuyPrices()` function
- [ ] Remove listener for `SyncBuyPrices` server command
- [ ] Keep `handleSyncInitialComplete()` for late-join
- [ ] Verify Shop.BuyPrices no longer populated from broadcast

#### 2.2.3 Verify Integration
Actions:
- [ ] Test: Open shop, no SyncBuyPrices packets logged
- [ ] Test: Prices render using ShopListingNPC.getPreviewBuyPrice()
- [ ] Test: Player shops still work (they use different path)
- [ ] Measure network traffic: should be 0 during listing

---

## Todo: 2.3 Add Client Price Mismatch Handler

### Tasks
1. Create price validation function in ShopUI
2. Implement tolerance checking (±1 coin variance)
3. Log mismatches silently (development aid)
4. Update transaction result handling (no rebuild on mismatch)
5. Handle insufficient funds gracefully (no resync)

---

## Architecture Changes Summary

### Before Phase 2.1
```
Client:                           Server:
  Open shop                         Price change
    ↓                                 ↓
  Wait for SyncBuyPrices ←―――― sendClientCommand(SyncBuyPrices)
    ↓                           (per-player, O(n) broadcasts)
  Store in Shop.BuyPrices
    ↓
  Render using Shop.BuyPrices
    ↓
  On price change → Invalidate UI ←―――― Another broadcast
```

### After Phase 2.1
```
Client:                           Server:
  Open shop                         (no broadcast)
    ↓
  Load NPCShopCatalog (static)
    ↓
  Calculate prices with
  PricingContract (deterministic)
    ↓
  Render preview prices
  (labeled non-authoritative)
    ↓                              On transaction:
  Transaction request ―――――→         Validate
                                     Recompute price
                                     Return result
                                     ↓
                                  (1 targeted packet)
```

---

## Testing Checklist (2.1)

- [x] ShopListingNPC.lua created with all functions
- [x] loadShop() returns correct catalog structure
- [x] getPreviewBuyPrice() returns numeric price
- [x] getPreviewSellPrice() returns numeric price
- [x] createPlayerSnapshot() captures traits only
- [x] createItemSnapshot() captures condition only
- [ ] ShopUI.lua integration test (Phase 2.2)
- [ ] Zero network traffic verification (Phase 2.2)
- [ ] Preview price rendering test (Phase 2.2)

---

## Integration Readiness

**Before Phase 2.2**, ShopUI must be updated to use ShopListingNPC:

**Required Changes to ShopUI.lua**:
1. On shop open: `ShopListingNPC.loadShop(shopId)` instead of waiting
2. In calcBuyPrice(): Use `ShopListingNPC.getPreviewBuyPrice()` instead of `Shop.BuyPrices[itemId]`
3. Remove dependency on `ShopSyncClient.invalidateUI()`
4. Add call to `ShopListingNPC.validatePriceMismatch()` on transaction

**Notes**:
- ShopListingNPC is SHARED code (both client and server can use)
- Use for client preview, server validation reuses same code
- No breaking changes to existing hook system
- Player shops not affected (Phase 4 will optimize)

---

## Success Criteria (Phase 2 Complete)

### 2.1 ✅ Client UI Refactoring
- [x] ShopListingNPC.lua created with preview pricing
- [x] Reads from deterministic sources only (catalog + traits)
- [x] Zero network calls during pricing calculation
- [x] Supports future shop model extension

### 2.2 (In Progress) ModData Sync Removal
- [ ] SyncBuyPrices broadcasts removed from server
- [ ] Reactive invalidation removed from client
- [ ] Zero broadcasts during shop listing
- [ ] 1 packet per transaction (verified)

### 2.3 (Todo) Price Mismatch Handler
- [ ] Validation function created
- [ ] Tolerance checking implemented
- [ ] Mismatch logged silently
- [ ] UI updates without rebuild

---

## Next Steps

1. **Complete 2.2**: Remove server-side broadcasts (SyncBuyPrices)
2. **Complete 2.3**: Add mismatch handler to transaction results
3. **Integration Test**: Load shop, browse items, make purchase
4. **Network Baseline**: Measure traffic reduction (target 99%+)
5. **Move to Phase 3**: Server-side transaction validation

