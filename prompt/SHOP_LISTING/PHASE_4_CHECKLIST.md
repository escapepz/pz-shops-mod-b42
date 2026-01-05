# Phase 4: NPC vs Player Shops Distinction — Checklist

**Status**: 🔄 IN PROGRESS  
**Date Started**: 2025-01-06

---

## Phase 4a: Create PlayerShopListingService

### Task 4a.1: Create New Module File

- [ ] Create: `Shops/42.13.1/media/lua/client/nshopsb42/ui/PlayerShopListingService.lua`
- [ ] Add module header + documentation
- [ ] Implement SHOPSB42.PlayerShopListingService = {}

### Task 4a.2: Implement initialize()

- [ ] Log initialization: `[PlayerShopListingService] Initialized`
- [ ] No shop data needed (called on demand)
- [ ] Handle errors gracefully

### Task 4a.3: Implement calculatePreviewBuyPrice()

- [ ] Accept: `itemId, playerId, basePrice, player`
- [ ] Read player shop ModData for item
- [ ] Use PricingContract for deterministic pricing
- [ ] Return: preview price
- [ ] Add logging for debug: `[PlayerShopListingService:calcBuyPrice] itemId=..., price=...`

### Task 4a.4: Implement calculatePreviewSellPrice()

- [ ] Accept: `itemId, playerId, basePrice, itemCondition, player`
- [ ] Use PricingContract for deterministic pricing
- [ ] Return: preview price
- [ ] Add logging for debug

### Task 4a.5: Error Handling

- [ ] Handle nil playerId
- [ ] Handle missing ModData (fallback to basePrice)
- [ ] Handle missing item (fallback to basePrice)
- [ ] Log errors (not user-facing)

---

## Phase 4b: Update PlayerShopUI

### Task 4b.1: Import PlayerShopListingService

- [ ] Add import at top of PlayerShopUI.lua
- [ ] Verify service available before use

### Task 4b.2: Update calcBuyPrice() method

- [ ] Find existing `calcBuyPrice()` function in PlayerShopUI.lua
- [ ] Add server-authoritative check first (hooks)
- [ ] Call `PlayerShopListingService.calculatePreviewBuyPrice()`
- [ ] Fallback to basePrice
- [ ] Add logging: `[PlayerShopUI:calcBuyPrice] Using PlayerShopListingService`

### Task 4b.3: Update calcSellPrice() method

- [ ] Find existing `calcSellPrice()` function in PlayerShopUI.lua
- [ ] Add server-authoritative check first (hooks)
- [ ] Call `PlayerShopListingService.calculatePreviewSellPrice()`
- [ ] Fallback to basePrice
- [ ] Add logging

---

## Phase 4c: Update Client Initialization

### Task 4c.1: Load PlayerShopListingService

- [ ] In AClientInit.lua, add after line 18:
  - `require("nshopsb42/ui/PlayerShopListingService")`

### Task 4c.2: Initialize PlayerShopListingService

- [ ] In `onGameStart()`, add after line 90:
  - Check if service exists
  - Call `.initialize()`
  - Log: `[Client Init onGameStart] PlayerShopListingService initialized`

---

## Phase 4d: Integration Testing

### Test 4d.1: NPC Shop Path (Regression Test)

- [ ] Open NPC shop
- [ ] Verify logs show `ClientShopListingService` used
- [ ] Verify zero broadcasts
- [ ] Buy item, verify determinism

### Test 4d.2: Player Shop Path

- [ ] Open player shop
- [ ] Verify logs show `PlayerShopListingService` used
- [ ] Verify zero broadcasts
- [ ] Buy item, verify determinism
- [ ] **Verify server re-reads ModData** (critical)

### Test 4d.3: Build & Compile

- [ ] Run `npm run build`
- [ ] No errors
- [ ] All modules load correctly

---

## Phase 4e: Documentation

### Task 4e.1: Create Phase 4 Completion Document

- [ ] Create: `PHASE_4_COMPLETION.md`
- [ ] Document all changes
- [ ] List test results
- [ ] Include log evidence

### Task 4e.2: Update CHANGES_CURRENT.md

- [ ] Add Phase 4 summary
- [ ] List files modified/created
- [ ] Note: "NPC and Player shops now have separate optimized paths"

### Task 4e.3: Update Architecture Diagram (if applicable)

- [ ] Add PlayerShopListingService to diagram
- [ ] Show routing decision
- [ ] Note server re-read step

---

## Testing Results

### Build

- [ ] `npm run build` successful — **Status**: ___

### 4d.1: NPC Shop Path (Regression)

- [ ] Shop opens: ___
- [ ] ClientShopListingService logs appear: ___
- [ ] Determinism verified (preview = server): ___

### 4d.2: Player Shop Path

- [ ] Player shop opens: ___
- [ ] PlayerShopListingService logs appear: ___
- [ ] Server re-reads ModData on purchase: ___
- [ ] Determinism verified: ___

### 4d.3: Zero Broadcasts

- [ ] No broadcasts during NPC browse: ___
- [ ] No broadcasts during Player browse: ___
- [ ] Only transaction results sent: ___

---

## Success Metrics

| Metric | Target | Achieved |
|--------|--------|----------|
| NPC shops (Phase 3b) | ClientShopListingService used | ✅ |
| Player shops optimized | PlayerShopListingService used | [ ] |
| Server authority maintained | Server re-reads ModData | ✅ |
| Zero broadcasts | Phase 2.2 still active | ✅ |
| Logging complete | Both paths instrumented | [ ] |
| No regressions | NPC path still works | [ ] |

---

## Sign-Off

**Completed by**: _________  
**Date**: _________  
**Status**: ✅ / ❌ / 🔄

**Notes**:
_______________________________________________________________________________

---

## Rollback Instructions (if needed)

1. Delete: `Shops/42.13.1/media/lua/client/nshopsb42/ui/PlayerShopListingService.lua`
2. Revert ShopUI.lua (remove routing logic)
3. Revert AClientInit.lua (remove PlayerShopListingService require/init)
4. Rebuild: `npm run build`
5. System falls back to Phase 3b (unified service)

---

## Next Phase

After Phase 4 completion: **Phase 5** (Determinism Validator)

