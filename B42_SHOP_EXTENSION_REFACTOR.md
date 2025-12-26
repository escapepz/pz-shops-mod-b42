# B42 Shop Extension System Refactor

## Summary

**Fixed invalid B41 API calls** in the Shop registration system and replaced them with a **B42-compliant explicit callback architecture**.

### What Was Broken

The original code contained invalid `triggerEvent()` calls:

```lua
-- ❌ INVALID (B41 assumption, does not exist in B42)
triggerEvent("OnShopRegisterItems")
triggerEvent("OnShopRegisterSellItems")
```

Project Zomboid B42 **does not expose a public `triggerEvent()` API**. These calls would silently fail or crash, breaking the extension system.

### What Was Changed

Replaced the broken event-based system with an **explicit callback registration API**:

```lua
-- ✔ CORRECT (B42-compliant)
Shop.RegisterItemCallback(function(items)
    items["MyMod.Item"] = { tab = "Weapons", price = 100 }
end)
```

---

## Files Modified

### NEW: **ShopPriceHooks.lua**

Implements callback-based price hooks:
- `Shop.PriceHooks.onBuyModifyPrice(fn)` - Hook into buy price modifications
- `Shop.PriceHooks.onBuyOverridePrice(fn)` - Override buy prices completely
- `Shop.PriceHooks.onSellModifyPrice(fn)` - Hook into sell price modifications
- `Shop.PriceHooks.onSellOverridePrice(fn)` - Override sell prices completely

### 1. **ShopRegistry.lua**

Added callback-based registration API:
- `Shop.RegisterItemCallback(fn)` - Register a callback to execute during finalization
- `Shop._executeItemRegistrars()` - Internal function to execute all registered callbacks

### 2. **ShopSellRegistry.lua**

Added callback-based registration API:
- `Shop.RegisterSellItemCallback(fn)` - Register a callback for sell items
- `Shop._executeSellRegistrars()` - Internal function to execute all registered callbacks

### 3. **ShopInit.lua**

Replaced invalid `triggerEvent("OnShopRegisterItems")` with:
```lua
Shop._executeItemRegistrars()
```

### 4. **ShopSellInit.lua**

Replaced invalid `triggerEvent("OnShopRegisterSellItems")` with:
```lua
Shop._executeSellRegistrars()
```

### 5. **Shop.lua**

Changed:
- `require "ShopPriceEvents"` → `require "ShopPriceHooks"` (use new callback system)

Removed:
- `require "ShopEvents"` and `require "ShopSellEvents"` (no longer needed)
- Invalid event listener registration code that tried to use `LuaEventManager`

### 6. **ShopPriceBuy.lua**

Fixed critical runtime error: replaced invalid `Events.OnShopModifyBuyPrice` calls with proper callback execution:
```lua
-- Before (broken)
if Events.OnShopModifyBuyPrice then
    Events.OnShopModifyBuyPrice(...)  -- ❌ Table has no __call metatable
end

-- After (correct)
local modifiers = Shop.PriceHooks._executeBuyModifyCallbacks(...)
```

### 7. **ShopPriceSell.lua**

Same fix as ShopPriceBuy.lua for sell price hooks.

### 8. **ShopEvents.lua** & **ShopSellEvents.lua** & **ShopPriceEvents.lua**

Converted to deprecation notices explaining the old systems are no longer used.

---

## How It Works (B42-Compliant Design)

### Initialization Flow

```
1. Shop.lua loads first
   ↓
2. ShopRegistry.lua / ShopSellRegistry.lua load
   (Define registration APIs)
   ↓
3. External mod files load
   (Call Shop.RegisterItemCallback(...))
   ↓
4. ShopInit.lua calls Shop.FinalizeRegistry()
   ├─ Shop._executeItemRegistrars() (calls all callbacks)
   ├─ Load defaults if no external registrations
   ├─ Commit all items to Shop.Items
   └─ Lock registry
   ↓
5. ShopSellInit.lua calls Shop.FinalizeSellRegistry()
   ├─ Shop._executeSellRegistrars() (calls all callbacks)
   ├─ Load defaults if no external registrations
   ├─ Commit all items to Shop.Sell
   └─ Lock registry
```

### Key Guarantees (B42 Compliance)

✔ **Deterministic**: Registration happens in a known phase, no race conditions

✔ **MP-Safe**: Shared Lua runs identically on all clients

✔ **Extensible**: Callbacks allow conditional logic, validation, or future enhancements

✔ **Explicit**: Clear public APIs, no implicit global side effects

---

## External Mod Integration

### Before (Broken)

```lua
-- ❌ This did not work
local onShopRegister = function()
    Shop.RegisterItem("MyMod.Item", {...})
end
Events.OnShopRegisterItems.Add(onShopRegister)
```

### After (Correct)

```lua
-- ✔ This works
Shop.RegisterItemCallback(function(items)
    items["MyMod.Item"] = { tab = "Weapons", price = 100 }
end)
```

---

## Documentation

See **docs/SHOP_EXTENSION_API.md** for:
- Complete API reference
- Examples and patterns
- Error handling
- FAQ

---

## Verification

All changes are B42-compliant:

- ✅ No engine event system abuse
- ✅ No `triggerEvent()` calls
- ✅ No undefined `Events` table access (fixed runtime error)
- ✅ No `__call` metatable errors
- ✅ No undefined globals
- ✅ Deterministic execution
- ✅ MP-safe (shared Lua)

### Critical Fix: Runtime Error Fixed

**Before**: Calling `Events.OnShopModifyBuyPrice` as a function → crashes with:
```
Object table 0x... did not have __call metatable set
```

**After**: Using `Shop.PriceHooks._executeBuyModifyCallbacks()` → no error, clean execution

---

## Backwards Compatibility

The `Shop.RegisterItem()` API remains unchanged. Existing code that directly calls:

```lua
Shop.RegisterItem("itemId", {def})
```

Will continue to work without modification.

The only breaking change is for mods that tried to hook into the now-deleted `Events.OnShopRegisterItems` event, which was broken in B42 anyway.

---

## Load Order

**Guaranteed load order in mod system:**

1. `Shop.lua` (master namespace)
2. `ShopRegistry.lua` / `ShopSellRegistry.lua` (APIs)
3. `ShopInit.lua` / `ShopSellInit.lua` (finalization)

External mods load **before finalization**, so their callbacks are registered in time.

---

## Benefits

1. **Fixes critical bug** - The broken event system is replaced
2. **Cleaner architecture** - Explicit registration is easier to understand and debug
3. **Future-proof** - Enables future features like validation, sandboxing, or dependency tracking
4. **MP-safe** - Aligns with B42's emphasis on determinism and server authority

---

## Next Steps (Optional Enhancements)

- Add debug logging to trace which mods registered which items
- Implement callback validation (e.g., ensure all items have required fields)
- Add per-mod namespacing to prevent ID collisions
- Extend callbacks to support item deletion or modification
