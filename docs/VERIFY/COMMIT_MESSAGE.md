# Commit Message for Lua File Changes

## Short Form (for commit title)
```
fix: player shop duplication and admin permission issues
```

## Detailed Form (full commit message)

```
fix: player shop duplication and admin permission issues

Fixed two critical bugs in the player shop system:

1. Item duplication exploit when creating player shops
   - Problem: Shop item was never removed from player inventory after placing shop
   - Solution: Added sendClientCommand() in ShopSpriteCursor:create() to trigger
     server-side item removal via PSServer.RemoveItemFromInventory()
   - Added sendRemoveItemFromContainer() in PSServer.RemoveItemFromInventory()
     to properly sync the inventory change to all connected clients
   - Matches synchronization pattern used throughout codebase
   - Affects both regular and freezer player shop variants

2. Admin users cannot add shops on multiplayer without -debug flag
   - Problem: Permission check logic was broken, only allowed access with
     isServer() or debug mode enabled
   - Solution: Replaced with Utilities.IsClientAdmin() helper function
     which correctly handles both multiplayer admins and single-player debug mode
   - Cleaner, more maintainable code using established utility patterns

Files Changed:
- Shops/42.13.1/media/lua/server/ShopSpriteCursor.lua (lines 58-65)
  Added missing sendClientCommand() for item removal
  
- Shops/42.13.1/media/lua/server/PlayerShopServer.lua (lines 70-72)
  Added sendRemoveItemFromContainer() for client sync
  
- Shops/42.13.1/media/lua/client/Context/ShopContext.lua (lines 2, 30-36)
  Added Utilities import and fixed admin permission check

Testing:
- Regular player shop: item removed from inventory after placement
- Freezer player shop: freezer item removed from inventory after placement
- Admin on multiplayer: can add shops without -debug flag
- Single-player: debug mode still works correctly
- Server logs show proper item removal audit trail
```

## Alternative Concise Form (if verbose commits not preferred)

```
fix: player shop item duplication and admin permissions

- Add sendClientCommand to remove shop item in ShopSpriteCursor.lua
- Add sendRemoveItemFromContainer sync in PlayerShopServer.lua
- Use Utilities.IsClientAdmin() for correct admin permission check
- Fixes duplication on both regular and freezer shops
- Fixes admin shop placement on multiplayer servers
```

## For Git

When committing, use:
```bash
git add Shops/42.13.1/media/lua/server/ShopSpriteCursor.lua
git add Shops/42.13.1/media/lua/server/PlayerShopServer.lua
git add Shops/42.13.1/media/lua/client/Context/ShopContext.lua

git commit -m "fix: player shop duplication and admin permission issues

Fixed two critical bugs in the player shop system:

1. Item duplication exploit when creating player shops
   - Added sendClientCommand() in ShopSpriteCursor:create()
   - Added sendRemoveItemFromContainer() in PSServer.RemoveItemFromInventory()
   - Properly syncs inventory removal to all clients
   - Affects both regular and freezer variants

2. Admin cannot add shops on multiplayer without -debug
   - Replaced broken permission logic with Utilities.IsClientAdmin()
   - Correctly handles both multiplayer admins and debug mode

Files:
- Shops/42.13.1/media/lua/server/ShopSpriteCursor.lua
- Shops/42.13.1/media/lua/server/PlayerShopServer.lua
- Shops/42.13.1/media/lua/client/Context/ShopContext.lua"
```
