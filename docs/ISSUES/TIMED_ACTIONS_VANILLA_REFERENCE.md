# Timed Actions - Vanilla Code Reference

## Vanilla Code Location
All timed actions in vanilla PZ are in **`shared/`** folder:
- `tmp/Vanilla/shared/BuildingObjects/TimedActions/ISPaintAction.lua`
- `tmp/Vanilla/shared/BuildingObjects/TimedActions/ISPlasterAction.lua`
- `tmp/Vanilla/shared/Camping/TimedActions/ISAddFuelAction.lua`
- And many others...

## Vanilla Pattern 1: ISPaintAction

**File location**: `tmp/Vanilla/shared/BuildingObjects/TimedActions/ISPaintAction.lua`

```lua
require "TimedActions/ISBaseTimedAction"

ISPaintAction = ISBaseTimedAction:derive("ISPaintAction");

function ISPaintAction:isValid()
    return true;
end

function ISPaintAction:perform()
    if self.sound then self.character:stopOrTriggerSound(self.sound) end
    self.thumpable:cleanWallBlood();
    -- needed to remove from queue / start next.
    ISBaseTimedAction.perform(self);
end

function ISPaintAction:complete()
    if self.thumpable:getSprite() == getSprite("carpentry_01_16") then
        self.thumpable:setSpriteFromName("carpentry_02_104")
    end
    -- ... more logic
end
```

**Key observations:**
- Line 1: `require "TimedActions/ISBaseTimedAction"` (client-only base class)
- Line 3: `ISBaseTimedAction:derive()` pattern
- `perform()`: Client-side animation, sounds, UI
- `complete()`: Server-side world state changes
- **FILE IS IN SHARED FOLDER** ✅

## Vanilla Pattern 2: ISAddFuelAction

**File location**: `tmp/Vanilla/shared/Camping/TimedActions/ISAddFuelAction.lua`

```lua
require "TimedActions/ISBaseTimedAction"

ISAddFuelAction = ISBaseTimedAction:derive("ISAddFuelAction");

function ISAddFuelAction:isValid()
    -- Can check both client and server conditions
    if isClient() and self.item then
        return self.campfire:getObject() and
            self.character:getInventory():containsID(self.item:getID())
    else
        return self.campfire:getObject() and
            self.character:getInventory():contains(self.item)
    end
end

function ISAddFuelAction:perform()
    self.character:stopOrTriggerSound(self.sound)
    self.item:setJobDelta(0.0);
    ISBaseTimedAction.perform(self);  -- REQUIRED
end

function ISAddFuelAction:complete()
    if self.item:IsDrainable() and not self.item:hasTag(ItemTag.IS_FIRE_FUEL_SINGLE_USE) then
        self.item:UseAndSync()
    else
        self.character:removeFromHands(self.item)
        self.character:getInventory():Remove(self.item)
        sendRemoveItemFromContainer(self.character:getInventory(),self.item)
    end
    local campfire = SCampfireSystem.instance:getLuaObjectAt(self.campfire.x, self.campfire.y, self.campfire.z)
    if campfire then
        campfire:addFuel(self.fuelAmt)
    end
    return true  -- REQUIRED
end

function ISAddFuelAction:new(character, campfire, item, fuelAmt)
    local o = ISBaseTimedAction.new(self, character)  -- Method syntax: self, not class name
    o.campfire = campfire
    o.item = item
    o.fuelAmt = fuelAmt
    o.maxTime = o:getDuration()
    return o
end
```

**Key observations:**
- Line 79: `ISBaseTimedAction.new(self, character)` - uses method syntax with `self`
- `isValid()`: Can use `if isClient()` to check different conditions per-side
- `complete()`: **Returns `true`** (required)
- `perform()`: **Calls `ISBaseTimedAction.perform(self)`** (required)
- **FILE IS IN SHARED FOLDER** ✅

## Comparison with Shops Timed Actions

### Shops ShopSellAction
**File location**: `Shops/42.13.1/media/lua/shared/nshopsb42/timers/ShopSellAction.lua`

```lua
require("TimedActions/ISBaseTimedAction")

SHOPSB42.ShopSellAction = ISBaseTimedAction:derive("ShopSellAction")
local ShopSellAction = SHOPSB42.ShopSellAction

function ShopSellAction:new(character, shop, sellList)
    local o = ISBaseTimedAction.new(ShopSellAction, character)  -- ✅ Correct
    o.shopCoords = { x = square:getX(), y = square:getY(), z = square:getZ() }
    o.sellList = sellList
    o.maxTime = o:getDuration()
    return o
end

function ShopSellAction:perform()
    -- Client-side
    ISBaseTimedAction.perform(self)
end

function ShopSellAction:complete()
    if not isServer() then return true end
    -- Server-side logic
    return true
end
```

**Comparison:**
| Aspect | Vanilla | Shops |
|--------|---------|-------|
| Location | `shared/` | `shared/` ✅ |
| Base class | `ISBaseTimedAction` | `ISBaseTimedAction` ✅ |
| Derive pattern | `ISBaseTimedAction:derive()` | `ISBaseTimedAction:derive()` ✅ |
| new() call | `ISBaseTimedAction.new(self, char)` | `ISBaseTimedAction.new(ShopSellAction, char)` ✅ |
| perform() | Calls `ISBaseTimedAction.perform()` | Calls `ISBaseTimedAction.perform()` ✅ |
| complete() | Returns `true`/`false` | Returns `true`/`false` ✅ |
| Guards | Optional in methods | Uses `if not isServer()` ✅ |

## Vanilla Conclusion

✅ **Shops timed actions follow vanilla patterns correctly:**
1. **File location**: `shared/` ✅
2. **Base class**: `ISBaseTimedAction` ✅
3. **Method signatures**: Match vanilla ✅
4. **perform() logic**: Client-side work ✅
5. **complete() logic**: Server-side work + returns `true` ✅
6. **new() pattern**: Correct ✅

**Status**: Shops mod timed actions are **aligned with vanilla code patterns**.
