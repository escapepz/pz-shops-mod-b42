# Base Price Separation Fix

## Problem
The price test hook was only applying once because the base price in `Shop.Items[itemId].price` was being overwritten with the calculated price. On the second hook execution, calculations used the modified price (30) instead of the original price (15), resulting in incorrect multiplication.

## Root Cause
Item definitions stored `.price` as the only price field. When prices were calculated and the item was used again, the `.price` field had been mutated, breaking subsequent calculations.

## Solution
Separate price storage into two fields:
- **`.basePrice`** - Original price (immutable, for calculations)
- **`.price`** - Current display price (can change based on hooks/modifiers)

## Files Modified

### 1. **ShopInit.lua**
- When finalizing items, set `basePrice = price` if not already set
- This preserves the original price for all future calculations

### 2. **ShopSellInit.lua**
- Same as above for sell items
- Set `basePrice = price` for all sell item definitions

### 3. **ShopPriceBuy.lua** 
- Changed: `local base = item.price`
- To: `local base = item.basePrice or item.price`
- Ensures calculations always use the original base price

### 4. **ShopPriceSell.lua**
- Changed: `local base = rule.price`
- To: `local base = rule.basePrice or rule.price`
- Same fix for sell price calculations

### 5. **ShopPriceCalculatorShared.lua**
- Updated buy price calculation to use `basePrice or price`
- Updated sell price calculation to use `basePrice or price`
- Ensures client-side price preview also uses correct base

### 6. **ShopTransactionValidationServer.lua**
- Updated fallback validation to use `basePrice or price`
- Ensures transaction validation uses correct base price

### 7. **ShopTabUI.lua** (Already Correct)
- Already uses `item.basePrice or item.price` for display
- `finalPrice = item.price` (calculated price)
- `basePrice = item.basePrice or item.price` (original price)
- Correctly shows discount based on difference

## How It Works Now

1. **Item Registration**: `Shop.RegisterItem("Base.Apple", {tab: "Food", price: 15})`
2. **Finalization**: Sets `basePrice = 15` automatically
3. **Price Calculation**: Always reads from `basePrice` (15)
4. **Hook Modifier**: Multiplies 15 by 2 = 30, stored in calculated prices
5. **Second Hook**: Still reads from `basePrice` (15), multiplies by 3 = 45 ✓
6. **Display**: Shows `finalPrice = 45`, `basePrice = 15`, discount applied

## Testing
Test with price hooks to verify:
- First hook: multiplier 2 should give price 30 (15 × 2)
- Second hook: multiplier 3 should give price 45 (15 × 3)
- Reset: Should revert to price 15 (original base)
