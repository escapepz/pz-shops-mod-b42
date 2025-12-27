# Price Hooks Runtime Error Fix

## The Problem

The original code attempted to call `Events.OnShopModifyBuyPrice` as a function:

```lua
-- ShopPriceBuy.lua, line 16
Events.OnShopModifyBuyPrice.Trigger(
    player, itemId, base, context, modifiers
)
```

This caused a **critical runtime crash**:

```
Object table 0x1013384674 did not have __call metatable set
```

### Root Cause

- `ShopPriceEvents.lua` created `Events.OnShopModifyBuyPrice` as an **empty table** via `LuaEventManager.AddEvent()`
- The price calculation code tried to **call it as a function**: `Events.OnShopModifyBuyPrice(...)`
- Lua tables without a `__call` metatable cannot be invoked
- This is a **B41-era assumption** that does not exist in B42

---

## The Solution

Replaced the broken event system with a **callback-based price hook system**.

### New Architecture

**ShopPriceHooks.lua** provides:

```lua
-- For modders to hook into price calculations
Shop.PriceHooks.onBuyModifyPrice(fn)       -- Modify buy prices
Shop.PriceHooks.onBuyOverridePrice(fn)     -- Override buy prices
Shop.PriceHooks.onSellModifyPrice(fn)      -- Modify sell prices
Shop.PriceHooks.onSellOverridePrice(fn)    -- Override sell prices

-- Called by ShopPriceBuy.lua and ShopPriceSell.lua
Shop.PriceHooks._executeBuyModifyCallbacks(...)
Shop.PriceHooks._executeBuyOverrideCallbacks(...)
Shop.PriceHooks._executeSellModifyCallbacks(...)
Shop.PriceHooks._executeSellOverrideCallbacks(...)
```

### Updated Files

| File | Change | Reason |
|------|--------|--------|
| **ShopPriceHooks.lua** | Created | New callback-based system |
| **ShopPriceBuy.lua** | Fixed | Now calls hook functions correctly |
| **ShopPriceSell.lua** | Fixed | Now calls hook functions correctly |
| **ShopPriceEvents.lua** | Deprecated | No longer needed; replaced by ShopPriceHooks |
| **Shop.lua** | Updated | Now requires ShopPriceHooks instead of ShopPriceEvents |

---

## Before vs After

### Before (Broken)

```lua
-- ShopPriceBuy.lua
local modifiers = {}

-- ❌ This crashes: Events.OnShopModifyBuyPrice is a table, not a function
Events.OnShopModifyBuyPrice.Trigger(
    player, itemId, base, context, modifiers
)
```

### After (Fixed)

```lua
-- ShopPriceBuy.lua
-- Phase 1: Execute modify hooks (allow modders to add multipliers/modifiers)
local modifiers = Shop.PriceHooks._executeBuyModifyCallbacks(
    player, itemId, base, context
)

-- Phase 2: Execute override hooks (allow modders to replace price entirely)
local override = Shop.PriceHooks._executeBuyOverrideCallbacks(
    player, itemId, price, context
)
```

---

## How Modders Use This (Clean API)

### Example 1: Modify Buy Price

```lua
-- MyMod_ShopHooks.lua
Shop.PriceHooks.onBuyModifyPrice(function(player, itemId, basePrice, context, modifiers)
    -- 10% discount for everyone
    table.insert(modifiers, { multiplier = 0.9 })
end)
```

### Example 2: Override Sell Price

```lua
Shop.PriceHooks.onSellOverridePrice(function(player, item, calculatedPrice, context)
    -- Damaged items (condition < 50) worth half price
    if item:getCondition() < 50 then
        return math.floor(calculatedPrice * 0.5)
    end
    return nil  -- use calculated price
end)
```

---

## Technical Details

### Callback Registration (Load Time)

```lua
-- Modders register callbacks during mod load
Shop.PriceHooks.onBuyModifyPrice(myCustomHook)
```

Callbacks are stored in:
- `Shop.PriceHooks._buyModifyCallbacks`
- `Shop.PriceHooks._buyOverrideCallbacks`
- `Shop.PriceHooks._sellModifyCallbacks`
- `Shop.PriceHooks._sellOverrideCallbacks`

### Callback Execution (Runtime)

```lua
-- ShopPriceBuy.lua calls these when calculating price
local modifiers = Shop.PriceHooks._executeBuyModifyCallbacks(...)

-- Each callback in the list is executed in order
for _, fn in ipairs(Shop.PriceHooks._buyModifyCallbacks) do
    fn(player, itemId, basePrice, context, modifiers)
end
```

---

## B42 Compliance

✅ No engine event system abuse  
✅ No undefined globals  
✅ No `__call` metatable errors  
✅ Deterministic execution order  
✅ MP-safe (shared Lua)  
✅ Extensible for future enhancements  

---

## Backwards Compatibility

- ✅ Existing code that calls `Shop.CalculateBuyPrice()` works unchanged
- ✅ Existing code that registers items still works unchanged
- ❌ Code that tried to hook into `Events.OnShopModifyBuyPrice` will not work (it was broken anyway in B42)

For mods that need price hooks, use the new `Shop.PriceHooks.onBuyModifyPrice()` API instead.

---

## Verification

No more crashes:
```
❌ Before: Object table 0x1013384674 did not have __call metatable set
✅ After: Clean price calculations with callback execution
```

All price calculations now properly execute registered callbacks without runtime errors.
