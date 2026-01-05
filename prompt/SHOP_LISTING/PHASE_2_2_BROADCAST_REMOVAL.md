# Phase 2.2: Remove Client ModData Syncing — Detailed Plan

## Scope: Eliminate Per-Player Price Broadcasts

**Goal**: Stop sending SyncBuyPrices/SyncSellRules to all players on every price change

**Impact**: Zero broadcasts during listing, prices calculated deterministically on client

---

## Changes Required

### 1. Server-Side: ShopFinalizeHandlerServer.lua

#### 1.1 Stop Broadcasting on Price Change
**Location**: Line 232-247 (`onPriceHooksChanged()`)

**Current**:
```lua
function ShopFinalizeHandler.onPriceHooksChanged()
    if ShopFinalizeHandler.shouldInvalidateBuyPrices() then
        ShopFinalizeHandler.broadcastBuyPrices()  -- ← REMOVE THIS
    end
    if ShopFinalizeHandler.shouldInvalidateSellRules() then
        ShopFinalizeHandler.broadcastSellRules()  -- ← REMOVE THIS
    end
end
```

**New**:
```lua
function ShopFinalizeHandler.onPriceHooksChanged()
    -- Phase 2.2: REMOVED per-player broadcasts
    -- Clients calculate prices deterministically using PricingContract
    -- No network sync needed during listing
    -- Server validates price on transaction (Phase 3)
end
```

**Rationale**: 
- Client loads catalog locally (NPCShopCatalog)
- Client calculates preview prices (PricingContract)
- No broadcast needed (deterministic = same everywhere)

#### 1.2 Keep Late-Join Support
**Location**: Line 320-466 (`sendShopDataToPlayer()`)

**Status**: KEEP UNCHANGED
- Line 394-399: Initial SyncBuyPrices for new player (needed for late-join)
- Line 425-432: Initial SyncSellRules for new player (needed for late-join)
- This is NOT a per-player broadcast, it's a one-time handshake

**Note**: Phase 3 will refactor this to send only what's needed for server validation

#### 1.3 Remove Unused Helper Functions (Optional Cleanup)
**Location**: Lines 173-194, 197-221

**Can Remove**: `broadcastBuyPrices()` and `broadcastSellRules()` functions if not called elsewhere

**But Keep For Now**: They might be called by other code; verify first

---

### 2. Client-Side: ShopSyncClient.lua

#### 2.1 Deprecate Per-Player Broadcast Handler
**Location**: Line 227 (`handleSyncBuyPrices()`)

**Current**: Receives SyncBuyPrices broadcast, stores in Shop.BuyPrices, invalidates UI

**New**: Remove this function entirely

**Steps**:
1. Comment out or delete `handleSyncBuyPrices()` function
2. Remove handler registration if it exists
3. Client no longer receives SyncBuyPrices broadcasts

**Important**: Initial sync (on late-join) is still received, just not the per-player broadcasts

#### 2.2 Keep Initial Sync Handler
**Location**: Line 454 (`handleSyncInitialComplete()`)

**Status**: KEEP UNCHANGED
- Late-join players still need initial data
- Will be refactored in Phase 3 (targeted handshake)

---

## Implementation Order

### Step 1: Server Changes (Safe First)
1. Comment out calls to `broadcastBuyPrices()` in `onPriceHooksChanged()`
2. Verify: No other code calls these functions
3. Test: Change prices via TestPriceHooksCommand, verify no broadcast logged

### Step 2: Client Changes (After Server is Safe)
1. Comment out or delete `handleSyncBuyPrices()` in ShopSyncClient
2. Verify: Handler no longer receives broadcasts
3. Test: Open shop, verify prices from NPCShopCatalog, not from broadcast

### Step 3: Integration Test
1. Start server with new code
2. Connect client
3. Open NPC shop - prices render from catalog (not from broadcast)
4. Change prices (via TestPriceHooksCommand if available)
5. Verify: No price change visible in shop UI (because UI is using deterministic calculation)
6. Make transaction - server validates and returns result

---

## Testing Checklist

### Before Changes
- [ ] Load mod, verify logs show normal initialization
- [ ] Open shop, verify SyncBuyPrices logged on open
- [ ] Change prices, verify SyncBuyPrices broadcast logged

### After Changes
- [ ] Load mod, verify logs still show initialization
- [ ] Open shop, verify NO SyncBuyPrices broadcast logged
- [ ] Shop displays items and prices (from NPCShopCatalog)
- [ ] Change prices via test command
- [ ] Verify: NO SyncBuyPrices broadcast in logs
- [ ] Verify: Shop UI prices unchanged (deterministic = same everywhere)
- [ ] Make transaction, verify: 1 packet sent/received (result only)

---

## Files to Modify

1. `server/nshopsb42/transactions/ShopFinalizeHandlerServer.lua`
   - Lines 232-247: Remove broadcast calls from `onPriceHooksChanged()`

2. `client/nshopsb42/sync/ShopSyncClient.lua`
   - Lines 227-?: Remove `handleSyncBuyPrices()` function
   - Remove handler registration if applicable

---

## Backward Compatibility

**What Still Works**:
- Late-join sync (initial handshake on player connect)
- Transaction validation (server validates price)
- Player shops (separate code path, Phase 4 will optimize)
- Hook system (unchanged)

**What Changes**:
- Per-player broadcasts removed (no longer sent)
- Client calculates prices locally (deterministic)
- UI no longer reactive to price changes (client doesn't receive them)

---

## Verification

After changes, verify:
1. Compilation succeeds (`npm run build`)
2. Game loads without errors
3. Shop UI works (items render, prices display)
4. Transaction completes (price validates on server)
5. Network traffic: 0 broadcasts during listing, 1 packet per transaction

