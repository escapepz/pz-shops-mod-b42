# Test Simulation: Price Hook Fixes

## Test Sequence

### Initial State
- Apple base price: 15
- Baseball Bat base sell price: 50
- All modifiers disabled

### Command 1: testapple(2.0)
**Expected Behavior:**
- Apple buy price multiplier set to 2.0
- Server broadcasts buy price delta: Apple 15 → 30
- Client receives SyncBuyPrices with buyPrices["Base.Apple"] = 30
- UI invalidation triggered: `invalidateUI(BUY_PRICE_DELTA)`
- **FIX 1 Effect**: Active tab rebuilt immediately
- **FIX 2 Effect**: When tab rebuilds:
  - basePrice = Shop.Items["Base.Apple"].price = 15 ✓ (original registration price)
  - price = Shop.CalculatedPrices.buyPrices["Base.Apple"] = 30 ✓ (server authoritative with multiplier)
- **UI Display**: 
  - Final price: 30 (white, price increase is bad for player)
  - Base price: 15 (grayed out below)
  - No percentage (increases don't show %)

### Command 2: testBatSell(0.5)
**Expected Behavior:**
- Baseball Bat sell price multiplier set to 0.5
- Server broadcasts sell rule delta
- Client receives SyncSellRules
- UI invalidation triggered: `invalidateUI(SELL_RULE_CHANGE)`
- Active tab rebuilt if it's Sell tab, or cache invalidated for lazy rebuild

### Command 3: testAppleOverrideBuy(10)
**Expected Behavior:**
- Apple buy price overridden to 10 (replaces 2.0 multiplier)
- Server broadcasts buy price delta: Apple 30 → 10
- Client receives SyncBuyPrices with buyPrices["Base.Apple"] = 10
- UI invalidation triggered: `invalidateUI(BUY_PRICE_DELTA)`
- **FIX 1 Effect**: Active tab rebuilt immediately
- **FIX 2 Effect**: When tab rebuilds:
  - basePrice = Shop.Items["Base.Apple"].price = 15 ✓ (original registration price)
  - price = Shop.CalculatedPrices.buyPrices["Base.Apple"] = 10 ✓ (server override)
- **UI Display**: 
  - Final price: 10 (green, discounted)
  - Base price: 15 (grayed out below)
  - Percentage: -33%

### Command 4: testappleReset()
**Expected Behavior:**
- All test hooks disabled
- Apple buy price reverts to 15 (no modifiers, no override)
- Baseball Bat sell price reverts to 50
- Server broadcasts buy price delta: Apple 10 → 15
- Server broadcasts sell rule delta (revert sell rules)
- Client receives both SyncBuyPrices and SyncSellRules
- UI invalidation triggered twice (once for buy, once for sell)
- **FIX 1 Effect**: Active tab rebuilt immediately after each invalidation
- **FIX 2 Effect**: When tab rebuilds:
  - basePrice = Shop.Items["Base.Apple"].price = 15 ✓ (original registration price)
  - price = Shop.CalculatedPrices.buyPrices["Base.Apple"] = 15 ✓ (no modifiers)
- **UI Display**: 
  - Final price: 15 (white, no change)
  - No base price shown (basePrice == price)
  - No percentage shown

## Key Fixes Verified

### Fix 1: ShopSyncClient.lua invalidateUI() - BUY_PRICE_DELTA
- **Before**: Lazy recalculation only (rows self-heal on visibility, active tab not rebuilt)
- **After**: Active tab rebuilt immediately, all caches cleared
- **Result**: When price hooks change, UI updates instantly without needing to switch tabs

### Fix 2: ShopUI.lua onActivateView() - basePrice calculation
- **Before**: `basePrice = v.price` (uses potentially stale current price)
- **After**: `basePrice = Shop.Items[k].price` (uses original registration price)
- **Result**: basePrice always reflects the original price, not affected by previous overrides

### Fix 3: ShopUI.lua onActivateView() - server price priority
- **Before**: Always uses preview calculator (calcBuyPrice)
- **After**: Uses server-authoritative price first (Shop.CalculatedPrices.buyPrices[k])
- **Result**: Price hooks and overrides are immediately visible on tab rebuild

## Expected Log Output

```
[SERVER] [TestPriceHooks] Apple BUY price multiplier set to: 2.0
[CLIENT] [ShopSyncClient] Delta BUY price update (buyRev=0->1, sellRev=0)
[CLIENT] [ShopSyncClient] Invalidating due to BUY_PRICE_DELTA
[CLIENT] [ShopSyncClient] Rebuilt active tab due to buy price change

[SERVER] [TestPriceHooks] Baseball Bat SELL price multiplier set to: 0.5
[CLIENT] [ShopSyncClient] Delta SELL price update (buyRev=1, sellRev=0->1)
[CLIENT] [ShopSyncClient] Invalidating due to SELL_RULE_CHANGE
[CLIENT] [ShopSyncClient] Rebuilt Sell tab on rule change

[SERVER] [TestPriceHooks] Apple override BUY price set to: 10
[CLIENT] [ShopSyncClient] Delta BUY price update (buyRev=1->2, sellRev=1)
[CLIENT] [ShopSyncClient] Invalidating due to BUY_PRICE_DELTA
[CLIENT] [ShopSyncClient] Rebuilt active tab due to buy price change

[SERVER] [TestPriceHooks] Test hooks disabled (all modifiers and overrides reset)
[CLIENT] [ShopSyncClient] Delta BUY price update (buyRev=2->3, sellRev=1)
[CLIENT] [ShopSyncClient] Invalidating due to BUY_PRICE_DELTA
[CLIENT] [ShopSyncClient] Rebuilt active tab due to buy price change
[CLIENT] [ShopSyncClient] Delta SELL price update (buyRev=3, sellRev=1->2)
[CLIENT] [ShopSyncClient] Invalidating due to SELL_RULE_CHANGE
```
