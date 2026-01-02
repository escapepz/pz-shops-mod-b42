# Sprite Toggle Event Trace

## Complete Flow: R Key → Sprite Rotation → Shop Placement

### 1. INITIALIZATION PHASE
**File:** `ShopSpriteCursorUI.lua`

**Entry Point:** `ensureInitialized()` (called once, lazily on first use)
```lua
function ensureInitialized()
    if initialized then return end
    
    -- Only runs once
    ShopSpriteCursorUI = ISBuildingObject:derive("ShopSpriteCursorUI")
    -- ... define methods ...
    Events.OnKeyPressed.Add(ShopSpriteCursorUI.toggleSprites)  -- LINE 107
    initialized = true
end
```

**Key Event Listener Registration (Line 107):**
- Global event listener is added to `Events.OnKeyPressed`
- `ShopSpriteCursorUI.toggleSprites` callback is registered
- This callback fires on **every key press** in the game

---

### 2. CONTEXT MENU PHASE
**File:** `PlayerShopContext.lua`

**Flow:**
1. User right-clicks on ground
2. Engine fires `OnPreFillWorldObjectContextMenu` event
3. `WorldObjectContextMenuDispatcher` triggers `PlayerShopContextMenu()`
4. Menu option added: "Add Player Shop"
5. User clicks the option → `PlayerShop.addPlayerShop()` called

**Function: `PlayerShop.addPlayerShop(worldobjects, playerNum, sprites)` (Line 76)**
```lua
function PlayerShop.addPlayerShop(worldobjects, playerNum, sprites)
    local player = getSpecificPlayer(playerNum)
    -- sprites = { "playershop_0", "playershop_1" } (example)
    
    -- Create cursor UI instance
    local cursorUI = SHOPSB42.ShopSpriteCursorUI:new(player, sprites)
    -- Sets actionClass for this specific cursor
    cursorUI.actionClass = SHOPSB42.ISAddPlayerShopAction
    -- Activate drag mode
    getCell():setDrag(cursorUI, playerNum)
end
```

---

### 3. CURSOR CREATION PHASE
**File:** `ShopSpriteCursorUI.lua`

**Function: `ShopSpriteCursorUI:new(character, sprites)` (Line 26)**
```lua
function ShopSpriteCursorUI:new(character, sprites)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o:init()                           -- PZ engine init
    o.sprites = sprites                -- Save sprite array: [west, north]
    o:setSprite(sprites[1])            -- Show first sprite (west)
    o:setNorthSprite(sprites[1])       -- Set north property sprite
    o.character = character
    o.player = character:getPlayerNum()
    o.noNeedHammer = true
    o.skipBuildAction = true
    o.spriteIndex = 1                  -- INDEX 1 = WEST
    o.north = false                    -- FIXED: Initialize north state (INDEX 1 = false)
    return o
end
```

**Important:** Instance is created but NOT stored as a singleton. Instead, `ShopSpriteCursorUI.instance` must be set elsewhere.

---

### 4. KEY PRESS PHASE
**File:** `ShopSpriteCursorUI.lua`

**Event: User presses R key**

**Step 1:** Game engine fires `Events.OnKeyPressed` event with key code

**Step 2:** `ShopSpriteCursorUI.toggleSprites(key)` callback fires (Line 86)**
```lua
function ShopSpriteCursorUI.toggleSprites(key)
    -- GATE 1: Check if a cursor instance is active
    if not ShopSpriteCursorUI.instance then
        return  -- Not in placement mode, exit
    end
    
    -- GATE 2: Check if pressed key is the rotation key (R)
    if key ~= getCore():getKey("Rotate building") then
        return  -- Wrong key, exit
    end
    
    -- GATE PASSED: Both conditions met
    local spriteIndex = ShopSpriteCursorUI.instance.spriteIndex
    
    -- Toggle between 1 and 2
    if spriteIndex == 2 then
        spriteIndex = 1
    else
        spriteIndex = 2
    end
    
    -- Get next sprite from array
    -- Array: [sprite_west, sprite_north]
    local nextSprite = ShopSpriteCursorUI.instance.sprites[spriteIndex]
    
    -- UPDATE INSTANCE STATE (FIXED)
    ShopSpriteCursorUI.instance.spriteIndex = spriteIndex
    ShopSpriteCursorUI.instance.north = (spriteIndex == 2)  -- LINE 101 (CRITICAL FIX)
    
    -- Update cursor visuals
    ShopSpriteCursorUI.instance:setSprite(nextSprite)       -- Display change
    ShopSpriteCursorUI.instance:setNorthSprite(nextSprite)  -- Rotation direction
end
```

**State After R Key Press (spriteIndex=2):**
```
Before R:  spriteIndex=1, north=false, sprite="playershop_0"
After R:   spriteIndex=2, north=true,  sprite="playershop_1"
```

---

### 5. PLACEMENT PHASE
**File:** `ShopSpriteCursorUI.lua`

**Event: User clicks to place shop**

**Function: `ShopSpriteCursorUI:tryBuild(x, y, z)` (Line 55)**
```lua
function ShopSpriteCursorUI:tryBuild(x, y, z)
    local ActionClass = self.actionClass or ISAddPlayerShopAction
    
    local square = getWorld():getCell():getGridSquare(x, y, z)
    if not square then
        return
    end
    
    -- CRITICAL: Pass north state to action
    -- self.north = true/false (from R key toggle)
    -- self:getSprite() = selected sprite ("playershop_0" or "playershop_1")
    local action = ActionClass:new(
        self.character,
        square,
        self:getSprite(),    -- Current sprite
        self.north           -- FIXED: Now properly set by toggleSprites
    )
    
    ISTimedActionQueue.add(action)  -- Queue for execution
end
```

---

### 6. ACTION PROCESSING PHASE
**File:** `ISAddPlayerShopAction.lua`

**Constructor: `ISAddPlayerShopAction:new(character, square, sprite, north)` (Line 169)**
```lua
function ISAddPlayerShopAction:new(character, square, sprite, north)
    -- ... validation ...
    local o = ISBaseTimedAction.new(ISAddPlayerShopAction, character)
    
    -- Save parameters
    o.character = character
    o.square = square
    o.sprite = sprite
    o.north = north or false  -- LINE 206: Store north state
    o.maxTime = o:getDuration()
    
    return o
end
```

**Complete: `ISAddPlayerShopAction:complete()` (Line 49)**
```lua
function ISAddPlayerShopAction:complete()
    -- Server-side only
    if not Utilities.IsServerOrSinglePlayer() then
        return true
    end
    
    local square = self.square
    local sprite = self.sprite
    local north = self.north or false  -- LINE 60: Retrieve north state
    
    -- Create shop with rotation
    -- Parameter: north = true  (facing north)
    --         or north = false (facing west)
    local shop = IsoThumpable.new(cell, square, sprite, north, self)
    
    -- IsoThumpable engine applies rotation based on north parameter
    square:AddTileObject(shop)
    -- ... rest of setup ...
end
```

---

## EVENT FLOW SUMMARY

```
User Input:
  Right-click → Context Menu → "Add Player Shop"
                    ↓
  ShopSpriteCursorUI created
  Drag mode activated
  Events.OnKeyPressed listener active
                    ↓
  Press R key
                    ↓
  Events.OnKeyPressed fires
  ShopSpriteCursorUI.toggleSprites() executes
  - spriteIndex: 1 → 2
  - north: false → true ✓ (FIXED)
  - Cursor updates visuals
                    ↓
  Click to place
                    ↓
  ShopSpriteCursorUI:tryBuild() calls
  ISAddPlayerShopAction created with north=true ✓ (FIXED)
  Action queued
                    ↓
  Server executes ISAddPlayerShopAction:complete()
  IsoThumpable.new(..., sprite, north=true)
  Shop placed with CORRECT ROTATION ✓
```

---

## KEY FIXES APPLIED

### Fix #1: Initialize `o.north` in Constructor (Line 39)
**Before:**
```lua
o.spriteIndex = 1
-- o.north was undefined ❌
return o
```

**After:**
```lua
o.spriteIndex = 1
o.north = false  -- Initialize with index 1 ✓
return o
```

---

### Fix #2: Update `self.north` in Toggle (Line 101)
**Before:**
```lua
ShopSpriteCursorUI.instance.spriteIndex = spriteIndex
-- self.north was NOT updated ❌
ShopSpriteCursorUI.instance:setSprite(nextSprite)
```

**After:**
```lua
ShopSpriteCursorUI.instance.spriteIndex = spriteIndex
ShopSpriteCursorUI.instance.north = (spriteIndex == 2)  -- ✓ FIXED
ShopSpriteCursorUI.instance:setSprite(nextSprite)
```

---

## Verification Points

1. **R Key Detection:** `getCore():getKey("Rotate building")` returns the R key code
2. **Instance Check:** `ShopSpriteCursorUI.instance` must be set during drag mode
3. **Sprite Array:** First element (index 1) = west, Second element (index 2) = north
4. **North State:** Properly passed through action constructor to server
5. **Server Application:** `IsoThumpable.new(cell, square, sprite, north)` uses north parameter

---

## Debugging Notes

- Enable logs in `SharedLogger` to trace: `[ShopSpriteCursorUI:tryBuild]` and `[ISAddPlayerShopAction:complete]`
- Look for: `sprite=playershop_0 north=true` in logs to verify rotation was set
- Check client logs for R key press events
- Verify `ShopSpriteCursorUI.instance` is set when drag mode starts
