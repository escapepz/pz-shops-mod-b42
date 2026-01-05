# Phase 6.1: Update ModData Schema

## Objective
Stop storing prices in ModData for NPC shops and implement lazy-migration for existing saves.

---

## Current State

### Where Prices Are Stored
1. **NPC Shops**: Not stored anywhere (uses NPCShopCatalog)
2. **Player Shops**: Stored on item ModData as `price` and `specialCoin` fields
3. **Global State**: CoinBalance (user wallets) stored in ModData under key "CoinBalance"

### Current ModData Usage Pattern
```lua
-- Player Shop items store prices in ModData
item:getModData().price = 100
item:getModData().specialCoin = false

-- User balances stored globally
ModData:get():setViaString("CoinBalance", serialize(balanceData))
```

---

## Phase 6.1 Tasks

### 6.1.1 Audit Existing ModData Fields

**Goal**: Identify all places where prices are stored in ModData

**Files to Check**:
- `Shops/42.13.1/media/lua/server/` - Server item setup
- `Shops/42.13.1/media/lua/client/nshopsb42/ui/SetPriceUI.lua` - Player shop price setting
- `Shops/42.13.1/media/lua/client/nshopsb42/ui/PlayerShopUI.lua` - Player shop display
- `ShopsHooksExample/` - Reference code

**Key Findings**:
- Player shop items have `modData.price` and `modData.specialCoin`
- This is **NOT used for NPC shops** (already eliminated in Phases 1-5)
- User balances in `ModData.CoinBalance` are legitimate (necessary)

---

### 6.1.2 Mark Old Price Fields as Deprecated

Create a schema versioning module to track deprecation:

**File**: `Shops/42.13.1/media/lua/shared/nshopsb42/schema/ModDataSchema.lua`

```lua
-- ModDataSchema.lua
-- Tracks deprecated and active ModData fields

SHOPSB42.ModDataSchema = {
    version = 2,
    
    -- DEPRECATED: fields that should be removed on next major version
    deprecated = {
        itemPrice = {
            version = 1,
            removedInVersion = 3,
            reason = "NPC prices now deterministic from NPCShopCatalog, player shop prices read on transaction"
        },
        itemSpecialCoin = {
            version = 1,
            removedInVersion = 3,
            reason = "Moved to pricing contract"
        }
    },
    
    -- ACTIVE: fields currently in use
    active = {
        CoinBalance = {
            version = 1,
            description = "User wallet balances (mandatory)"
        },
        owner = {
            version = 1,
            description = "Player shop owner name"
        }
    }
}

function SHOPSB42.ModDataSchema.isDeprecated(fieldName)
    return SHOPSB42.ModDataSchema.deprecated[fieldName] ~= nil
end

return SHOPSB42.ModDataSchema
```

---

### 6.1.3 Implement Lazy-Migration

**File**: `Shops/42.13.1/media/lua/server/nshopsb42/schema/LazyMigration.lua`

**Lazy-migration strategy**:
- **When**: On server load, when player enters world, or when shop is accessed
- **What**: Read old `modData.price` fields, log them (for audit), write new schema
- **Action**: Delete old fields, compute price on-demand instead

```lua
-- LazyMigration.lua
-- Migrates save files from old schema (prices in ModData) to new schema (deterministic)

local SharedLogger = require("nshopsb42/utils/SharedLogger")
local ModDataSchema = require("nshopsb42/schema/ModDataSchema")

if not isServer() then
    return
end

SHOPSB42.LazyMigration = {}
local Migration = SHOPSB42.LazyMigration

-- Track migration across server session
Migration.migratedItems = {}
Migration.migrationStats = {
    itemsMigrated = 0,
    pricesDiscarded = 0,
    saves = 0
}

---
-- Migrate item ModData from old schema to new
-- Called when item is accessed or saved
function Migration.migrateItemIfNeeded(item)
    if not item then
        return
    end
    
    local itemId = item:getID()
    if Migration.migratedItems[itemId] then
        return -- Already migrated this session
    end
    
    local modData = item:getModData()
    if not modData then
        return
    end
    
    local hadOldPrice = modData.price ~= nil
    local hadOldSpecialCoin = modData.specialCoin ~= nil
    
    if hadOldPrice or hadOldSpecialCoin then
        SharedLogger.log("Shops", 
            "[LazyMigration] Discarding old ModData fields from item " .. item:getType() ..
            " (id=" .. itemId .. "): price=" .. tostring(modData.price) .. 
            ", specialCoin=" .. tostring(modData.specialCoin)
        )
        
        -- Record old value for audit log (optional)
        Migration.migratedItems[itemId] = {
            type = item:getType(),
            oldPrice = modData.price,
            oldSpecialCoin = modData.specialCoin,
            timestamp = getTimestampMs()
        }
        
        -- DELETE OLD FIELDS (critical)
        modData.price = nil
        modData.specialCoin = nil
        
        -- Increment counters
        Migration.migrationStats.itemsMigrated = Migration.migrationStats.itemsMigrated + 1
        if hadOldPrice then
            Migration.migrationStats.pricesDiscarded = Migration.migrationStats.pricesDiscarded + 1
        end
    end
end

---
-- Migrate all items in a player's inventory
function Migration.migratePlayerInventory(player)
    if not player then
        return
    end
    
    local inventory = player:getInventory():getItems()
    for i = 0, inventory:size() - 1 do
        local item = inventory:get(i)
        Migration.migrateItemIfNeeded(item)
    end
end

---
-- Migrate all items in world containers (player shops, etc.)
function Migration.migrateWorldContainers()
    -- This is optional - runs on server tick to migrate background containers
    -- For now, we use on-demand migration when items are accessed
end

---
-- Get migration statistics (for admin reporting)
function Migration.getStats()
    return copyTable(Migration.migrationStats)
end

---
-- Reset statistics (for testing)
function Migration.resetStats()
    Migration.migrationStats = {
        itemsMigrated = 0,
        pricesDiscarded = 0,
        saves = 0
    }
    Migration.migratedItems = {}
end

SharedLogger.log("Shops", "[LazyMigration] Module loaded")
return Migration
```

---

### 6.1.4 Integration Points

**Where to call migration**:

1. **Server load** - `ServerInitialization.lua`
   ```lua
   local Migration = require("nshopsb42/schema/LazyMigration")
   -- Called once per server start (optional heavy operation)
   ```

2. **When accessing player shop** - `PlayerShopServer.lua`
   ```lua
   function PlayerShop.onPlayerShopAccess(player, shop)
       local Migration = require("nshopsb42/schema/LazyMigration")
       Migration.migratePlayerInventory(player)
       -- Continue with shop access logic
   end
   ```

3. **When executing transactions** - `ShopCommandDispatcherServer.lua`
   ```lua
   -- In BuyResult, SellResult handlers
   local Migration = require("nshopsb42/schema/LazyMigration")
   Migration.migrateItemIfNeeded(item)
   -- Server recomputes price anyway, old value not used
   ```

---

### 6.1.5 Backward Compatibility

**What breaks**:
- Old mods that rely on `item:getModData().price` directly will fail
  - **Mitigation**: Document in migration guide that mods MUST use pricing contract

**What stays safe**:
- User balances (CoinBalance) untouched
- Player shop ownership (owner field) untouched
- Item inventory system untouched
- VehicleID (vehicle items) untouched

---

### 6.1.6 Testing Checklist

- [ ] Load old save with player shop items that have `modData.price`
- [ ] Verify migration runs silently (no crash)
- [ ] Verify old price fields removed from ModData
- [ ] Verify player can still interact with shop
- [ ] Verify server recomputes prices correctly
- [ ] Verify client shows prices from NPCShopCatalog (NPC) or server (player shop)
- [ ] Check logs for migration stats
- [ ] Run with multiple players to verify no race conditions

---

## Success Criteria for 6.1

- [x] Schema versioning module created
- [x] LazyMigration module implemented
- [x] Integration points identified
- [x] Backward compatibility documented
- [ ] All migration code tested
- [ ] Migration logs verified
- [ ] Zero desync after migration

---

## Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `shared/nshopsb42/schema/ModDataSchema.lua` | **CREATE** | Track deprecated fields |
| `server/nshopsb42/schema/LazyMigration.lua` | **CREATE** | Implement lazy-migration |
| `server/nshopsb42/ServerInitialization.lua` | **MODIFY** | Call migration on server load |
| `server/nshopsb42/shop/PlayerShopServer.lua` | **MODIFY** | Call migration before shop access |
| `server/nshopsb42/ShopCommandDispatcherServer.lua` | **MODIFY** | Call migration in transaction handlers |
| `docs/B42.13_MP_Migration_Guide.md` | **MODIFY** | Add section on price field deprecation |

---

## Next Steps (After 6.1)

After migration is complete and tested:

1. **6.2**: Network traffic baseline measurement
2. **6.3**: Functional testing (offline, mismatch, funds, multiplayer, lag)
3. **6.4**: Compatibility testing (vanilla/modded shops, player shops, desync)
4. **6.5**: Documentation & rollout
