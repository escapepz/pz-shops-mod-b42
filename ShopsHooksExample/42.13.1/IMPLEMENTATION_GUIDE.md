# ShopsHooksExample — Implementation Guide

A **server-side-only reference implementation** demonstrating the 3 core Shops price hook patterns.

## Quick Overview

This mod is intentionally **minimal and focused**. It demonstrates:

1. **Modifier Hook Pattern** — Append multipliers to stack with other mods
2. **Override Hook Pattern** — Return final price or nil for short-circuit behavior
3. **Buy vs Sell Asymmetry** — ItemId string vs item object, different signatures

**Not included**: VIP system, time-based pricing, reputation, bulk discounts, client code.

---

## File Structure

```
ShopsHooksExample/42.13.1/media/lua/server/
├── ShopsHooksExample_init.lua          ← PZ server entry point
└── nshopsb42/
    ├── ShopsHooksExampleInit.lua       ← Hook registration
    ├── ShopsHooksExampleHooks.lua      ← Hook implementations
    └── ShopsHooksExampleState.lua      ← Configuration
```

### Module Responsibilities

| File                       | Lines | Purpose                                |
| -------------------------- | ----- | -------------------------------------- |
| ShopsHooksExampleInit.lua  | 94    | Hook registration via ShopPriceEvents  |
| ShopsHooksExampleHooks.lua | 180   | 3 hook implementations                 |
| ShopsHooksExampleState.lua | 25    | Configuration (multipliers, overrides) |

---

## Pattern 1: Modifier Hooks

### What They Do

Append a multiplier to the `modifiers` array. All modifier hooks execute, and multipliers **stack**:

```
Price = Base × M1 × M2 × M3 × ...
```

### Example: Fruit Category Discount

```lua
function Hooks.modifyAppleBuyPrice(player, itemId, basePrice, context, modifiers)
    -- Guard: Only apply to Apple
    if itemId ~= "Base.Apple" then
        return
    end

    -- Guard: Ensure modifiers exists
    if not modifiers then
        return
    end

    -- Append multiplier
    table.insert(modifiers, {
        multiplier = 0.9,
        label = "appleFruitDiscount"
    })
end
```

### Hook Signature

```lua
function(player, itemId, basePrice, context, modifiers)
    -- player: Player object (may be nil)
    -- itemId: Item ID string (e.g., "Base.Apple")
    -- basePrice: Numeric price before modifications
    -- context: Table with shopId, quantity, etc.
    -- modifiers: Array to append to

    table.insert(modifiers, { multiplier = X })
end
```

### Key Points

- ✅ **Returns**: nil (modifications happen via side-effect)
- ✅ **Multiple hooks**: All execute in order registered
- ✅ **Stacking**: Price multiplied by each modifier
- ✅ **ItemId**: Buy hooks receive string, not object
- ✅ **Guards**: Always check for nil before use

### Common Modifications

**Category Markup:**

```lua
if string.find(itemId, "Weapon") then
    table.insert(modifiers, { multiplier = 1.3 })
end
```

**Quantity Bonus:**

```lua
if context.quantity >= 10 then
    table.insert(modifiers, { multiplier = 0.85 })
end
```

**Reputation Discount (if you extend):**

```lua
if player and player:getProperty("reputation") > 100 then
    table.insert(modifiers, { multiplier = 0.9 })
end
```

---

## Pattern 2: Override Hooks

### What They Do

Return a **final price** to short-circuit modifier stacking, or **nil** to use calculated price.

### Example: Optional Fixed Price

```lua
function Hooks.overrideAppleBuyPrice(player, itemId, price, context)
    -- Guard: Only apply to Apple
    if itemId ~= "Base.Apple" then
        return nil
    end

    -- Check if override is enabled
    local overridePrice = ShopsHooksExampleState.appleOverrideBuyPrice
    if overridePrice == nil then
        return nil  -- Skip override, use modifiers
    end

    -- Return override (short-circuits modifiers)
    return overridePrice
end
```

### Hook Signature

```lua
function(player, itemId, price, context)
    -- player: Player object (may be nil)
    -- itemId: Item ID string
    -- price: Current calculated price
    -- context: Table with shopId, quantity, etc.

    return finalPrice or nil  -- MUST return something
end
```

### Key Points

- ✅ **Returns**: Numeric price (apply) or nil (skip)
- ✅ **Short-circuit**: First non-nil return stops chain
- ✅ **Order**: First matching override wins
- ✅ **Must return**: Always return something (nil or price)
- ✅ **Optional**: Override disabled by default (nil)

### Override Execution Order

```
1. Modifier hooks run (all of them)
2. Price = Base × M1 × M2 × M3 × ...
3. Override hook 1 runs:
   - If returns price → USE IT (stop)
   - If returns nil → CONTINUE
4. Override hook 2 runs (if hook 1 returned nil)
   - If returns price → USE IT (stop)
   - If returns nil → CONTINUE
5. If all overrides return nil → USE CALCULATED PRICE
```

### Common Overrides

**Fixed Prices:**

```lua
local specialPrices = {
    ["Base.Water"] = 10,
    ["Base.Pop"] = 15,
}

if specialPrices[itemId] then
    return specialPrices[itemId]
end

return nil
```

**Admin Free Items:**

```lua
if player and player:isAdmin() then
    return 0  -- Free
end

return nil
```

**Condition-based Pricing (sell):**

```lua
if item:getCondition() < 30 then
    return 0  -- Won't buy damaged
end

return nil
```

---

## Pattern 3: Buy vs Sell Asymmetry

### Why Different?

**Buy hooks** decide price for player purchasing from shop:

- Item ID only (string)
- Simple: category, time, reputation, bulk

**Sell hooks** decide price for player selling to shop:

- Full item object (with condition, wear, etc.)
- Complex: condition-based, item-specific logic

### Buy Hook Signature

```lua
function(player, itemId, basePrice, context, modifiers)
    -- Receives: itemId STRING
    -- Example: "Base.Apple"

    if itemId ~= "Base.Apple" then return end
end
```

### Sell Hook Signature

```lua
function(player, item, basePrice, context, modifiers)
    -- Receives: item OBJECT
    -- Must use: item:getFullType(), item:getCondition()

    local itemId = item:getFullType()  -- Get ID from object
    if itemId ~= "Base.Apple" then return end

    local condition = item:getCondition()  -- Get quality (0-100)
    if condition < 50 then
        table.insert(modifiers, { multiplier = 0.5 })
    end
end
```

### Key Differences

| Aspect        | Buy                     | Sell                  |
| ------------- | ----------------------- | --------------------- |
| Item param    | String ID (`itemId`)    | Object (`item`)       |
| Signature     | `(player, itemId, ...)` | `(player, item, ...)` |
| Get ID        | Use directly            | `item:getFullType()`  |
| Extra data    | Limited                 | `item:getCondition()` |
| Typical logic | Category, time          | Condition, quality    |

### When to Use Each

**Modify hooks** (shared approach):

```lua
-- Buy: Easy, just filter by itemId
if itemId == "Base.Apple" then
    table.insert(modifiers, { multiplier = 0.9 })
end

-- Sell: Need item object for condition
if item:getFullType() == "Base.Apple" then
    local condition = item:getCondition()
    local mult = condition < 50 and 0.5 or 1.0
    table.insert(modifiers, { multiplier = mult })
end
```

**Override hooks**:

```lua
-- Buy: Check itemId string
function overrideBuyPrice(player, itemId, price, context)
    if itemId ~= "Base.Apple" then return nil end
    return 5  -- Fixed price
end

-- Sell: Check item object and condition
function overrideSellPrice(player, item, price, context)
    if item:getFullType() ~= "Base.Bat" then return nil end
    if item:getCondition() < 30 then return 0 end  -- Won't buy
    return nil  -- Use calculated price
end
```

---

## Configuration

All configuration is in `ShopsHooksExampleState.lua`:

```lua
-- Apple buy price multiplier (0.9 = 10% discount)
State.appleBuyMultiplier = 0.9

-- Apple buy price override (nil = disabled, or set to numeric value)
State.appleOverrideBuyPrice = nil
```

### At Runtime

To change configuration after initialization:

```lua
-- Change multiplier
SHOPSB42.ShopsHooksExampleState.appleBuyMultiplier = 0.5

-- CRITICAL: Trigger resync
SHOPSB42.ShopFinalizeHandler.onPriceHooksChanged()
```

Without calling `onPriceHooksChanged()`, the new value won't take effect until server restart.

---

## Common Implementation Tasks

### Task 1: Add a New Item

**Step 1:** Update configuration to add new item

In `ShopsHooksExampleHooks.lua`, add check:

```lua
function Hooks.modifyAppleBuyPrice(player, itemId, basePrice, context, modifiers)
    if itemId ~= "Base.Apple" and itemId ~= "Base.Banana" then
        return
    end

    table.insert(modifiers, {
        multiplier = 0.9,
        label = "fruitDiscount"
    })
end
```

**Step 2:** Test in-game

- Buy the new item
- Check server logs for hook execution

### Task 2: Change Multiplier Value

Edit `ShopsHooksExampleState.lua`:

```lua
-- Old: 0.9 (10% discount)
State.appleBuyMultiplier = 0.5  -- New: 50% discount
```

Then restart server, or call:

```lua
SHOPSB42.ShopFinalizeHandler.onPriceHooksChanged()
```

### Task 3: Add Time-Based Pricing

Create new hook in `ShopsHooksExampleHooks.lua`:

```lua
function Hooks.modifyAppleBuyPriceByTime(player, itemId, basePrice, context, modifiers)
    if itemId ~= "Base.Apple" then return end
    if not modifiers then return end

    local hour = getGameTime():getHour()

    -- Night premium (11 PM - 6 AM): +15%
    if hour >= 23 or hour < 6 then
        table.insert(modifiers, {
            multiplier = 1.15,
            label = "nightPremium"
        })
    end
end
```

Register in `ShopsHooksExampleInit.lua`:

```lua
ShopPriceEvents.registerOnShopModifyBuyPrice(
    ShopsHooksExampleHooks.modifyAppleBuyPriceByTime
)
```

### Task 4: Add Reputation-Based Discount

Create new hook:

```lua
function Hooks.modifyAppleBuyPriceByReputation(player, itemId, basePrice, context, modifiers)
    if itemId ~= "Base.Apple" then return end
    if not player or not modifiers then return end

    local reputation = player:getProperty("mymod_reputation") or 0

    if reputation > 100 then
        table.insert(modifiers, {
            multiplier = 0.9,
            label = "reputationDiscount"
        })
    end
end
```

---

## Debugging

### Check Hook Registration

Server logs should show:

```
[ShopsHooksExample] Registered: modifyAppleBuyPrice
[ShopsHooksExample] Registered: overrideAppleBuyPrice
[ShopsHooksExample] Registered: modifySellPriceByCondition
[ShopsHooksExample] All hooks registered successfully
```

**Location**: `Logs/Server/*_Shops.txt`

### Check Hook Execution

When you buy/sell, you should see:

```
[ShopsHooksExample] Applied buy modifier to Base.Apple: multiplier=0.9
[ShopsHooksExample] Applied condition modifier to Base.Apple: condition=85, multiplier=1.0
```

### Enable Debug Logging

Logging is enabled by default. Check server logs during transactions.

### Test Prices Manually

```lua
-- In server console:
local player = getPlayer()
local finalPrice = Shop.resolvePlayerBuyPrice(player, "Base.Apple", {shopId = "test", quantity = 1})
print("Final price: " .. finalPrice)
```

---

## Performance Considerations

### Modifier Hooks

Called **per transaction** when player buys item. Minimize work:

✅ **Good:**

```lua
if itemId ~= "Base.Apple" then return end  -- Early exit
local mult = ShopsHooksExampleState.appleBuyMultiplier
table.insert(modifiers, { multiplier = mult })
```

❌ **Bad:**

```lua
for i = 1, 1000 do  -- Expensive loop
    -- Do something
end
table.insert(modifiers, {...})
```

### Override Hooks

Called **per transaction**, check conditions first:

✅ **Good:**

```lua
if itemId ~= "Base.Apple" then return nil end  -- Fast exit
-- Expensive operation only if needed
```

❌ **Bad:**

```lua
-- Expensive operation first
local expensiveValue = expensiveFunction()

if itemId ~= "Base.Apple" then return nil end
```

---

## Examples

### Complete Buy Modifier Example

```lua
function Hooks.modifyAppleBuyPrice(player, itemId, basePrice, context, modifiers)
    -- Guard: Item filter
    if itemId ~= "Base.Apple" then
        return
    end

    -- Guard: Nil check
    if not modifiers then
        return
    end

    -- Get current multiplier from state
    local multiplier = ShopsHooksExampleState.appleBuyMultiplier

    -- Append to modifiers (stacks with others)
    table.insert(modifiers, {
        multiplier = multiplier,
        label = "appleFruitDiscount"
    })

    -- Log for debugging
    SharedLogger.log(
        "Shops",
        "[ShopsHooksExample] Applied buy modifier to Base.Apple: multiplier=" .. multiplier
    )
end
```

### Complete Buy Override Example

```lua
function Hooks.overrideAppleBuyPrice(player, itemId, price, context)
    -- Guard: Item filter
    if itemId ~= "Base.Apple" then
        return nil
    end

    -- Get override state
    local overridePrice = ShopsHooksExampleState.appleOverrideBuyPrice

    -- If not set, use calculated price
    if overridePrice == nil then
        return nil
    end

    -- Log when override applies
    SharedLogger.log(
        "Shops",
        "[ShopsHooksExample] Overriding Apple buy price: " .. price .. " -> " .. overridePrice
    )

    -- Return override (short-circuits)
    return overridePrice
end
```

### Complete Sell Modifier Example

```lua
function Hooks.modifySellPriceByCondition(player, item, basePrice, context, modifiers)
    -- Guard: Nil checks
    if not item or not modifiers then
        return
    end

    -- Get item ID from object
    local itemId = item:getFullType()

    -- Guard: Only apply to specific items
    if itemId ~= "Base.Apple" and itemId ~= "Base.BaseballBat" then
        return
    end

    -- Get item condition (0-100)
    local condition = item:getCondition()

    -- Calculate multiplier based on condition
    local multiplier = 1.0
    if condition < 50 then
        multiplier = 0.5  -- Poor condition: 50% of price
    elseif condition < 75 then
        multiplier = 0.85  -- Fair condition: 85% of price
    end

    -- Only add modifier if it changes price
    if multiplier ~= 1.0 then
        table.insert(modifiers, {
            multiplier = multiplier,
            label = "conditionFactor"
        })

        SharedLogger.log(
            "Shops",
            "[ShopsHooksExample] Applied condition modifier to " .. itemId ..
            ": condition=" .. condition .. ", multiplier=" .. multiplier
        )
    end
end
```

---

## Testing

### Minimal Test

1. Enable mod
2. Buy Base.Apple
3. Check server logs for "Applied buy modifier"
4. Verify price is reduced (0.9x = 10% discount)

### Override Test

1. Set override: `SHOPSB42.ShopsHooksExampleState.appleOverrideBuyPrice = 5`
2. Call resync: `SHOPSB42.ShopFinalizeHandler.onPriceHooksChanged()`
3. Buy Base.Apple
4. Verify price is exactly 5
5. Check logs for "Overriding Apple buy price"

### Condition Test

1. Get Base.Apple from ground (condition < 100)
2. Sell to shop
3. Verify price reduced by condition factor
4. Check logs for "Applied condition modifier"

---

## Next Steps

1. **Read README.md** for complete feature overview
2. **Read ShopsHooksExampleInit.lua** to understand registration
3. **Read ShopsHooksExampleHooks.lua** to see implementations
4. **Read ShopsHooksExampleState.lua** for configuration
5. **Modify** item IDs to your items
6. **Adjust** multipliers to your preferences
7. **Test** in-game with logging enabled
8. **Extend** by adding more hooks following these patterns

---

**Implementation Guide — ShopsHooksExample**  
Server-only reference for Shops B42.13.1 price hooks
