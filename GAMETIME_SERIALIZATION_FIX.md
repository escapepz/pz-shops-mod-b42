# GameTime Serialization Bug Fix

## Problem

Console error found in game logs:
```
ERROR: sendServerCommand: can't save key,value=timestamp,zombie.GameTime@72c743f4
```

This indicated that Shops mod code was attempting to send a Java `GameTime` object over the network, which cannot be serialized.

## Root Cause

Two locations in Shops code were directly including `getGameTime()` (a Java object reference) in network command arguments:

### 1. Server-side: ShopFinalizeHandlerServer.lua (Line 447)
```lua
-- BEFORE (broken)
Utilities.SendServerCommandTo(player, "nshopsb42", "SyncInitialComplete", {
    buyRevision = Shop.BuyPriceRevision,
    sellRevision = Shop.SellRuleRevision,
    timestamp = getGameTime(),  -- Java object, cannot serialize
})
```

### 2. Client-side: ShopSyncClient.lua (Line 521)
```lua
-- BEFORE (broken)
return {
    buyRevision = Shop.BuyPriceRevision,
    sellRevision = Shop.SellRuleRevision,
    timestamp = getGameTime(),  -- Java object, cannot serialize
    isComplete = Shop._initialSyncComplete,
}
```

## Solution

Convert Java objects to primitives before serialization. Both instances now extract a numeric value from the GameTime object:

### 1. Server-side: ShopFinalizeHandlerServer.lua (Line 447)
```lua
-- AFTER (fixed)
Utilities.SendServerCommandTo(player, "nshopsb42", "SyncInitialComplete", {
    buyRevision = Shop.BuyPriceRevision,
    sellRevision = Shop.SellRuleRevision,
    timestamp = getGameTime():getWorldAgeHours(),  -- Returns number (hours)
})
```

### 2. Client-side: ShopSyncClient.lua (Line 521)
```lua
-- AFTER (fixed)
return {
    buyRevision = Shop.BuyPriceRevision,
    sellRevision = Shop.SellRuleRevision,
    timestamp = getGameTime():getWorldAgeHours(),  -- Returns number (hours)
    isComplete = Shop._initialSyncComplete,
}
```

## Technical Details

**Network Serialization Rules:**
- `sendServerCommand()` and `sendClientCommand()` can only serialize:
  - `number`
  - `string`
  - `boolean`
  - Plain Lua tables (with serializable contents)
  
**Cannot serialize:**
- Java object references (e.g., `zombie.GameTime@72c743f4`)
- Function references
- Complex Lua userdata

**getGameTime() Methods:**
- `getGameTime():getWorldAgeHours()` → Returns `number` (world age in hours)
- `getGameTime():getCalender():getTimeInMillis()` → Returns `number` (milliseconds)

## Impact

- **Severity**: High (silent packet drop)
- **Scope**: Affects `SyncInitialComplete` command synchronization
- **Fix**: Convert to numeric timestamp before transmission

## Files Modified

1. `Shops/42.13.1/media/lua/server/nshopsb42/transactions/ShopFinalizeHandlerServer.lua` (Line 447)
2. `Shops/42.13.1/media/lua/client/nshopsb42/sync/ShopSyncClient.lua` (Line 521)

## Status

✅ Fixed - GameTime objects now converted to numeric values before network transmission
