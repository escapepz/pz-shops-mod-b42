# PlayerShop Implementation Guide - Vanilla Compatibility

Based on analysis of Project Zomboid B42.13.1 vanilla building system.

## Quick Reference: IsoThumpable.new() Signature

```lua
IsoThumpable.new(cell, square, sprite, north, self)
    ├─ cell:        IsoCell (getWorld():getCell())
    ├─ square:      IsoGridSquare (getGridSquare(x,y,z))
    ├─ sprite:      String "sprite_name"
    ├─ north:       Boolean or String
    │   ├─ Boolean:  Direction (true=north, false=west)
    │   └─ String:   Open sprite name (doors only)
    └─ self:        ISBuildingObject instance (the builder)
```

## PlayerShop.create() Template

```lua
function PlayerShop:create(x, y, z, north, sprite)
    -- STEP 1: Get cell and square
    local cell = getWorld():getCell()
    self.sq = cell:getGridSquare(x, y, z)
    
    -- STEP 2: Create IsoThumpable with self as 5th param
    self.javaObject = IsoThumpable.new(cell, self.sq, sprite, north, self)
    
    -- STEP 3: Metadata (MUST be before consumeMaterial)
    buildUtil.setInfo(self.javaObject, self)
    
    -- STEP 4: Remove materials from player inventory
    buildUtil.consumeMaterial(self)
    
    -- STEP 5: Configure object
    self.javaObject:setMaxHealth(self:getHealth())
    self.javaObject:setHealth(self.javaObject:getMaxHealth())
    self.javaObject:setBreakSound("BreakObject")
    -- Optional: self.javaObject:setName("Player Shop")
    
    -- STEP 6: Set ownership (modData)
    self.javaObject:getModData()["owner"] = self.playerName
    self.javaObject:getModData()["shop_name"] = self.shopName
    
    -- STEP 7: Add to world
    self.sq:AddSpecialObject(self.javaObject)
    
    -- STEP 8: Sync to all clients (MUST be last)
    self.javaObject:transmitCompleteItemToClients()
end
```

## Checklist: Order of Operations

This order is **critical** for multiplayer:

1. ✅ `IsoThumpable.new()` with self
2. ✅ `buildUtil.setInfo()`
3. ✅ `buildUtil.consumeMaterial()`
4. ✅ All `set*()` methods (health, sounds, etc.)
5. ✅ `getModData()` assignments
6. ✅ `square:AddSpecialObject()`
7. ✅ `transmitCompleteItemToClients()` **LAST**

## Synchronization for Owner Changes

If owner changes after initial creation:

```lua
self.javaObject:getModData()["owner"] = newOwner
self.javaObject:transmitModData()  -- ONLY send modData
```

## Container Example (if applicable)

If PlayerShop is a container:

```lua
function PlayerShop:create(x, y, z, north, sprite)
    local cell = getWorld():getCell()
    self.sq = cell:getGridSquare(x, y, z)
    self.javaObject = IsoThumpable.new(cell, self.sq, sprite, north, self)
    
    buildUtil.setInfo(self.javaObject, self)
    buildUtil.consumeMaterial(self)
    
    self.javaObject:setMaxHealth(self:getHealth())
    self.javaObject:setHealth(self.javaObject:getMaxHealth())
    
    -- If stackable furniture
    local sharedSprite = getSprite(self:getSprite())
    if self.sq and sharedSprite and sharedSprite:getProperties():has("IsStackable") then
        local props = ISMoveableSpriteProps.new(sharedSprite)
        self.javaObject:setRenderYOffset(props:getTotalTableHeight(self.sq))
    end
    
    self.javaObject:getModData()["owner"] = self.playerName
    
    self.sq:AddSpecialObject(self.javaObject)
    self.javaObject:transmitCompleteItemToClients()
end
```

## DO NOT DO

❌ Pass empty table `{}` as 5th param (that's for generic thumpables)  
❌ Call transmit methods in middle of setup  
❌ Forget to call `buildUtil.setInfo()`  
❌ Forget to call `buildUtil.consumeMaterial()`  
❌ Call `transmitCompleteItemToClients()` before modData is set  
❌ Use boolean for 4th param if it's an open sprite  

## DO DO

✅ Always use `self` as 5th parameter  
✅ Call `buildUtil.setInfo()` right after `new()`  
✅ Set all modData before `transmitCompleteItemToClients()`  
✅ Use `transmitModData()` for updates only  
✅ Match signature: `create(x, y, z, north, sprite)`  

## Health Calculation Pattern

```lua
function PlayerShop:getHealth()
    -- Base health + player woodwork level bonus
    return 200 + buildUtil.getWoodHealth(self)
end

-- buildUtil.getWoodHealth() provides:
-- - carpentry_level * 50
-- - +100 if player has HANDY trait
```

## Destruction Hook

If you need custom destruction logic:

```lua
-- Register in your init
Events.OnDestroyIsoThumpable.Add(PlayerShop.onDestroy)

-- Implement
function PlayerShop.onDestroy(thump, player)
    -- thump is the IsoThumpable
    -- player is the IsoGameCharacter who destroyed it
    thump:dumpContentsInSquare()
    -- Custom logic here
    thump:getSquare():transmitRemoveItemFromSquare(thump)
end
```

## Expected setDrag() Integration

Your drag object will be used by the game engine like this:

```lua
-- Player initiates
getCell():setDrag(PlayerShop:new(...), playerNum)

-- Game calls
draggingItem:render(x, y, z, square)       -- Your render()
draggingItem:isValid(square)               -- Your isValid()
draggingItem:tryBuild(x, y, z)             -- Inherited from ISBuildingObject
    └─> self:create(...)                    -- Your create()
```

The engine will automatically:
1. Call `render()` for preview
2. Call `isValid()` for placement check
3. Call `tryBuild()` which eventually calls your `create()`
4. Your `create()` then creates the IsoThumpable

## Multiplayer Safety

✅ All creation happens server-side  
✅ `consumeMaterial()` removes from server inventory  
✅ `transmitCompleteItemToClients()` broadcasts to all players  
✅ Clients cannot create objects (server only)  
✅ ModData changes must be explicitly transmitted  

## Testing Checklist

- [ ] PlayerShop created with owner set
- [ ] Materials consumed from player inventory
- [ ] All players see the shop object
- [ ] ModData visible on clients (via inspection)
- [ ] Owner field persists after reload
- [ ] Destruction returns modData items
- [ ] Can't place invalid (testing with `isValid()`)
