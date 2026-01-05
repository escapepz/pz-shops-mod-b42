# Phase 6: Functional Testing Plan

## Overview
Phase 6 validates the complete refactored shop listing system through functional and compatibility testing. Tests verify:
1. Client-side listing works deterministically
2. Server-side settlement is authoritative
3. No network desync in multiplayer
4. Backward compatibility with existing saves

---

## Integration Point: Determinism Validation

**File**: `Shops/42.13.1/media/lua/shared/nshopsb42/ShopInit.lua`

DeterminismTest is now wired into Shop.FinalizeRegistry():
```lua
-- Phase 5: Run determinism validation (Phase 6 integration)
SharedLogger.log("Shops", "[ShopBuyInit] Phase 5: Running determinism validation...")
if DeterminismTest.runComplete() then
    SharedLogger.log("Shops", "[ShopBuyInit] ✓ Determinism validation PASSED")
else
    SharedLogger.log("Shops", "[ShopBuyInit] ✗ Determinism validation FAILED")
end
```

**Execution**: Runs automatically when mod initializes during game startup.

---

## Functional Tests (6 Scenarios)

### Test 1: NPC Shop Listing Without Server Connection
**Goal**: Verify client can load and display shop UI without network access

**Setup**:
1. Start client-only game (no server)
2. Navigate to NPC shop (general store)
3. Open shop UI

**Expected**:
- ✅ Shop listing displays items with preview prices
- ✅ No server connection error shown
- ✅ Preview prices calculated from deterministic contract
- ✅ UI loads in < 2 seconds

**Actual**: (To be filled during testing)

**Notes**: 
- Tests client-side determinism
- Validates NPCShopCatalog + PricingContract standalone

---

### Test 2: Buy Transaction with Price Mismatch (Server Authority)
**Goal**: Verify server price is final authority when client preview differs

**Setup**:
1. Start client + server (multiplayer)
2. Add modifier to pricing (server-side only)
3. Client previews price (no modifier)
4. Client purchases item

**Expected**:
- ✅ Client shows preview price (e.g., 100)
- ✅ Server calculates actual price (e.g., 120)
- ✅ Transaction succeeds at server price (120)
- ✅ Balance deducted correctly (server wins)
- ✅ UI updates silently (no error dialog)
- ✅ Zero broadcasts triggered

**Actual**: (To be filled during testing)

**Notes**:
- Tests Phase 2.3 mismatch handler
- Validates server authority
- Confirms no resync broadcasts

---

### Test 3: Insufficient Funds → Error (No Shop Rebuild)
**Goal**: Verify error handling doesn't trigger full UI rebuild

**Setup**:
1. Client has 50 coins
2. Item costs 100 coins
3. Click buy

**Expected**:
- ✅ Transaction rejected (insufficient funds)
- ✅ Error message shown ("Insufficient funds")
- ✅ UI remains open, item list unchanged
- ✅ No shop catalog reload
- ✅ Can retry after obtaining more coins

**Actual**: (To be filled during testing)

**Notes**:
- Tests error resilience
- Validates UI stability
- Confirms no network traffic on error

---

### Test 4: Multiple Players Browsing Same Shop (No Cross-Talk)
**Goal**: Verify multiple clients can browse without interference

**Setup**:
1. Start server with 2 clients
2. Both clients open same NPC shop
3. Client A adds item to cart
4. Client B browses items
5. Client A purchases

**Expected**:
- ✅ Each client sees independent preview prices
- ✅ Client A's cart purchase doesn't affect Client B's view
- ✅ Server balance updates only for Client A
- ✅ Client B's UI unaffected
- ✅ No cross-client messages logged

**Actual**: (To be filled during testing)

**Notes**:
- Tests network isolation
- Validates targeted responses (not broadcasts)
- Confirms Phase 2.2 (zero broadcasts)

---

### Test 5: Lag Scenario - Late Price Response
**Goal**: Verify client handles delayed server response

**Setup**:
1. Simulate network lag (500ms+ latency)
2. Client purchases item at time T
3. Server response arrives at T + 800ms
4. Meanwhile, client may have clicked another action

**Expected**:
- ✅ Transaction eventually completes
- ✅ Client balance updates correctly
- ✅ UI doesn't show duplicate transaction
- ✅ Transaction ID prevents double-processing
- ✅ Late response is ignored if action already resolved

**Actual**: (To be filled during testing)

**Notes**:
- Tests network resilience
- Validates transaction ID tracking
- Confirms idempotency

---

### Test 6: Price Change While Shopping (Tolerance Handling)
**Goal**: Verify client tolerates price fluctuations (±1 coin)

**Setup**:
1. Client browsing shop
2. Preview price stored: 100 coins
3. Server recalculates on purchase: 101 coins
4. Client executes transaction

**Expected**:
- ✅ Transaction succeeds (101 within ±1 tolerance)
- ✅ Balance deducted for 101 (server price)
- ✅ No error dialog shown
- ✅ Mismatch logged silently in debug logs

**Actual**: (To be filled during testing)

**Notes**:
- Tests Phase 2.3 validation
- Confirms tolerance logic
- Validates silent logging

---

## Compatibility Tests

### Test 7: Vanilla NPC Shops
**Goal**: Ensure refactor doesn't break standard shops

**Setup**:
1. Load vanilla-only game (no mods except Shops B42)
2. Access general store (vanilla NPC)
3. Purchase items

**Expected**:
- ✅ Vanilla shops load prices correctly
- ✅ Transactions execute normally
- ✅ No errors in logs

**Actual**: (To be filled during testing)

---

### Test 8: Modded NPC Shops
**Goal**: Verify compatibility with other mods' NPC definitions

**Setup**:
1. Load with compatible mods (e.g., gun shops)
2. Access modded NPC shop
3. Purchase modded item

**Expected**:
- ✅ Modded shop items appear in catalog
- ✅ Pricing calculated correctly
- ✅ Transactions succeed
- ✅ No conflicts with mod hooks

**Actual**: (To be filled during testing)

---

### Test 9: Player Shops (Safe Path)
**Goal**: Verify player shop transactions still work (with server revalidation)

**Setup**:
1. Create player shop
2. Set custom prices via ModData
3. Another player purchases from shop

**Expected**:
- ✅ Server re-reads ModData at transaction time
- ✅ Player shop prices honored
- ✅ No caching issues
- ✅ Mods can adjust prices dynamically

**Actual**: (To be filled during testing)

**Notes**: 
- Player shops have slightly higher network traffic (revalidation)
- Acceptable tradeoff for flexibility

---

### Test 10: Save/Restore → No Desync on Server Restart
**Goal**: Verify saves migrate cleanly and prices remain consistent

**Setup**:
1. Play session 1: Purchase items, save
2. Restart server
3. Load save, verify state
4. Continue shopping

**Expected**:
- ✅ Old ModData price fields ignored
- ✅ New prices computed deterministically
- ✅ Player inventory correct
- ✅ No price divergence after restart
- ✅ No errors on load

**Actual**: (To be filled during testing)

**Notes**:
- Tests Phase 6.1 (ModData migration)
- Validates save/restore determinism

---

## Network Traffic Baseline (Optional)

### Before Refactor
- Measure per-player price sync packets
- Measure transaction packets
- Baseline: ~800+ packets per session (WIP\_ before refactor)

### After Refactor
- Measure same scenario
- Expected: ~4 packets per session (transaction-only)
- **Target**: 70%+ reduction

**Measurement Method**:
```lua
-- Log packet count in transaction handlers
SHOPSB42.ShopUI.buyCartBtn = function(...)
    local packetsBefore = getNetworkStats()
    -- ... execute transaction ...
    local packetsAfter = getNetworkStats()
    SharedLogger.log("Shops", "Transaction: " .. (packetsAfter - packetsBefore) .. " packets")
end
```

---

## Test Execution Order

1. **Determinism Validation** (automatic on startup)
   - Verify logs show PASSED
   
2. **Functional Tests 1-6** (manual in game)
   - Execute each scenario
   - Verify expected results
   - Record actual results
   
3. **Compatibility Tests 7-10** (manual in game)
   - Test with various mod configurations
   - Verify no regressions
   
4. **Network Traffic Baseline** (optional)
   - Compare before/after
   - Document metrics

---

## Success Criteria

### Phase 6 Complete When:
- [x] Determinism validation wired into initialization
- [ ] All 6 functional tests pass
- [ ] All 4 compatibility tests pass
- [ ] Zero desync events logged
- [ ] Network traffic reduced 70%+ (optional)
- [ ] All test results documented in TEST_RESULTS.md

---

## Logging Locations

**Server Logs**:
```
Logs/Server/*_Shops.txt
- Look for "[ShopBuyInit] Phase 5: Running determinism validation..."
- Look for "[DeterminismTest] ✓ ALL DETERMINISM TESTS PASSED" or "✗ ... FAILED"
```

**Client Logs**:
```
Logs/Client/*_Shops.txt
- Look for price validation entries
- Look for mismatch warnings (if tolerance exceeded)
- Look for transaction status (success/error)
```

---

## Notes

- Tests validate behavior, not performance
- Determinism validation is automatic; functional tests are manual
- If any test fails, check logs for detailed error messages
- Phase 6 complete when all tests pass
- Document results for rollout (Phase 7)

