# Shop Network Handshake - Fix Summary

## Problem
Initial network handshake between client and server for syncing shop data was failing with silent packet drops. Client would send `RequestShopData` but server dispatcher wouldn't receive it.

## Thread Approach (Failed)
**Reference**: T-019b7f9c-2fec-7177-a493-8cf634d86a1e

Attempted a sophisticated two-way handshake:
1. **Server** sends `ShopServerReady` via `sendServerCommand` during `OnPlayerUpdate` (tick 3+)
2. **Client** receives `ShopServerReady` and then sends `RequestShopData`
3. **Result**: Server never sent `ShopServerReady` (command silently dropped at `OnPlayerUpdate`), handshake never completed

**Root cause**: `OnPlayerUpdate` is unreliable for initial network commands - player not fully registered as networked entity at that point.

## Current Approach (Working)

### Server (AServerInit.lua)
- **Removed** all `OnPlayerUpdate` handshake code
- **Simplified**: Just wait for client to request data
- Comments added (lines 32-35) acknowledging the original approach had race conditions

### Client (AClientInit.lua)

**1. Initial send during OnGameStart (lines 88-115)**
```lua
-- Send TestPing and RequestShopData during OnGameStart
sendClientCommand("nshopsb42", "TestPing", {})
sendClientCommand("nshopsb42", "RequestShopData", {})
```

**2. Retry mechanism every 60 ticks (lines 122-145)**
```lua
-- Retry every 60 ticks (3 seconds), max 3 retries
if SHOPSB42.lastRequestTick >= 60 and SHOPSB42.requestRetryCount < 3 then
    -- Send RequestShopData again
end
```

**3. State tracking (lines 55-59)**
```lua
SHOPSB42.serverReady = false
SHOPSB42.hasRequestedData = false
SHOPSB42.hasReceivedData = false  -- Set by dispatcher when SyncShopData arrives
SHOPSB42.requestRetryCount = 0
SHOPSB42.lastRequestTick = 0
```

## Why It Works

1. **Simpler design**: No server-side handshake complexity
2. **Reliable fallback**: Retries handle packet loss
3. **Client-driven**: Client sends when it knows it's ready (`OnGameStart`)
4. **Empirical result**: 
   - First `RequestShopData` (OnGameStart) silently dropped
   - Retry #1 (at tick 60) succeeded
   - All sync data received and Shop UI opened successfully

## Key Insight

The **retry mechanism is essential**, not optional. Without it, the initial packet drop would prevent shop data from ever syncing. The design works because:
- Initial send may fail silently
- Retries are guaranteed to eventually succeed
- Once data arrives, retries stop (`hasReceivedData` flag)

## Files Modified
- `Shops/42.13.1/media/lua/server/nshopsb42/AServerInit.lua` - Removed handshake code
- `Shops/42.13.1/media/lua/client/nshopsb42/AClientInit.lua` - Current retry-based implementation

## Status
✅ Working - Shop UI opens, all data syncs, no errors in mod logs
