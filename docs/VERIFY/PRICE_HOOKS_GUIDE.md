# Dynamic Buy & Sell Price Hooks System

This document describes the dynamic price hook system for the Shops mod, enabling mods to affect item prices at runtime without mutating base price values.

## Overview

**Goal**: Provide a composable, MP-safe system for dynamic price modification

**Key Features**:
- Immutable base prices (registries never modified)
- Runtime price calculation on demand
- Multiple hooks can affect a single price (additive modifiers)
- Server-authoritative pricing (client preview, server final)
- Separate buy and sell pipelines
- Support for modifier stacking and final overrides

---

## Core Events

Four events control the price calculation pipeline:

```lua
Events.OnShopModifyBuyPrice    -- Add modifiers to buy prices
Events.OnShopOverrideBuyPrice  -- Override final buy price
Events.OnShopModifySellPrice   -- Add modifiers to sell prices
Events.OnShopOverrideSellPrice -- Override final sell price
```

### Event Signatures

#### OnShopModifyBuyPrice
```lua
Events.OnShopModifyBuyPrice.Add(function(player, itemId, basePrice, context, modifiers)
    -- player: ISCharacter
    -- itemId: string (e.g., "Base.Hammer")
    -- basePrice: number (from Shop.Items[itemId].price)
    -- context: table with {shopId, quantity, isSpecialCoin, isBroken}
    -- modifiers: table (output) - add modifiers here
end)
```

**Modifiers Table Format**:
```lua
table.insert(modifiers, {
    multiplier = 0.9,  -- optional: multiply final price
    add = 10,          -- optional: add to final price
})
```

Modifiers are applied in order: all multipliers, then all additions.

#### OnShopModifySellPrice
```lua
Events.OnShopModifySellPrice.Add(function(player, item, basePrice, context, modifiers)
    -- player: ISCharacter
    -- item: InventoryItem (the item being sold)
    -- basePrice: number (from Shop.Sell rules or default)
    -- context: table with {shopId, quantity, isSpecialCoin, isBroken}
    -- modifiers: table (output) - add modifiers here
end)
```

#### OnShopOverrideBuyPrice
```lua
Events.OnShopOverrideBuyPrice.Add(function(player, itemId, computedPrice, context)
    -- player: ISCharacter
    -- itemId: string
    -- computedPrice: number (result of applying all modifiers)
    -- context: table with {shopId, quantity, isSpecialCoin, isBroken}
    -- Return: number (final price) or nil (use computed price)
end)
```

#### OnShopOverrideSellPrice
```lua
Events.OnShopOverrideSellPrice.Add(function(player, item, computedPrice, context)
    -- player: ISCharacter
    -- item: InventoryItem
    -- computedPrice: number (result of applying all modifiers)
    -- context: table with {shopId, quantity, isSpecialCoin, isBroken}
    -- Return: number (final price), 0 (worthless), or nil (use computed price)
end)
```

---

## Context Object

All price calculations receive a **context** table for decision-making:

```lua
context = {
    shopId = "Kiosk01",        -- Identifier of the shop
    quantity = 1,              -- How many items being bought/sold
    isSpecialCoin = false,     -- Use special currency?
    isBroken = false,          -- Item is damaged/condition low
}
```

**Context is read-only** and identical on client and server.

---

## Price Calculation Pipeline

### Buy Price Flow
1. **Base Price**: Fetch from `Shop.Items[itemId].price`
2. **Modify Phase**: Trigger `OnShopModifyBuyPrice` - mods add modifiers
3. **Apply Modifiers**: Stack all multipliers and additions (clamped to 0)
4. **Override Phase**: Trigger `OnShopOverrideBuyPrice` - mods can replace final price
5. **Return**: Final price (or base if no hooks)

### Sell Price Flow
1. **Base Price**: Fetch from `Shop.Sell[itemId].price` or default
2. **Blacklist Check**: Return `nil` if item is blacklisted (unsellable)
3. **Modify Phase**: Trigger `OnShopModifySellPrice` - mods add modifiers
4. **Apply Modifiers**: Stack all multipliers and additions (clamped to 0)
5. **Override Phase**: Trigger `OnShopOverrideSellPrice` - mods can replace final price
6. **Return**: Final price or `nil` (if blacklisted or overridden as nil)

---

## API Functions

### Shop.CalculateBuyPrice(player, itemId, context) → number
Calculate the final buy price for an item.

```lua
local context = {
    shopId = "Kiosk01",
    quantity = 1,
    isSpecialCoin = false,
    isBroken = false,
}
local price = Shop.CalculateBuyPrice(player, "Base.Hammer", context)
```

### Shop.CalculateSellPrice(player, item, context) → number | nil
Calculate the final sell price for an inventory item.

Returns `nil` if the item is unsellable (blacklisted).

```lua
local context = {
    shopId = "Kiosk01",
    quantity = 1,
    isSpecialCoin = false,
    isBroken = false,
}
local price = Shop.CalculateSellPrice(player, invItem, context)
if price == nil then
    -- Item cannot be sold
end
```

---

## Example Hooks

### Example 1: Buy Discount for Discount Card Holders

```lua
Events.OnShopModifyBuyPrice.Add(function(player, itemId, basePrice, ctx, modifiers)
    if player:HasItem("KnoxBank.DiscountCard") then
        table.insert(modifiers, { multiplier = 0.9 })  -- 10% off
    end
end)
```

### Example 2: Bulk Sell Bonus

```lua
Events.OnShopModifySellPrice.Add(function(player, item, basePrice, ctx, modifiers)
    if ctx.quantity >= 10 then
        table.insert(modifiers, { multiplier = 1.2 })  -- 20% bonus
    end
end)
```

### Example 3: VIP Price Override

```lua
Events.OnShopOverrideBuyPrice.Add(function(player, itemId, price, ctx)
    if player:getModData().isVIP then
        return math.floor(price * 0.5)  -- VIP pays 50% of computed price
    end
    return nil  -- Use computed price
end)
```

### Example 4: Broken Items Are Worthless

```lua
Events.OnShopOverrideSellPrice.Add(function(player, item, price, ctx)
    if ctx.isBroken then
        return 0  -- Worthless
    end
    return nil
end)
```

---

## Integration Points

### Client-Side (ShopUI.lua)
- **Buy Items Display**: Prices calculated when populating shop tabs (Favorites, All, etc.)
- **Cart Preview**: Prices recalculated when building buy ticket (for preview accuracy)
- **Sell Items Display**: Prices calculated when populating sell tab
- **Sell Cart Preview**: Prices recalculated when building sell list

### Server-Side (ShopBuyAction.lua, ShopSellAction.lua)
- **Buy Complete**: Prices recalculated authoritatively before balance deduction
- **Sell Complete**: Prices recalculated authoritatively per item

### Result
Client shows accurate price preview; server computes final price for transaction.

---

## Implementation Checklist

- [x] Create `ShopPriceEvents.lua` - Event declarations
- [x] Create `ShopPriceUtils.lua` - Modifier application logic
- [x] Create `ShopPriceBuy.lua` - Buy price pipeline
- [x] Create `ShopPriceSell.lua` - Sell price pipeline
- [x] Integrate into `Shop.lua` - Require files
- [x] Update `ShopUI.lua` - Call price calculators for buy items
- [x] Update `ShopUI.lua` - Call price calculators for sell items
- [x] Update `ShopUI.lua` - Recalculate in `buildBuyTicket()`
- [x] Update `ShopUI.lua` - Recalculate in `buildSellList()`
- [x] Update `ShopBuyAction.lua` - Server-side authoritative pricing
- [x] Update `ShopSellAction.lua` - Server-side authoritative pricing
- [x] Create example hooks for verification

---

## Verification

### Test Case 1: No Hooks
Expected: Prices match base values.

### Test Case 2: Modifier Stacking
Add two modifiers (0.9x and +10). Verify multiplication first, then addition.

### Test Case 3: Override
Add modifier hook and override hook. Override should replace final value.

### Test Case 4: Server Authority
Client tampers with prices in cart. Server recomputes and charges correct amount.

### Test Case 5: Sell Blacklist
Mark item as blacklisted. Verify it cannot be sold (returns nil).

---

## Non-Goals (Do NOT implement)

- ❌ Mutating `Shop.Items` or `Shop.Sell` in hooks
- ❌ Caching computed prices (calculate on demand)
- ❌ Client-only price logic without server validation
- ❌ Per-frame price recalculation (only on cart/transaction)
- ❌ Bypassing registry locks

---

## Files Modified

- `Shop.lua` - Added requires for price system
- `ShopUI.lua` - Integrated price calculation in item display and ticket building
- `ShopBuyAction.lua` - Server-side authoritative pricing
- `ShopSellAction.lua` - Server-side authoritative pricing

## Files Created

- `ShopPriceEvents.lua` - Event declarations
- `ShopPriceUtils.lua` - Utility functions
- `ShopPriceBuy.lua` - Buy pipeline
- `ShopPriceSell.lua` - Sell pipeline
- Examples: `ExampleBuyDiscountHook.lua`, `ExampleSellBonusHook.lua`, `ExampleOverrideHook.lua`

---

## Final Validation

✓ Base prices are never mutated
✓ Prices are calculated at runtime
✓ Multiple mods can affect price composition
✓ Client preview uses same logic as server
✓ Server recomputes price authoritatively
✓ Buy and sell pipelines are separate but symmetric
✓ Hooks are additive and composable
✓ Registry locks are maintained

**Status**: Implementation Complete ✓
