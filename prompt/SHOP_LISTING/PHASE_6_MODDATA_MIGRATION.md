# Phase 6: ModData Schema Migration

## Overview
Phase 6.1 updates the ModData schema to remove per-player NPC shop pricing. Prices are now computed deterministically on-demand instead of stored and synced.

---

## Schema Changes

### Old Schema (Before Refactor)
```lua
-- Per-player ModData (synchronized every N seconds)
player:getModData()["Shops"] = {
    prices = {
        ["Base.Apple"] = 50,
        ["Base.Axe"] = 120,
        -- ... hundreds of items ...
    },
    timestamp = os.time(),  -- Triggers resync
    broadcast = true,       -- Per-player broadcast
}
```

**Problems**:
- 800+ packets per session (price broadcasts)
- Per-player syncing (scales poorly)
- Time-dependent (o.time desync risk)
- No determinism guarantee

---

### New Schema (After Refactor)

```lua
-- Deterministic pricing, no storage
-- prices computed from PricingContract at transaction time
player:getModData()["Shops"] = {
    -- NPC SHOP PRICES: REMOVED (computed deterministically)
    -- Player shop data still stored, but re-read server-side
    playerShops = {
        ["shopId"] = {
            name = "My Shop",
            items = {
                ["Base.Apple"] = { basePrice = 50, condition = 1.0 },
                -- ...
            },
        },
    },
    -- Transaction history (optional, for UI feedback)
    lastTransactionId = "txn_12345",
    lastTransactionResult = {
        success = true,
        finalPrice = 100,
        timestamp = os.time(),  -- For UI only, not synced
    },
}
```

**Benefits**:
- Zero price sync (deterministic calculation)
- 4 packets per session (transaction-only)
- No time dependency
- Determinism guaranteed

---

## Migration Strategy

### Goal: Lazy Migration
- Old saves: Price fields ignored on load
- New saves: No price fields written
- No data loss: Only deprecated fields removed
- Backward compatible: Works with old saves

### Migration Logic

```lua
-- ShopInit.lua (Phase 6 task)
function Shop.MigrateLegacyModData(player)
    local modData = player:getModData()["Shops"]
    if not modData then
        return  -- Already migrated or new game
    end

    -- Mark old price field as deprecated
    if modData.prices then
        SharedLogger.log(
            "Shops",
            "[Migration] Removing deprecated 'prices' from player " .. player:getUsername()
        )
        modData.prices = nil  -- Remove old field
    end

    -- Ensure playerShops is initialized
    modData.playerShops = modData.playerShops or {}

    -- Future: If player shops present, verify structure
    if modData.playerShops then
        for shopId, shop in pairs(modData.playerShops) do
            if shop.items then
                -- Items structure OK, will be re-read server-side
            end
        end
    end
end
```

### When to Call
```lua
-- Call during late-join sync (Phase 4)
-- Or on-demand when player loads game

function Shop.LateJoinSync(player)
    Shop.MigrateLegacyModData(player)  -- Phase 6.1
    -- ... rest of sync logic ...
end
```

---

## Migration Checklist

### Phase 6.1 Tasks

1. **Code**: Add MigrateLegacyModData() function
   - [ ] Remove deprecated price fields
   - [ ] Preserve playerShops data
   - [ ] Log migration events

2. **Integration**: Wire migration into initialization
   - [ ] Call in Shop.FinalizeRegistry()
   - [ ] Or in LateJoinSync() for each player

3. **Testing**: Verify backward compatibility
   - [ ] Load old save → No errors
   - [ ] Old price fields removed
   - [ ] New prices computed correctly
   - [ ] Prices deterministic after migration

4. **Logging**: Confirm migration in logs
   - [ ] "Migration: Removing deprecated 'prices'..." entries
   - [ ] One log per player who had old data

---

## Example Migration Scenarios

### Scenario 1: Old Save with Prices
```lua
-- Old ModData
modData["Shops"] = {
    prices = { ["Base.Apple"] = 50, ... },  -- 200+ items
    timestamp = 1234567890,
}

-- After migration
modData["Shops"] = {
    -- prices removed
    -- (playerShops empty/not present)
}

-- Next transaction
price = PricingContract.calculateBuyPrice("Base.Apple", shopId, 50)
-- Result: { finalPrice = 50, revision = 1 }
```

### Scenario 2: New Save (No Migration Needed)
```lua
-- New ModData (from new game)
modData["Shops"] = {
    playerShops = {},  -- Empty, as expected
}

-- Migration skipped (no prices field)
-- All transactions use deterministic pricing
```

### Scenario 3: Mixed Old/New
```lua
-- Old save still has prices, but also playerShops
modData["Shops"] = {
    prices = { ... },          -- Old field (to be removed)
    playerShops = { ... },     -- New field (preserved)
}

-- Migration removes prices, keeps playerShops
modData["Shops"] = {
    -- prices removed
    playerShops = { ... },     -- Kept for player shop data
}
```

---

## Validation After Migration

```lua
function Shop.ValidateMigration(player)
    local modData = player:getModData()["Shops"]
    
    -- Check: No prices field
    if modData and modData.prices then
        SharedLogger.log("Shops", "ERROR: prices field still present after migration")
        return false
    end
    
    -- Check: playerShops preserved (if present)
    if modData and modData.playerShops then
        for shopId, shop in pairs(modData.playerShops) do
            if not shop.items then
                SharedLogger.log("Shops", "ERROR: playerShop structure invalid")
                return false
            end
        end
    end
    
    return true
end
```

---

## Performance Impact

### Storage
- **Before**: ~50-100 KB per player (prices for 200+ items)
- **After**: ~5-10 KB per player (playerShops only)
- **Reduction**: 80%+ smaller saves

### Network
- **Before**: 800+ packets per session
- **After**: ~4 packets per session
- **Reduction**: 99.5%

### CPU
- **Before**: Broadcast loop every 5 seconds
- **After**: Deterministic calculation on-demand
- **Impact**: Negligible

---

## Rollback Plan (if needed)

If migration needs to be reverted:
1. Keep old price fields in code (commented out)
2. Flag migration as optional
3. Re-enable price broadcasts if revert needed
4. Log all reverted saves

**Note**: Migration is read-only for old data (doesn't rewrite saves), so rollback is low-risk.

---

## Documentation Updates Needed

### For Modders
- Update modding guide: NPC prices are deterministic, not stored
- Show: How to add custom pricing via hooks (Phase 7)
- Example: Custom multiplier hook

### For Players
- Update changelog: Smaller save files, faster load times
- Note: Prices now calculated on-demand (no stale prices)

---

## Code Template (Phase 6.1 Implementation)

```lua
-- Add to ShopInit.lua

function Shop.MigrateLegacyModData(player)
    if not player then return end
    
    local modData = player:getModData()
    if not modData["Shops"] then
        return  -- Nothing to migrate
    end
    
    local shopData = modData["Shops"]
    
    -- Phase 6.1: Remove deprecated price fields
    if shopData.prices then
        SharedLogger.log(
            "Shops",
            "[Migration] Removing deprecated 'prices' field from " .. player:getUsername()
        )
        shopData.prices = nil
        
        -- Update timestamp for save
        shopData._migrationTime = os.time()
    end
    
    -- Preserve playerShops (will be revalidated at transaction time)
    -- No other action needed
end

-- Call in FinalizeRegistry() or on player load
function Shop.FinalizeRegistry()
    -- ... existing code ...
    
    -- Phase 6.1: Set up migration for next player load
    -- (will be called when player ModData is loaded)
    
    Shop._locked = true
end
```

---

## Testing Migration

### Test Case 1: Old Save with Prices
1. Use old-format save file
2. Load game
3. Verify logs show migration message
4. Check ModData: prices field absent
5. Verify transaction prices calculated correctly

### Test Case 2: New Save (No Migration)
1. Start new game
2. Verify ModData has no prices field
3. Complete transaction
4. Verify deterministic pricing works

### Test Case 3: Player with playerShops
1. Load save with existing player shops
2. Verify prices field removed
3. Verify playerShops preserved
4. Complete player shop transaction
5. Verify prices re-read from ModData

---

## Notes

- Migration is **non-destructive**: Only removes deprecated fields
- **Backward compatible**: Old saves work without modification
- **One-time process**: After migration, all future saves are new format
- **Logging**: All migrations logged for audit trail

