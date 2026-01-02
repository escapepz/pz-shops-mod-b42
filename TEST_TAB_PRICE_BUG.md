# Test: Tab Price Bug Fix

## Problem
When on the All tab and a price hook change occurs (showing correct discount %), switching to Food tab causes basePrice to equal price (no discount shown).

## Root Cause
The `onActivateView()` function in ShopUI.lua was overwriting `v.basePrice` with the current `v.price` value AFTER it had already been modified by price hooks. When switching tabs:

1. All tab loads items from Shop.Items
   - Sets `v.basePrice = v.price` (original price) ✓
   - Sets `v.price = dynamicPrice` ✓
   
2. Price hook updates arrive
   - Updates `v.price = newDynamicPrice` but leaves `v.basePrice` unchanged ✓
   
3. Switch to Food tab - cache was invalidated
   - Reloads items from Shop.Items 
   - Shop.Items entries still have old `v.price = oldDynamicPrice`
   - Sets `v.basePrice = v.price` (which is oldDynamicPrice, NOT original!) ❌
   - Now `v.basePrice == v.price` because both were modified

## Solution
Use the ORIGINAL shop item price (which may be stored in an existing basePrice) instead of the potentially-modified v.price:

```lua
-- Line 656-661 in ShopUI.lua
local originalPrice = v.basePrice or v.price
v.basePrice = originalPrice
local calculatedPrice = calcBuyPrice(k, character, originalPrice)
local dynamicPrice = calculatedPrice or Shop.resolvePlayerBuyPrice(character, k, context)
v.price = dynamicPrice or originalPrice
```

This ensures:
- First load: `originalPrice = v.price` (original), sets `basePrice = original` ✓
- Tab reload after invalidation: `originalPrice = v.basePrice` (preserved), uses correct original ✓

## Test Steps
1. Open shop, click All tab
2. Observe prices are loaded
3. Trigger price hook change (e.g., use admin tool to modify a hook)
4. Verify All tab shows correct discount percentage
5. **Click Food tab**
6. **Verify Food items show correct discount (basePrice ≠ price)**
   - Before fix: basePrice = price (0% discount)
   - After fix: basePrice > price (shows discount %)

## Files Modified
- Shops/42.13.1/media/lua/client/nshopsb42/ui/ShopUI.lua (line 656-661)
