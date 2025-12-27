# Dynamic Price Hooks - Implementation Summary

## What Was Implemented

A complete **dynamic buy and sell price hook system** for the Shops mod, enabling mods to modify item prices at runtime without mutating base prices.

---

## Core Files Created

### 1. ShopPriceEvents.lua
Declares four events for price modification:
- `Events.OnShopModifyBuyPrice` - Add modifiers to buy prices
- `Events.OnShopOverrideBuyPrice` - Override final buy price
- `Events.OnShopModifySellPrice` - Add modifiers to sell prices  
- `Events.OnShopOverrideSellPrice` - Override final sell price

### 2. ShopPriceUtils.lua
Provides `applyModifiers(base, modifiers)` function:
- Applies multiplier then addition to price
- Clamps to non-negative values
- Floors result to integer

### 3. ShopPriceBuy.lua
Implements `Shop.CalculateBuyPrice(player, itemId, context)`:
- Reads base price from registry
- Triggers modify event to collect modifiers
- Applies modifiers using utility
- Triggers override event for final replacement
- Returns computed or overridden price

### 4. ShopPriceSell.lua
Implements `Shop.CalculateSellPrice(player, item, context)`:
- Checks blacklist first (returns nil if blacklisted)
- Reads base price from registry or default
- Triggers modify event
- Applies modifiers
- Triggers override event
- Returns computed/overridden price or nil

---

## Integration Points

### Shop.lua
Added requires for all price modules, ensuring they load on game startup.

### ShopUI.lua (Client-Side)
**Buy Items Display**:
- Favorites tab: Calls `CalculateBuyPrice()` for each item
- All/category tabs: Calls `CalculateBuyPrice()` for each item

**Sell Items Display**:
- Calls `CalculateSellPrice()` for each sellable item

**Cart Preview**:
- `buildBuyTicket()`: Recalculates prices before accumulating total
- `buildSellList()`: Recalculates prices for each item in sell list

### ShopBuyAction.lua (Server-Side)
**complete() function**:
- Recomputes prices authoritatively before balance check
- Validates balance against server-computed totals
- Deducts server-computed amounts from account
- Spawns items

**Result**: Server prices override client, preventing tampering.

### ShopSellAction.lua (Server-Side)
**complete() function**:
- Recomputes price for each item before removal
- Handles nil return (blacklisted items skipped)
- Accumulates server-computed totals
- Deposits server-computed amounts to account

**Result**: Server prices override client, preventing tampering.

---

## Context Object

All price functions receive a context table:
```lua
{
    shopId = "Kiosk01",        -- Shop identifier
    quantity = 1,              -- Number of items
    isSpecialCoin = false,     -- Special currency?
    isBroken = false,          -- Item damaged?
}
```

This allows hooks to make context-aware pricing decisions.

---

## Event Usage Pattern

### Modify Hook (Additive)
```lua
Events.OnShopModifyBuyPrice.Add(function(player, itemId, base, ctx, mods)
    if player:HasItem("DiscountCard") then
        table.insert(mods, { multiplier = 0.9 })
    end
end)
```

### Override Hook (Replacement)
```lua
Events.OnShopOverrideBuyPrice.Add(function(player, itemId, price, ctx)
    if player:getModData().isVIP then
        return math.floor(price * 0.5)
    end
    return nil  -- Use computed value
end)
```

---

## Example Hooks Provided

1. **ExampleBuyDiscountHook.lua** - 10% discount for badge holders
2. **ExampleSellBonusHook.lua** - 20% bonus for bulk sales (10+ items)
3. **ExampleOverrideHook.lua** - VIP override and broken item handling

---

## Key Design Decisions

### ✅ Immutable Registries
Prices calculated fresh, never stored. Base prices protected from modification.

### ✅ Runtime Calculation
Prices computed on demand (when displayed, when transacted), enabling truly dynamic economy.

### ✅ Client Preview + Server Authority
Client shows accurate preview using same logic as server. Server recomputes before commitment, preventing tampering.

### ✅ Separate Pipelines
Buy and sell have distinct flows (different item types, different base sources), but share modifier application system.

### ✅ Additive Hooks
Multiple mods can add modifiers without conflict. All modifiers apply. Last override wins.

### ✅ Context-Aware
Hooks receive full context (shop, quantity, coin type, condition) to make informed decisions.

---

## Acceptance Criteria Met

| Criterion | Status |
|-----------|--------|
| Base prices never mutated | ✅ |
| Prices calculated at runtime | ✅ |
| Multiple mods can affect prices | ✅ |
| Client preview matches server logic | ✅ |
| Server recomputes authoritatively | ✅ |
| Buy and sell pipelines separate | ✅ |
| Hooks are additive/composable | ✅ |
| Registry locks maintained | ✅ |

---

## Usage for Mod Developers

To add a price hook:

```lua
-- Buy price modifier
Events.OnShopModifyBuyPrice.Add(function(player, itemId, base, ctx, out)
    if someCondition then
        table.insert(out, { multiplier = 0.95, add = 0 })
    end
end)

-- Buy price override
Events.OnShopOverrideBuyPrice.Add(function(player, itemId, price, ctx)
    if someOtherCondition then
        return 100  -- Fixed price
    end
    return nil
end)

-- Sell price modifier
Events.OnShopModifySellPrice.Add(function(player, item, base, ctx, out)
    if item:getCondition() < 0.5 then
        table.insert(out, { multiplier = 0.5 })  -- Half price for damaged
    end
end)

-- Sell price override
Events.OnShopOverrideSellPrice.Add(function(player, item, price, ctx)
    if item:isRotten() then
        return 0  -- Worthless
    end
    return nil
end)
```

---

## File Statistics

| Category | Count |
|----------|-------|
| Files Created | 7 |
| Files Modified | 4 |
| Events Declared | 4 |
| Functions Implemented | 2 |
| Documentation Files | 3 |
| Example Hooks | 3 |

---

## Next Steps for Users

1. **Load the system**: Already integrated into Shop.lua
2. **Optional**: Review PRICE_HOOKS_GUIDE.md for detailed API
3. **Create hooks**: Use example hooks as templates
4. **Test**: Verify prices in-game with and without hooks
5. **Deploy**: No configuration needed; hooks auto-discovered

---

## Non-Breaking Changes

This implementation:
- ✅ Does not modify existing APIs
- ✅ Does not change base registration system
- ✅ Does not require config changes
- ✅ Maintains backward compatibility
- ✅ Works with existing Shop.Items and Shop.Sell

Existing shops continue to work exactly as before. Dynamic pricing is opt-in via event listeners.

---

## Performance Impact

- **Memory**: Minimal (event listeners, modifiers stored in stack)
- **CPU**: Price calculation is O(modifiers) per price calc
- **Impact**: Negligible for typical hook counts (<5 per event)

---

**Status**: ✅ Complete and ready for use.

See PRICE_HOOKS_GUIDE.md for comprehensive documentation.
