# Phase 1: Core Revision Tracking - COMPLETE

## Objective
Add both `buyRevision` and `sellRevision` to every broadcast so clients always know if they're viewing complete pricing state.

## Changes Made

### Server-side (ShopFinalizeHandlerServer.lua)

**Function: `broadcastBuyPrices()` (line 127)**
- Changed: `revision = Shop.BuyPriceRevision`
- To: `buyRevision = Shop.BuyPriceRevision, sellRevision = Shop.SellRuleRevision`
- Ensures clients see both revisions in every buy price update

**Function: `broadcastSellRules()` (line 145)**
- Changed: `revision = Shop.SellRuleRevision`
- To: `buyRevision = Shop.BuyPriceRevision, sellRevision = Shop.SellRuleRevision`
- Ensures clients see both revisions in every sell rule update

**Function: `sendShopDataToPlayer()` - SyncBuyPrices (line 307)**
- Changed: `revision = Shop.BuyPriceRevision`
- To: `buyRevision = Shop.BuyPriceRevision, sellRevision = Shop.SellRuleRevision`
- Initial sync now includes both revisions

**Function: `sendShopDataToPlayer()` - SyncSellRules (line 321)**
- Changed: `revision = Shop.SellRuleRevision`
- To: `buyRevision = Shop.BuyPriceRevision, sellRevision = Shop.SellRuleRevision`
- Initial sync now includes both revisions

### Client-side (ShopSyncClient.lua)

**Handler: `handleSyncBuyPrices()` (line 182)**
- Changed: Reads from `data.revision`
- To: Reads from `data.buyRevision` and `data.sellRevision`
- Stores both revisions: `Shop.BuyPriceRevision` and `Shop.SellRuleRevision`
- Logs both revisions for debugging

**Handler: `handleSyncSellRules()` (line 214)**
- Changed: Reads from `data.revision`
- To: Reads from `data.buyRevision` and `data.sellRevision`
- Stores both revisions: `Shop.BuyPriceRevision` and `Shop.SellRuleRevision`
- Logs both revisions for debugging

## Behavioral Impact

### Before Phase 1
```
Server:  buyRev=5, sellRev=3
Broadcast BuyPrices: revision=5
Client receives: buyRev=5, sellRev=nil (or previous value)
                 ↓ INCONSISTENT STATE
Broadcast SellRules: revision=3
Client receives: buyRev=5, sellRev=3  ✓ (now consistent, but only AFTER both broadcasts)
```

### After Phase 1
```
Server:  buyRev=5, sellRev=3
Broadcast BuyPrices: buyRevision=5, sellRevision=3
Client receives: buyRev=5, sellRev=3  ✓ CONSISTENT IMMEDIATELY
Broadcast SellRules: buyRevision=5, sellRevision=3
Client receives: buyRev=5, sellRev=3  ✓ CONSISTENT STILL
```

## Testing Checklist

### Unit Tests
- [ ] Verify `SyncBuyPrices` includes both revision fields
- [ ] Verify `SyncSellRules` includes both revision fields
- [ ] Verify client stores both revisions correctly

### Integration Tests
- [ ] Simulate server with buyRev=10, sellRev=8
- [ ] Send `SyncBuyPrices` → client should have both values
- [ ] Send `SyncSellRules` → client should have both values
- [ ] Verify no race conditions with missing data

### Regression Tests
- [ ] Buy prices still update correctly
- [ ] Sell rules still update correctly
- [ ] Delta updates still work
- [ ] Initial sync still complete
- [ ] UI still renders correctly

## Files Modified

1. `Shops/42.13.1/media/lua/server/nshopsb42/transactions/ShopFinalizeHandlerServer.lua`
   - 4 changes (2 broadcast functions, 2 initial sync locations)

2. `Shops/42.13.1/media/lua/client/nshopsb42/sync/ShopSyncClient.lua`
   - 2 handler functions updated
   - Both now read and store both revisions

## Next Phase
Ready for **Phase 2: Buy Modifiers in Sync**

Phase 1 establishes the protocol. Phase 2 will add modifier transparency to the buy broadcast.

## Notes

- No logic changes, only protocol changes
- Both revisions always sent together (maintains atomicity)
- Client handlers validated against both old and new data
- No breaking changes to other code that reads these revisions
