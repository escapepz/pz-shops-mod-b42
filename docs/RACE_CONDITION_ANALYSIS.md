# Race Condition Analysis: Player Shop UI Opening/Pickup

## Problem Summary

When a player opens the shop UI and another player picks up the shop (while it's open), there are several race conditions:

1. **Shop Object Reference Becomes Stale** - The UI holds a reference to the shop object, but the server removes it from the world
2. **ModData Persistence** - The shop's modData (income, prices, etc.) may not be properly cleaned up when the shop is picked up while UI is open
3. **UI State Mismatch** - The UI continues to operate on a shop object that no longer exists in the world
4. **No Busy Lock Check on Pickup** - The server's `PickupShop()` doesn't verify if the shop is currently busy before allowing pickup

## Current Implementation

### UI Opening (PlayerShopUI:show, line 41-62)
```lua
function PlayerShopUI:show(player, shop)
    -- Store SHOP position for distance checking
    posX = square:getX()
    posY = square:getY()
    if PlayerShopUI.instance == nil then
        ...create UI instance...
    end
    PlayerShopUI.instance.shop = shop  -- Stores reference to shop object
    PlayerShop.toggleBusy(shop, player:getUsername(), true)  -- Marks as busy
    return PlayerShopUI.instance
end
```

### Pickup Handler (PlayerShopServer.lua:92-125)
```lua
function PSServer.PickupShop(player, args)
    local shop = getShopObject(coords)
    
    -- Only checks if shop has items/income
    -- NO CHECK if shop is currently busy (UI is open)
    
    if items and items:size() > 0 then
        return
    end
    if income and #income > 0 then
        return
    end
    
    -- Removes shop from world (shop object becomes stale in UI)
    shop:getSquare():transmitRemoveItemFromSquare(shop)
    
    -- Adds item to player inventory
    local newItem = instanceItem(itemType)
    player:getInventory():AddItem(newItem)
    sendAddItemToContainer(player:getInventory(), newItem)
end
```

### Busy Status Check (PlayerShopContext.lua:141-157)
```lua
function PlayerShop.isBusy(shop)
    local id = PlayerShop.getShopID(shop)
    local shopStatus = PlayerShop.status[id]
    if shopStatus then
        if not shopStatus.time then
            shopStatus.time = getTimestampMs() + shopLockTime
        end
        if getTimestampMs() > shopStatus.time then
            return false  -- Timeout after 10 minutes
        else
            return shopStatus.busy
        end
    else
        return false
    end
end
```

## Race Condition Scenarios

### Scenario 1: Concurrent Pickup While UI Open
**Timeline:**
1. Player A opens shop UI at location (100, 100)
   - `toggleBusy(shop, "PlayerA", true)` sent to server
   - `PlayerShopUI.instance.shop` holds reference to shop object
2. Player B picks up the same shop
   - Server's `PickupShop()` **DOES NOT CHECK** if shop is busy
   - Server removes shop from world: `transmitRemoveItemFromSquare()`
   - PlayerShopUI still holds stale reference
3. Player A interacts with UI
   - Calls methods on stale shop object
   - May cause crashes or undefined behavior

**Impact:**
- Stale shop reference in UI
- Potential crash when UI tries to access shop properties
- No cleanup of shop modData

### Scenario 2: ModData Orphaning
**Problem:**
- When pickup happens, the server creates new item from inventory template
- Original shop's modData (income, prices, custom settings) may not transfer correctly
- If modData stays on world object, it persists as "ghost data"

### Scenario 3: UI Closes, Then Toggles Busy Off
**Timeline:**
1. Player A opens shop UI, marks busy=true
2. Player B picks up shop while UI open
3. Player A's UI closes (noticing stale reference or distance)
4. UI calls `toggleBusy(shop, "PlayerA", false)`
   - But shop is now gone from world
   - LocalShop.status may not update correctly
   - Lock state becomes inconsistent

## Required Fixes

### 1. **Server-Side: Add Busy Check to Pickup** (CRITICAL)
In `PlayerShopServer.lua:PickupShop()`:
```lua
function PSServer.PickupShop(player, args)
    local coords = args[1]
    local shop = getShopObject(coords)
    
    if not shop then
        return
    end
    
    -- NEW: Check if shop is currently busy (UI open elsewhere)
    local PSClient = require("nshopsb42/PlayerShopClient")
    if PlayerShopStatus[tostring(shop:getX()) .. "-" .. tostring(shop:getY())] then
        local status = PlayerShopStatus[tostring(shop:getX()) .. "-" .. tostring(shop:getY())]
        if status and status.busy then
            -- Reject pickup while shop UI is open
            -- Sync status back to requester so they see it's locked
            Utilities.SendServerCommandTo(player, "nshopsb42", "PlayerShopSyncStatusData", { PlayerShopStatus })
            return
        end
    end
    
    -- Continue with existing checks...
    local items = shop:getContainer():getItems()
    if items and items:size() > 0 then
        return
    end
    
    -- ... rest of function
end
```

### 2. **Client-Side: Validate Shop Object in UI**
In `PlayerShopUI.lua:update()`:
```lua
function PlayerShopUI:update()
    local player = self.player
    if not player then
        self:close()
        return
    end
    
    -- NEW: Check if shop object is still valid
    local shop = self.shop
    if not shop or not shop:getSquare() then
        -- Shop was removed from world
        SharedLogger.log("Shops", "[PlayerShopUI] Shop object became invalid, closing UI")
        self:close()
        return
    end
    
    -- Existing distance check
    if player:DistTo(posX, posY) > 2 then
        self:close()
    end
    
    -- ... rest of function
end
```

### 3. **Client-Side: Safe Cleanup on Close**
In `PlayerShopUI.lua:close()`:
```lua
function PlayerShopUI:close()
    ISCollapsableWindow.close(self)
    if not PlayerShopUI.instance then
        return
    end
    
    local shop = PlayerShopUI.instance.shop
    local username = self.player:getUsername()
    
    -- NEW: Check if shop still exists before toggling busy
    if shop and shop:getSquare() then
        if PlayerShop.isBlockByUser(shop, username) then
            PlayerShop.toggleBusy(shop, username, false)
        end
    else
        -- Shop was removed; clear local busy state directly
        local shopId = tostring(shop:getX()) .. "-" .. tostring(shop:getY())
        PlayerShop.status[shopId] = nil
        SharedLogger.log("Shops", "[PlayerShopUI:close] Shop was removed, cleared local status")
    end
    
    -- ... rest of cleanup
end
```

### 4. **Prevent UI From Opening on Busy Shop** (Already Exists)
Verify `PlayerShopContext.lua:playerShopUI()` line 68-70 works correctly:
```lua
action:setOnComplete(function()
    if PlayerShop.isBusy(shop) then
        return  -- Prevents opening UI if shop is busy
    end
    PlayerShopUI:show(player, shop)
end)
```

## Testing Checklist

- [ ] Player A opens shop UI at location (100, 100)
- [ ] While UI is open, Player B right-clicks shop and selects "Pick Up"
  - Expected: Pickup is rejected with message
  - Verify: UI remains open on Player A's screen
- [ ] After pickup is rejected, Player A closes UI
  - Expected: No errors, UI closes cleanly
  - Verify: Busy state is toggled false properly
- [ ] Test timeout: Leave shop UI open for >10 minutes
  - Expected: Timeout after 10 minutes, other players can pick up
  - Verify: Timer works correctly
- [ ] Kill process while UI open, reconnect
  - Expected: Busy state expires after 10 minutes
  - Verify: Shop becomes available to other players

## Files to Modify

1. `Shops/42.13.1/media/lua/server/nshopsb42/PlayerShopServer.lua` - Add busy check to `PickupShop()`
2. `Shops/42.13.1/media/lua/client/nshopsb42/ui/PlayerShopUI.lua` - Add object validation in `update()` and `close()`
3. `Shops/42.13.1/media/lua/client/nshopsb42/context/PlayerShopContext.lua` - (Optional) Add logging for debugging

## Severity

**CRITICAL** - Can cause crashes, UI hangs, and inconsistent game state if race condition triggers.
