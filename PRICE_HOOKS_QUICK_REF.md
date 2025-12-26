# Dynamic Price Hooks - Quick Reference

## Event Signatures

### OnShopModifyBuyPrice
```lua
Events.OnShopModifyBuyPrice.Add(function(player, itemId, basePrice, context, modifiers)
    table.insert(modifiers, { multiplier = 0.9, add = 10 })
end)
```

### OnShopOverrideBuyPrice
```lua
Events.OnShopOverrideBuyPrice.Add(function(player, itemId, computedPrice, context)
    return 50  -- or nil for default
end)
```

### OnShopModifySellPrice
```lua
Events.OnShopModifySellPrice.Add(function(player, item, basePrice, context, modifiers)
    table.insert(modifiers, { multiplier = 1.2 })
end)
```

### OnShopOverrideSellPrice
```lua
Events.OnShopOverrideSellPrice.Add(function(player, item, computedPrice, context)
    return 0  -- or nil for default
end)
```

---

## Context Object

```lua
context = {
    shopId = "Kiosk01",        -- Shop identifier
    quantity = 1,              -- Items being bought/sold
    isSpecialCoin = false,     -- Special currency?
    isBroken = false,          -- Item condition < 50%?
}
```

---

## Functions

### Buy Price
```lua
local price = Shop.CalculateBuyPrice(player, "Base.Hammer", context)
-- Returns: number (>= 0)
```

### Sell Price
```lua
local price = Shop.CalculateSellPrice(player, invItem, context)
-- Returns: number (>= 0) or nil (unsellable)
```

---

## Modifier Format

```lua
{ 
    multiplier = 0.9,  -- Optional: multiply price
    add = 10,          -- Optional: add to price
}
```

**Order**: All multipliers applied first, then additions. Result clamped to >= 0.

---

## One-Liners

### 10% Discount
```lua
Events.OnShopModifyBuyPrice.Add(function(p,id,b,ctx,out)
    table.insert(out, {multiplier=0.9})
end)
```

### 20% Markup
```lua
Events.OnShopModifySellPrice.Add(function(p,item,b,ctx,out)
    table.insert(out, {multiplier=1.2})
end)
```

### Fixed Price
```lua
Events.OnShopOverrideBuyPrice.Add(function(p,id,price,ctx)
    return 50
end)
```

### Conditional Block
```lua
Events.OnShopModifyBuyPrice.Add(function(p,id,b,ctx,out)
    if ctx.quantity >= 10 then
        table.insert(out, {multiplier=0.95})
    end
end)
```

---

## Common Patterns

### Player Status Check
```lua
if player:HasItem("DiscountCard") then ... end
if player:getModData().isVIP then ... end
if player:getSkillLevel("Bartering") >= 5 then ... end
```

### Context Checks
```lua
if ctx.quantity >= 10 then ... end
if ctx.isSpecialCoin then ... end
if ctx.isBroken then ... end
if ctx.shopId == "MarketStall" then ... end
```

### Item Checks (Sell)
```lua
if item:getCondition() < 0.5 then ... end
if item:isRotten() then ... end
if item:getFullType() == "Food.Apple" then ... end
```

### Math
```lua
local discounted = math.floor(price * 0.9)
local marked_up = math.floor(price * 1.25)
local flat_rate = 50
local calculated = math.floor(base * modifier + flat)
```

---

## Rules

1. ✅ **Read** context, player, item
2. ✅ **Add** modifiers or return override
3. ✅ **Never mutate** Shop.Items or Shop.Sell
4. ✅ **Use modifiers** for stacking effects
5. ✅ **Use overrides** for final replacement
6. ✅ **Return nil** in overrides to use computed value

---

## Files

**Core**:
- `ShopPriceEvents.lua` - Events
- `ShopPriceUtils.lua` - Utility
- `ShopPriceBuy.lua` - Buy pipeline
- `ShopPriceSell.lua` - Sell pipeline

**Examples**:
- `ExampleBuyDiscountHook.lua`
- `ExampleSellBonusHook.lua`
- `ExampleOverrideHook.lua`

**Docs**:
- `PRICE_HOOKS_GUIDE.md` - Full documentation
- `PRICE_HOOKS_VERIFICATION.md` - Acceptance criteria

---

## Integration

**Client** (ShopUI.lua):
- Item display → CalculateBuyPrice/CalculateSellPrice
- Cart preview → Recalculate per item

**Server** (ShopBuyAction/ShopSellAction):
- Complete → Recompute authoritatively
- Balance → Check against server prices
- Deduct/Deposit → Server amounts

---

**Status**: Ready to use. See PRICE_HOOKS_GUIDE.md for details.
