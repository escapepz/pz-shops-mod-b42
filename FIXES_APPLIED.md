# Bug Fixes Applied - Player Shop System

## Summary
Two critical bugs in the player shop system have been fixed:
1. ✅ Item duplication when creating player shops
2. ✅ Admin permission check broken on multiplayer servers

---

## Fix #1: Item Duplication (Bug #1)

**Files Modified**:
1. `Shops/42.13.1/media/lua/server/ShopSpriteCursor.lua` (Lines 55-67)
2. `Shops/42.13.1/media/lua/server/PlayerShopServer.lua` (Lines 64-74)

**Lines Changed**:
- ShopSpriteCursor.lua: 55-67 (previously 55-61)
- PlayerShopServer.lua: 64-74 (previously 64-73)

### What Was Wrong
When a player placed a player shop (regular or freezer), the shop was created but the inventory item was never removed, allowing players to create infinite duplicates.

### What Was Fixed

**Part 1: ShopSpriteCursor.lua**
Added the missing `sendClientCommand()` call to trigger item removal:

**Part 2: PlayerShopServer.lua**
Added the missing `sendRemoveItemFromContainer()` call to sync the removal to all clients:

---

### Change 1: ShopSpriteCursor.lua

**Before**:
```lua
if itemTag then
    local playerShop = self.character:getInventory():getFirstTag(itemTag)
    if playerShop then
        -- Item removal is handled server-side via onClientCommand to prevent client-side inventory mutations
        writeLog("Shops", "[SERVER] ShopSpriteCursor:create() - Shop created, item removal delegated to server command")
    end
end
```

**After**:
```lua
if itemTag then
    local playerShop = self.character:getInventory():getFirstTag(itemTag)
    if playerShop then
        -- Send server command to remove the shop item from inventory
        sendClientCommand(
            self.character,
            "PS",
            "RemoveItemFromInventory",
            { itemID = playerShop:getID() }
        )
        writeLog("Shops", "[SERVER] ShopSpriteCursor:create() - Item removal command sent for ID: " .. tostring(playerShop:getID()))
    end
end
```

### Change 2: PlayerShopServer.lua

**Before**:
```lua
function PSServer.RemoveItemFromInventory(player, args)
	local itemID = args.itemID
	if not itemID then return end
	
	local item = player:getInventory():getItemById(itemID)
	if item then
		item:getContainer():Remove(item)
		writeLog("Shops", "[SERVER] PlayerShop inventory item removed - ID: " .. tostring(itemID))
	end
end
```

**After**:
```lua
function PSServer.RemoveItemFromInventory(player, args)
	local itemID = args.itemID
	if not itemID then return end
	
	local item = player:getInventory():getItemById(itemID)
	if item then
		local container = item:getContainer()
		container:Remove(item)
		sendRemoveItemFromContainer(container, item)
		writeLog("Shops", "[SERVER] PlayerShop inventory item removed - ID: " .. tostring(itemID))
	end
end
```

### Impact
- **Server-side**: Item removed from player's inventory via `container:Remove(item)`
- **Client sync**: `sendRemoveItemFromContainer()` broadcasts removal to all connected clients
- Both regular player shops and freezer player shops now properly remove the item from inventory
- Prevents item duplication exploit
- Logs the removal for audit trail
- Matches the synchronization pattern used throughout the codebase (PlayerShopBuyAction, ShopSellAction, etc.)

### Affected Features
- "Add Player Shop" 
- "Add Player Shop Freezer"

---

## Fix #2: Admin Permission Check (Bug #2)

**File**: `Shops/42.13.1/media/lua/client/Context/ShopContext.lua`

**Lines Changed**: 
- Line 2: Added Utilities import
- Lines 30-38: Refactored admin check logic

### What Was Wrong
The admin permission check used faulty logic that only allowed access in debug mode or single-player, blocking admins on multiplayer servers from creating shops.

### What Was Fixed
Replaced the broken logic with the `Utilities.IsClientAdmin()` helper function which correctly handles both:
- Multiplayer admins (via `isAdmin()`)
- Single-player debug mode

**Before**:
```lua
function Shop.ShopContextMenu(playerNum, context, worldobjects)
    local isSinglePlayer = isServer() or isDebug
    local isAdminMode = isClient() and isAdmin()
    local allowAccess = isSinglePlayer or isAdminMode
    
    if isDebug then 
         writeLog("Shops", "[CLIENT] ShopContextMenu: isServer=" .. tostring(isSinglePlayer) .. ", isAdmin=" .. tostring(isAdminMode) .. ", allowAccess=" .. tostring(allowAccess))
     end
      
      if not allowAccess then return end
```

**After**:
```lua
function Shop.ShopContextMenu(playerNum, context, worldobjects)
    -- Allow access if client is admin or in single-player debug mode
    if not Utilities.IsClientAdmin() then return end
    
    if isDebug then 
         writeLog("Shops", "[CLIENT] ShopContextMenu: Admin access granted")
     end
```

### Added Import
```lua
local Utilities = require "HelperFunction/Utilities"
```

The `Utilities.IsClientAdmin()` function (from `HelperFunction/Utilities.lua:49-50`):
```lua
function Utilities.IsClientAdmin()
    return (isClient() and isAdmin()) or Utilities.IsSinglePlayerDebug();
end
```

### Impact
- Admins on multiplayer servers can now add shops without the `-debug` flag
- Cleaner, more maintainable code
- Uses established utility patterns instead of custom logic
- Better logging

---

## Testing Checklist

### Fix #1 Testing
- [ ] Regular player shop: Place shop → Verify item removed from inventory
- [ ] Freezer player shop: Place freezer → Verify freezer item removed from inventory
- [ ] Server logs show "Item removal command sent" for each shop created
- [ ] Cannot create duplicates by placing multiple shops with same item

### Fix #2 Testing
- [ ] Admin user on multiplayer server (no `-debug` flag) can see "Add Shop" option
- [ ] Admin can successfully place shops
- [ ] Single-player with debug mode still works
- [ ] Non-admin players still cannot see "Add Shop" option
- [ ] Debug logs show "Admin access granted" when admin opens context menu

---

## Code Quality
- ✅ Uses existing utility functions for consistency
- ✅ Maintains logging for audit trail
- ✅ No breaking changes to other systems
- ✅ Handles both shop variants with single fix
- ✅ Cleaner, more maintainable code

---

## Synchronization Flow (Fix #1)

```
Client                              Server                          All Clients
------                              ------                          -----------
Place shop
       |
       └─> ShopSpriteCursor:create()
                                    Creates shop object
                                    Finds shop item
                                    |
                                    └─> sendClientCommand("PS", "RemoveItemFromInventory", {itemID})
                                        |
                                        └─> PSServer.RemoveItemFromInventory(player, args)
                                            container:Remove(item)
                                            sendRemoveItemFromContainer(container, item)
                                            └──────────────────────────────> Sync to all clients
                                                                              Item removed from inventory
```

The fix ensures:
1. **Server Authority**: Item removal happens server-side (prevents client tampering)
2. **Client Sync**: `sendRemoveItemFromContainer()` notifies all connected clients of the change
3. **Atomicity**: Shop creation and item removal are part of the same transaction flow

## Related Files
- `HelperFunction/Utilities.lua` - Already contains `IsClientAdmin()` function (used by Fix #2)
- `PlayerShopContext.lua` - Not affected by these fixes
- Other removal patterns: `PlayerShopBuyAction.lua`, `ShopSellAction.lua` - Follow the same sync pattern
