# Phase 3b: Client-Side Listing Activation & Testing

**Date Started**: 2025-01-06  
**Status**: 🔄 IN PROGRESS  
**Dependency**: Phase 3a ✅ Complete

---

## Overview

Phase 3b activates the hybrid client-listing model from Phase 3a by:
1. Integrating Phase 3 preview pricing into ShopUI
2. Running functional tests to verify determinism
3. Validating network traffic reduction (99.5%)
4. Preparing rollout to Phase 4 (NPC vs Player distinction)

---

## Tasks

### 3b.1: Activate Phase 3 Preview Pricing in ShopUI

**Objective**: Replace legacy `calcBuyPrice()` with `ClientShopListingService` calls in ShopUI

**Location**: `Shops/42.13.1/media/lua/client/nshopsb42/ui/ShopUI.lua`

**Changes Required**:

1. **Update `calcBuyPrice()` method**:
   ```lua
   function ShopUI:calcBuyPrice(itemId, shopId, basePrice, player)
       if ClientShopListingService then
           return ClientShopListingService.calculatePreviewBuyPrice(
               itemId, shopId, basePrice, player
           )
       else
           -- Fallback to legacy (should not happen)
           return basePrice
       end
   end
   ```

2. **Update `calcSellPrice()` method**:
   ```lua
   function ShopUI:calcSellPrice(itemId, shopId, basePrice, condition, player)
       if ClientShopListingService then
           return ClientShopListingService.calculatePreviewSellPrice(
               itemId, shopId, basePrice, condition, player
           )
       else
           -- Fallback to legacy
           return basePrice
       end
   end
   ```

3. **Add debug logging** (for Phase 3b testing):
   ```lua
   function ShopUI:_logPriceCalculation(itemId, basePrice, finalPrice, source)
       if DEBUG_PRICING then
           print("[ShopUI:calcBuyPrice] itemId=" .. itemId 
               .. " base=" .. basePrice 
               .. " final=" .. finalPrice 
               .. " source=" .. source)
       end
   end
   ```

4. **Verify initialization order**:
   - ClientShopListingService must be loaded BEFORE ShopUI
   - Check `AClientInit.lua` for correct require order
   - Add assertion if ClientShopListingService is nil

---

### 3b.2: Determinism Verification Test

**Objective**: Prove preview prices match server recomputed prices

**Test Script** (manual testing in-game):

1. **Single Item Purchase**:
   - [ ] Note preview price shown in UI (e.g., Apple: 15 coins)
   - [ ] Purchase item
   - [ ] Check logs for:
     ```
     [ClientShopListingService] calculatePreviewBuyPrice: itemId=Base.Apple, finalPrice=15
     [ShopBuyAction] Final buy price computed: 15
     ```
   - [ ] Verify logs show identical price
   - [ ] Balance deducted correctly

2. **Multiple Items (Cart)**:
   - [ ] Add 3 different items to cart
   - [ ] Note all preview prices
   - [ ] Checkout
   - [ ] Monitor logs for each item's server-recomputed price
   - [ ] Verify all match preview exactly (0 tolerance)

3. **Sell Transaction**:
   - [ ] Pick up item with condition 100%
   - [ ] Open shop, go to sell tab
   - [ ] Note sell preview price
   - [ ] Sell item
   - [ ] Verify server price matches exactly

---

### 3b.3: Network Traffic Baseline Test

**Objective**: Measure and document 99.5% reduction vs Phase 2.2

**Test Plan**:

1. **Setup**:
   - [ ] Run server with WIP\_ architecture (Phase 2.2)
   - [ ] 4 simultaneous players
   - [ ] Admin tool to change prices mid-game

2. **Baseline Measurement** (before Phase 3b activation):
   - [ ] Open shop with all 4 players
   - [ ] Count `SyncBuyPrices` packets in logs: _____ (should be ~400)
   - [ ] Change price (admin)
   - [ ] Count broadcasts: _____ (should be ~400)
   - [ ] Each player buys 1 item
   - [ ] Count transaction packets: _____ (should be 4)
   - **Total Before**: _____ packets

3. **Phase 3b Measurement** (after activation):
   - [ ] Activate Phase 3b code
   - [ ] Repeat same test
   - [ ] Open shop with all 4 players
   - [ ] Count `SyncBuyPrices` in logs: _____ (should be 0)
   - [ ] Change price (admin)
   - [ ] Count broadcasts: _____ (should be 0)
   - [ ] Each player buys 1 item
   - [ ] Count transaction packets: _____ (should be 4)
   - **Total After**: _____ packets

4. **Calculate Reduction**:
   - Reduction % = ((Before - After) / Before) × 100
   - Target: ≥ 99% reduction

5. **Document Results**:
   - Update CHANGES_CURRENT.md with metrics
   - Include timestamp and test conditions

---

### 3b.4: Error Handling & Edge Cases

**Objective**: Verify Phase 3b handles all error scenarios gracefully

| Test Case | Expected Behavior | Verification |
|-----------|-------------------|--------------|
| Insufficient balance at purchase time | Transaction denied, error shown | [ ] |
| Inventory full | Transaction denied, error shown | [ ] |
| Item condition changed (sell) | Server uses new condition, recalculates | [ ] |
| Price hook adds modifier | Server applies modifier, client tolerates mismatch | [ ] |
| Late-join player opens shop | UI shows correct prices immediately (no wait) | [ ] |
| Admin changes price mid-transaction | Server uses new price, client tolerates mismatch | [ ] |
| Multiple players same shop | No cross-talk, individual balance updates | [ ] |

---

### 3b.5: Mismatch Tolerance Validation

**Objective**: Verify Phase 2.3 mismatch handler works correctly

**Test Cases**:

1. **Exact Match** (tolerance = 0):
   - [ ] Preview: 15 coins, Server: 15 coins
   - [ ] Expected: No log entry
   - [ ] Verify: Transaction succeeds

2. **Within Tolerance** (±1 coin):
   - [ ] Preview: 15 coins, Server: 16 coins (diff = 1)
   - [ ] Expected: Silently tolerated
   - [ ] Verify: Transaction succeeds, no user-facing error

3. **Exceeded Tolerance** (>1 coin):
   - [ ] Preview: 15 coins, Server: 20 coins (diff = 5)
   - [ ] Expected: Logged but not blocking
   - [ ] Verify: Log shows: `[ShopUI:validateTransactionPrice] MISMATCH: itemId=Base.Apple, clientPrice=15, serverPrice=20, diff=5`
   - [ ] Verify: Transaction succeeds using server price

---

### 3b.6: UI Responsiveness Test

**Objective**: Verify client-side UI is instant (no network wait)

**Test Cases**:

1. **Shop Open Speed**:
   - [ ] Time from UI open to "items loaded" (no network lag)
   - [ ] Should be <100ms (local catalog + calculation)
   - [ ] Log should show: `[ClientShopListingService] Catalog loaded in Xms`

2. **Item Browsing**:
   - [ ] Scroll through items, verify smooth performance
   - [ ] No network stall when switching categories
   - [ ] All prices calculated instantly locally

3. **Cart Addition**:
   - [ ] Add items to cart, no lag
   - [ ] Preview prices shown immediately
   - [ ] No broadcast triggered

---

### 3b.7: Logging & Instrumentation

**Objective**: Add debug output to verify Phase 3b behavior

**Log Points to Add**:

| Location | Log Message | Condition |
|----------|-------------|-----------|
| ClientShopListingService.initialize() | `[ClientShopListingService] Initialized catalog with X shops` | Always |
| ClientShopListingService.calculatePreviewBuyPrice() | `[ClientShopListingService:calcBuyPrice] itemId=..., finalPrice=...` | DEBUG_PRICING=true |
| ShopUI.calcBuyPrice() | `[ShopUI:calcBuyPrice] Delegating to ClientShopListingService` | DEBUG_PRICING=true |
| ShopBuyAction.complete() | `[ShopBuyAction] Server price: X (from PricingContract)` | Always |
| TransactionValidationClient.validatePrice() | `[TransactionValidationClient] Validated: diff=X (within tolerance)` | DEBUG_PRICING=true |

**Enable Debug Mode**:
```lua
-- In ShopUI.lua or AClientInit.lua
DEBUG_PRICING = true  -- Set during Phase 3b testing
```

---

## Implementation Order

1. **3b.1**: Activate Phase 3 in ShopUI
2. **3b.7**: Add logging instrumentation
3. Build project: `npm run build`
4. **3b.2**: Run determinism test (manual)
5. **3b.3**: Run network traffic baseline
6. **3b.4**: Run error handling tests
7. **3b.5**: Validate mismatch tolerance
8. **3b.6**: Test UI responsiveness

---

## Success Criteria

| Criterion | Target | Status |
|-----------|--------|--------|
| Phase 3 code activated in ShopUI | All `calcBuyPrice` calls delegated | [ ] |
| Determinism verified | Preview = Server price (diff ≤ 0) | [ ] |
| Network reduction measured | ≥99% packet reduction | [ ] |
| Error handling robust | All edge cases pass | [ ] |
| Mismatch tolerance working | ±1 coin tolerance verified | [ ] |
| UI responsive | <100ms to show prices | [ ] |
| Logging complete | All debug points output | [ ] |
| No regressions | Phase 2.3 tests still pass | [ ] |

---

## Files to Modify

### Primary
- `Shops/42.13.1/media/lua/client/nshopsb42/ui/ShopUI.lua` — Activate Phase 3 pricing

### Secondary (for instrumentation)
- `Shops/42.13.1/media/lua/client/nshopsb42/ui/ClientShopListingService.lua` — Add debug logging
- `Shops/42.13.1/media/lua/shared/nshopsb42/timers/ShopBuyAction.lua` — Add server price logging

### Documentation
- `CHANGES_CURRENT.md` — Update with Phase 3b completion
- `prompt/SHOP_LISTING/PHASE_3B_COMPLETION.md` — Sign-off (after testing)

---

## Rollback Plan

If Phase 3b causes issues:

1. Revert `ShopUI.lua` changes (revert `calcBuyPrice()` and `calcSellPrice()`)
2. System falls back to legacy behavior
3. All Phase 2.3 functionality preserved
4. No breaking changes

---

## Known Risks

| Risk | Mitigation | Status |
|------|-----------|--------|
| ClientShopListingService not initialized | Add assertion in ShopUI.calcBuyPrice() | [ ] |
| Circular dependency with ShopUI | Load order verified in AClientInit.lua | [ ] |
| Price modifier hooks interfere | Expect tolerance mechanism to handle | [ ] |
| Logging spams in non-debug mode | Wrap all logs in `if DEBUG_PRICING` | [ ] |

---

## Next Phase (Phase 4)

Once Phase 3b testing is complete:
- Phase 4: NPC vs Player Shops Distinction
- Depends on Phase 3b validation metrics
- Can proceed immediately after success criteria met

---

## Notes

- **Do not merge to main until Phase 3b testing passes**
- **Keep all debug logging in place (can be disabled via flag)**
- **Document any price divergence found during testing**
- **Prepare rollback procedure before testing begins**

