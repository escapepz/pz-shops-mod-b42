# Phase 2.3 Testing Plan & Execution

**Date**: 2025-01-05  
**Status**: Ready for Testing  
**Implementation**: COMPLETE  

## Core Implementation Summary

✅ **Completed**:
- `ShopUI.validateTransactionPrice()` - Static validation function with tolerance checking
- `ModDataDispatcherClient` enhanced - Transaction validation on balance updates
- `TransactionValidationClient` - Records and clears transactions
- `ShopTabUI.addToCart()` - Stores preview prices when items added
- `ShopUI.buyCartBtn()` - Records transaction before sending to server

✅ **Maintained Invariants**:
- Zero broadcasts on price mismatch (Phase 2.2 preserved)
- No UI rebuild triggered
- Server prices remain authoritative
- Transaction atomicity maintained

---

## Test Scenarios

### Test 1: Exact Match (No Modifiers)
**Goal**: Verify baseline case where client and server prices match

**Steps**:
1. Open NPC shop (e.g., gun store)
2. Add item to cart (e.g., Base.Apple at 15 coins)
3. Verify preview price displayed correctly
4. Click Buy button
5. Monitor logs for: `[TransactionValidationClient:recordTransaction]`
6. Transaction completes
7. Monitor logs for: `[TransactionValidationClient:validateTransaction]`

**Expected Result**:
- ✅ Transaction recorded with preview price
- ✅ No mismatch logged
- ✅ Balance updated correctly
- ✅ UI shows success
- ✅ Cart cleared

**Log Output Expected**:
```
[ShopUI:buyCartBtn] Recorded transaction for validation - txnId=...
[TransactionValidationClient:recordTransaction] txnId=... itemCount=1 totalPreview=15
[TransactionValidationClient:validateTransaction] Transaction validated successfully - txnId=... delta=15
```

---

### Test 2: Expected Mismatch (Within Tolerance)
**Goal**: Verify system handles small price variations

**Setup**:
- Use admin tool to set buy multiplier on apple to 1.05 (5% markup)

**Steps**:
1. Open NPC shop
2. Add apple to cart (preview shows ~16 coins if base is 15)
3. Server may apply different modifiers
4. Server returns final price: 15 or 17 (within ±1 tolerance)
5. Purchase completes

**Expected Result**:
- ✅ If diff ≤ 1: No mismatch logged
- ✅ If diff = 0: Silent success
- ✅ Transaction completes
- ✅ Balance updated with server price

---

### Test 3: Exceeded Tolerance (Mismatch Detected)
**Goal**: Verify system logs mismatches exceeding tolerance

**Setup**:
- Create price hook that significantly modifies price (e.g., 5x multiplier)

**Steps**:
1. Add item to cart (preview: 15 coins)
2. Hook applies different modifier chain
3. Server returns final price: 25 coins (diff = 10, exceeds tolerance of 1)
4. Purchase completes

**Expected Result**:
- ✅ Mismatch logged with details:
  ```
  [ShopUI:validateTransactionPrice] Price mismatch: Base.Apple
  client=15 server=25 diff=10
  ```
- ✅ No error thrown
- ✅ Transaction succeeds with server price
- ✅ UI updates to show final price

---

### Test 4: Network Traffic Verification
**Goal**: Confirm zero broadcasts triggered

**Steps**:
1. Open shop browser console or use network monitor
2. Add items to cart
3. Make purchase
4. Monitor server logs for broadcast mentions

**Expected Result**:
- ✅ Only ModData.transmit("CoinBalance") sent (server → client)
- ✅ Zero `broadcastBuyPrices` calls in logs
- ✅ Zero `broadcastSellRules` calls in logs
- ✅ Server log shows: `[ShopCommandDispatcher:SyncBuyPrices] IGNORED`

---

### Test 5: Price Change While Shopping
**Goal**: Verify cart persistence when prices update server-side

**Steps**:
1. Add item to cart (price A)
2. Admin changes item price (price B, significant difference)
3. Cart should still show original price
4. Complete purchase
5. Check final transaction price

**Expected Result**:
- ✅ Preview price stored: A
- ✅ Server returns final: B
- ✅ Mismatch logged if |A - B| > 1
- ✅ Transaction uses server price (B)

---

### Test 6: Cart Clearing After Price Change
**Goal**: Verify UI clears cart when prices change

**Steps**:
1. Add items to cart (preview prices stored)
2. Admin triggers price hook change (significant)
3. Observe UI response
4. Verify cart state

**Expected Result**:
- ✅ `ShopUI:clearCartOnPriceChange()` called
- ✅ Cart cleared on screen
- ✅ Player must re-add items
- ✅ New preview prices reflect current server state

---

## Manual Testing Checklist

### Pre-Test
- [ ] Build project: `npm run build`
- [ ] No compile errors
- [ ] Game starts without errors
- [ ] Server logs accessible

### During Testing
- [ ] Monitor server logs: `Logs/Server/*_Shops.txt`
- [ ] Monitor client logs: `Logs/Client/*_Shops.txt`
- [ ] Use admin tool to modify prices if available
- [ ] Record any unexpected behavior

### Post-Test
- [ ] Compile results
- [ ] Document mismatches found
- [ ] Verify zero broadcasts
- [ ] Update PHASE_2_3_TEST_RESULTS.md

---

## Success Criteria

All must pass:

✅ **Functionality**:
- Price validation function works correctly
- Mismatches logged silently
- Tolerance checking accurate (±1 coin)
- Transactions complete successfully

✅ **Network**:
- Zero broadcasts triggered
- Only ModData sync sent
- Consistent with Phase 2.2 (99.5% reduction)

✅ **UI**:
- Cart displays preview prices correctly
- Transaction success/error shown appropriately
- No unexpected resyncs

✅ **Logging**:
- TransactionValidationClient logs appear
- Mismatch details captured
- Server authoritative prices logged

---

## Known Issues / Gotchas

⚠️ **Phase 2.3 Status**:
- ModDataDispatcher validation hook may need timing adjustment
- TransactionValidationClient.clearTransaction() must be called after validation
- Lazy-loading of TransactionValidationClient must avoid circular deps

⚠️ **Testing Blockers**:
- Admin price modification tool may not be available (use console if needed)
- Large price multipliers may be constrained by game rules
- Test environment must be multiplayer to trigger proper sync

---

## Next Phase

After Phase 2.3 testing passes:
- **Phase 3**: Server-side transaction settlement
- **Phase 4**: Integration with ShopUI for all shop types
- **Phase 5**: Full system testing and optimization

---

## Timeline

- Core Implementation: ✅ 2025-01-05 (COMPLETE)
- Testing: 📅 Starting now
- Expected Completion: Within 24 hours
- Documentation: Upon test completion
