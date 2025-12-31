# Differences: Build.md Documentation vs Add Shop/Add Player Shop Implementation

## Summary
The current implementation **violates the documented B42 building object pipeline**. According to BUILD.md, object creation and inventory consumption must happen in `complete()` on the server in MP, but the implementation places objects directly on click without proper timed action structure.

---

## BUILD.md Requirements

### Proper B42 Pipeline:
1. **Drag preview** (client-side) - `ISBuildingObject` visual
2. **Timed action queued** - `ISBuildAction`
3. **`perform()`** - Animation, sounds, progress
4. **`complete()`** - Server: create object, consume items, transmit
5. **`transmit()` calls** - Sync to all clients

---

## Actual Implementation

### Add Player Shop (PlayerShopContext.lua:61-73)
```lua
function PlayerShop.addPlayerShop(worldobjects, playerNum, sprites)
    local cursor = ShopSpriteCursorUI:new(player, sprites)
    if cursor and cursor.render and cursor.isValid then
        getCell():setDrag(cursor, playerNum)
    end
end
```

**Issues:**
- ❌ No timed action queued - skips delay/animation
- ❌ Object creation directly in cursor (not in `complete()`)
- ❌ Inventory item consumed in server-side `create()` without validation action
- ✅ Uses `ShopSpriteCursorUI` for drag preview (correct)

### Add Shop (ShopContext.lua:26-37)
```lua
function Shop.addShop(worldobjects, playerNum, sprites)
    local cursor = ShopSpriteCursorUI:new(player, sprites)
    cursor.onPlace = function(self, x, y, z, north, sprite)
        sendClientCommand("Shop", "PlaceAdminShop", { sprites, x, y, z, north })
    end
    if cursor and cursor.render and cursor.isValid then
        getCell():setDrag(cursor, playerNum)
    end
end
```

**Issues:**
- ❌ No timed action - direct command on click
- ❌ `onPlace` callback is never called (not part of ISBuildingObject interface)
- ✅ Attempts to use client command (better than direct server creation)
- ✅ Uses drag preview (correct)

---

## ShopSpriteCursor Server Logic

### Current Flow (ShopSpriteCursor.lua:22-83)
```lua
function ShopSpriteCursor:create(x, y, z, north, sprite)
    -- Creates IsoThumpable directly
    local shop = IsoThumpable.new(...)
    square:AddSpecialObject(shop)
    -- Consumes inventory item directly
    local playerShop = self.character:getInventory():getFirstTag(itemTag)
    sendClientCommand(self.character, "PS", "RemoveItemFromInventory", ...)
end
```

**Issues:**
- ❌ Object created directly (no permission/validation action)
- ❌ Inventory item removal sent as *another* command after object exists
- ❌ No `transmitCompleteItemToClients()` call (object may not sync)
- ⚠️  Uses `AddSpecialObject()` instead of `AddTileObject()`
- ⚠️  No explicit sync after `shop:transmitModData()`

---

## Key Violations of BUILD.md Section 9 (Common Mistakes)

| Mistake                          | Found? | Location |
|----------------------------------|--------|----------|
| Creating IsoObject in perform()  | ✅     | Direct in ShopSpriteCursor |
| Creating objects on client in MP | ✅     | Cursor.tryBuild() for Player Shop |
| Forgetting transmitComplete...() | ✅     | ShopSpriteCursor.lua line 62 |
| Mutating inventory without sync  | ✅     | Removed in separate command |
| Passing client objects to server | ✅     | Client creates, passes cursor |

---

## What Should Happen (Per BUILD.md)

### Correct Player Shop Placement:
1. Player selects "Add Player Shop" → drag cursor appears (✅ working)
2. Player clicks location → **Queue ISBuildAction** (❌ missing)
3. Player performs animation → `perform()` runs (❌ missing)
4. Animation completes → `complete()` runs on server (❌ runs directly)
   - Create IsoThumpable
   - Set owner and container
   - Call `transmitCompleteItemToClients()` ← **Critical, missing**
   - Remove item from inventory + sync

### Correct Admin Shop Placement:
1. Admin selects sprite → drag cursor (✅ working)
2. Admin clicks → **Queue ISBuildAction** (❌ missing)
3. Same flow as Player Shop

---

## Impact

### Singleplayer
- Works but violates pattern
- No visible bugs (local authority)

### Multiplayer
- **Objects may not sync properly** (no transmitComplete call)
- **Inventory desyncs possible** (remove command sent after placement)
- **Race conditions** (no permission action before placement)
- **Duplication risk** (client creates visual object, then server object)

---

## Recommendations

1. **Create `ISAddPlayerShopAction`** extending `ISBuildAction`
   - `perform()`: Animation, sounds
   - `complete()`: Server creates object, calls `transmitCompleteItemToClients()`

2. **Remove direct server creation** from ShopSpriteCursor
   - Move logic to timed action handler in server code

3. **Add explicit transmit calls**
   - `shop:transmitCompleteItemToClients()` after creation
   - `sendRemoveItemFromContainer()` within same action

4. **Add validation hook** in timed action
   - Check ownership rules
   - Check inventory has item
   - Validate placement square before queuing

---

## Files Affected

- `Shops/42.13.1/media/lua/shared/nshopsb42/transactions/ShopSpriteCursor.lua`
- `Shops/42.13.1/media/lua/shared/nshopsb42/transactions/ShopSpriteCursorUI.lua`
- `Shops/42.13.1/media/lua/client/nshopsb42/context/PlayerShopContext.lua`
- `Shops/42.13.1/media/lua/client/nshopsb42/context/ShopContext.lua`
- `Shops/42.13.1/media/lua/server/nshopsb42/PlayerShopServer.lua` (needs handler)
- `Shops/42.13.1/media/lua/server/nshopsb42/ShopInitServer.lua` (needs handler)
