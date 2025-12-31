# Project Zomboid B42.13+ Vanilla Building System Analysis

## Overview

Analysis of vanilla Project Zomboid building implementations to verify PlayerShop compatibility with B42.13.1 multiplayer. All findings are from server-side code in `BuildingObjects/` directory.

---

## 1. ISBuildingObject.create() Implementation

### Entry Point

```lua
-- From ActionManager.lua (line 28):
Actions.build = function(character, args)
    args.item.character = character
    args.item:create(args.x, args.y, args.z, args.north, args.spriteName);
    local square = getCell():getGridSquare(args.x, args.y, args.z);
    square:RecalcAllWithNeighbours(true);
    buildUtil.setHaveConstruction(square, true);
end
```

### Flow Chain

1. **User initiates building**: `getCell():setDrag(ISWoodenDoor:new(...), playerNum)`
2. **Game loop**: `DoTileBuilding()` handles render/preview via `draggingItem:render()`
3. **Player confirms**: `draggingItem:tryBuild(x, y, z)`
4. **ISBuildingObject.tryBuild()** (line 181):
   - Creates ISBuildAction (timed action)
   - Player walks to location (if needed)
   - Calls `self:create(x, y, z, self.north, self:getSprite())`
5. **Subclass create()**: Instance-specific creation logic
6. **Post-create**: `square:RecalcAllWithNeighbours(true)`

### Signature

```lua
function ISBuildingObject:create(x, y, z, north, sprite)
    -- x, y, z = world coordinates
    -- north = direction boolean (true=north, false=west)
    -- sprite = sprite name STRING (not object)
end
```

---

## 2. IsoThumpable.new() Complete Signature

### Standard 5-Parameter Form

```lua
IsoThumpable.new(cell, square, sprite, north, self)
```

| Parameter | Type | Meaning |
|-----------|------|---------|
| `cell` | IsoCell | `getWorld():getCell()` |
| `square` | IsoGridSquare | Target grid square |
| `sprite` | String | Sprite name (e.g., "carpentry_02_1") |
| `north` | Boolean | Direction (true=north, false=west) |
| `self` | ISBuildingObject | The building object that created it |

### Special Case: Doors with Open Sprite

```lua
IsoThumpable.new(cell, square, sprite, openSprite, north, self)
```

- Param 4 becomes `openSprite` (String) instead of boolean
- Used by ISWoodenDoor to handle open/closed states
- ISWoodenDoor.lua, line 11

### The 5th Parameter (self)

**Critical finding**: The 5th parameter is always the **ISBuildingObject instance**.

```lua
self.javaObject = IsoThumpable.new(cell, self.sq, sprite, north, self)
```

This enables:
- Java engine to reference building definition
- Callbacks back to Lua builder object
- Metadata propagation via `buildUtil.setInfo()`

---

## 3. Vanilla Building Examples (Complete)

### Example 1: ISWoodenDoor (Door with open state)

**File**: `server/BuildingObjects/ISWoodenDoor.lua`

```lua
function ISWoodenDoor:create(x, y, z, north, sprite)
    showDebugInfoInChat("Cursor Create 'ISWoodenDoor' "..x..", "..y..", "..z..", "..north..", "..sprite)
    
    local cell = getWorld():getCell()
    self.sq = cell:getGridSquare(x, y, z)
    
    -- Get appropriate open sprite based on direction
    local openSprite = self.openSprite
    if north then
        openSprite = self.openNorthSprite
    end
    
    -- Create thumpable with open sprite as param 4
    self.javaObject = IsoThumpable.new(cell, self.sq, sprite, openSprite, north, self)
    
    -- Metadata setup
    buildUtil.setInfo(self.javaObject, self)
    
    -- Remove materials from inventory
    local consumedItems = buildUtil.consumeMaterial(self)
    
    -- Health: 300 + (carpentry_level * 50)
    self.javaObject:setMaxHealth(self:getHealth())
    self.javaObject:setHealth(self.javaObject:getMaxHealth())
    
    -- Sound
    self.javaObject:setBreakSound("BreakDoor")
    
    -- Add to world
    self.sq:AddSpecialObject(self.javaObject)
    
    -- Handle consumed special items
    for _,item in ipairs(consumedItems) do
        if item:getType() == "Doorknob" and item:getKeyId() ~= -1 then
            self.javaObject:setKeyId(item:getKeyId())
        end
    end
    
    -- SYNC TO ALL CLIENTS
    self.javaObject:transmitCompleteItemToClients()
end
```

**Key points**:
- Open sprite passed as param 4 instead of boolean
- Material consumption removes items from inventory
- keyId set from consumed doorknob
- `transmitCompleteItemToClients()` syncs to MP

### Example 2: ISWoodenWall (Simple wall)

**File**: `server/BuildingObjects/ISWoodenWall.lua`

```lua
function ISWoodenWall:create(x, y, z, north, sprite)
    local cell = getWorld():getCell()
    self.sq = cell:getGridSquare(x, y, z)
    
    -- Simple form: sprite as param 3, direction as param 4
    self.javaObject = IsoThumpable.new(cell, self.sq, sprite, north, self)
    
    buildUtil.setInfo(self.javaObject, self)
    buildUtil.consumeMaterial(self)
    
    -- Health: 200-400 + (carpentry_level * 50)
    if not self.health then
        self.javaObject:setMaxHealth(self:getHealth())
    else
        self.javaObject:setMaxHealth(self.health)
    end
    self.javaObject:setHealth(self.javaObject:getMaxHealth())
    self.javaObject:setName(self.name)
    self.javaObject:setBreakSound("BreakObject")
    
    -- Add with optional index for layering
    self.sq:AddSpecialObject(self.javaObject, self:getObjectIndex())
    self.sq:RecalcAllWithNeighbours(true)
    
    -- Corner check
    buildUtil.checkCorner(x, y, z, north, self, self.javaObject)
    
    self.javaObject:transmitCompleteItemToClients()
end
```

**Key points**:
- No special param 4 (it's just direction boolean)
- Calls `RecalcAllWithNeighbours()` for wall coherence
- Corner auto-placement

### Example 3: ISWoodenContainer (Furniture/storage)

**File**: `server/BuildingObjects/ISWoodenContainer.lua`

```lua
function ISWoodenContainer:create(x, y, z, north, sprite)
    local cell = getWorld():getCell()
    self.sq = cell:getGridSquare(x, y, z)
    
    self.javaObject = IsoThumpable.new(cell, self.sq, sprite, north, self)
    
    buildUtil.setInfo(self.javaObject, self)
    buildUtil.consumeMaterial(self)
    
    self.javaObject:setMaxHealth(self:getHealth())
    self.javaObject:setHealth(self.javaObject:getMaxHealth())
    self.javaObject:setBreakSound(IsoThumpable.GetBreakFurnitureSound(sprite))
    
    -- Stack detection for stackable furniture
    local sharedSprite = getSprite(self:getSprite())
    if self.sq and sharedSprite and sharedSprite:getProperties():has("IsStackable") then
        local props = ISMoveableSpriteProps.new(sharedSprite)
        self.javaObject:setRenderYOffset(props:getTotalTableHeight(self.sq))
    end
    
    self.sq:AddSpecialObject(self.javaObject)
    self.javaObject:transmitCompleteItemToClients()
end
```

**Key points**:
- Used for containers and furniture
- Special handling for stackable items
- RenderYOffset for visual stacking

### Common Pattern

All three follow this structure:

1. **Get cell & square**: `getWorld():getCell()` → `getGridSquare(x,y,z)`
2. **Create IsoThumpable**: `IsoThumpable.new(cell, sq, sprite, north, self)`
3. **Set metadata**: `buildUtil.setInfo()`
4. **Consume materials**: `buildUtil.consumeMaterial()`
5. **Configure object**:
   - `setMaxHealth()` / `setHealth()`
   - `setBreakSound()`
   - Optional: `setName()`, `setKeyId()`, etc.
6. **Add to world**: `square:AddSpecialObject()`
7. **Optional**: `RecalcAllWithNeighbours()`, `checkCorner()`
8. **Sync**: `transmitCompleteItemToClients()`

---

## 4. Ownership & ModData Patterns

### ModData Usage (Grave Example)

**File**: `shared/Util/GraveHelper.lua`

```lua
GraveHelper.updateGrave = function(grave)
    -- Modify modData
    grave:getModData()["corpses"] = grave:getModData()["corpses"] + 1
    
    -- SYNC to clients
    grave:transmitModData()
    
    -- ... more logic
end
```

**File**: `shared/TimedActions/ISFillGrave.lua`

```lua
function ISFillGrave:changeSprite(square)
    for i=0,square:getSpecialObjects():size()-1 do
        local grave = square:getSpecialObjects():get(i)
        if grave:getName() == "EmptyGraves" then
            grave:getModData()["filled"] = true
            grave:transmitModData()  -- Sync change
            grave:setSpriteFromName(newSpriteName)
            grave:transmitUpdatedSpriteToClients()
        end
    end
end
```

### Pattern for Custom Data

```lua
-- Set ownership
self.javaObject:getModData()["owner"] = playerUsername

-- Set custom metadata
self.javaObject:getModData()["shop_name"] = "John's Store"
self.javaObject:getModData()["price"] = 100

-- Sync to clients
self.javaObject:transmitModData()
```

### When to Transmit

- **During create()**: Set modData, then call `transmitCompleteItemToClients()` last
- **During updates**: Call `transmitModData()` immediately after changes

---

## 5. transmitCompleteItemToClients() vs transmitModData()

### transmitCompleteItemToClients()

```lua
self.javaObject:transmitCompleteItemToClients()
```

**Use when**:
- Object newly created in `create()`
- Called AFTER all setup complete
- Syncs: sprite, health, properties, AND modData

**Timing in create()**:
```lua
self.javaObject:setMaxHealth(...)
self.javaObject:getModData()["owner"] = ...
-- ... all setup done
self.javaObject:transmitCompleteItemToClients()  -- LAST
```

### transmitModData()

```lua
self.javaObject:transmitModData()
```

**Use when**:
- Updating modData on existing object
- During gameplay (not in create)
- Example: Grave being filled, chest being locked

---

## 6. consumeMaterial() Behavior

### Function Call

```lua
local consumedItems = buildUtil.consumeMaterial(self)
```

### What It Does

1. Reads material requirements from ISBuildingObject
2. Removes items from player inventory automatically
3. Returns list of consumed items

### Usage Example

```lua
function ISWoodenDoor:create(x, y, z, north, sprite)
    -- ... create javaObject ...
    
    local consumedItems = buildUtil.consumeMaterial(self)
    
    -- Special handling: extract keyId from doorknob
    for _,item in ipairs(consumedItems) do
        if item:getType() == "Doorknob" and item:getKeyId() ~= -1 then
            self.javaObject:setKeyId(item:getKeyId())
        end
    end
end
```

### Material Definition

Materials are defined in ISBuildingObject instance, e.g.:

```lua
local doorBuilder = ISWoodenDoor:new(sprite, northSprite, openSprite, openNorthSprite)
doorBuilder.needItem = { [1] = { "Doorframe", 1 }, [2] = { "Doorknob", 1 } }
```

---

## 7. setDrag() System & create() Invocation

### Full Flow Diagram

```
Player initiates building (via context menu)
    ↓
    getCell():setDrag(ISWoodenDoor:new(...), playerNum)
    ↓
Game loop calls Events.OnDoTileBuilding2 (every frame)
    ↓
DoTileBuilding(draggingItem, isRender, x, y, z, square)
    ├─ Render preview: draggingItem:render(x, y, z, square)
    ├─ Check validity: draggingItem:isValid(square)
    └─ When confirmed: draggingItem:tryBuild(x, y, z)
    ↓
ISBuildingObject:tryBuild()
    ├─ Create ISBuildAction (timed action)
    ├─ Player walks to location
    ├─ Action completes
    └─ Calls self:create(x, y, z, self.north, self:getSprite())
    ↓
ISWoodenDoor:create(x, y, z, north, sprite)
    ├─ Create IsoThumpable
    ├─ Configure properties
    └─ Call transmitCompleteItemToClients()
    ↓
Optional cleanup:
    getCell():setDrag(nil, self.player)
```

### Called by Java

**Critical**: The game engine calls the `create()` method via Java reflection/dispatch. The 5th parameter to `IsoThumpable.new()` (the ISBuildingObject reference) allows Java to:
1. Know which builder object created it
2. Call back to Lua if needed
3. Access metadata via `buildUtil.setInfo()`

---

## 8. Multiplayer Synchronization Guarantees

### Server-Authoritative

All building object creation is server-side:
- `create()` runs on server only
- `consumeMaterial()` removes from server inventory
- `transmitCompleteItemToClients()` broadcasts to all

### Client Sync Points

1. **Object creation**: `transmitCompleteItemToClients()`
2. **ModData updates**: `transmitModData()`
3. **Sprite changes**: `transmitUpdatedSpriteToClients()`

### For PlayerShop with Ownership

```lua
-- Server-side create():
self.javaObject:getModData()["owner"] = playerUsername
self.javaObject:transmitCompleteItemToClients()  -- All clients see owner

-- If owner changes later:
self.javaObject:getModData()["owner"] = newOwner
self.javaObject:transmitModData()  -- Update all clients
```

---

## 9. setInfo() and buildUtil Integration

### setInfo() Call

```lua
buildUtil.setInfo(self.javaObject, self)
```

**Purpose**: Passes metadata from ISBuildingObject to IsoThumpable
- Implementation details not found in Lua code
- Likely Java-side method
- Called in ALL vanilla create() implementations
- **Must be called after IsoThumpable.new() but before transmit**

### Expected Order

```lua
function ISWoodenDoor:create(x, y, z, north, sprite)
    self.javaObject = IsoThumpable.new(cell, self.sq, sprite, openSprite, north, self)
    buildUtil.setInfo(self.javaObject, self)  -- Must be early
    buildUtil.consumeMaterial(self)            -- Material removal
    -- ... configure properties ...
    self.javaObject:transmitCompleteItemToClients()  -- Must be last
end
```

---

## 10. Health & Damage System

### Setup Pattern

```lua
-- Example: 200 base health + 100 per woodwork level
self.javaObject:setMaxHealth(self:getHealth())
self.javaObject:setHealth(self.javaObject:getMaxHealth())

-- Optional: damage threshold
self.javaObject:setThumpDmg(1)  -- Zombies needed to hurt it

-- Optional: break sound
self.javaObject:setBreakSound("BreakDoor")
```

### Health Calculation Functions

```lua
-- ISWoodenWall:getHealth()
return 200 + buildUtil.getWoodHealth(self)

-- ISWoodenDoor:getHealth()
return 300 + buildUtil.getWoodHealth(self)

-- buildUtil.getWoodHealth(ISItem)
local health = (playerObj:getPerkLevel(Perks.Woodwork) * 50)
if playerObj:hasTrait(CharacterTrait.HANDY) then
    health = health + 100
end
return health
```

---

## 11. Destruction & Cleanup

### onDestroy() Hook

**File**: `server/BuildingObjects/ISBuildingObject.lua` (line 39)

```lua
function ISBuildingObject.onDestroy(thump, player)
    thump:dumpContentsInSquare()  -- Drop contents
    
    -- Return materials from modData
    for index, value in pairs(thump:getModData()) do
        if luautils.stringStarts(index, "need:") then
            local itemFullType = luautils.split(index, ":")[2]
            for i=1,tonumber(value) do
                if ZombRand(2) == 0 then
                    -- Item destroyed
                elseif player then
                    player:getInventory():AddItem(itemFullType)
                else
                    thump:getSquare():AddWorldInventoryItem(itemFullType, 0.0, 0.0, 0.0)
                end
            end
        end
    end
    
    -- Remove from world
    thump:getSquare():transmitRemoveItemFromSquare(thump)
end

-- Hook registration:
Events.OnDestroyIsoThumpable.Add(ISBuildingObject.onDestroy)
```

---

## Verification Checklist for PlayerShop

### ✅ Create Method

- [ ] Signature: `function PlayerShop:create(x, y, z, north, sprite)`
- [ ] Parameters match exactly (sprite is STRING, not object)
- [ ] Gets cell: `getWorld():getCell()`
- [ ] Gets square: `cell:getGridSquare(x, y, z)`

### ✅ IsoThumpable Creation

- [ ] Call: `IsoThumpable.new(cell, square, sprite, north, self)`
- [ ] 5th parameter is `self` (the ISBuildingObject instance)
- [ ] Stores result in `self.javaObject`

### ✅ Setup & Metadata

- [ ] Call `buildUtil.setInfo(self.javaObject, self)` early
- [ ] Call `buildUtil.consumeMaterial(self)` to remove items
- [ ] Set health: `setMaxHealth()` and `setHealth()`
- [ ] Set sound: `setBreakSound()` if desired
- [ ] Set ownership: `getModData()["owner"] = ...`

### ✅ World Integration

- [ ] Add to world: `square:AddSpecialObject(self.javaObject)`
- [ ] Call `transmitCompleteItemToClients()` last (after ALL setup)
- [ ] Optional: `square:RecalcAllWithNeighbours(true)` if affects walls

### ✅ Container-Specific (if applicable)

- [ ] Call `setIsContainer(true)` if it's a container
- [ ] Set up container inventory
- [ ] Handle stackable detection like ISWoodenContainer

---

## Summary: Vanilla Pattern

Every vanilla building (`ISWoodenDoor`, `ISWoodenWall`, `ISWoodenContainer`) follows this exact pattern:

```lua
function SomeBuilding:create(x, y, z, north, sprite)
    -- 1. Get cell & square
    local cell = getWorld():getCell()
    local sq = cell:getGridSquare(x, y, z)
    
    -- 2. Create thumpable (5-param form with self)
    self.javaObject = IsoThumpable.new(cell, sq, sprite, north, self)
    
    -- 3. Metadata setup
    buildUtil.setInfo(self.javaObject, self)
    buildUtil.consumeMaterial(self)
    
    -- 4. Configure
    self.javaObject:setMaxHealth(self:getHealth())
    self.javaObject:setHealth(self.javaObject:getMaxHealth())
    self.javaObject:setBreakSound(...)
    -- ... etc ...
    
    -- 5. Add to world
    sq:AddSpecialObject(self.javaObject)
    
    -- 6. Sync (MUST be last)
    self.javaObject:transmitCompleteItemToClients()
end
```

**This pattern is compatible with B42.13.1 multiplayer.**
