# Timed Action Registration Fix

## Issue 1: Global Namespace Registration
Timed actions were failing on multiplayer server reconstruction with error:
```
LuaManager.getFunctionObject > no such function "ShopBuyAction.new"
```

This occurred because Project Zomboid's engine reconstructs timed actions by resolving constructors from the **global Lua table** during network deserialization. Namespace-only registration was insufficient.

### Root Cause
The original pattern:
```lua
SHOPSB42.ShopBuyAction = ISBaseTimedAction:derive("ShopBuyAction")
local ShopBuyAction = SHOPSB42.ShopBuyAction  -- Only local, not global
```

This made `ShopBuyAction` unavailable in `_G`, causing the engine lookup `_G["ShopBuyAction"].new` to fail.

### Solution
Changed all timed action registrations to the **global-first pattern**:
```lua
ShopBuyAction = ISBaseTimedAction:derive("ShopBuyAction")
SHOPSB42.ShopBuyAction = ShopBuyAction  -- Then register to namespace
```

## Issue 2: Serialization of Non-Serializable Objects
Timed action constructors were passed shop objects directly:
```lua
local action = ShopBuyAction:new(self.player, self.shop, ticket)
```

During network reconstruction (MP mode), the `self.shop` parameter became `nil` because **game objects cannot be serialized over the network**. This caused crashes when calling `shop:getSquare()`.

### Root Cause
```
ERROR: attempted index: getSquare of non-table: null
```

The shop object parameter was always `nil` during server deserialization, causing null pointer dereference.

### Solution
Refactored to pass shop coordinates instead of the shop object. Client-side code now extracts coordinates before passing to the action:

**Before:**
```lua
local action = ShopBuyAction:new(self.player, self.shop, ticket)
```

**After:**
```lua
local shopCoords = nil
if self.shop then
    local square = self.shop:getSquare()
    shopCoords = { x = square:getX(), y = square:getY(), z = square:getZ() }
else
    shopCoords = { x = 0, y = 0, z = 0 }
end
local action = ShopBuyAction:new(self.player, shopCoords, ticket)
```

Action constructors now accept `shopCoords` table directly:
```lua
function ShopBuyAction:new(character, shopCoords, ticket)
    local o = ISBaseTimedAction.new(ShopBuyAction, character)
    o.shopCoords = shopCoords or { x = 0, y = 0, z = 0 }
    -- ...
end
```

## Files Fixed

### Timed Action Registrations
1. **ShopBuyAction.lua** - Global registration + constructor refactoring
2. **PlayerShopBuyAction.lua** - Global registration + constructor refactoring
3. **ShopSellAction.lua** - Global registration + constructor refactoring
4. **SendTransferAction.lua** - Global registration only (no shop object param)

### Client UI Dispatchers
1. **ShopUI.lua** - `buyCartBtn()` and `sellCartBtn()` now extract coords before dispatch
2. **PlayerShopUI.lua** - `buyCartBtn()` now extracts coords before dispatch

### Files Already Correct
- **ISAddShopAction.lua** - Already used global-first pattern
- **ISAddPlayerShopAction.lua** - Already used global-first pattern

## Technical Details
- **Registration pattern**: Global assignment → namespace aliasing (mandatory for MP reconstruction)
- **Serialization pattern**: Extract primitive data types on client, pass to action constructor
- **Parameter change**: Shop object → shop coordinates table `{x, y, z}`
- **Compatibility**: Works identically in singleplayer, MP client, and server contexts
- **Guard checks**: Existing proximity validation in `complete()` methods ensures player is near shop (already implemented)

## Date
Fixed: 2026-01-03
