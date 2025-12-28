# Example Shop Mod - Configuration Guide

## Overview

The Example Shop mod is highly configurable. All settings are contained in `ExampleShop.lua` in the `CONFIG` table. This guide shows how to customize every aspect of the mod.

## Configuration Options

### Main Settings

Located at top of `ExampleShop.lua` (lines 14-19):

```lua
ExampleShop.CONFIG = {
    enableVIPSystem = true,        -- Enable reputation/VIP system
    enableTimedSales = true,       -- Enable time-based pricing variations
    enableBulkDiscounts = true,    -- Enable bulk purchase/sale bonuses
    debugLogging = true,           -- Enable debug output to console
}
```

## Option Reference

### `enableVIPSystem` (boolean, default: `true`)

Controls reputation-based VIP tiers and discounts/bonuses.

**When enabled:**
- Players earn 1 reputation per item purchased
- Players earn 2 reputation per item sold
- Buy discounts applied:
  - Bronze (100+ rep): -5% discount
  - Silver (250+ rep): -10% discount
  - Gold (500+ rep): -15% discount
- Sell bonuses applied:
  - Bronze: +5% bonus
  - Silver: +10% bonus
  - Gold: +15% bonus

**When disabled:**
- No reputation tracking
- No VIP tiers
- VIP hooks still execute but have no effect

**To disable:**
```lua
ExampleShop.CONFIG.enableVIPSystem = false
```

---

### `enableTimedSales` (boolean, default: `true`)

Controls time-of-day based price variations.

**When enabled:**
- Morning (6 AM - 10 AM): -5% discount on all items
- Day (10 AM - 6 PM): Standard prices (no modifier)
- Evening (6 PM - 11 PM): +10% premium on all items
- Night (11 PM - 6 AM): +15% premium on all items

**When disabled:**
- All items always at base price (no time modifiers)
- No advantage to shopping at specific times

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
- Players encouraged to sell small quantities

**To disable:**
```lua
ExampleShop.CONFIG.enableBulkDiscounts = false
```

---

### `debugLogging` (boolean, default: `true`)

Controls debug output to console. Useful during development.

**When enabled:**
- Prints all hook registrations on load
- Prints hook execution details
- Prints price calculations for each item
- Prints VIP tier changes
- Prints transaction logging
- Useful for troubleshooting
- **Causes console spam** on busy servers

**When disabled:**
- Silent operation
- No console output
- Better performance on high-traffic servers

**To enable:**
```lua
ExampleShop.CONFIG.debugLogging = true
```

**Check console when mod loads for:**
```
[ExampleShop] Registering hooks...
[ExampleShop] Registered OnShopRegisterItems
[ExampleShop] Registered OnShopRegisterSellItems
[ExampleShop] Registered OnShopModifyBuyPrice hooks (4x)
[ExampleShop] Registered OnShopOverrideBuyPrice hooks (2x)
[ExampleShop] Registered OnShopModifySellPrice hooks (3x)
[ExampleShop] Registered OnShopOverrideSellPrice hooks (2x)
[ExampleShop] All hooks registered successfully!
```

---

## Customizing Items

### Modify Buy Prices

Edit `ExampleShop.registerBuyItems()` (lines 50-93):

```lua
-- Original
Shop.RegisterItem("Base.Apple", { tab = Tab.Food, price = 12 })

-- More expensive
Shop.RegisterItem("Base.Apple", { tab = Tab.Food, price = 25 })

-- Much cheaper
Shop.RegisterItem("Base.Apple", { tab = Tab.Food, price = 5 })
```

### Modify Sell Prices

Edit `ExampleShop.registerSellItems()` (lines 96-140):

```lua
-- Original (50% of buy price)
Shop.RegisterSellItem("Base.Apple", { price = 6 })

-- More generous (70% of buy price)
Shop.RegisterSellItem("Base.Apple", { price = 8 })

-- Less generous (30% of buy price)
Shop.RegisterSellItem("Base.Apple", { price = 3 })
```

### Add New Item

1. Add to `registerBuyItems()`:
```lua
Shop.RegisterItem("Base.MyNewItem", { tab = Tab.Food, price = 50 })
```

2. Add to `registerSellItems()`:
```lua
Shop.RegisterSellItem("Base.MyNewItem", { price = 25 })
```

3. Add pricing logic to `modifyBuyPriceByCategory()`:
```lua
if string.find(itemId, "MyNewItem") then
    table.insert(modifiers, { multiplier = 1.1, label = "newItemMarkup" })
end
```

### Remove Item

1. Delete from `registerBuyItems()`
2. Delete from `registerSellItems()`
3. Delete any pricing logic for that item

---

## Customizing Price Multipliers

### Category-based Markups

Edit `modifyBuyPriceByCategory()` (lines 145-176):

```lua
-- Weapon markup: change from 1.3 (30%) to 1.5 (50%)
if string.find(itemId, "Handgun") or string.find(itemId, "Pistol") or
    string.find(itemId, "Revolver") or string.find(itemId, "Rifle") then
    table.insert(modifiers, { multiplier = 1.5, label = "weaponMarkup" })  -- Changed
end

-- Food discount: change from 0.9 (-10%) to 0.8 (-20%)
if string.find(itemId, "Apple") or ... then
    table.insert(modifiers, { multiplier = 0.8, label = "foodDiscount" })  -- Changed
end
```

### Time-based Pricing

Edit `modifyBuyPriceByTime()` (lines 179-202):

```lua
-- Morning discount: change from -5% to -10%
if currentHour >= 6 and currentHour < 10 then
    table.insert(modifiers, { multiplier = 0.90, label = "morningDiscount" })  -- Changed
end

-- Evening premium: change from +10% to +20%
if currentHour >= 18 and currentHour < 23 then
    table.insert(modifiers, { multiplier = 1.20, label = "eveningPremium" })  -- Changed
end

-- Night premium: change from +15% to +25%
if currentHour >= 23 or currentHour < 6 then
    table.insert(modifiers, { multiplier = 1.25, label = "nightPremium" })  -- Changed
end
```

### VIP Reputation Tiers

Edit `modifyBuyPriceVIP()` (lines 205-227):

```lua
-- Bronze: change threshold from 100 to 50, discount from -5% to -10%
if reputation >= 50 and reputation < 250 then
    table.insert(modifiers, { multiplier = 0.90, label = "vipBronze" })  -- Changed
end

-- Silver: change threshold from 250 to 200, discount from -10% to -15%
if reputation >= 200 and reputation < 500 then
    table.insert(modifiers, { multiplier = 0.85, label = "vipSilver" })  -- Changed
end

-- Gold: change threshold from 500 to 300, discount from -15% to -20%
if reputation >= 300 then
    table.insert(modifiers, { multiplier = 0.80, label = "vipGold" })  -- Changed
end
```

### Bulk Purchase Discounts

Edit `modifyBuyPriceByBulk()` (lines 230-244):

```lua
-- Change thresholds from 5/10 to 3/8, discounts from 0.9/0.85 to 0.85/0.75
if count >= 8 then
    table.insert(modifiers, { multiplier = 0.75, label = "bulkDiscount" })  -- Changed
elseif count >= 3 then
    table.insert(modifiers, { multiplier = 0.85, label = "bulkDiscount" })  -- Changed
end
```

---

## Customizing Sell Price Modifiers

### Item Condition Tiers

Edit `modifySellPriceByCondition()` (lines 276-295):

```lua
-- Original condition ranges
if condition < 25 then
    table.insert(modifiers, { multiplier = 0.2, label = "conditionBad" })
elseif condition < 50 then
    table.insert(modifiers, { multiplier = 0.5, label = "conditionFair" })
elseif condition < 75 then
    table.insert(modifiers, { multiplier = 0.85, label = "conditionGood" })

-- Change to stricter conditions
if condition < 40 then  -- Changed from 25
    table.insert(modifiers, { multiplier = 0.1, label = "conditionBad" })  -- Changed
elseif condition < 60 then  -- Changed from 50
    table.insert(modifiers, { multiplier = 0.4, label = "conditionFair" })  -- Changed
elseif condition < 80 then  -- Changed from 75
    table.insert(modifiers, { multiplier = 0.9, label = "conditionGood" })  -- Changed
```

### Bulk Seller Bonus

Edit `modifySellPriceByQuantity()` (lines 298-309):

```lua
-- Change thresholds from 10/20 to 5/15, bonuses from 1.05/1.1 to 1.02/1.08
if count > 15 then  -- Changed from 20
    table.insert(modifiers, { multiplier = 1.08, label = "bulkSeller" })  -- Changed
elseif count > 5 then  -- Changed from 10
    table.insert(modifiers, { multiplier = 1.02, label = "bulkSeller" })  -- Changed
end
```

### Reputation Sell Bonus

Edit `modifySellPriceByReputation()` (lines 312-327):

```lua
-- Change thresholds and bonuses
if reputation > 400 then  -- Changed from 500
    table.insert(modifiers, { multiplier = 1.20, label = "loyaltyGold" })  -- Changed
elseif reputation > 200 then  -- Changed from 250
    table.insert(modifiers, { multiplier = 1.12, label = "loyaltysilver" })  -- Changed
elseif reputation > 80 then  -- Changed from 100
    table.insert(modifiers, { multiplier = 1.08, label = "loyaltyBronze" })  -- Changed
end
```

---

## Special Prices

### Override Buy Prices

Edit `overrideBuyPriceSpecialItems()` (lines 249-261):

```lua
local specialPrices = {
    ["Base.Water"] = 10,      -- Always 10
    ["Base.Pop"] = 15,        -- Always 15
    ["Base.Apple"] = 5,       -- Add new special price
    ["Base.Premium"] = 1000,  -- Add premium item
}
```

### Override Sell Prices (Premium Items)

Edit `overrideSellPricePremium()` (lines 429-445):

```lua
local premiumPrices = {
    ["Base.AssaultRifle"] = 150,
    ["Base.HuntingRifle"] = 120,
    ["Base.Pistol"] = 75,
    ["Base.GoldenWeapon"] = 500,  -- Add new premium item
}
```

### Reject Damaged Items

Edit `overrideSellPriceDamaged()` (lines 412-426):

```lua
-- Tighten weapon condition requirement from 30 to 50
if (string.find(itemId, "Pistol") or string.find(itemId, "Rifle") or
        string.find(itemId, "Handgun")) and condition < 50 then  -- Changed
    return 0  -- Won't buy
end

-- Add other item types with condition requirements
if string.find(itemId, "Tool") and condition < 20 then
    return 0
end
```

---

## Configuration Presets

### "Budget Shop" (Low prices, high availability)

```lua
ExampleShop.CONFIG = {
    enableVIPSystem = false,
    enableTimedSales = false,
    enableBulkDiscounts = true,
    debugLogging = false,
}

-- In modifyBuyPriceByCategory(), comment out or remove all markups
-- Example:
-- if string.find(itemId, "Handgun") or ... then
--     table.insert(modifiers, { multiplier = 1.0, label = "weaponMarkup" })  -- No markup
-- end
```

### "Premium Shop" (High prices, limited availability)

```lua
ExampleShop.CONFIG = {
    enableVIPSystem = true,
    enableTimedSales = true,
    enableBulkDiscounts = false,
    debugLogging = false,
}

-- In modifyBuyPriceByCategory(), increase all multipliers
-- Example:
-- if string.find(itemId, "Handgun") or ... then
--     table.insert(modifiers, { multiplier = 1.5, label = "weaponMarkup" })  -- 50% markup
-- end
```

### "Dynamic Economy" (Aggressive pricing variations)

```lua
ExampleShop.CONFIG = {
    enableVIPSystem = true,
    enableTimedSales = true,
    enableBulkDiscounts = true,
    debugLogging = true,
}

-- Increase all multipliers in price modification functions
```

### "Flat Pricing" (Simple, no variations)

```lua
ExampleShop.CONFIG = {
    enableVIPSystem = false,
    enableTimedSales = false,
    enableBulkDiscounts = false,
    debugLogging = false,
}

-- Comment out modification hook registrations (lines 470-476)
-- Keep only override hooks for fixed prices
```

### "Hardcore Economy" (Severe penalties, high rewards)

```lua
ExampleShop.CONFIG = {
    enableVIPSystem = true,
    enableTimedSales = true,
    enableBulkDiscounts = true,
    debugLogging = false,
}

-- Modify multipliers:
-- Category markups: increase (e.g., 1.3 → 1.8)
-- VIP discounts: decrease (e.g., 0.85 → 0.70)
-- Bulk discounts: decrease (e.g., 0.85 → 0.60)
-- Time premiums: increase (e.g., 1.15 → 1.30)
```

---

## Sell Item Whitelist Mode

Sell items are registered in **whitelist mode** (line 100):

```lua
Shop.SellisWhitelist = true
```

This means:
- ONLY registered sell items can be sold
- Any item NOT in `registerSellItems()` cannot be sold
- Blacklisted items are explicitly prevented

To switch to **blacklist mode** (allow everything except blacklisted):

```lua
Shop.SellisWhitelist = false  -- Remove or comment this line
```

Then only blacklisted items are rejected:

```lua
Shop.RegisterSellItem("Base.KeyRing", { blacklisted = true })
```

---

## Performance Tuning

### Disable Expensive Features

If experiencing lag:

```lua
ExampleShop.CONFIG = {
    enableVIPSystem = false,      -- Disables property lookups
    enableTimedSales = false,     -- Disables time calculations
    enableBulkDiscounts = false,  -- Disables inventory checks
    debugLogging = false,         -- Disables console output
}
```

### Limit Hook Count

Comment out modification hook registrations (lines 470-476):

```lua
-- Only register essential hooks
ShopPriceEvents.registerOnShopModifyBuyPrice(ExampleShop.modifyBuyPriceByCategory)
-- Comment out others
```

### Cache Calculations

In buy price hooks, cache reputation:

```lua
function ExampleShop.modifyBuyPriceVIP(player, itemId, base, context, modifiers)
    if context.cachedReputation then
        local reputation = context.cachedReputation
    else
        local reputation = ExampleShop.getPlayerReputation(player)
    end
end
```

---

## Common Configuration Tasks

### Make weapons cheaper

```lua
-- In modifyBuyPriceByCategory(), line 152
table.insert(modifiers, { multiplier = 1.1, label = "weaponMarkup" })  -- Changed from 1.3
```

### Make food more expensive

```lua
-- In modifyBuyPriceByCategory(), line 166
table.insert(modifiers, { multiplier = 1.0, label = "foodDiscount" })  -- Changed from 0.9 (removes discount)
```

### Increase VIP discount

```lua
-- In modifyBuyPriceVIP(), line 224
table.insert(modifiers, { multiplier = 0.75, label = "vipGold" })  -- Changed from 0.85 (25% off)
```

### More aggressive bulk discount

```lua
-- In modifyBuyPriceByBulk(), line 238
table.insert(modifiers, { multiplier = 0.70, label = "bulkDiscount" })  -- Changed from 0.85
```

### Stricter damage limits

```lua
-- In overrideSellPriceDamaged(), line 420
if ... and condition < 50 then  -- Changed from 30
    return 0
end
```

### Allow selling more items

Remove or comment out lines 136-137:

```lua
-- Shop.RegisterSellItem("Base.KeyRing", { blacklisted = true })
```

### Disable VIP system but keep transactions

```lua
ExampleShop.CONFIG.enableVIPSystem = false
-- Reputation still tracked, but not used in pricing
```

---

## Debugging Configuration

### Check Hook Registration

Enable logging and check console:

```lua
ExampleShop.CONFIG.debugLogging = true
-- Look for lines like:
-- [ExampleShop] Registered OnShopModifyBuyPrice hooks (4x)
```

### Test Price Modifications

```lua
ExampleShop.CONFIG.debugLogging = true
-- Buy an item and check console for:
-- [ExampleShop] modifyBuyPriceByCategory: Base.Apple (base: 12)
-- [ExampleShop]   -> Food discount 0.9x applied
```

### Verify Item Registration

```lua
-- In ExampleShop.registerBuyItems():
ExampleShop.log("Registered " .. "25" .. " buy items")
```

---

## Reverting Changes

If something breaks:

1. **Compare with original:** Check git history or backup
2. **Restore from comments:** Original values are noted in code comments
3. **Check defaults:** Look at lines 14-19 for default CONFIG values

Always test changes in a copy before deploying to production.

---

## Next Steps

- See `README.md` for feature overview
- See `IMPLEMENTATION_GUIDE.md` for code patterns
- Test configuration changes with `ExampleShop.CONFIG.debugLogging = true`
- Use git/backups to track safe configurations
