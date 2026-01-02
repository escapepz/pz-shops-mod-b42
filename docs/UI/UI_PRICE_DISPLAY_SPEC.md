# Shop UI Price Display Specification

## Overview
The shop UI should display prices intelligently based on whether the price differs from the base price.

## Display Logic

### If NO Price Change (finalPrice == basePrice)
```
[Coin Icon] [Price only]
Example: [💰] 50
```
- Show only the final price
- No base price shown
- No discount percentage
- Color: White (1, 1, 1)

### If Price Changed (finalPrice < basePrice - discount applied)
```
[Coin Icon] [Base Price] [New Price] [Discount %]
Example: [💰] 100 50 -50%
```
- Show base price (gray strikethrough: 0.5, 0.5, 0.5)
- Show new/final price (green: 0.2, 1, 0.2)
- Show discount percentage in compact format (green: 0.2, 1, 0.2)
- Spacing: base at X, final at X+35px, discount at X+65px

## Implementation Status

### ✅ ShopTabUI.lua (Buy/Sell Tabs)
**File:** `Shops/42.13.1/media/lua/client/nshopsb42/ui/ShopTabUI.lua`
**Lines:** 96-129 (`doDrawShopItem` function)

Current implementation:
```lua
local discount = basePrice - finalPrice

if discount > 0 then
    -- Show: base (gray) + final (green) + discount %
else
    -- Show: final only (white)
end
```

**Status:** ✅ Correct - When `discount > 0`, prices differ. When `discount <= 0`, no change.

### ✅ ShopUI.lua (Cart List)
**File:** `Shops/42.13.1/media/lua/client/nshopsb42/ui/ShopUI.lua`
**Lines:** 236-271 (`doDrawCartItem` function)

Current implementation:
```lua
local discount = basePrice - finalPrice

if discount > 0 then
    -- Show: base (gray) + final (green) + discount %
else
    -- Show: final only (white or dimmed)
end
```

**Status:** ✅ Correct - Same logic as ShopTabUI

## Price Fields Expected on Item

Each item should have:
- `item.price` - The final/calculated price
- `item.basePrice` - The base price (optional, defaults to `price` if missing)

The logic automatically handles:
- No modifiers applied: `basePrice == price` → show price only
- Modifiers applied: `basePrice > price` → show both with discount %

## Testing Checklist

- [ ] Item with no price modifiers: Shows price only
- [ ] Item with active discount modifier: Shows base + final + discount %
- [ ] Buy tab: Correctly displays prices
- [ ] Sell tab: Correctly displays prices
- [ ] Cart items: Correctly displays prices
- [ ] Discount percentage calculates correctly: `math.floor((discount / basePrice) * 100)`
- [ ] Colors are applied correctly (gray base, green final/discount)
- [ ] Spacing is correct: base at X, final at X+35, discount at X+65

## Notes

The implementation is already correct and follows the specification.
The display logic is tied to the `discount` variable calculation:
- When discount > 0: Price changed (show both)
- When discount ≤ 0: Price unchanged (show only final)
