# Buy Price Live Update Issue - Trace Analysis

## Problem Statement
Buy price modifications are not updating live on the "All" tab when price hooks change.

## Root Cause

### Issue 1: Cache Not Properly Invalidated (PRIMARY)
**Location**: `ShopUI.lua:632-635`

```lua
if not self.reloadItems then
    if self.shopItemsCache[tabType] then
        shopItems.items = self.shopItemsCache[tabType]
        return  -- RETURNS CACHED ITEMS WITHOUT RECALCULATION
    end
end
```

**Flow**:
1. When price hooks change, `ShopSyncClient.onBuyPricesChanged()` is called
2. This calls `refreshUIForPriceChange()` which invalidates caches for NON-active tabs only
3. For the ACTIVE tab, it calls `rebuildActiveTab()` which sets `reloadItems = true` temporarily
4. **BUT**: If the "All" tab is NOT the active tab when prices change, its cache is invalidated
5. **THEN**: When user switches TO the "All" tab later, the cache IS gone (correctly invalidated)
6. **HOWEVER**: The issue is that the cache invalidation might not be working for "All" tab specifically

### Issue 2: Cache Invalidation Logic for "All" Tab
**Location**: `ShopSyncClient.lua:36-48`

```lua
-- Step 1: Invalidate caches for NON-active tabs
if ui.shopItemsCache then
    for tabType, _ in pairs(ui.shopItemsCache) do
        if tabType ~= activeTabType then
            ui.shopItemsCache[tabType] = nil
        end
    end
end
```

This correctly invalidates non-active tabs, but there's a timing issue:

1. User is on "Buy Weapons" tab when prices change
2. Cache for "All" tab is invalidated (line 41: `ui.shopItemsCache[tabType] = nil`)
3. "Buy Weapons" tab is rebuilt with updated prices
4. BUT user then switches to "All" tab

### Issue 3: Cached Items Are Objects, Not Re-evaluated
**Location**: `ShopUI.lua:633`

```lua
shopItems.items = self.shopItemsCache[tabType]
```

When restoring from cache:
- The cached `items` array contains row objects with **pre-calculated prices**
- These objects don't get re-evaluated against the new `Shop.CalculatedPrices.buyPrices`
- The prices in the row objects are stale

## How Buy Prices Flow

1. **Server Side** (ShopPriceBuy.lua):
   - Server calculates final buy prices with modifiers applied
   - Sends final prices via `SyncBuyPrices` command
   - Prices stored in `Shop.CalculatedPrices.buyPrices[itemId]`

2. **Client Side** (ShopUI.lua, lines 20-68):
   - `calcBuyPrice()` tries to use `Shop.CalculatedPrices.buyPrices` first
   - Falls back to `Shop.PriceModifiers` (which is empty for buy prices - server-only)
   - Falls back to base price

3. **Tab Loading** (ShopUI.lua, lines 638-676):
   - When "All" tab loads, it calls `calcBuyPrice(k, character, originalPrice)` for each item
   - This SHOULD get the calculated price from the server
   - **BUT** if items are cached, this code never runs

## Evidence from Logs

### Price Hook Changed (setSellMultiplier at 09:13:11):
```
[SERVER] [ShopFinalizeHandler] onPriceHooksChanged() called.
[SERVER] [ShopSyncClient] Received SyncBuyPrices from server.
[SERVER] [ShopSyncClient] Delta BUY price update (rev=7->7).
[SERVER] [ShopFinalizeHandler] BUY prices broadcast (rev=7).
```

### But calcSellPrice Shows Modifiers Count = 0:
```
[ShopUI:calcSellPrice] Base.Apple: basePrice=1, calculated=1, modifiers count=0.
```

This is NORMAL because:
- `Shop.PriceModifiers` is for BUY modifiers (hooks)
- `Shop.SellModifiers` and `Shop.SellOverrides` are for SELL rules
- Buy prices are server-only, sell prices are previewable

## Solution

Ensure that when `refreshUIForPriceChange()` rebuilds the active tab with `rebuildActiveTab()`, it:

1. ✅ Sets `reloadItems = true` (already done, line 1171)
2. ✅ Calls `onActivateView()` (already done, line 1174)
3. ✅ Clears the cache for that tab (needs verification)

The issue is likely in step 3: the cache invalidation might not be clearing the "All" tab's cache entry.

**Check**: In `ShopUI.lua:onActivateView()`, does it properly handle the `reloadItems = true` flag for the "All" tab?

Line 497-499:
```lua
if self.reloadItems then
    shopItems:clear()  -- This should clear the items
end
```

**BUT** line 633-634 might override this:
```lua
if self.reloadItems then
    shopItems.items = self.shopItemsCache[tabType]  -- RESTORES CACHE
```

No wait, if `reloadItems = true`, line 632's condition fails, so it won't use the cache.

## Hypothesis for Actual Issue

The problem might be **Tab.All not matching the cache key**:

1. When items are cached for "All" tab, what is the cache key?
2. Is it `Tab.All` string/constant?
3. Could there be a type mismatch between what's stored and what's being looked up?

Need to verify:
- What value is `Tab.All`?
- Is it consistent between cache storage (line 623, 674) and cache lookup (line 632)?
- Could there be multiple "All" tabs or different representations?
