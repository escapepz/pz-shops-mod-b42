# Example Shop Mod

A comprehensive example mod demonstrating all Shop hook system features, including item registration, dynamic pricing, VIP reputation system, and time-based sales.

## Overview

This mod registers 25 buyable items and 25 sellable items, then applies complex pricing logic through the Shop hook system to demonstrate:

- **Multiple item categories** (food, medical, tools, weapons, ammunition)
- **Dynamic pricing** via modification hooks (category, time, reputation, bulk)
- **Price overrides** for special items and conditions
- **Reputation/VIP system** with tiered discounts and bonuses
- **Server/client separation** for authority and UI
- **Whitelist sell mode** restricting what items can be sold

## Features

### 1. Item Registration

**Buy Items (25 total):**
- Food & Supplies: Apple, Banana, Orange, Bread, Pop, Water (6 items)
- Canned Goods: Apple, Bell Peppers, Carrot, Chili (4 items)
- First Aid: Bandage, Painkiller, Antibiotic, Disinfectant (4 items)
- Tools & Equipment: Flashlight, Rope, Hammer, Screwdriver (4 items)
- Weapons: Handgun, Pistol, Revolver, Assault Rifle, Hunting Rifle (5 items)
- Ammunition: 223 Rounds, 762mm Rounds, 9mm Rounds, Shotgun Shells (4 items)

**Sell Items (25 + 1 blacklisted):**
- Same 25 items at reduced base prices (30-50% of buy price)
- 1 blacklisted item (KeyRing) that cannot be sold
- Whitelist mode enabled: ONLY registered items can be sold

### 2. Buy Price System

**Category-based Markup:**
- Weapons: +30% markup
- Ammunition: +20% markup
- Medical items: +15% markup
- Food: -10% discount

**Time-based Pricing:**
- Morning (6 AM - 10 AM): -5% discount
- Evening (6 PM - 11 PM): +10% premium
- Night (11 PM - 6 AM): +15% premium

**VIP System (Reputation-based):**
- Bronze (100+ rep): -5% discount
- Silver (250+ rep): -10% discount
- Gold (500+ rep): -15% discount

**Bulk Discounts:**
- 5-9 items in inventory: -10% discount
- 10+ items in inventory: -15% discount

**Price Overrides:**
- Water: Fixed at 10 (overrides all modifiers)
- Pop: Fixed at 15
- Admin access can be implemented for free items

### 3. Sell Price System

**Condition-based Multipliers:**
- Excellent (75-100): 1.0x (full price)
- Good (50-74): 0.85x
- Fair (25-49): 0.5x
- Poor (0-24): 0.2x

**Bulk Seller Bonus:**
- 10-20 items: +5% bonus
- 20+ items: +10% bonus

**Reputation Bonus:**
- Bronze (100+ rep): +5% bonus
- Silver (250+ rep): +10% bonus
- Gold (500+ rep): +15% bonus

**Price Overrides:**
- Damaged weapons (condition < 30): Won't buy (return 0)
- Premium weapons (Assault Rifle, Hunting Rifle, Pistol): Fixed buyback prices

### 4. Reputation System

- Earn 1 reputation per item purchased
- Earn 2 reputation per item sold
- Unlock VIP tiers for better prices

## File Structure

```
ShopsHooksExample/
├── 42.13.1/
│   ├── mod.info                          # Mod metadata
│   ├── README.md                         # This file
│   ├── CONFIGURATION.md                  # Config reference guide
│   ├── IMPLEMENTATION_GUIDE.md           # Implementation patterns
│   └── media/
│       └── lua/
│           ├── shared/
│           │   └── ExampleShop.lua       # Main mod (32 functions)
│           ├── server/
│           │   └── ExampleShopServer.lua # Server logic (reputation, stats)
│           └── client/
│               └── ExampleShopClient.lua # Client UI helpers
└── common/
```

## Installation

1. Copy `ShopsHooksExample/` to your `Mods` directory
2. Enable "Shops" mod (required dependency)
3. Enable "ShopsHooksExample" mod
4. Load game

## Configuration

All settings in `ExampleShop.lua`:

```lua
ExampleShop.CONFIG = {
    enableVIPSystem = true,        -- VIP tiers and reputation
    enableTimedSales = true,       -- Time-based pricing variations
    enableBulkDiscounts = true,    -- Bulk purchase/sale bonuses
    debugLogging = true,           -- Console output for debugging
}
```

See `CONFIGURATION.md` for detailed customization options.

## Key Modules

### ExampleShop.lua (Shared)

**32 functions:**
- `registerBuyItems()` - Register 25 buyable items
- `registerSellItems()` - Register 25 sellable items (whitelist mode)
- `modifyBuyPriceByCategory()` - Apply category-based markups
- `modifyBuyPriceByTime()` - Apply time-of-day variations
- `modifyBuyPriceVIP()` - Apply reputation-based discounts
- `modifyBuyPriceByBulk()` - Apply bulk purchase discounts
- `overrideBuyPriceSpecialItems()` - Fixed prices for specific items
- `overrideBuyPriceAdmin()` - Free items for admins
- `modifySellPriceByCondition()` - Adjust by item condition
- `modifySellPriceByQuantity()` - Bulk seller bonus
- `modifySellPriceByReputation()` - Loyalty bonus
- `overrideSellPriceDamaged()` - Reject damaged weapons
- `overrideSellPricePremium()` - Fixed prices for premium weapons
- `registerHooks()` - Register all 11 hook callbacks
- `testPriceHooks()` - Verify pricing calculations

### ExampleShopServer.lua (Server-side)

**Reputation & Statistics:**
- `onPlayerBuyFromShop()` - Award 1 rep per item
- `onPlayerSellToShop()` - Award 2 rep per item
- `getVIPTierName()` - Get tier: Standard, Bronze, Silver, Gold
- `getPlayerShopStats()` - Return player reputation and tier info
- `getBuyDiscount()` - Calculate discount percentage
- `getSellBonus()` - Calculate sell bonus percentage
- Finalizes buy/sell registries on load

### ExampleShopClient.lua (Client-side)

**UI Display Helpers:**
- `getVIPTierDisplay()` - Get tier name with RGB color
- `formatPrice()` - Format price with currency symbol
- `getDiscountText()` - Display discount percentage
- `createItemTooltip()` - Generate item info tooltip
- `showVIPBenefits()` - Display player VIP status
- `getTimePeriod()` - Get current game time period name
- `getBuyItems()` - Get item list organized by category
- `getCategoryName()` - Get display name for category

## Hook Usage

### Item Registration Hook

```lua
ShopEvents.registerOnShopRegisterItems(function()
    Shop.RegisterItem("Base.Apple", { tab = Tab.Food, price = 12 })
    Shop.RegisterItem("Base.Banana", { tab = Tab.Food, price = 15 })
end)
```

### Buy Price Modification Hook (4 hooks registered)

```lua
ShopPriceEvents.registerOnShopModifyBuyPrice(function(player, itemId, base, context, modifiers)
    if string.find(itemId, "Weapon") then
        table.insert(modifiers, { multiplier = 1.3, label = "weaponMarkup" })
    end
end)
```

Modifiers are multiplied sequentially:
- Base: 100
- Weapon markup: 100 × 1.3 = 130
- Time-based: 130 × 0.95 (morning) = 123.5
- VIP Gold: 123.5 × 0.85 = 105

### Buy Price Override Hook (2 hooks registered)

```lua
ShopPriceEvents.registerOnShopOverrideBuyPrice(function(player, itemId, price, context)
    if itemId == "Base.Water" then
        return 10  -- Override with fixed price
    end
    return nil  -- Use calculated price
end)
```

### Sell Price Hooks (3 modification + 2 override)

```lua
ShopPriceEvents.registerOnShopModifySellPrice(function(player, item, base, context, modifiers)
    local condition = item:getCondition()
    if condition < 50 then
        table.insert(modifiers, { multiplier = 0.5, label = "conditionFair" })
    end
end)

ShopPriceEvents.registerOnShopOverrideSellPrice(function(player, item, price, context)
    if item:getCondition() < 30 and string.find(item:getID(), "Rifle") then
        return 0  -- Won't buy damaged weapon
    end
    return nil
end)
```

## Price Calculation Example

**Buying 10x Apples as Gold VIP at night:**

1. Base price: 12
2. Food discount: 12 × 0.9 = 10.8
3. Night premium: 10.8 × 1.15 = 12.42
4. VIP Gold: 12.42 × 0.85 = 10.557
5. Bulk discount (10+): 10.557 × 0.85 = 8.97
6. **Final: 8.97 (rounded)**

## Testing

To test price hooks, enable debug logging and check console output:

```lua
ExampleShop.CONFIG.debugLogging = true
-- Game will log all hook registrations and price calculations
```

Console output shows:
- Hook registration counts
- Each price modification applied
- Final calculated prices for test items

## Features Demonstrated

✓ Item registration with Shop.RegisterItem()
✓ Multiple modification hooks on single event
✓ Override hooks with short-circuit behavior
✓ Modifier table manipulation with labels
✓ Parameter access (player, item, context)
✓ Reputation system with player properties
✓ Time-based game mechanics
✓ Condition-based quality pricing
✓ Admin special handling (template)
✓ Server/client code separation
✓ Whitelist sell mode configuration
✓ Transaction logging and tracking

## Performance Notes

- All hooks registered once during initialization (one-time cost)
- Price hooks called per transaction (optimized for typical server load)
- Modification hooks always execute; override hooks short-circuit
- Bulk discount checks inventory (slight performance cost)
- Debug logging can be disabled for production

## Common Customizations

### Make weapons cheaper
Edit `modifyBuyPriceByCategory()` line 152:
```lua
table.insert(modifiers, { multiplier = 1.1, label = "weaponMarkup" })  -- 1.1 instead of 1.3
```

### Increase VIP discount
Edit `modifyBuyPriceVIP()` line 224:
```lua
table.insert(modifiers, { multiplier = 0.75, label = "vipGold" })  -- 0.75 = 25% off instead of 15%
```

### Change VIP reputation thresholds
Edit `modifyBuyPriceVIP()` lines 211-226:
```lua
if reputation >= 75 then  -- Changed from 100
```

See `CONFIGURATION.md` for more customization examples.

## Debugging

Enable debug logging to see:
- Hook registrations (how many registered)
- Hook execution (when called, with what parameters)
- Price modifications (each multiplier applied)
- Reputation changes
- Transaction logging

## Compatibility

- **Requires:** Shops (B42.13.1+)
- **Works with:** Any mod respecting Shop hooks
- **Conflicts:** None known

## Advanced Examples

### Conditional VIP Discount

```lua
ShopPriceEvents.registerOnShopOverrideBuyPrice(function(player, itemId, price, context)
    if player and ExampleShop.getPlayerReputation(player) >= 500 then
        return math.floor(price * 0.85)  -- 15% off for Gold VIP
    end
    return nil
end)
```

### Item Bundle Pricing

```lua
if context.quantity >= 10 then
    table.insert(modifiers, { multiplier = 0.8, label = "bundleDiscount" })
end
```

### Dynamic Weekend Pricing

```lua
-- Add to modifyBuyPriceByTime()
local gameTime = getGameTime()
if gameTime:getDaysSurvived() % 7 >= 5 then  -- Weekend
    table.insert(modifiers, { multiplier = 1.2, label = "weekendPremium" })
end
```

## License

Example mod for educational purposes. Modify and distribute freely.

## Next Steps

1. Read `CONFIGURATION.md` to customize settings
2. Read `IMPLEMENTATION_GUIDE.md` to understand patterns
3. Edit ExampleShop.lua to modify items and prices
4. Test using debug logging
5. Use as template for your own Shop mod
