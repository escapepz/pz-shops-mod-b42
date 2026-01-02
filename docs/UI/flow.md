Key differences between old and new:

```mermaid
graph TD
    A["Old Implementation"] -->|Context Menu| B["PlayerShopContextMenu checks inventory"]
    B -->|Add Player Shop| C["addPlayerShop creates ShopSpriteCursor"]
    C -->|setDrag| D["ISBuildingObject direct subclass"]
    D -->|toggle sprites| E["Rotate key"]
    D -->|click to place| F["ShopSpriteCursor:create"]
    F -->|spawns| G["IsoThumpable + owner + container"]

    H["New Implementation"] -->|Context Menu| I["PlayerShopContextMenu checks inventory"]
    I -->|Add Player Shop| J["addPlayerShop creates ShopSpriteCursor"]
    J -->|setDrag| K["ShopSpriteCursorUI lazy-loading wrapper"]
    K -->|defers to| L["ISBuildingObject on first use"]
    L -->|toggle sprites| M["Rotate key"]
    K -->|click to place| N["ShopSpriteCursor:create server-side"]
    N -->|spawns| O["IsoThumpable + owner + container"]

    style K fill:#1a1a1a,stroke:#0f0,color:#0f0
    style L fill:#1a1a1a,stroke:#ff0,color:#ff0
    style N fill:#1a1a1a,stroke:#0ff,color:#0ff
```

**1. Lazy-loading wrapper** (NEW)

```lua
-- OLD: Direct ISBuildingObject subclass
ShopSpriteCursor = ISBuildingObject:derive("ShopSpriteCursor")

-- NEW: Deferred initialization via ShopSpriteCursorUIBase
ShopSpriteCursor = ShopSpriteCursorUI:derive("ShopSpriteCursor")
  └─ ShopSpriteCursorUI is a lazy wrapper
     └─ Upgrades to ISBuildingObject on first client-side use
```

**2. File split** (NEW)

- `ShopSpriteCursorUI.lua` - Client-side UI wrapper (shared code, defers to ISBuildingObject)
- `ShopSpriteCursor.lua` - Server/SP-only creation logic (lines 1-4 check: `if isClient() and not isServer() then return end`)

**3. Error handling** (NEW)
More verbose logging and null checks:

```lua
-- NEW lines 51-54
if SHOPSB42.ShopSpriteCursor and SHOPSB42.ShopSpriteCursor.create then
    return SHOPSB42.ShopSpriteCursor:create(...)
end
SharedLogger.log("Shops", "[RealUI:create] ERROR: ShopSpriteCursor:create not available")
```

**4. Inventory removal** (SAME LOGIC, DIFFERENT FLOW)

- Now sends client command instead of direct removal (line 74):

```lua
sendClientCommand(self.character, "PS", "RemoveItemFromInventory", { itemID = playerShop:getID() })
```

**Result**: The new implementation is more robust with lazy-loading (handles ISBuildingObject availability gracefully) and proper client/server separation for multiplayer safety.
