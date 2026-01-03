# ShopsHooksExample — Server-Only Reference Implementation

A **minimal, focused server-side reference implementation** demonstrating correct usage of the Shops price hook system in Project Zomboid B42.13.1 Multiplayer.

## Overview

This mod is a **drop-in template** for mod authors who want to create custom price hooks. It demonstrates:

- ✅ Server-side-only hook registration
- ✅ Modifier hook pattern (multiplier stacking)
- ✅ Override hook pattern (short-circuit behavior)
- ✅ Buy vs Sell asymmetry (itemId string vs item object)
- ✅ SHOPSB42 namespace usage (no globals)
- ✅ Correct logging with SharedLogger
- ✅ Price hook lifecycle and resync

This example is **NOT**:
- ❌ A testing harness (see Shops/TestPriceHooks.lua for that)
- ❌ A debug console mod
- ❌ A UI-driven mod
- ❌ A command-based mod

## Features Demonstrated

### 1. Modifier Hook (Buy Price)

**Hook**: `registerOnShopModifyBuyPrice`  
**Item**: Base.Apple  
**Effect**: -10% fruit category discount

```lua
function modifyAppleBuyPrice(player, itemId, basePrice, context, modifiers)
    if itemId ~= "Base.Apple" then return end
    
    table.insert(modifiers, {
        multiplier = 0.9,
        label = "appleFruitDiscount"
    })
end
```

**Key Points**:
- Receives `itemId` as string (not item object)
- Appends to `modifiers` table for stacking
- Multipliers chain: 100 → 100 × 0.9 = 90

### 2. Override Hook (Buy Price)

**Hook**: `registerOnShopOverrideBuyPrice`  
**Item**: Base.Apple (optional)  
**Effect**: Fixed price (if enabled)

```lua
function overrideAppleBuyPrice(player, itemId, price, context)
    if itemId ~= "Base.Apple" then return nil end
    
    if appleOverrideBuyPrice == nil then return nil end
    
    return appleOverrideBuyPrice  -- Short-circuits modifiers
end
```

**Key Points**:
- Returns final price OR `nil` (skip override)
- Non-nil return short-circuits modifier stacking
- Disabled by default (appleOverrideBuyPrice = nil)

### 3. Modifier Hook (Sell Price)

**Hook**: `registerOnShopModifySellPrice`  
**Items**: Base.Apple, Base.BaseballBat  
**Effect**: Condition-based multiplier

```lua
function modifySellPriceByCondition(player, item, basePrice, context, modifiers)
    if item:getFullType() ~= "Base.Apple" and
       item:getFullType() ~= "Base.BaseballBat" then
        return
    end
    
    local condition = item:getCondition()
    local multiplier = condition < 50 and 0.5 or (condition < 75 and 0.85 or 1.0)
    
    if multiplier ~= 1.0 then
        table.insert(modifiers, {
            multiplier = multiplier,
            label = "conditionFactor"
        })
    end
end
```

**Key Points**:
- Receives `item` object (not itemId string)
- Use `item:getFullType()` to get ID
- Use `item:getCondition()` for quality (0-100)
- Asymmetry from buy hooks: different signatures

## File Structure

```
ShopsHooksExample/
├── 42.13.1/
│   ├── mod.info
│   ├── README.md                      (this file)
│   ├── CONFIGURATION.md               (quick reference)
│   └── media/
│       └── lua/
│           └── server/
│               ├── ShopsHooksExample_init.lua      (entry point)
│               └── nshopsb42/
│                   ├── ShopsHooksExampleInit.lua       (registration)
│                   ├── ShopsHooksExampleHooks.lua      (implementations)
│                   └── ShopsHooksExampleState.lua      (configuration)
└── common/
```

## Installation

1. Copy `ShopsHooksExample/` to your `Mods` directory
2. Ensure "Shops" mod (B42.13.1+) is installed and enabled
3. Enable "ShopsHooksExample" mod
4. Load game (server starts, hooks register automatically)

## Configuration

Edit `ShopsHooksExampleState.lua`:

```lua
-- Apple buy price multiplier (default 0.9 = -10%)
State.appleBuyMultiplier = 0.9

-- Apple buy price override (default nil = disabled)
-- Set to numeric value to fix apple buy price
State.appleOverrideBuyPrice = nil
```

To enable apple buy override:
```lua
State.appleOverrideBuyPrice = 5  -- Force apple buy price to 5
```

## Customization Guide

### Add a New Item

Edit `ShopsHooksExampleInit.lua` and `ShopsHooksExampleHooks.lua`:

```lua
-- In ShopsHooksExampleHooks.lua, add new hook function:
function Hooks.modifyBananaPrice(player, itemId, basePrice, context, modifiers)
    if itemId ~= "Base.Banana" then return end
    
    table.insert(modifiers, {
        multiplier = 0.95,
        label = "bananaDiscount"
    })
end

-- In ShopsHooksExampleInit.lua, register it:
ShopPriceEvents.registerOnShopModifyBuyPrice(
    ShopsHooksExampleHooks.modifyBananaPrice
)
```

### Change Multiplier at Runtime

```lua
-- From admin mod or server console:
SHOPSB42.ShopsHooksExampleState.appleBuyMultiplier = 0.75

-- IMPORTANT: Trigger resync to apply changes
SHOPSB42.ShopFinalizeHandler.onPriceHooksChanged()
```

### Add Sell Override

Similar to buy override, in `ShopsHooksExampleHooks.lua`:

```lua
function Hooks.overrideSellPrice(player, item, price, context)
    if item:getFullType() ~= "Base.BaseballBat" then return nil end
    
    -- Don't buy damaged bats
    if item:getCondition() < 30 then return 0 end
    
    return nil  -- Use calculated price
end
```

Then register in `ShopsHooksExampleInit.lua`:

```lua
ShopPriceEvents.registerOnShopOverrideSellPrice(
    ShopsHooksExampleHooks.overrideSellPrice
)
```

## Hook Semantics Reference

### Modify Hooks
- **Function**: Appends multiplier to `modifiers` table
- **Returns**: `nil` (side-effect on modifiers)
- **Stacking**: All modify hooks execute, multipliers chain
- **Example**: `table.insert(modifiers, { multiplier = 0.9 })`

### Override Hooks
- **Function**: Returns final price or `nil`
- **Returns**: Numeric price (override) or `nil` (skip)
- **Short-circuit**: First non-nil return wins, stops modifier stacking
- **Example**: `return price or nil`

### Buy vs Sell Signatures

| Aspect | Buy | Sell |
|--------|-----|------|
| Modify | `(player, itemId, basePrice, context, modifiers)` | `(player, item, basePrice, context, modifiers)` |
| Override | `(player, itemId, price, context)` | `(player, item, price, context)` |
| Item param | String ID | Object |
| Item access | `itemId` | `item:getFullType()` |
| Extra methods | — | `item:getCondition()` |

## Price Calculation Example

**Buying Apple (Base.Apple)**:

```
Base price: 12
Modifier 1 (fruit discount): 12 × 0.9 = 10.8
Modifier 2 (other mods): 10.8 × 1.0 = 10.8
Override: nil (not applied)
Final: 10.8 (rounded to 10 or 11)
```

**With override active** (override = 5):

```
Base price: 12
[All modifiers ignored]
Override: 5 ← Short-circuits
Final: 5
```

**Selling Apple (condition = 60)**:

```
Base price: 6
Modifier 1 (condition fair): 6 × 0.85 = 5.1
Modifier 2 (other mods): 5.1 × 1.0 = 5.1
Override: nil (not applied)
Final: 5.1 (rounded)
```

## Key Concepts

### Modifier Stacking

Multipliers chain together:
```
Price = Base × Multiplier1 × Multiplier2 × Multiplier3 × ...
```

All modifier hooks execute (no short-circuit).

### Override Short-Circuit

First non-nil override wins:
```
If Override1 returns 50 → use 50 (stop)
Else if Override2 returns 75 → use 75 (stop)
Else if Override3 returns nil → continue
Else use calculated price from modifiers
```

### Buy vs Sell Asymmetry

**Buy hooks receive itemId** (string):
```lua
function(player, itemId, basePrice, context, modifiers)
    if itemId == "Base.Apple" then ...
```

**Sell hooks receive item object**:
```lua
function(player, item, basePrice, context, modifiers)
    if item:getFullType() == "Base.Apple" then
        local condition = item:getCondition()
```

This is intentional: sell pricing often depends on item quality.

### Resync Lifecycle

**Initial registration** (on mod load):
- No resync needed
- Shops collects hooks during startup
- Prices cached after finalization

**Runtime changes** (if state modified):
```lua
SHOPSB42.ShopsHooksExampleState.appleBuyMultiplier = 0.5
SHOPSB42.ShopFinalizeHandler.onPriceHooksChanged()  -- Trigger resync
```

This invalidates caches and broadcasts updated prices to clients.

## Logging

All logging uses `SharedLogger`:

```lua
SharedLogger.log("Shops", "[ShopsHooksExample] Message here")
```

Output appears in:
- **Server logs**: `Logs/Server/*_Shops.txt`
- **Client logs**: `Logs/Client/*_Shops.txt`

Never use `writeLog()` directly (except in SharedLogger itself).

## Multiplayer Safety

- ✅ Server-authoritative pricing
- ✅ All calculations server-side only
- ✅ Prices sync to clients via Shops resync
- ✅ No client code, no command flow
- ✅ Thread-safe (Lua single-threaded)
- ✅ Cache invalidation via `onPriceHooksChanged()`

## Testing

Enable logging and check server logs:

```bash
tail -f Logs/Server/*_Shops.txt
```

You should see:
```
[ShopsHooksExample] Initializing server-only reference example
[ShopsHooksExample] Registered: modifyAppleBuyPrice
[ShopsHooksExample] Registered: overrideAppleBuyPrice
[ShopsHooksExample] Registered: modifySellPriceByCondition
[ShopsHooksExample] All hooks registered successfully
```

When buying/selling:
```
[ShopsHooksExample] Applied buy modifier to Base.Apple: multiplier=0.9
[ShopsHooksExample] Applied condition modifier to Base.Apple: condition=85, multiplier=1.0
```

## Code Quality Notes

- **SHOPSB42 namespace**: No globals, all code under SHOPSB42
- **SharedLogger only**: No `writeLog()` calls outside SharedLogger
- **Comment style**: "Why" not "What" — explains intent, not implementation
- **Error handling**: Guards check for nil parameters before use
- **Logging**: Registered on hook activation, executed with parameters
- **Structure**: Init → Registration → Hooks → State (clear separation)

## Common Issues

### Hooks Don't Execute

1. Check mod is enabled
2. Check server logs for registration errors
3. Verify items exist (Base.Apple, Base.BaseballBat)
4. Verify Shops mod is installed and enabled

### Prices Don't Change

1. Check that hook state is correct
   ```lua
   print(SHOPSB42.ShopsHooksExampleState.appleBuyMultiplier)
   ```
2. If you modified state, call resync:
   ```lua
   SHOPSB42.ShopFinalizeHandler.onPriceHooksChanged()
   ```
3. Check client logs for price broadcasts

### Logs Not Appearing

1. Verify logging is enabled
2. Check log file: `Logs/Server/*_Shops.txt`
3. Verify mod loaded (check server console)

## Advanced: Extending the Example

### Adding Reputation-Based Pricing

```lua
function Hooks.modifyApplePriceByReputation(player, itemId, basePrice, context, modifiers)
    if itemId ~= "Base.Apple" then return end
    if not player then return end
    
    local reputation = player:getProperty("mymod_reputation") or 0
    if reputation > 100 then
        table.insert(modifiers, { multiplier = 0.9, label = "reputationDiscount" })
    end
end
```

### Adding Time-Based Pricing

```lua
function Hooks.modifyApplePriceByTime(player, itemId, basePrice, context, modifiers)
    if itemId ~= "Base.Apple" then return end
    
    local hour = getGameTime():getHour()
    if hour >= 22 or hour < 6 then
        table.insert(modifiers, { multiplier = 1.15, label = "nightPremium" })
    end
end
```

## References

- **Shops API**: See `.libraries/library/lua/` for PZ engine definitions
- **TestPriceHooks**: `Shops/42.13.1/media/lua/server/nshopsb42/TestPriceHooks.lua`
- **Vanilla game code**: `tmp/Vanilla/` for reference implementations
- **Price resolution**: See Shops mod `ShopPriceEvents.lua`

## License

Reference implementation for educational purposes. Modify and distribute freely as part of your own mods.

## Next Steps

1. Copy this directory
2. Adjust item IDs to your items
3. Modify multipliers and conditions
4. Test in-game
5. Customize hooks as needed

No additional setup, no undocumented dependencies, no trial-and-error.
