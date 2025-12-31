# Working vs Broken Implementation Comparison

## OLD WORKING (Commit 263f718 - `ShopSpriteCursor:create()`)

**File**: `Shops/42.13.1/media/lua/server/ShopSpriteCursor.lua`

**Approach**: Direct server-side placement via ISBuildingObject cursor

```lua
function ShopSpriteCursor:create(x, y, z, north, sprite)
    local cell = getWorld():getCell()
    local square = cell:getGridSquare(x, y, z)
    
    -- Key line: IsoThumpable.new with 5 args (cell, square, sprite, north, self)
    local shop = IsoThumpable.new(cell, square, sprite, north, self)
    
    shop:setIsContainer(true)
    shop:setCanBeLockByPadlock(true)
    square:AddSpecialObject(shop)  -- Uses AddSpecialObject, not AddTileObject
    
    if isPlayerShop then
        shop:getModData().owner = self.character:getUsername()
        shop:getModData().income = {}
        shop:transmitModData()
    end
    
    if itemTag then
        local playerShop = self.character:getInventory():getFirstTag(itemTag)
        if playerShop then
            self.character:getInventory():Remove(playerShop)
            sendRemoveItemFromContainer(self.character:getInventory(), playerShop)
        end
    end
end
```

**Key Characteristics**:
- ✅ Runs directly on server (no serialization)
- ✅ Uses `ISBuildingObject.create()` pattern (proven to work)
- ✅ Calls `IsoThumpable.new(cell, square, sprite, north, self)` with 5 args
- ✅ Uses `AddSpecialObject()` not `AddTileObject()`
- ✅ Synchronously removes inventory item
- ✅ No timed action = no "bugged action" errors

---

## NEW BROKEN (Current - `ISAddPlayerShopAction:complete()`)

**File**: `Shops/42.13.1/media/lua/shared/nshopsb42/timers/ISAddPlayerShopAction.lua`

**Approach**: Client queues timed action → server reconstructs → complete runs

```lua
function ISAddPlayerShopAction:complete()
    -- ... validation ...
    
    local square = self.square
    local sprite = self.sprite
    local north = self.north or false
    
    -- Key line: IsoThumpable.new with 3 args (square, sprite, north)
    local shop = IsoThumpable.new(square, sprite, north)
    
    shop:setSprite(sprite)
    shop:setIsThumpable(false)
    shop:setIsContainer(true)
    shop:setCanBeLockByPadlock(true)
    
    square:AddTileObject(shop)  -- Uses AddTileObject, not AddSpecialObject
    
    shop:transmitCompleteItemToClients()  -- Different sync method
    
    -- Remove item later
    local item = player:getInventory():getFirstTag(itemTag)
    if item then
        player:getInventory():Remove(item)
        sendRemoveItemFromContainer(player:getInventory(), item)
    end
end

function ISAddPlayerShopAction:new(character, square, sprite, north, isPlayerShop, isFreezer)
    -- 6 parameters - potential serialization issue
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.square = square
    o.sprite = sprite
    o.north = north or false
    o.isPlayerShop = isPlayerShop or false
    o.isFreezer = isFreezer or false
    o.maxTime = o:getDuration()
    return o
end
```

**Problems**:
1. ❌ **Too many constructor arguments** (6 params) → serialization mismatch
2. ❌ **Inherits from `ISBaseTimedAction`** instead of proven `ISBuildAction`
3. ❌ **Uses `AddTileObject()` instead of `AddSpecialObject()`** (different object layer)
4. ❌ **Uses `IsoThumpable.new(square, sprite, north)` with 3 args** instead of old 5 args:
   - **Old**: `IsoThumpable.new(cell, square, sprite, north, self)` ← 5 args including cell + self
   - **New**: `IsoThumpable.new(square, sprite, north)` ← 3 args, missing cell and self
5. ❌ **Network serialization required** → "bugged action" when reconstruction fails

---

## Key Differences Summary

| Aspect | Old (Working) | New (Broken) |
|--------|---------------|-------------|
| **Location** | Server-only | Shared (requires serialization) |
| **Base Class** | `ISBuildingObject` | `ISBaseTimedAction` |
| **IsoThumpable.new() args** | 5: (cell, square, sprite, north, self) | 3: (square, sprite, north) |
| **AddObject method** | `AddSpecialObject()` | `AddTileObject()` |
| **Sync method** | `transmitModData()` | `transmitCompleteItemToClients()` |
| **Constructor params** | Implicit from cursor | 6 explicit params (too many) |

---

## Why New Approach Fails

1. **Server reconstruction fails** because `ISAddPlayerShopAction:new()` has 6 parameters but the action signature doesn't properly match what the engine expects for serialization
2. **Argument mismatch**: The engine tries to reconstruct as `ISAddPlayerShopAction:new(character, square, sprite, north, isPlayerShop, isFreezer)` but can't serialize `isPlayerShop` and `isFreezer` properly
3. **Action marked bugged** before `perform()` even runs, so `complete()` never executes

---

## Solution Options

### Option A: Return to Old Pattern
Use `ShopSpriteCursor:create()` directly (server-side placement via ISBuildingObject)

### Option B: Simplify Timed Action
Reduce constructor to only essential params:
```lua
function ISAddPlayerShopAction:new(character, square, sprite, north)
    -- Only 4 params instead of 6
    -- Store isFreezer in sprite name itself
end
```

### Option C: Use ISBuildAction Instead
Switch to `ISBuildAction` base class (proven pattern in docs)

