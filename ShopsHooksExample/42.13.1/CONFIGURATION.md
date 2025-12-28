# Example Shop Mod - Configuration Guide

## Overview

The Example Shop mod is highly configurable. All settings are in `ExampleShop.lua` in the `CONFIG` table.

## Configuration Options

### Main Settings

Located at top of `ExampleShop.lua`:

```lua
ExampleShop.CONFIG = {
    enableVIPSystem = true,
    enableTimedSales = true,
    enableBulkDiscounts = true,
    debugLogging = false,
}
```

## Option Reference

### `enableVIPSystem` (boolean, default: `true`)

Controls reputation-based VIP tiers and discounts.

**When enabled:**
- Players earn reputation from purchases (+1 per item bought)
- Players earn reputation from sales (+2 per item sold)
- Discounts applied for VIP tiers:
  - Bronze (100+ rep): -5%
  - Silver (250+ rep): -10%
  - Gold (500+ rep): -15%
- Sell bonuses applied:
  - Bronze: +5%
  - Silver: +10%
  - Gold: +15%

**When disabled:**
- No reputation tracking
- No VIP tiers
- No VIP discounts or bonuses

**To disable:**
```lua
ExampleShop.CONFIG.enableVIPSystem = false
```

---

### `enableTimedSales` (boolean, default: `true`)

Controls time-of-day based price variations.

**When enabled:**
- Morning (6 AM - 10 AM): -5% discount on all items
- Day (10 AM - 6 PM): Standard prices
- Evening (6 PM - 11 PM): +10% premium on all items
- Night (11 PM - 6 AM): +15% premium on all items

**When disabled:**
- All items always at standard prices
- No time-based price variations

**To disable:**
```lua
ExampleShop.CONFIG.enableTimedSales = false
```

---

### `enableBulkDiscounts` (boolean, default: `true`)

Controls discounts for buying/selling items in bulk.

**When enabled (Buy):**
- 5-9 items in inventory: -10% discount
- 10+ items in inventory: -15% discount

**When enabled (Sell):**
- 10-20 items in inventory: +5% bonus
- 20+ items in inventory: +10% bonus

**When disabled:**
- No bulk discounts on purchases
- No bulk bonuses on sales

**To disable:**
```lua
ExampleShop.CONFIG.enableBulkDiscounts = false
```

---

### `debugLogging` (boolean, default: `false`)

Controls debug output to console.

**When enabled:**
- Prints all hook registrations
- Prints hook execution with parameters
- Prints price calculations
- Prints VIP tier changes
- Useful for troubleshooting

**When disabled:**
- Silent operation
- No console spam

**To enable:**
```lua
ExampleShop.CONFIG.debugLogging = true
```

---

## Advanced Configuration

### Modifying Item Prices

Edit `ExampleShop.registerBuyItems()`:

```lua
function ExampleShop.registerBuyItems()
    -- Change this
    ShopRegistry.addShopItem("Base.Apple", 12)
    -- To this (higher price)
    ShopRegistry.addShopItem("Base.Apple", 25)
end
```

And corresponding sell prices in `ExampleShop.registerSellItems()`:

```lua
function ExampleShop.registerSellItems()
    ShopSellRegistry.addSellItem("Base.Apple", 6)  -- Change from 6 to other value
end
```

### Modifying Price Multipliers

Edit price modification functions:

```lua
function ExampleShop.modifyBuyPriceByCategory(player, itemId, base, context, modifiers)
    -- Change weapon markup from 1.3 to 1.5 (50% markup)
    if string.find(itemId, "Pistol") or ... then
        modifiers.weaponMarkup = 1.5  -- Changed from 1.3
    end
end
```

### Modifying VIP Reputation Thresholds

Edit VIP tier checks:

```lua
function ExampleShop.modifyBuyPriceVIP(player, itemId, base, context, modifiers)
    local reputation = ExampleShop.getPlayerReputation(player)
    
    -- Change thresholds
    if reputation >= 200 and reputation < 500 then  -- Changed from 250
        modifiers.vipSilver = 0.9
    end
    
    if reputation >= 1000 then  -- Changed from 500
        modifiers.vipGold = 0.85
    end
end
```

### Adding New Item Categories

In `ExampleShop.registerBuyItems()`:

```lua
-- Add new category
ShopRegistry.addShopItem("Base.CustomItem1", 150)
ShopRegistry.addShopItem("Base.CustomItem2", 200)
```

Then add pricing logic in `ExampleShop.modifyBuyPriceByCategory()`:

```lua
-- Custom category markup
if string.find(itemId, "CustomItem") then
    modifiers.customMarkup = 1.25
end
```

### Modifying Time Period Prices

Edit `ExampleShop.modifyBuyPriceByTime()`:

```lua
-- Change morning discount from -5% to -10%
if currentHour >= 6 and currentHour < 10 then
    modifiers.morningDiscount = 0.90  -- Changed from 0.95
end

-- Change evening premium from +10% to +20%
if currentHour >= 18 and currentHour < 23 then
    modifiers.eveningPremium = 1.20  -- Changed from 1.1
end
```

### Modifying Item Condition Tiers

Edit `ExampleShop.modifySellPriceByCondition()`:

```lua
local condition = item:getCondition()

if condition < 40 then  -- Changed from 25
    modifiers.conditionBad = 0.1  -- Changed from 0.2
elseif condition < 70 then  -- Changed from 50
    modifiers.conditionFair = 0.4  -- Changed from 0.5
end
```

---

## Configuration Presets

### "Budget Shop" (Lower prices)

```lua
ExampleShop.CONFIG = {
    enableVIPSystem = false,
    enableTimedSales = false,
    enableBulkDiscounts = true,
    debugLogging = false,
}

-- Edit modifyBuyPriceByCategory:
-- Remove all multipliers or set to 1.0
```

### "Premium Shop" (Higher prices)

```lua
ExampleShop.CONFIG = {
    enableVIPSystem = true,
    enableTimedSales = true,
    enableBulkDiscounts = false,
    debugLogging = false,
}

-- Edit modifyBuyPriceByCategory:
-- Increase all multipliers (e.g., 1.3 → 1.5)
```

### "Dynamic Economy" (Aggressive pricing)

```lua
ExampleShop.CONFIG = {
    enableVIPSystem = true,
    enableTimedSales = true,
    enableBulkDiscounts = true,
    debugLogging = true,
}

-- Edit all price modification functions
-- to use more aggressive multipliers
```

### "Flat Pricing" (Simple)

```lua
ExampleShop.CONFIG = {
    enableVIPSystem = false,
    enableTimedSales = false,
    enableBulkDiscounts = false,
    debugLogging = false,
}

-- Comment out all modification hooks
-- Only use override hooks for fixed prices
```

---

## Debugging Configuration

### Verify Configuration Loaded

Check console when mod loads:

```
[ExampleShop] Registering hooks...
[ExampleShop] Registered OnShopRegisterItems
[ExampleShop] Registered OnShopRegisterSellItems
[ExampleShop] Registered OnShopModifyBuyPrice hooks (4x)
...
```

### Test Price Modifications

Enable debugging and buy an item:

```
[ExampleShop] Item: Base.Apple, Base: 12
[ExampleShop] Food discount applied to Base.Apple
[ExampleShop] Morning discount applied
```

### Check Hook Registration

```lua
print("Buy price modification hooks: " .. #ShopPriceEvents.OnShopModifyBuyPrice)
print("Buy price override hooks: " .. #ShopPriceEvents.OnShopOverrideBuyPrice)
```

---

## Performance Tuning

### Disable Expensive Features

If experiencing lag with multiple mods:

```lua
ExampleShop.CONFIG = {
    enableVIPSystem = false,  -- Disables reputation checks
    enableTimedSales = false, -- Disables time calculations
    enableBulkDiscounts = false,  -- Disables inventory checks
    debugLogging = false,
}
```

### Limit Debug Output

Always disable in production:

```lua
ExampleShop.CONFIG.debugLogging = false
```

---

## Common Configuration Tasks

### Make weapons cheaper
```lua
modifiers.weaponMarkup = 1.1  -- Changed from 1.3
```

### Make food more expensive
```lua
modifiers.foodDiscount = 1.1  -- Changed from 0.9 (removes discount)
```

### Increase VIP discount
```lua
modifiers.vipGold = 0.75  -- Changed from 0.85 (25% off)
```

### More aggressive bulk discount
```lua
modifiers.bulkDiscount = 0.7  -- Changed from 0.85 (30% off)
```

### Stricter condition limits for selling
```lua
if condition < 50 then  -- Changed from 25
    return 0  -- Won't buy
end
```

---

## Reverting Changes

If something breaks, restore original values from this file or the code comments showing original values.

Always test changes in a copy before deploying to server.
