# Example Shop Mod - Implementation Guide

## Overview

This guide explains how the Example Shop mod implements various features using the Shop hook system. Use this as a reference when building your own Shop mods.

## Architecture

```
ExampleShop (Shared)
├── Hook Registration
├── Item Registration
├── Price Modification Functions
└── Price Override Functions

ExampleShopServer (Server)
├── Reputation Tracking
├── Transaction Logging
└── Player Statistics

ExampleShopClient (Client)
├── UI Helpers
├── Display Functions
└── Item Browser
```

## Module Separation

### Shared Module (`ExampleShop.lua`)

**Loaded:** Both client and server

**Contains:**
- Core configuration
- Hook registration
- Price calculation logic
- Item lists

**Why shared?**
- Price hooks must run on both sides for consistency
- Items need to be available to both client (UI) and server (transactions)

```lua
require("ShopEvents")
require("ShopSellEvents")
require("ShopPriceEvents")
```

### Server Module (`ExampleShopServer.lua`)

**Loaded:** Server only

**Contains:**
- Reputation tracking
- Transaction logging
- Player statistics
- Server-side business logic

**Why server-only?**
- Reputation must be authoritative (prevent cheating)
- Transaction logging is server record
- Sensitive calculations need server authority

```lua
ExampleShop.addPlayerReputation(player, amount)
ExampleShop.getPlayerReputation(player)
```

### Client Module (`ExampleShopClient.lua`)

**Loaded:** Client only

**Contains:**
- UI display helpers
- Formatting functions
- Item browser logic
- VIP tier display

**Why client-only?**
- UI only needs to show on client
- Reduces network overhead
- Client-specific rendering

```lua
ExampleShopClient.getVIPTierDisplay(reputation)
ExampleShopClient.formatPrice(price)
```

## Implementation Patterns

### Pattern 1: Simple Item Registration

```lua
function ExampleShop.registerBuyItems()
    ShopRegistry.addShopItem("Base.Apple", 12)
    ShopRegistry.addShopItem("Base.Banana", 15)
end

ShopEvents.registerOnShopRegisterItems(ExampleShop.registerBuyItems)
```

**Key Points:**
- Called once during initialization
- No parameters passed
- Register all items in single callback or multiple callbacks
- Order doesn't matter

### Pattern 2: Multiple Modification Hooks

```lua
-- Hook 1: Category-based markup
ShopPriceEvents.registerOnShopModifyBuyPrice(function(player, itemId, base, context, modifiers)
    if string.find(itemId, "Weapon") then
        modifiers.weaponMarkup = 1.3
    end
end)

-- Hook 2: Time-based pricing
ShopPriceEvents.registerOnShopModifyBuyPrice(function(player, itemId, base, context, modifiers)
    if currentHour >= 18 then
        modifiers.eveningPremium = 1.1
    end
end)
```

**Key Points:**
- Multiple hooks accumulate modifications
- Each hook can modify same `modifiers` table
- Order matters if hooks depend on each other
- Final price = base * multiplier1 * multiplier2 * ...

### Pattern 3: Conditional Override

```lua
ShopPriceEvents.registerOnShopOverrideBuyPrice(function(player, itemId, price, context)
    if player:isAdmin() then
        return 0  -- Override with free
    end
    
    if itemId == "special_item" then
        return 500  -- Override with fixed price
    end
    
    return nil  -- Use calculated price
end)
```

**Key Points:**
- Must return value OR nil
- First non-nil stops execution chain
- Can check multiple conditions
- Good for special cases

### Pattern 4: Player Data Tracking

```lua
function ExampleShop.modifyBuyPriceVIP(player, itemId, base, context, modifiers)
    if not player then return end
    
    local reputation = ExampleShop.getPlayerReputation(player)
    
    if reputation >= 500 then
        modifiers.vipGold = 0.85
    end
end
```

**Key Points:**
- Always check if player exists
- Use player properties for persistent data
- Access player methods safely with nil checks
- Cache values if accessed multiple times

### Pattern 5: Item Inspection

```lua
function ExampleShop.modifySellPriceByCondition(player, item, base, context, modifiers)
    if not item then return end
    
    local condition = item:getCondition()
    local itemType = item:getType()
    
    if condition < 50 then
        modifiers.wornCondition = 0.5
    end
end
```

**Key Points:**
- Always check if item exists
- Item provides condition and type info
- Safe to call item methods
- Use for quality-based pricing

## Hook Chaining Example

Complete workflow showing all hooks:

```lua
-- 1. Items are registered
ShopEvents.registerOnShopRegisterItems(function()
    ShopRegistry.addShopItem("Base.Apple", 12)
end)

-- 2. Player buys item, price hooks execute
ShopPriceEvents.registerOnShopModifyBuyPrice(function(player, itemId, base, context, modifiers)
    modifiers.category = 0.9  -- Food discount
end)

ShopPriceEvents.registerOnShopModifyBuyPrice(function(player, itemId, base, context, modifiers)
    modifiers.vip = 0.95  -- VIP discount
end)

-- Calculation:
-- base: 12
-- After modify: 12 * 0.9 * 0.95 = 10.26
-- After override (if any): use override or 10.26

ShopPriceEvents.registerOnShopOverrideBuyPrice(function(player, itemId, price, context)
    if itemId == "Base.Apple" and player:isAdmin() then
        return 0  -- Admin gets free apples
    end
    return nil  -- Use calculated 10.26
end)
```

## Error Handling

### Safe Parameter Access

```lua
-- BAD: No nil checks
function unsafeHook(player, itemId, base, context, modifiers)
    local username = player:getUsername()  -- Crash if player is nil
end

-- GOOD: With nil checks
function safeHook(player, itemId, base, context, modifiers)
    if player then
        local username = player:getUsername()
    end
end
```

### Safe Table Access

```lua
-- BAD: Assumes keys exist
function badModification(player, itemId, base, context, modifiers)
    modifiers.multiplier = 1.0
    print(context.shopName .. " shop")  -- Crash if key missing
end

-- GOOD: Use defaults
function goodModification(player, itemId, base, context, modifiers)
    modifiers.multiplier = 1.0
    local shopName = context.shopName or "Unknown"
    print(shopName .. " shop")
end
```

### Type Validation

```lua
-- BAD: Trust input types
function badValidation(player, itemId, base, context, modifiers)
    local price = base * 2  -- Crash if base not number
end

-- GOOD: Validate types
function goodValidation(player, itemId, base, context, modifiers)
    if type(base) ~= "number" then
        base = 0  -- Default or error
    end
    local price = base * 2
end
```

## Performance Optimization

### Avoid Expensive Operations in Hooks

```lua
-- BAD: File I/O in price hook
ShopPriceEvents.registerOnShopModifyBuyPrice(function(...)
    local config = io.open("config.txt")  -- Slow!
end)

-- GOOD: Load once, reuse
local CONFIG = loadConfigOnce()

ShopPriceEvents.registerOnShopModifyBuyPrice(function(...)
    -- Use CONFIG directly
end)
```

### Cache Calculations

```lua
-- BAD: Recalculate every hook call
ShopPriceEvents.registerOnShopModifyBuyPrice(function(player, itemId, base, context, modifiers)
    local reputation = ExampleShop.getPlayerReputation(player)  -- Database call
    -- Use reputation
end)

-- GOOD: Cache in context if possible
ShopPriceEvents.registerOnShopModifyBuyPrice(function(player, itemId, base, context, modifiers)
    local reputation = context.playerReputation or ExampleShop.getPlayerReputation(player)
end)
```

### Early Returns in Override Hooks

```lua
-- GOOD: Check conditions quickly
ShopPriceEvents.registerOnShopOverrideBuyPrice(function(player, itemId, price, context)
    -- Fastest checks first
    if itemId ~= "special_item" then
        return nil  -- Exit immediately
    end
    
    if not player then
        return nil
    end
    
    -- Expensive check only if needed
    local reputation = ExampleShop.getPlayerReputation(player)
    if reputation >= 500 then
        return math.floor(price * 0.8)
    end
    
    return nil
end)
```

## Testing Individual Hooks

### Unit Test Template

```lua
function testVIPDiscount()
    local mockPlayer = {
        getProperty = function(self, key)
            if key == "exampleshop_reputation" then
                return 500  -- Gold VIP
            end
        end
    }
    
    local modifiers = {}
    ExampleShop.modifyBuyPriceVIP(mockPlayer, "Base.Apple", 12, {}, modifiers)
    
    assert(modifiers.vipGold == 0.85, "VIP Gold discount not applied")
    print("✓ VIP discount test passed")
end
```

## Common Implementation Tasks

### Task 1: Add new item category

1. Add items in `registerBuyItems()`:
```lua
ShopRegistry.addShopItem("CustomItem.Sword", 500)
```

2. Add sell items in `registerSellItems()`:
```lua
ShopSellRegistry.addSellItem("CustomItem.Sword", 250)
```

3. Add pricing logic:
```lua
if string.find(itemId, "CustomItem") then
    modifiers.customMarkup = 1.25
end
```

### Task 2: Add player reward system

1. Server module tracks purchases:
```lua
ExampleShop.addPlayerReputation(player, amount)
```

2. Modify hooks check reputation:
```lua
local rep = ExampleShop.getPlayerReputation(player)
if rep > threshold then
    modifiers.reward = rewardMultiplier
end
```

3. Client displays tier:
```lua
local tierInfo = ExampleShopClient.getVIPTierDisplay(reputation)
```

### Task 3: Add conditional pricing

Use override hooks:

```lua
ShopPriceEvents.registerOnShopOverrideBuyPrice(function(player, itemId, price, context)
    if condition then
        return customPrice
    end
    return nil
end)
```

## Debugging Tips

### Print Hook Registration

```lua
ExampleShop.CONFIG.debugLogging = true
```

Outputs:
```
[ExampleShop] Registering hooks...
[ExampleShop] Registered OnShopRegisterItems
```

### Log Price Calculations

```lua
ShopPriceEvents.registerOnShopModifyBuyPrice(function(player, itemId, base, context, modifiers)
    print("Item: " .. itemId .. ", Base: " .. base)
    print("Current modifiers: " .. table.concat(modifiers, ", "))
end)
```

### Check Hook Count

```lua
print("Registered hooks: " .. #ShopPriceEvents.OnShopModifyBuyPrice)
```

## Next Steps

1. **Copy ExampleShop** as template for your mod
2. **Customize items** in registration functions
3. **Adjust prices** in modification functions
4. **Add features** using override hooks
5. **Test thoroughly** with hook test suite
6. **Debug** using logging options

See `CONFIGURATION.md` for detailed setup instructions.
