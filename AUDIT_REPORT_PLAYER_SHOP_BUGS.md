# Audit Report - Player Shop Critical Bugs

## Bug #1: Item Not Removed from Inventory When Creating Player Shop (Duplication)

**Severity**: CRITICAL (Item duplication exploit)

**Affected Component**: Player Shop Creation System (both regular and freezer variants)

**Affected Features**:
- "Add Player Shop" (regular shop)
- "Add Player Shop Freezer" (freezer variant)

### Problem Description
When a player places a player shop in the world (regular or freezer), the shop container is successfully created, but the player's inventory item (the shop tile itself) is NOT removed from inventory. This creates a duplication: the player now has a shop in the world AND the shop item still in their inventory.

### Root Cause Analysis

**Location**: `Shops/42.13.1/media/lua/server/ShopSpriteCursor.lua` (Lines 55-61)

The bug is in the `ShopSpriteCursor:create()` method:

```lua
if itemTag then
    local playerShop = self.character:getInventory():getFirstTag(itemTag)
    if playerShop then
        -- Item removal is handled server-side via onClientCommand to prevent client-side inventory mutations
        writeLog("Shops", "[SERVER] ShopSpriteCursor:create() - Shop created, item removal delegated to server command")
    end
end
```

**The Issue**:
1. Line 56: The code finds the shop item via `getFirstTag()` ✓
2. Line 57: It checks if the item exists ✓
3. **Line 59: The comment claims removal is "delegated to server command"**
4. **Line 60: But NO server command is actually sent** ✗

The comment suggests future work or broken delegation. The `RemoveItemFromInventory` server function exists in `PlayerShopServer.lua` (line 64-73) but is NEVER called.

### Impact
- Players can duplicate player shop items infinitely
- Breaks economy/balance if shop items are tradeable or valuable
- Server logs show shops being created but never show items being removed
- No error occurs, just silently fails to remove item

### Evidence
1. Both player shop variants use the same code path: `ShopSpriteCursor:create()` (line 12-47)
   - Regular shops check: `ItemTag.get(ResourceLocation.of("shops:PlayerShop"))` (line 36)
   - Freezer shops check: `ItemTag.get(ResourceLocation.of("shops:PlayerShopFreezer"))` (line 34)
   - Both set the `itemTag` variable, which triggers the removal code at lines 55-61
2. `RemoveItemFromInventory` function defined at `PlayerShopServer.lua:64` but is never referenced anywhere in the codebase (verified via grep)
3. No `sendClientCommand("PS", "RemoveItemFromInventory", ...)` call exists anywhere
4. Similar legitimate removal exists in `PlayerShopServer.lua:64-73` for income withdrawal, showing the pattern is known

### Solution
**Add the missing server command call in `ShopSpriteCursor.lua` after line 57:**

```lua
if itemTag then
    local playerShop = self.character:getInventory():getFirstTag(itemTag)
    if playerShop then
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

---

## Bug #2: Admin Users Cannot Add Shops Without Debug Mode

**Severity**: HIGH (Feature broken for multiplayer admins)

**Affected Component**: Admin Shop Creation

### Problem Description
Admin users on multiplayer servers cannot place shops (either regular shops or player shops) unless the server is running with the `-debug` flag enabled. The "Add Shop" context menu option does not appear for admins without debug mode.

### Root Cause Analysis

**Location**: `Shops/42.13.1/media/lua/client/Context/ShopContext.lua` (Lines 29-38)

```lua
function Shop.ShopContextMenu(playerNum, context, worldobjects)
    local isSinglePlayer = isServer() or isDebug    -- <-- PROBLEM: mixing isServer with isDebug
    local isAdminMode = isClient() and isAdmin()
    local allowAccess = isSinglePlayer or isAdminMode
    
    if isDebug then 
         writeLog("Shops", "[CLIENT] ShopContextMenu: isServer=" .. tostring(isSinglePlayer) .. ", isAdmin=" .. tostring(isAdminMode) .. ", allowAccess=" .. tostring(allowAccess))
     end
      
      if not allowAccess then return end
      ...
end
```

**The Logic Error**:
- Line 30: `isSinglePlayer = isServer() or isDebug`
  - In multiplayer, `isServer()` returns false (only true on server, not on client)
  - On client, the server flag is also false
  - This means `isSinglePlayer` is only true if debug mode is on
  
- Line 31: `isAdminMode = isClient() and isAdmin()`
  - This should correctly identify admins on clients
  
- Line 32: `allowAccess = isSinglePlayer or isAdminMode`
  - Should allow access if admin OR single player
  - Should be true for admins

**But the log message reveals the actual behavior**:
- When an admin tests on multiplayer without debug: `isSinglePlayer=false, isAdmin=true, allowAccess=true`
- Yet the menu doesn't appear

### Root Cause (Deeper Analysis)

The variable naming is misleading. `isSinglePlayer` is NOT actually "single player detection" - it's a debug OR single player check. The intent was:
- "Allow in single player OR allow in debug mode"

But the admin check is independent. The real issue is that the variable should be used for something else, and the logic is convoluted.

### Comparison with PlayerShopContext.lua

**Location**: `Shops/42.13.1/media/lua/client/Context/PlayerShopContext.lua` (Lines 203-220)

```lua
function PlayerShop.ItemsSellPrice(playerNum, context, items)
     items = ISInventoryPane.getActualItems(items)
     if not items then return end
     if #items < 1 then return end
     local container = items[1]:getContainer()
     local player = getPlayer(playerNum)
     if container and container:isInCharacterInventory(player) then
         local inv = player:getInventory()

         -- Check if player has Write tag OR is in debug mode
         local hasWriteTag = ItemTag.Write ~= nil and inv:containsTag(ItemTag.get(ResourceLocation.of("shops:Write")))
         local isDebugMode = getCore():getDebug()
         
         if hasWriteTag or isDebugMode then  -- <-- Correct logic
             context:addOption(UIText.SetPricePlayerShop, worldobjects, PlayerShop.PlayerShopSetPrice, playerNum, items,
                  container);
         end
     end
 end
```

**This uses correct logic**:
- Line 213: Check for Write tag (permission) OR debug mode
- Line 216: Simple OR condition - no convoluted variable assignments

But PlayerShop doesn't have admin checks at all! It uses a Write tag system.

### Impact
- Admins on multiplayer servers cannot manage shops unless debug flag is enabled
- The "Add Shop" option is completely hidden from the context menu
- Feature is broken for multiplayer administration
- Inconsistent with other admin-permissioned features (player shop management is owner-only, regular shops require debug OR single player)

### Solution

**Option A: Fix the Logic (Simple Fix)**
```lua
function Shop.ShopContextMenu(playerNum, context, worldobjects)
    local isAdminMode = isClient() and isAdmin()
    local isSinglePlayerDebug = (not isClient() and not isServer()) and getCore():getDebug()
    local allowAccess = isAdminMode or isSinglePlayerDebug
    
    if not allowAccess then return end
    -- ... rest of function
end
```

**Option B: Add Admin Check to Helper Function (Recommended)**

Use the existing `Utilities.IsClientAdmin()` function which already handles this correctly:
```lua
local Utilities = require "HelperFunction/Utilities"

function Shop.ShopContextMenu(playerNum, context, worldobjects)
    if not Utilities.IsClientAdmin() then return end
    -- ... rest of function
end
```

The `Utilities.IsClientAdmin()` function (line 49-50) is designed exactly for this:
```lua
function Utilities.IsClientAdmin()
    return (isClient() and isAdmin()) or Utilities.IsSinglePlayerDebug();
end
```

---

## Summary Table

| Bug | Root Cause | Impact | Fix Complexity |
|-----|-----------|--------|-----------------|
| #1: Item Duplication | Missing `sendClientCommand()` call in `ShopSpriteCursor.lua:create()` | Item duplication exploit possible | Simple (1 line) |
| #2: Admin Cannot Add Shops | Incorrect logic in `ShopContext.lua:30` mixing isServer/isDebug checks | Admin feature broken on multiplayer | Simple (refactor condition) |

---

## Verification Steps

### Bug #1 Verification

**Test Case 1: Regular Player Shop**
1. Admin/Owner creates a regular player shop tile item
2. Right-click ground → "Add Player Shop" → Select location
3. **BUG**: Shop exists in world AND player still has shop item in inventory
4. **FIX**: After fix, shop exists but inventory item is removed

**Test Case 2: Freezer Player Shop**
1. Admin/Owner creates a freezer player shop tile item
2. Right-click ground → "Add Player Shop Freezer" → Select location
3. **BUG**: Freezer shop exists in world AND player still has freezer shop item in inventory
4. **FIX**: After fix, freezer shop exists but inventory item is removed

### Bug #2 Verification
1. Admin logs into multiplayer server (without -debug flag)
2. Right-click on ground where shops can be placed
3. **BUG**: "Add Shop" option does NOT appear in context menu
4. **FIX**: After fix, "Add Shop" option appears for admins
5. **Confirm**: Works without -debug flag enabled on server
