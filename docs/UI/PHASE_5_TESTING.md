# Phase 5: Split Broadcast Testing

## Overview
Verify that buy and sell broadcasts are now independent with separate revisions.

---

## Test Setup

### Prerequisites
1. Start Project Zomboid in single-player or multiplayer mode with Shops mod loaded
2. Open the game console or use Lua debug console
3. Have the Shop UI open (or ready to open during tests)

---

## Test 5.1: Buy Price Changes Only

### Command
```lua
SHOPSB42.TestPriceHooksCommand.testapple(2.0)
```

### Expected Behavior
- **Server logs**: `[ShopFinalizeHandler] BUY prices broadcast (rev=X)`
- **Server logs**: NO `SELL rules broadcast` message
- **Client logs**: `Received SyncBuyPrices from server` (not `SyncSellRules`)
- **Client logs**: `BuyPriceRevision` increments (e.g., 1 → 2)
- **Client logs**: `SellRuleRevision` UNCHANGED
- **UI**: Buy tab prices update (Base.Apple shows 2x price)
- **UI**: Sell tab prices UNCHANGED

### Verification Checklist
- [ ] `BuyPriceRevision` changed
- [ ] `SellRuleRevision` unchanged
- [ ] Only `SyncBuyPrices` broadcast sent
- [ ] Buy prices updated in UI
- [ ] Sell prices unchanged

---

## Test 5.2: Sell Rule Changes Only

### Command
```lua
SHOPSB42.TestPriceHooksCommand.testBatSell(2.0)
```

### Expected Behavior
- **Server logs**: `[ShopFinalizeHandler] SELL rules broadcast (rev=X)`
- **Server logs**: NO `BUY prices broadcast` message
- **Client logs**: `Received SyncSellRules from server` (not `SyncBuyPrices`)
- **Client logs**: `SellRuleRevision` increments (e.g., 1 → 2)
- **Client logs**: `BuyPriceRevision` UNCHANGED
- **UI**: Sell tab prices update (Base.BaseballBat shows 2x price)
- **UI**: Buy tab prices UNCHANGED

### Verification Checklist
- [ ] `SellRuleRevision` changed
- [ ] `BuyPriceRevision` unchanged
- [ ] Only `SyncSellRules` broadcast sent
- [ ] Sell prices updated in UI
- [ ] Buy prices unchanged

---

## Test 5.3: Independent Revisions

### Commands (in sequence)
```lua
-- Verify initial state
SHOPSB42.TestPriceHooksCommand.testapple(2.0)     -- BuyRev: 1, SellRev: 1
SHOPSB42.TestPriceHooksCommand.testapple(3.0)     -- BuyRev: 2, SellRev: 1
SHOPSB42.TestPriceHooksCommand.testBatSell(2.0)   -- BuyRev: 2, SellRev: 2
SHOPSB42.TestPriceHooksCommand.testBatSell(3.0)   -- BuyRev: 2, SellRev: 3
```

### Expected Log Pattern
```
[ShopFinalizeHandler] BUY prices broadcast (rev=1)
[ShopFinalizeHandler] BUY prices broadcast (rev=2)
[ShopFinalizeHandler] SELL rules broadcast (rev=2)
[ShopFinalizeHandler] SELL rules broadcast (rev=3)
```

### Verification Checklist
- [ ] Buy revision: 1, 2, 2, 2 (increments on buy changes only)
- [ ] Sell revision: 1, 1, 2, 3 (increments on sell changes only)
- [ ] Each broadcast contains ONLY its type (no mixed broadcasts)

---

## Test 5.4: Buy Override (Buy Path Only)

### Command
```lua
SHOPSB42.TestPriceHooksCommand.testAppleOverrideBuy(100)
```

### Expected Behavior
- **Server logs**: `[ShopFinalizeHandler] BUY prices broadcast (rev=X)`
- **Server logs**: NO `SELL rules broadcast` message
- **Client logs**: Only `SyncBuyPrices` received
- **UI**: Buy tab shows Base.Apple at fixed price 100
- **UI**: Sell prices unchanged

### Verification Checklist
- [ ] Buy path triggered (not sell)
- [ ] Only `SyncBuyPrices` sent
- [ ] Buy price override applied

---

## Test 5.5: Sell Override (Sell Path Only)

### Command
```lua
SHOPSB42.TestPriceHooksCommand.testBatOverrideSell(50)
```

### Expected Behavior
- **Server logs**: `[ShopFinalizeHandler] SELL rules broadcast (rev=X)`
- **Server logs**: NO `BUY prices broadcast` message
- **Client logs**: Only `SyncSellRules` received
- **UI**: Sell tab shows Base.BaseballBat at fixed price 50
- **UI**: Buy prices unchanged

### Verification Checklist
- [ ] Sell path triggered (not buy)
- [ ] Only `SyncSellRules` sent
- [ ] Sell price override applied

---

## Test 5.6: Reset (All Paths)

### Command
```lua
SHOPSB42.TestPriceHooksCommand.testappleReset()
```

### Expected Behavior
- **Server logs**: `[TestPriceHooks] Calling ShopFinalizeHandler.onPriceHooksChanged()`
- **Server logs**: Both `BUY prices broadcast` AND `SELL rules broadcast`
- **Client logs**: Both `SyncBuyPrices` and `SyncSellRules` received
- **UI**: All prices reset to normal

### Verification Checklist
- [ ] Both revisions increment
- [ ] Both broadcasts sent
- [ ] All prices reset to normal

---

## Test 5.7: Initial Player Sync (Simulate New Player Join)

### Setup
1. Keep current state with modified prices
2. Simulate new player connecting (check server logs for send order)

### Expected Behavior
- **Server logs**: 
  ```
  [ShopFinalizeHandler] Sending SyncShopData...
  [ShopFinalizeHandler] Sending SyncBuyPrices (revision: X)
  [ShopFinalizeHandler] Sending SyncSellRules (revision: Y)
  ```
- **Client logs** (in order):
  - `Received SyncShopData from server`
  - `Received SyncBuyPrices from server` (isInitialSync=true)
  - `Received SyncSellRules from server` (isInitialSync=true)

### Verification Checklist
- [ ] Both broadcasts sent on initial sync
- [ ] Both marked with `isInitialSync=true`
- [ ] Both revisions match current server state

---

## Success Criteria (All Tests Pass)

- [ ] Test 5.1 PASSED: Buy-only broadcasts work
- [ ] Test 5.2 PASSED: Sell-only broadcasts work
- [ ] Test 5.3 PASSED: Revisions increment independently
- [ ] Test 5.4 PASSED: Buy overrides trigger only buy broadcast
- [ ] Test 5.5 PASSED: Sell overrides trigger only sell broadcast
- [ ] Test 5.6 PASSED: Reset triggers both broadcasts
- [ ] Test 5.7 PASSED: Initial sync sends both broadcasts

---

## Debugging Tips

### Check Server Logs
```
Shops > [ShopFinalizeHandler] BUY prices broadcast (rev=X)
Shops > [ShopFinalizeHandler] SELL rules broadcast (rev=Y)
```

### Check Client Logs
```
Shops > [ShopSyncClient] Received SyncBuyPrices from server
Shops > [ShopSyncClient] Received SyncSellRules from server
```

### Check Revisions
- Look for `BUY price update (rev=X->Y)`
- Look for `SELL rules updated (rev=X->Y)`

### If Tests Fail
1. Verify `ShopFinalizeHandler.shouldInvalidateBuyPrices()` and `shouldInvalidateSellRules()` return correct values
2. Check that hooks are properly registered for buy vs. sell events
3. Verify `Shop.SellModifiers` and `Shop.SellOverrides` are being set on client
4. Check that `calcSellPrice()` is using split modifiers correctly

---

## Notes

- Each test command can be run multiple times in sequence
- Prices reset to normal with `testappleReset()`
- Monitor console logs throughout all tests
- UI refresh should be smooth (no lag)
- Verify no false invalidations between unrelated paths
