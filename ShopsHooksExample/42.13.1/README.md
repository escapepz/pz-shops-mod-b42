# Example Shop Mod

A comprehensive example mod demonstrating all Shop hook system features.

## Features

### 1. Item Registration
- **25 Buy Items**: Food, first aid, tools, weapons, ammunition
- **25 Sell Items**: Same items at reduced prices
- Automatic registration during shop initialization

### 2. Buy Price System

#### Price Modifications
- **Category-based Markup**
  - Weapons: +30%
  - Ammunition: +20%
  - Medical: +15%
  - Food: -10%

- **Time-based Pricing**
  - Morning (6 AM - 10 AM): -5% discount
  - Evening (6 PM - 11 PM): +10% premium
  - Night (11 PM - 6 AM): +15% premium

- **VIP System**
  - Bronze (100+ reputation): -5% discount
  - Silver (250+ reputation): -10% discount
  - Gold (500+ reputation): -15% discount

- **Bulk Discount**
  - Buy 5+ of same item: -10% discount
  - Buy 10+ of same item: -15% discount

#### Price Overrides
- **Special Items**: Water and Pop have fixed prices
- **Admin Access**: Admins get all items for free

### 3. Sell Price System

#### Price Modifications
- **Condition-based**
  - Excellent (75-100): Full price
  - Good (50-74): -15%
  - Fair (25-49): -50%
  - Poor (0-24): -80%

- **Bulk Seller Bonus**
  - 10-20 items: +5% bonus
  - 20+ items: +10% bonus

- **Reputation Bonus**
  - Bronze (100+ rep): +5%
  - Silver (250+ rep): +10%
  - Gold (500+ rep): +15%

#### Price Overrides
- **Damaged Weapons**: Won't buy weapons with <30% condition
- **Premium Weapons**: Fixed buyback prices for special weapons

### 4. Reputation System
- Earn 1 rep per item purchased
- Earn 2 rep per item sold
- Unlock VIP tiers for better prices

## Installation

1. Copy `ExampleShop` folder to your `Mods` directory
2. Enable "Shops" mod (dependency)
3. Enable "ExampleShop" mod
4. Load game

## File Structure

```
ExampleShop/
├── mod.info                                  # Mod metadata
├── README.md                                 # This file
└── media/
    └── lua/
        ├── shared/
        │   └── ExampleShop.lua              # Main mod logic, hook registration
        ├── server/
        │   └── ExampleShopServer.lua        # Server-side features, reputation
        └── client/
            └── ExampleShopClient.lua        # Client-side UI helpers
```

## Hook Usage Examples

### Item Registration
```lua
ShopEvents.registerOnShopRegisterItems(function()
    ShopRegistry.addShopItem("Base.Apple", 12)
end)
```

### Buy Price Modification
```lua
ShopPriceEvents.registerOnShopModifyBuyPrice(function(player, itemId, base, context, modifiers)
    if string.find(itemId, "Weapon") then
        modifiers.weaponMarkup = 1.3
    end
end)
```

### Buy Price Override
```lua
ShopPriceEvents.registerOnShopOverrideBuyPrice(function(player, itemId, price, context)
    if player:isAdmin() then
        return 0  -- Free
    end
    return nil  -- Use calculated price
end)
```

### Sell Price Modification
```lua
ShopPriceEvents.registerOnShopModifySellPrice(function(player, item, base, context, modifiers)
    if item:getCondition() < 50 then
        modifiers.wornCondition = 0.5
    end
end)
```

### Sell Price Override
```lua
ShopPriceEvents.registerOnShopOverrideSellPrice(function(player, item, price, context)
    if item:getCondition() < 30 then
        return 0  -- Won't buy
    end
    return nil
end)
```

## Configuration

Edit `ExampleShop.lua` to customize:

```lua
ExampleShop.CONFIG = {
    enableVIPSystem = true,        -- Enable reputation/VIP system
    enableTimedSales = true,       -- Enable time-based pricing
    enableBulkDiscounts = true,    -- Enable bulk purchase discounts
    debugLogging = false,          -- Enable debug output
}
```

## Testing

Run the hook test suite:

```lua
_G.testMode = true
require("hooks_test")
HooksTest.runAll()
```

## Debugging

Enable debug logging:

```lua
ExampleShop.CONFIG.debugLogging = true
```

Check console output for hook registration and execution logs.

## Features Demonstrated

✅ Item registration hooks  
✅ Multiple modification hooks on same event  
✅ Override hooks with short-circuit behavior  
✅ Parameter access and mutation  
✅ Configuration system  
✅ VIP/reputation system  
✅ Time-based mechanics  
✅ Condition-based pricing  
✅ Admin special handling  
✅ Server/client separation  

## Advanced Usage

### Custom Price Calculation

Combine multiple modifiers:

```lua
-- Base price: 100
-- weaponMarkup: 1.3 (130)
-- vipGold: 0.85 (110.5)
-- nightPremium: 1.15 (127)
-- Final: 100 * 1.3 * 0.85 * 1.15 ≈ 127
```

### Conditional Pricing

Override hook example:

```lua
ShopPriceEvents.registerOnShopOverrideBuyPrice(function(player, itemId, price, context)
    -- Only override if condition is met
    if itemId == "Base.Water" then
        return 10
    elseif player and player:isAdmin() then
        return 0
    end
    return nil  -- Let other hooks run
end)
```

### Reputation Rewards

Server-side example:

```lua
ExampleShop.addPlayerReputation(player, 50)
local reputation = ExampleShop.getPlayerReputation(player)
```

## Performance Notes

- All hooks registered during initialization (one-time cost)
- Price hooks called during every transaction (optimize if high-traffic server)
- Modification hooks always execute; override hooks short-circuit on first non-nil
- Consider caching calculations if using expensive operations

## Compatibility

- Requires: Shops (B42.13.1+)
- Works with: Any mod that respects Shop hooks
- Conflicts: None known

## Support

For issues with the Shop hook system, see:
- `mods/HOOKS_ANALYSIS.md` - Detailed hook documentation
- `mods/HOOKS_QUICK_REFERENCE.md` - Quick lookup guide
- `mods/HOOKS_EXAMPLES.lua` - More code examples

## License

Example mod for educational purposes. Modify and distribute freely.
