# Timed Action Registration Fix

## Issue
Timed actions were failing on multiplayer server reconstruction with error:
```
LuaManager.getFunctionObject > no such function "ShopBuyAction.new"
```

This occurred because Project Zomboid's engine reconstructs timed actions by resolving constructors from the **global Lua table** during network deserialization. Namespace-only registration was insufficient.

## Root Cause
The original pattern:
```lua
SHOPSB42.ShopBuyAction = ISBaseTimedAction:derive("ShopBuyAction")
local ShopBuyAction = SHOPSB42.ShopBuyAction  -- Only local, not global
```

This made `ShopBuyAction` unavailable in `_G`, causing the engine lookup `_G["ShopBuyAction"].new` to fail during MP action reconstruction.

## Solution
Changed all timed action registrations to the **global-first pattern**:
```lua
ShopBuyAction = ISBaseTimedAction:derive("ShopBuyAction")
SHOPSB42.ShopBuyAction = ShopBuyAction  -- Then register to namespace
```

This ensures:
- Constructor is immediately available globally: `_G["ShopBuyAction"].new`
- Namespace reference maintained for code organization
- Engine reconstruction succeeds on server/client deserialization

## Files Fixed
1. **ShopBuyAction.lua** - Shop purchase action
2. **PlayerShopBuyAction.lua** - Player shop purchase action
3. **ShopSellAction.lua** - Shop sell action
4. **SendTransferAction.lua** - Coin transfer action

## Files Already Correct
- **ISAddShopAction.lua** - Already used global-first pattern
- **ISAddPlayerShopAction.lua** - Already used global-first pattern

## Technical Details
- **Pattern**: Global assignment → namespace aliasing
- **Requirement**: Mandatory for all timed actions in multiplayer builds
- **Engine behavior**: Serialization uses class name string; deserialization resolves from global Lua environment only
- **Compatibility**: Works identically in singleplayer, MP client, and server contexts

## Date
Fixed: 2026-01-03
