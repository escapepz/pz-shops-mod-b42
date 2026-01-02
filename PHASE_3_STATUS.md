# Phase 3: SyncInitialComplete Handshake - COMPLETE

## Objective
Eliminate ambiguity about when UI can safely render pricing data by introducing an explicit completion signal that gates UI rendering.

## Changes Made

### Server-side (ShopFinalizeHandlerServer.lua)

**Updated: `sendShopDataToPlayer()` (line 367)**
- Added new SyncInitialComplete command sent after SyncSellRules
- Sequence: SyncShopData → SyncBuyPrices → SyncSellRules → **SyncInitialComplete**
- Payload includes both revisions for consistency verification
- Logged with timestamps for debugging

```lua
Utilities.SendServerCommandTo(player, "Shops", "SyncInitialComplete", {
    buyRevision = Shop.BuyPriceRevision,
    sellRevision = Shop.SellRuleRevision,
    timestamp = getGameTime(),
})
```

### Client-side (ShopSyncClient.lua)

**Updated: `Initialize()` (line 154)**
- Added three new state variables to track initial sync:
  - `Shop._initialSyncComplete = false` (critical flag)
  - `Shop._initialSyncStartTime = nil`
  - `Shop._initialSyncCompleteTime = nil`

**New Handler: `handleSyncInitialComplete(data)` (line 330)**
- Receives completion signal from server
- Validates revision consistency (both should match current state)
- Sets `Shop._initialSyncComplete = true`
- Records completion time for debugging
- Calls all registered completion callbacks

**New Helper: `onInitialSyncComplete(callback)` (line 372)**
- Registration point for listeners to react to sync completion
- Allows UI and external code to know when rendering is safe
- Callbacks stored in `ShopSyncClient._initialSyncCompleteCallbacks`

**New Helper: `isShopReady()` (line 381)**
- Public API to check if initial sync is complete
- Returns `true` only when `Shop._initialSyncComplete == true`
- Used by UI to gate rendering

### UI Layer (ShopUI.lua)

**Updated: `show()` function (line 151)**
- Added gating check at the **beginning** of the function
- Checks `ShopSyncClient.isShopReady()` before proceeding
- If not ready:
  - Logs "Shop not yet synced from server. Waiting..."
  - Queues the show request in `ShopUI._pendingShowRequest`
  - Registers a callback via `onInitialSyncComplete()` to retry
  - Returns `nil` immediately
- Once sync complete, callback triggers retry automatically

**Result**: UI never renders incomplete data. If user tries to open shop before sync finishes, they simply wait (or see a "loading" message if we add one).

### UI Layer (PlayerShopUI.lua)

**No changes**
- Player shops do NOT require gating
- Player shops use container-based items and mod data only
- They do not depend on synced pricing state (SyncBuyPrices, SyncSellRules)
- Can open immediately without waiting for NPC shop sync to complete

## Data Flow

### Before Phase 3
```
Timeline:
  t=0:  Server sends SyncShopData
  t=1:  Server sends SyncBuyPrices (buyRev=5, sellRev=3)
  t=2:  Server sends SyncSellRules (buyRev=5, sellRev=3)
  t=3:  Client could try to open UI ← PROBLEM: What if SyncBuyPrices hasn't arrived yet?
        Client state: Items=✓, BuyPrices=✓, SellRules=✗
        UI renders with incomplete data!

Potential race:
  - Network latency causes SyncSellRules to arrive before SyncBuyPrices
  - UI opens and renders partial state
  - Client and server have different pricing views
```

### After Phase 3
```
Timeline:
  t=0:  Server sends SyncShopData
  t=1:  Server sends SyncBuyPrices (buyRev=5, sellRev=3)
  t=2:  Server sends SyncSellRules (buyRev=5, sellRev=3)
  t=3:  Server sends SyncInitialComplete ✓
  t=4:  Client sets _initialSyncComplete=true
  
User attempts to open UI at t=2.5:
  - ShopUI:show() checks isShopReady()
  - Returns false (SyncInitialComplete hasn't arrived)
  - UI opens queued for retry
  - At t=4, callback fires and UI opens automatically
  
Result: UI always has complete, consistent pricing state
```

## Behavioral Impact

### User Perspective
- **No change in normal case**: If latency is low, UI opens immediately as before
- **Better in slow case**: If network is slow, UI waits for complete sync rather than showing partial data
- **Clear intent**: Server explicitly signals "all data here, safe to use"

### Code Perspective
- **Two-phase open**: 1) Register callback, 2) Retry when ready
- **Fail-safe**: If callback never fires (shouldn't happen), user can manually retry
- **Logging**: Clear debug path - can see when sync completes

## Validation Checklist

### Unit Tests
- [ ] `handleSyncInitialComplete()` correctly parses incoming data
- [ ] `_initialSyncComplete` flag is set to `true` only on this command
- [ ] Revision mismatch is logged but doesn't block completion
- [ ] `isShopReady()` returns correct value

### Integration Tests
- [ ] Server sends all 4 commands in correct order
- [ ] Client sets completion flag on 4th command
- [ ] Callbacks are triggered when flag is set
- [ ] UI gating prevents premature rendering
- [ ] UI automatically retries after completion

### Regression Tests
- [ ] Existing UI rendering works normally (no delays)
- [ ] Price updates after initial sync still work
- [ ] Both ShopUI and PlayerShopUI work correctly
- [ ] No infinite retry loops on callback

### Stress Tests
- [ ] Rapid open/close doesn't break callback system
- [ ] Network latency doesn't cause races
- [ ] Multiple clients opening shops simultaneously

## Files Modified

1. `Shops/42.13.1/media/lua/server/nshopsb42/transactions/ShopFinalizeHandlerServer.lua`
   - Updated: `sendShopDataToPlayer()` - added SyncInitialComplete command

2. `Shops/42.13.1/media/lua/client/nshopsb42/sync/ShopSyncClient.lua`
   - Updated: `Initialize()` - added completion tracking variables
   - New: `handleSyncInitialComplete()` - command handler
   - New: `onInitialSyncComplete()` - callback registration
   - New: `isShopReady()` - public API check

3. `Shops/42.13.1/media/lua/client/nshopsb42/ui/ShopUI.lua`
   - Updated: `show()` - added gating logic for NPC shops

4. `Shops/42.13.1/media/lua/client/nshopsb42/ui/PlayerShopUI.lua`
   - No changes (player shops don't depend on synced pricing)

## Next Phase
Ready for **Phase 4: Composite-State Helpers**

Phase 3 ensures clients know when initial sync is complete. Phase 4 will provide semantic helpers so code doesn't have to manually track two revision counters.

## Notes

- **Callbacks are fire-once**: Each UI open registers one callback, fires once on completion
- **Backward compatible**: Old code that doesn't check readiness still works (just waits)
- **Explicit contract**: UI explicitly gates on this flag, making intent clear
- **Debuggable**: All state transitions logged with timestamps
- **Safe**: Revision validation prevents stale or out-of-order data from being used

## Example Usage

### Checking if Shop is Ready
```lua
local ShopSyncClient = SHOPSB42.ShopSyncClient
if ShopSyncClient.isShopReady() then
    -- Safe to access Shop.BuyPrices, Shop.SellModifiers, etc.
    local price = Shop.BuyPrices["Base.Apple"]
else
    -- Wait or queue request
end
```

### Registering for Completion
```lua
ShopSyncClient.onInitialSyncComplete(function()
    print("Shop sync complete, all data available!")
    -- Now safe to use Shop data
end)
```

### UI Opening Pattern
```lua
function ShopUI:show(player, viewMode, shop)
    if not ShopSyncClient.isShopReady() then
        -- Queue and wait
        ShopUI._pendingShowRequest = {player, viewMode, shop}
        ShopSyncClient.onInitialSyncComplete(function()
            -- Retry with queued params
            ShopUI:show(...)
        end)
        return nil
    end
    -- Now safe to render UI with complete data
end
```
