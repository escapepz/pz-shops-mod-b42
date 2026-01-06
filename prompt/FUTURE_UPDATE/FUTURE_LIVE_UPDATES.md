# Future: Live Price Updates from Server

**Status**: Infrastructure kept, broadcasts disabled (Phase 3)

This document explains how to enable live price updates if needed in the future.

## Current State (Phase 3 - Deterministic Client Pricing)

- Client calculates preview prices deterministically (no server sync needed)
- Server validates prices on transaction (authoritative)
- Broadcasts disabled for performance

## Future: Live Price Updates

If you need the server to push price changes to clients in real-time (e.g., when a mod changes prices dynamically), here's what to do:

### Step 1: Uncomment Broadcasts in `onPriceHooksChanged()`

File: `Shops/42.13.1/media/lua/server/nshopsb42/transactions/ShopFinalizeHandlerServer.lua`

```lua
function ShopFinalizeHandler.onPriceHooksChanged()
    -- ... existing code ...
    
    -- TODO: Uncomment these for live price update feature:
    ShopFinalizeHandler.broadcastBuyPrices()
    ShopFinalizeHandler.broadcastSellRules()
end
```

### Step 2: Re-enable Broadcast Functions

The functions are marked as disabled but still exist:
- `broadcastBuyPrices()` - broadcasts buy prices
- `broadcastSellRules()` - broadcasts sell rule modifiers

They will re-enable and execute network broadcasts.

### Step 3: Restore Price Calculation

If you want server to compute prices before broadcasting (not just use modifiers):
1. Un-comment `computeBuyPriceWithModifiers()` function
2. Un-comment `buildCalculatedPrices()` function
3. Restore the SyncBuyPrices send call in `sendShopDataToPlayer()`

### Step 4: Client Side Already Ready

Client handlers exist in:
- `ShopSyncClient.handleSyncBuyPrices()` - receives buy prices
- `ShopSyncClient.handleSyncSellRules()` - receives sell modifiers
- `ShopUI.calcBuyPrice()` - respects server prices when available

These will automatically use server prices if they arrive.

## Performance Note

Current design (Phase 3) is optimal:
- **No network overhead** during preview (client calculates locally)
- **Deterministic** (same inputs = same output always)
- **Future-proof** (infrastructure ready for live updates)

Only enable broadcasts if you have a specific need for live updates (e.g., economy events, seasonal pricing changes, admin commands).

## Timeline

- **Phase 1**: Switched to PricingContract as canonical source ✅
- **Phase 2**: Removed dead price calculation code ✅
- **Phase 3**: Disabled broadcasts for performance ✅
- **Phase 4 (future)**: Could re-enable for live updates if needed
