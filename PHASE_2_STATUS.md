# Phase 2: Buy Modifiers in Sync - COMPLETE

## Objective
Restore transparency so clients and external mods can see **why** prices changed by including buy modifiers in the price broadcast.

## Changes Made

### Server-side (ShopFinalizeHandlerServer.lua)

**New Helper Function: `computeBuyPriceWithModifiers(itemId)` (line 32)**
- Computes buy price while tracking modifiers
- Returns `{ price, basePrice, modifiers }` structure
- Mirrors the logic in `Shop.resolvePlayerBuyPrice` but captures modifiers for serialization
- Handles both modify hooks and override hooks

**Updated: `buildCalculatedPrices()` (line 69)**
- Changed to call `computeBuyPriceWithModifiers()` instead of `Shop.resolvePlayerBuyPrice()`
- Now returns full price data structure (price + basePrice + modifiers)
- Maintains same loop structure, just enriched data

**Updated: `detectPriceChanges()` (line 104)**
- Changed to handle both old format (number) and new format (table with modifiers)
- Compares prices flexibly: `oldPriceData.price or oldPriceData`
- Returns full `priceData` objects instead of just numbers
- Backward compatible with legacy numeric format

**Updated: `broadcastBuyPrices()` (line 171)**
- Changed to store full price data in `_previousBuyPrices` (was numeric)
- Now broadcasts `changedPrices` containing full price objects with modifiers
- Comment updated: "now includes modifiers" for clarity

**Updated: `sendShopDataToPlayer()` - SyncBuyPrices (line 352)**
- Initial sync now sends full price data with modifiers
- Comment added: "Now includes modifiers for transparency"

### Client-side (ShopSyncClient.lua)

**New Storage: `Shop._buyModifierMetadata` (initialized in handleSyncBuyPrices)**
- Stores modifier information separately from prices
- Format: `_buyModifierMetadata[itemId] = array of modifiers`
- Allows external mods/consumers to inspect price modifiers

**Updated: `handleSyncBuyPrices()` (line 181)**
- Extracts `priceData.price` for UI (backward compatibility)
- Stores full modifier arrays in `Shop._buyModifierMetadata`
- Handles both new format (table with modifiers) and legacy format (just numbers)
- Logs modifier counts for debugging
- Supports both initial sync and delta updates

## Data Flow

### Before Phase 2
```
Server computes:
  itemId="Weapon_Pistol"
  basePrice=80
  modifiers=[{multiplier: 1.1}, {multiplier: 1.05}]
  finalPrice=92

Broadcast:
  SyncBuyPrices {
    buyRevision: 5,
    sellRevision: 3,
    buyPrices: {
      "Weapon_Pistol": 92   ← Lost modifier info!
    }
  }

Client receives:
  Shop.BuyPrices["Weapon_Pistol"] = 92
  ✗ No way to see why price is 92 (what modifiers applied?)
```

### After Phase 2
```
Server computes:
  itemId="Weapon_Pistol"
  basePrice=80
  modifiers=[{multiplier: 1.1}, {multiplier: 1.05}]
  finalPrice=92

Broadcast:
  SyncBuyPrices {
    buyRevision: 5,
    sellRevision: 3,
    buyPrices: {
      "Weapon_Pistol": {
        price: 92,
        basePrice: 80,
        modifiers: [{multiplier: 1.1}, {multiplier: 1.05}]
      }
    }
  }

Client receives:
  Shop.BuyPrices["Weapon_Pistol"] = 92              ← For UI (unchanged)
  Shop._buyModifierMetadata["Weapon_Pistol"] = [...]  ← For external mods
  ✓ Full transparency: can see 80 → 92 via 1.1x and 1.05x
```

## Behavioral Impact

**UI Impact**: None
- UI continues to extract `Shop.BuyPrices[itemId]` as a number
- Price display is identical to before
- No visual changes

**External Mod Impact**: Enhanced
- Mods can now query `Shop._buyModifierMetadata[itemId]`
- Can inspect which modifiers affected a price
- Can audit/trace price calculations
- Enables price transparency in tools, logs, external systems

## Backward Compatibility

- Server continues to compute prices the same way
- Client still extracts numeric prices for UI
- Legacy format (numeric-only) is still supported
- No breaking changes to existing code paths

## Testing Checklist

### Unit Tests
- [ ] `computeBuyPriceWithModifiers()` returns correct price, basePrice, modifiers
- [ ] Modifiers array is properly populated from hooks
- [ ] Override hooks take precedence over modifiers
- [ ] `detectPriceChanges()` handles both numeric and object formats

### Integration Tests
- [ ] Initial sync includes modifiers in broadcast
- [ ] Delta broadcasts include modifiers for changed items
- [ ] UI extracts numeric price correctly from object
- [ ] External mods can access `_buyModifierMetadata`
- [ ] Modifier counts logged accurately

### Regression Tests
- [ ] Price calculations unchanged (same final values)
- [ ] UI rendering unchanged (same visual display)
- [ ] Performance not impacted (modifiers are lightweight)
- [ ] Broadcast size reasonable (modifiers are serializable)

## Files Modified

1. `Shops/42.13.1/media/lua/server/nshopsb42/transactions/ShopFinalizeHandlerServer.lua`
   - New function: `computeBuyPriceWithModifiers()`
   - Updated: `buildCalculatedPrices()`
   - Updated: `detectPriceChanges()`
   - Updated: `broadcastBuyPrices()`
   - Updated: `sendShopDataToPlayer()` (SyncBuyPrices section)

2. `Shops/42.13.1/media/lua/client/nshopsb42/sync/ShopSyncClient.lua`
   - Updated: `handleSyncBuyPrices()` to extract and store modifiers

## Next Phase
Ready for **Phase 3: SyncInitialComplete Handshake**

Phase 2 establishes modifier transparency. Phase 3 will ensure clients know when initial sync is complete and safe to use.

## Notes

- Modifiers are human-readable objects with `multiplier` and/or `add` fields
- Modifier metadata is optional (external mods use it, UI doesn't need it)
- Server-side modifier computation matches client-side UI calculation logic
- No changes to price values themselves, only added transparency
