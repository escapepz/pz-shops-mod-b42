# Implementation Changes Required (BUILD_FIX.md Review)

## High-Level Architecture Change

**Current (Broken):**
```
Click → Direct object creation in ShopSpriteCursor
     ↓
No timed action, no permission check, no sync guarantee
```

**Target (Correct - B42 Compliant):**
```
Click → Queue ISAddPlayerShopAction / ISAddShopAction
     ↓
perform() on client (animation)
     ↓
complete() on server (object creation + inventory removal + transmit)
     ↓
All mutations synced with transmitCompleteItemToClients()
```

---

## Mandatory Changes (6 Items)

### 1. ❌ DELETE object creation from ShopSpriteCursor

**File:** `Shops/42.13.1/media/lua/shared/nshopsb42/transactions/ShopSpriteCursor.lua`

**Current code to DELETE:**
```lua
function ShopSpriteCursor:create(x, y, z, north, sprite)
    writeLog("Shops", "[SERVER] ShopSpriteCursor:create() called...")
    local cell = getWorld():getCell()
    local square = cell:getGridSquare(x, y, z)
    local shop = IsoThumpable.new(cell, square, sprite, north, self)
    shop:setSprite(sprite)
    shop:setIsThumpable(false)
    square:AddSpecialObject(shop)  -- WRONG: AddTileObject() should be in timed action
    
    if isPlayerShop then
        shop:getModData().owner = self.character:getUsername()
        shop:getModData().income = {}
        shop:transmitModData()
    end
    
    if itemTag then
        local playerShop = self.character:getInventory():getFirstTag(itemTag)
        if playerShop then
            sendClientCommand(self.character, "PS", "RemoveItemFromInventory", ...)
        end
    end
end
```

**Replace with:**
```lua
function ShopSpriteCursor:create(x, y, z, north, sprite)
    -- DEPRECATED: Cursor no longer creates objects
    -- Object creation now happens in ISAddPlayerShopAction:complete()
    -- This method is kept for backward compatibility only
    writeLog("Shops", "[DEPRECATED] ShopSpriteCursor:create() should not be called")
end
```

---

### 2. ✅ INTRODUCE ISAddPlayerShopAction (NEW FILE)

**File:** `Shops/42.13.1/media/lua/server/nshopsb42/actions/ISAddPlayerShopAction.lua`

**New code:**
```lua
-- Server-side timed action for Player Shop placement
if isClient() and not isServer() then
    return
end

require "TimedActions/ISBuildAction"
local PlayerShop = SHOPSB42.PlayerShop

ISAddPlayerShopAction = ISBuildAction:derive("ISAddPlayerShopAction")

function ISAddPlayerShopAction:isValid(square)
    -- Double-check square is still free (client preview may be stale)
    if not square then return false end
    if not square:isFree() then return false end
    if square:isSolid() then return false end
    return true
end

function ISAddPlayerShopAction:perform()
    ISBuildAction.perform(self)
    -- Client-side animation, sounds, progress bar
end

function ISAddPlayerShopAction:complete()
    ISBuildAction.complete(self)
    
    local square = self.square
    local sprite = self.sprite
    local north = self.north or false
    local player = self.character
    
    -- Validate again (anti-cheat)
    if not self:isValid(square) then
        player:setHaloNote("Cannot place shop here", 255, 0, 0, 400)
        return
    end
    
    -- Verify player still has item
    local itemTag = nil
    if self.isPlayerShop then
        if self.isFreezer then
            itemTag = ItemTag.get(ResourceLocation.of("shops:PlayerShopFreezer"))
        else
            itemTag = ItemTag.get(ResourceLocation.of("shops:PlayerShop"))
        end
        
        if not player:getInventory():containsTag(itemTag) then
            player:setHaloNote("Item missing from inventory", 255, 0, 0, 400)
            return
        end
    end
    
    -- Create object (SERVER AUTHORITY)
    local cell = getWorld():getCell()
    local shop = IsoThumpable.new(cell, square, sprite, north, nil)
    if not shop then
        writeLog("Shops", "[ISAddPlayerShopAction] Failed to create IsoThumpable")
        return
    end
    
    shop:setSprite(sprite)
    shop:setIsThumpable(false)
    
    if self.isPlayerShop then
        shop:setIsContainer(true)
        shop:setCanBeLockByPadlock(true)
        if self.isFreezer then
            shop:getContainer():setType("freezer")
        end
        shop:getModData().owner = player:getUsername()
        shop:getModData().income = {}
    end
    
    -- Add to world
    square:AddTileObject(shop)
    
    -- CRITICAL: Sync to all clients
    shop:transmitCompleteItemToClients()
    
    -- Remove item from inventory + sync
    local item = player:getInventory():getFirstTag(itemTag)
    if item then
        player:getInventory():Remove(item)
        sendRemoveItemFromContainer(player:getInventory(), item)
    end
    
    writeLog("Shops", "[ISAddPlayerShopAction] Shop placed at " .. square:getX() .. "," .. square:getY())
end

function ISAddPlayerShopAction:new(player, square, sprite, north, isPlayerShop, isFreezer)
    local o = ISBuildAction.new(self, player, square)
    o.stopOnRun = true
    o.stopOnWalk = false
    o.skipBuildAction = false
    o.maxTime = 50  -- 5 seconds (ticks are 0.1s)
    o.sprite = sprite
    o.north = north or false
    o.isPlayerShop = isPlayerShop or false
    o.isFreezer = isFreezer or false
    return o
end
```

---

### 3. ✅ INTRODUCE ISAddShopAction (NEW FILE)

**File:** `Shops/42.13.1/media/lua/server/nshopsb42/actions/ISAddShopAction.lua`

**New code:**
```lua
-- Server-side timed action for Admin Shop placement
if isClient() and not isServer() then
    return
end

require "TimedActions/ISBuildAction"
local Shop = SHOPSB42.Shop
local Utilities = require("nshopsb42/HelperFunction/Utilities")

ISAddShopAction = ISBuildAction:derive("ISAddShopAction")

function ISAddShopAction:isValid(square)
    if not square then return false end
    if not square:isFree() then return false end
    if not square:isSolid() then return false end
    return true
end

function ISAddShopAction:perform()
    ISBuildAction.perform(self)
end

function ISAddShopAction:complete()
    ISBuildAction.complete(self)
    
    local square = self.square
    local sprite = self.sprite
    local north = self.north or false
    local player = self.character
    
    -- Admin validation
    if not Utilities.IsServerAdmin(player) then
        writeLog("Shops", "[ISAddShopAction] Non-admin attempted to place shop")
        return
    end
    
    if not self:isValid(square) then
        player:setHaloNote("Cannot place shop here", 255, 0, 0, 400)
        return
    end
    
    -- Create object (SERVER AUTHORITY)
    local cell = getWorld():getCell()
    local shop = IsoThumpable.new(cell, square, sprite, north, nil)
    if not shop then
        writeLog("Shops", "[ISAddShopAction] Failed to create IsoThumpable")
        return
    end
    
    shop:setSprite(sprite)
    shop:setIsThumpable(false)
    
    -- Add to world
    square:AddTileObject(shop)
    
    -- CRITICAL: Sync to all clients
    shop:transmitCompleteItemToClients()
    
    writeLog("Shops", "[ISAddShopAction] Admin shop placed at " .. square:getX() .. "," .. square:getY())
end

function ISAddShopAction:new(player, square, sprite, north)
    local o = ISBuildAction.new(self, player, square)
    o.stopOnRun = true
    o.stopOnWalk = false
    o.skipBuildAction = false
    o.maxTime = 50  -- 5 seconds
    o.sprite = sprite
    o.north = north or false
    return o
end
```

---

### 4. ✅ MODIFY PlayerShopContext - Queue action instead of direct creation

**File:** `Shops/42.13.1/media/lua/client/nshopsb42/context/PlayerShopContext.lua`

**CURRENT (lines 61-73):**
```lua
function PlayerShop.addPlayerShop(worldobjects, playerNum, sprites)
    local player = getSpecificPlayer(playerNum)
    SharedLogger.log("Shops", "[PlayerShop.addPlayerShop] Creating cursor for playerNum=" .. playerNum)
    local cursor = ShopSpriteCursorUI:new(player, sprites)
    if cursor and cursor.render and cursor.isValid then
        getCell():setDrag(cursor, playerNum)
    else
        SharedLogger.log("Shops", "[PlayerShop.addPlayerShop] NOT setting drag - cursor missing methods")
    end
end
```

**CHANGE TO:**
```lua
function PlayerShop.addPlayerShop(worldobjects, playerNum, sprites, isFreezer)
    local player = getSpecificPlayer(playerNum)
    SharedLogger.log("Shops", "[PlayerShop.addPlayerShop] Starting placement, isFreezer=" .. tostring(isFreezer))
    
    -- Create cursor for visual preview only
    local cursor = ShopSpriteCursorUI:new(player, sprites)
    
    -- Override tryBuild to queue action instead of creating object
    cursor.tryBuild = function(self)
        local sprite = self:getSprite()
        if not sprite then return end
        
        local spriteName = sprite:getName()
        local square = getWorld():getCell():getGridSquare(self.x, self.y, self.z)
        
        if not square then return end
        
        -- Queue the timed action (moved to server)
        local action = ISAddPlayerShopAction:new(
            player,
            square,
            spriteName,
            self.north or false,
            true,  -- isPlayerShop
            isFreezer or false
        )
        ISTimedActionQueue.add(action)
        
        -- Clear drag
        getWorld():getCell():setDrag(nil, 0)
    end
    
    if cursor and cursor.render and cursor.isValid then
        getCell():setDrag(cursor, playerNum)
    else
        SharedLogger.log("Shops", "[PlayerShop.addPlayerShop] Cursor missing required methods")
    end
end
```

**Also update the context menu calls (lines 232-249):**
```lua
if inv:containsTag(ItemTag.get(ResourceLocation.of("shops:PlayerShop"))) then
    context:addOption(
        UIText.AddPlayerShop,
        worldobjects,
        PlayerShop.addPlayerShop,
        playerNum,
        PlayerShop.sprites.NoSign,
        false  -- isFreezer
    )
end

if inv:containsTag(ItemTag.get(ResourceLocation.of("shops:PlayerShopFreezer"))) then
    context:addOption(
        UIText.AddPlayerShopFreezer,
        worldobjects,
        PlayerShop.addPlayerShop,
        playerNum,
        PlayerShop.sprites.Freezer,
        true  -- isFreezer
    )
end
```

---

### 5. ✅ MODIFY ShopContext - Queue action instead of sendClientCommand

**File:** `Shops/42.13.1/media/lua/client/nshopsb42/context/ShopContext.lua`

**CURRENT (lines 26-37):**
```lua
function Shop.addShop(worldobjects, playerNum, sprites)
    local player = getSpecificPlayer(playerNum)
    local cursor = ShopSpriteCursorUI:new(player, sprites)
    cursor.onPlace = function(self, x, y, z, north, sprite)
        sendClientCommand("Shop", "PlaceAdminShop", { sprites, x, y, z, north })
    end
    if cursor and cursor.render and cursor.isValid then
        getCell():setDrag(cursor, playerNum)
    end
end
```

**CHANGE TO:**
```lua
function Shop.addShop(worldobjects, playerNum, sprites)
    local player = getSpecificPlayer(playerNum)
    SharedLogger.log("Shops", "[Shop.addShop] Starting admin shop placement")
    
    -- Create cursor for visual preview only
    local cursor = ShopSpriteCursorUI:new(player, sprites)
    
    -- Override tryBuild to queue action instead of sending command
    cursor.tryBuild = function(self)
        local sprite = self:getSprite()
        if not sprite then return end
        
        local spriteName = sprite:getName()
        local square = getWorld():getCell():getGridSquare(self.x, self.y, self.z)
        
        if not square then return end
        
        -- Queue the timed action (server will execute complete())
        local action = ISAddShopAction:new(
            player,
            square,
            spriteName,
            self.north or false
        )
        ISTimedActionQueue.add(action)
        
        -- Clear drag
        getWorld():getCell():setDrag(nil, 0)
    end
    
    if cursor and cursor.render and cursor.isValid then
        getCell():setDrag(cursor, playerNum)
    else
        SharedLogger.log("Shops", "[Shop.addShop] Cursor missing required methods")
    end
end
```

---

### 6. ✅ MODIFY ShopSpriteCursorUI - Remove direct object creation

**File:** `Shops/42.13.1/media/lua/shared/nshopsb42/transactions/ShopSpriteCursorUI.lua`

**CURRENT (lines 40-56):**
```lua
function RealUI:tryBuild()
    if not self.character then return end
    local sprite = self:getSprite()
    if not sprite then return end
    local spriteName = sprite:getName()
    if not spriteName then return end
    self:create(self.x, self.y, self.z, self.north, spriteName)
    getWorld():getCell():setDrag(nil, 0)
end

function RealUI:create(x, y, z, north, sprite)
    sendClientCommand("PS", "PlacePlayerShop", { sprite, x, y, z, north })
end
```

**CHANGE TO:**
```lua
function RealUI:tryBuild()
    -- Base implementation: subclasses override to queue action
    -- Do NOT create objects or send placement commands here
    -- This is just the default no-op; PlayerShopContext/ShopContext override this
end

function RealUI:create(x, y, z, north, sprite)
    -- DEPRECATED: Use tryBuild() instead, which queues ISAddPlayerShopAction
    -- This is kept for backward compatibility only
end
```

---

## Summary of Changes

| File | Change | Type | Impact |
|------|--------|------|--------|
| ShopSpriteCursor.lua | Remove `create()` object creation | DELETE | Critical |
| ShopSpriteCursorUI.lua | Remove default `create()` implementation | DELETE | Medium |
| PlayerShopContext.lua | Override cursor.tryBuild() to queue action | MODIFY | Critical |
| ShopContext.lua | Override cursor.tryBuild() to queue action | MODIFY | Critical |
| ISAddPlayerShopAction.lua | NEW - server-side timed action | CREATE | Critical |
| ISAddShopAction.lua | NEW - admin shop timed action | CREATE | Critical |

---

## Order of Implementation

1. **Create ISAddPlayerShopAction.lua** (new file)
2. **Create ISAddShopAction.lua** (new file)
3. **Modify PlayerShopContext.lua** (queue action in tryBuild)
4. **Modify ShopContext.lua** (queue action in tryBuild)
5. **Modify ShopSpriteCursorUI.lua** (deprecate create(), keep tryBuild empty)
6. **Modify ShopSpriteCursor.lua** (deprecate create(), add warning log)
7. **Test in SP first**, then MP

---

## Expected Results

✅ Objects created only in server `complete()`
✅ Animations play during `perform()`
✅ `transmitCompleteItemToClients()` called
✅ Inventory removal synced atomically
✅ No duplication, no desync
✅ B42 compliant pattern
