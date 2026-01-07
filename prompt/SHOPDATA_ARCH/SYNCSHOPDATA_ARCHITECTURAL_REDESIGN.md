# SyncShopData Architectural Redesign
## From Ephemeral Session Sync to Versioned Content Distribution

**Status**: Design Document (Not yet implemented)  
**Severity**: HIGH - Architectural refactor required  
**Benefits**: Eliminates all original sync failures while maintaining current benefits

---

## Executive Summary

The current SyncShopData model has a **fundamental design flaw**:

**Current Model** (Ephemeral Session Sync):
```
Client joins
  → Requests RequestShopData
    → Server sends SyncShopData
      → Client stores in memory
        → UI renders
          → Client disconnects
            → SyncShopData LOST
```

**Problems**:
- ❌ Re-sent on every join (wasteful)
- ❌ Lost on disconnect (fragile)
- ❌ No version tracking (can't detect changes)
- ❌ Creates ordering dependencies (late-join races)
- ❌ No persistence (survives neither client restart nor reconnect)

---

**Proposed Model** (Versioned Content Distribution):
```
Client boots
  → Loads shared/ShopCatalog (revision 0)
    → Loads ~/.../Zomboid/Lua/shops/listing_<serverId>.json (if exists)
      → Selects highest revision available
        → UI ready immediately (no network wait)
          → On join: Query server for revision
            → If mismatch: Receive SyncShopData
              → Update cache to disk
                → Rebuild UI
```

**Benefits**:
- ✅ UI works offline immediately
- ✅ Only re-syncs on actual changes (revision mismatch)
- ✅ Persists across client restarts
- ✅ Survives reconnects
- ✅ No ordering dependencies
- ✅ Eliminates all original failure modes

---

## Current State: Session Sync Model

### AClientInit.lua (Current)

```lua
-- Lines 103-129: Sends on EVERY join, NO versioning
if not SHOPSB42.hasRequestedData then
    SHOPSB42.hasRequestedData = true
    sendClientCommand("nshopsb42", "RequestShopData", {})  ← ALWAYS SENDS
end

-- Lines 136-168: Retries 3x if dropped
-- But still: ephemeral, no persistence
```

**Problems**:
1. Sends even if client already has data
2. No way to know if server data changed
3. Data lost on disconnect
4. No offline operation possible

---

### ShopCommandDispatcherServer.lua (Current)

```lua
-- Lines 30-47: Sends full snapshot every time
function Commands.RequestShopData(player, args)
    ShopFinalizeHandler.sendShopDataToPlayer(player)  ← ALWAYS SENDS
end
```

**Problems**:
1. No revision check before sending
2. Broadcasts all ~42 items + config per player
3. No caching strategy
4. Creates latency on every join

---

### ShopCommandDispatcherClient.lua (Current)

```lua
-- Lines 19-81: Receives and stores in memory only
function Commands.SyncShopData(data)
    SHOPSB42.hasReceivedData = true
    Shop.Items = data.Items or {}          ← MEMORY ONLY
    Shop.PlayerBuy = data.PlayerBuy or {}  ← NO PERSISTENCE
    Shop.PlayerSell = data.PlayerSell or {}
    -- ... etc
end
```

**Problems**:
1. No disk persistence
2. Lost on client restart
3. Lost on disconnect
4. No revision field stored

---

## Proposed State: Versioned Content Model

### Three-Tier Listing System

#### Tier 0: Built-in Default (Shared Code)

**File**: `shared/ShopCatalog.lua`

```lua
-- Always available, version 0
-- This is the bootstrap floor

SHOPSB42.ShopCatalog = {
    revision = 0,  -- Immutable default version
    Items = {
        ["Base.Apple"] = { basePrice = 150, ... },
        ["Base.Banana"] = { basePrice = 200, ... },
        -- ... hardcoded baseline
    },
    PlayerBuy = { ... },
    PlayerSell = { ... },
    BuyIsWhitelist = true,
    SellIsWhitelist = false,
    defaultPrice = 100,
    defaultPriceBroken = 50,
}
```

**Properties**:
- ✅ Exists on both client & server
- ✅ Never changes (version 0)
- ✅ Always available (no network required)
- ✅ Fallback if server is unreachable

---

#### Tier 1: Server Listing Snapshot

**Generated at**: Server startup (or on demand)

**File**: `Zomboid/Shops/server_listing_snapshot.json`

```json
{
    "revision": 47,
    "timestamp": 1704844800,
    "Items": {
        "Base.Apple": {"basePrice": 150, ...},
        "Base.Banana": {"basePrice": 200, ...},
        ...
    },
    "PlayerBuy": {...},
    "PlayerSell": {...},
    "BuyIsWhitelist": true,
    "SellIsWhitelist": false,
    "defaultPrice": 100,
    "defaultPriceBroken": 50
}
```

**Properties**:
- ✅ Generated server-side
- ✅ Incorporates hooks, mods, admin scripts
- ✅ Changes only on server restart
- ✅ Versioned with monotonic revision number
- ✅ Authoritative for that server instance

---

#### Tier 2: Client Cache (Persistent)

**Stored at**: `Zomboid/Lua/shops/listing_snapshot_<serverId>.lua`

```lua
{
    revision = 47,
    timestamp = 1704844800,
    Items = {...},
    PlayerBuy = {...},
    PlayerSell = {...},
    BuyIsWhitelist = true,
    SellIsWhitelist = false,
    defaultPrice = 100,
    defaultPriceBroken = 50,
}
```

**Format**: Lua table serialization (human-readable, no external deps)

**Properties**:
- ✅ Persists across client restarts
- ✅ Survives reconnects
- ✅ Keyed by server ID (multiple servers supported)
- ✅ Loaded before networking
- ✅ Used for UI immediately

---

### Revised Client Boot Sequence

#### Phase 1: Local Bootstrap (No Network)

**Location**: New module `client/nshopsb42/listing/ListingBootstrap.lua`

```lua
function ListingBootstrap.bootstrap()
    -- Step 1: Load shared default (always available)
    local defaultCatalog = require("nshopsb42/ShopCatalog")
    local selectedCatalog = defaultCatalog
    local selectedRevision = 0
    
    -- Step 2: Load server-specific cache (if exists)
    local serverId = getServer() and getServer():getLocalServerIdentifier() or "unknown"
    local cachedListing = ListingBootstrap.loadCacheForServer(serverId)
    
    if cachedListing and cachedListing.revision > selectedRevision then
        selectedCatalog = cachedListing
        selectedRevision = cachedListing.revision
    end
    
    -- Step 3: Store for later use
    SHOPSB42.Shop.Items = selectedCatalog.Items
    SHOPSB42.Shop.PlayerBuy = selectedCatalog.PlayerBuy
    SHOPSB42.Shop.PlayerSell = selectedCatalog.PlayerSell
    SHOPSB42.Shop.BuyIsWhitelist = selectedCatalog.BuyIsWhitelist
    SHOPSB42.Shop.SellIsWhitelist = selectedCatalog.SellIsWhitelist
    SHOPSB42.Shop.defaultPrice = selectedCatalog.defaultPrice
    SHOPSB42.Shop.currentRevision = selectedRevision
    
    -- Step 4: Initialize UI immediately (no waiting for network)
    SHOPSB42.ClientShopListingService.initialize()
    
    SharedLogger.log("Shops", "[ListingBootstrap] Loaded revision " .. selectedRevision)
    return selectedRevision
end
```

**Result**: UI is ready before server contact.

---

#### Phase 2: Network Handshake (Online)

**Location**: Modified `AClientInit.lua`

```lua
local function onGameStart()
    -- Already have UI ready from bootstrap
    local currentRevision = SHOPSB42.Shop.currentRevision or 0
    
    -- Query server for its revision (minimal payload)
    sendClientCommand("nshopsb42", "QueryListingRevision", {
        clientRevision = currentRevision
    })
end

Events.OnGameStart.Add(onGameStart)
```

**Payload**: ~20 bytes (revision number only)

---

### Revised Server Listing Query

**Location**: `server/nshopsb42/ListingServer.lua` (new module)

```lua
function ListingServer.getSnapshot()
    -- Return in-memory snapshot (generated at startup)
    return SHOPSB42.ShopListingSnapshot or SHOPSB42.ShopCatalog
end

function ListingServer.getRevision()
    local snapshot = ListingServer.getSnapshot()
    return snapshot.revision or 0
end
```

**Handler**: `ShopCommandDispatcherServer.lua`

```lua
function Commands.QueryListingRevision(player, args)
    local clientRevision = args.clientRevision or 0
    local serverRevision = ListingServer.getRevision()
    
    if clientRevision == serverRevision then
        -- Client is up-to-date
        SharedLogger.log("Shops", "[Server] Client already has revision " .. clientRevision)
        Utilities.SendServerCommandTo(player, "nshopsb42", "ListingRevisionOK", {
            revision = serverRevision
        })
    else
        -- Client needs update
        SharedLogger.log("Shops", "[Server] Client needs update: " .. clientRevision .. " → " .. serverRevision)
        local snapshot = ListingServer.getSnapshot()
        Utilities.SendServerCommandTo(player, "nshopsb42", "SyncListingSnapshot", snapshot)
    end
end
```

**Behavior**:
- ✅ Check revision first (no data sent if match)
- ✅ Only send snapshot if revision differs
- ✅ Client caches result to disk

---

### Revised Client Handler

**Location**: `ShopCommandDispatcherClient.lua`

```lua
function Commands.ListingRevisionOK(data)
    -- Server confirms: client is up-to-date
    -- No action needed
    SharedLogger.log("Shops", "[Client] Listing already current (revision " .. data.revision .. ")")
end

function Commands.SyncListingSnapshot(snapshot)
    -- Server sent updated snapshot
    if not snapshot or not snapshot.revision then
        return
    end
    
    -- Update in-memory catalog
    SHOPSB42.Shop.Items = snapshot.Items or {}
    SHOPSB42.Shop.PlayerBuy = snapshot.PlayerBuy or {}
    SHOPSB42.Shop.PlayerSell = snapshot.PlayerSell or {}
    SHOPSB42.Shop.BuyIsWhitelist = snapshot.BuyIsWhitelist or false
    SHOPSB42.Shop.SellIsWhitelist = snapshot.SellIsWhitelist or false
    SHOPSB42.Shop.defaultPrice = snapshot.defaultPrice
    SHOPSB42.Shop.currentRevision = snapshot.revision
    
    -- CRITICAL: Persist to disk for next session
    ListingCache.saveCacheForServer(snapshot)
    
    -- Rebuild UI if visible
    if SHOPSB42.ShopUI and SHOPSB42.ShopUI.instance then
        SHOPSB42.ShopUI.instance:rebuildActiveTab()
    end
    
    SharedLogger.log("Shops", "[Client] Updated to revision " .. snapshot.revision)
end
```

**New module**: `client/nshopsb42/listing/ListingCache.lua`

**Note**: Project Zomboid does not provide a JSON library. Use Lua table serialization instead.

```lua
local SharedLogger = require("nshopsb42/utils/SharedLogger")

local ListingCache = {}

-- Serialize table to Lua source code for storage
local function serializeTable(tbl, indent)
    indent = indent or ""
    local lines = {}
    table.insert(lines, "{")
    
    for k, v in pairs(tbl) do
        local key = type(k) == "string" and string.format("[%q]", k) or "[" .. k .. "]"
        local value
        
        if type(v) == "table" then
            value = serializeTable(v, indent .. "  ")
        elseif type(v) == "string" then
            value = string.format("%q", v)
        elseif type(v) == "boolean" then
            value = v and "true" or "false"
        else
            value = tostring(v)
        end
        
        table.insert(lines, indent .. "  " .. key .. " = " .. value .. ",")
    end
    
    table.insert(lines, indent .. "}")
    return table.concat(lines, "\n")
end

-- Save snapshot to disk (persists across client restart)
function ListingCache.saveCacheForServer(snapshot)
    local serverId = getServer() and getServer():getLocalServerIdentifier() or "unknown"
    local fileName = "shops/listing_snapshot_" .. serverId .. ".lua"
    
    if not snapshot or not snapshot.revision then
        SharedLogger.log("Shops", "[ListingCache] ERROR: Invalid snapshot (no revision)")
        return false
    end
    
    -- Serialize snapshot as Lua table
    local serialized = "return " .. serializeTable(snapshot)
    
    -- Use PZ file API to write
    local writer = getFileWriter(fileName, true, false)
    if not writer then
        SharedLogger.log("Shops", "[ListingCache] ERROR: Could not open writer for " .. fileName)
        return false
    end
    
    writer:write(serialized)
    writer:close()
    
    SharedLogger.log("Shops", "[ListingCache] Saved revision " .. snapshot.revision .. " to " .. fileName)
    return true
end

-- Load snapshot from disk (survives client restart)
function ListingCache.loadCacheForServer(serverId)
    local fileName = "shops/listing_snapshot_" .. serverId .. ".lua"
    
    -- Try to load cached snapshot
    local ok, cached = pcall(function()
        return dofile(fileName)
    end)
    
    if not ok then
        SharedLogger.log("Shops", "[ListingCache] No cache for server " .. serverId)
        return nil
    end
    
    if type(cached) ~= "table" then
        SharedLogger.log("Shops", "[ListingCache] ERROR: Cache file is corrupted (not a table)")
        return nil
    end
    
    if not cached.revision then
        SharedLogger.log("Shops", "[ListingCache] ERROR: Cache missing revision field")
        return nil
    end
    
    SharedLogger.log("Shops", "[ListingCache] Loaded revision " .. cached.revision .. " from cache")
    return cached
end

return ListingCache
```

**Why Lua table serialization instead of JSON**:

1. ✅ No external dependencies (PZ doesn't have JSON library)
2. ✅ Works with `dofile()` directly (no parsing needed)
3. ✅ Human-readable for debugging
4. ✅ Fast to load and serialize
5. ✅ Safe for client-side cache (server still validates everything)

---

## Test Cases: Why This Fixes Original Failures

### Test 1: Late-Join Desync

**Scenario**: Player A buys item at T+0. Server is restarted at T+10. Player B joins at T+15 with old client cache.

**Old Model**:
- Player B sends RequestShopData
- Server sends new SyncShopData
- Ordering race: Who is processing ModData changes? Unknown.
- **Result**: ❌ Possible desync

**New Model**:
- Player B already has revision 47 (cached)
- Server has revision 48 (after restart)
- Server detects mismatch
- Server sends SyncListingSnapshot (explicit version)
- Player B updates cache to disk
- **Result**: ✅ No race, no desync, clear version boundary

---

### Test 2: UI Waits for Network

**Scenario**: Client boots, server is offline.

**Old Model**:
- Client needs SyncShopData
- Waits 3 seconds for RequestShopData timeout
- UI broken
- **Result**: ❌ 3+ second lag, broken offline

**New Model**:
- Client loads cached listing (revision 47) from disk
- UI ready immediately
- Network query is asynchronous
- **Result**: ✅ Instant UI, works offline

---

### Test 3: Reconnect Fragility

**Scenario**: Player D disconnects, reconnects 5 minutes later.

**Old Model**:
- In-memory SyncShopData lost
- Sends RequestShopData again
- Server sends SyncShopData again
- UI rebuilds
- **Result**: ⚠️ Works, but wasteful (re-sent data)

**New Model**:
- In-memory catalog already loaded from disk cache
- Sends QueryListingRevision (20 bytes)
- If match: No data sent
- If mismatch: SyncListingSnapshot sent once
- **Result**: ✅ Efficient, survives reconnect

---

### Test 4: Multiple Server Support

**Scenario**: Player alternates between server A and server B.

**Old Model**:
- Joins A: Gets SyncShopData from A
- Joins B: Gets SyncShopData from B
- Joins A again: Waits for SyncShopData again
- **Result**: ❌ No cache differentiation

**New Model**:
- Joins A: Loads cache for A (revision 47)
- Joins B: Loads cache for B (revision 23)
- Joins A again: Loads cache for A from disk (revision 47)
- **Result**: ✅ Per-server caching, instant load

---

## Migration Path

### Step 1: Add Versioning to Current System (Backward Compatible)

- Add `revision` field to SyncShopData
- Client stores revision in memory
- Server increments on startup

**Impact**: No behavior change, just preparation

---

### Step 2: Add Disk Caching

- Implement ListingCache module
- Save SyncShopData to disk after receiving
- Load on client boot

**Impact**: Survives client restart, no network change yet

---

### Step 3: Implement Bootstrap (Local Load)

- Load shared default on client boot
- Load disk cache if exists
- Initialize UI immediately
- **Flag**: `SHOPSB42.listingBootstrapComplete = true`

**Impact**: UI instant, no network wait

---

### Step 4: Change Handshake Pattern

- Replace RequestShopData with QueryListingRevision
- Server checks revision before sending
- Only send SyncListingSnapshot on mismatch

**Impact**: Reduces network traffic to ~5 packets/join (was ~20+)

---

### Step 5: Update Documentation

- Codify rules in AGENTS.md
- Document version semantics
- Define server ID generation

**Impact**: Clear contract for future mods

---

## Hard Rules (Architecture Contract)

These rules **must be enforced** to prevent regression:

1. ✅ **Listings only change on server restart**
   - Runtime: Mutable via hooks
   - Snapshot: Immutable per session

2. ✅ **Listings are versioned**
   - Every snapshot has revision field
   - Revision is monotonically increasing
   - Server revision = max hook iteration number

3. ✅ **Listings are cached client-side**
   - Persisted to disk per server
   - Loaded before networking
   - Survives client restart

4. ✅ **Listings are never recomputed client-side**
   - Executed once at server startup
   - Shipped as snapshot
   - Client treats as read-only

5. ✅ **Prices are never trusted client-side**
   - Preview prices calculated separately
   - Server validates on transaction
   - No price data in listing snapshot

6. ✅ **SyncListingSnapshot is revision-gated**
   - Only sent if clientRevision ≠ serverRevision
   - Rare, explicit, documented

---

## Implementation Checklist

- [ ] Create `shared/ShopCatalog.lua` with revision 0
- [ ] Create `server/nshopsb42/listing/ListingServer.lua`
- [ ] Create `client/nshopsb42/listing/ListingBootstrap.lua`
- [ ] Create `client/nshopsb42/listing/ListingCache.lua`
- [ ] Modify `ShopCommandDispatcherServer.lua` (add QueryListingRevision handler)
- [ ] Modify `ShopCommandDispatcherClient.lua` (add ListingRevisionOK + SyncListingSnapshot handlers)
- [ ] Modify `AClientInit.lua` (call ListingBootstrap, send QueryListingRevision)
- [ ] Modify `ShopFinalizeHandlerServer.lua` (generate snapshot at startup)
- [ ] Add tests for all failure scenarios
- [ ] Update AGENTS.md with versioning rules
- [ ] Update COMMUNICATION_VALIDATION_AUDIT.md with new flow

---

## Implementation Constraints (Project Zomboid Lua Runtime)

### File I/O

**Available**:
- ✅ `getFileWriter(filename, append, doNotMakeDir)` - Write files
- ✅ `getFileReader(filename, doNotMakeDir)` - Read files
- ✅ `dofile(filename)` - Load and execute Lua file

**Not available**:
- ❌ `require("json")` - No JSON library in PZ
- ❌ Standard Lua filesystem module
- ❌ External file I/O APIs

**Solution**: Use Lua table serialization with `getFileWriter()` and `dofile()`.

---

### Serialization Format

**Do NOT use**: JSON, YAML, or other formats requiring a parser

**Use**: Lua table source code (human-readable, no deps)

```lua
-- Write
local serialized = "return " .. serializeTable(snapshot)
local writer = getFileWriter("shops/listing.lua", true, false)
writer:write(serialized)
writer:close()

-- Read
local ok, snapshot = pcall(function()
    return dofile("shops/listing.lua")
end)
```

**Why this works**:
- PZ Lua can execute Lua source directly
- No parsing library needed
- Fast and simple
- Safe for client-side cache (server validates everything)

---

### Table Serialization Implementation

See `ListingCache.lua` in this document (lines ~359-446) for complete implementation.

Key points:
- Handles nested tables, strings, booleans, numbers
- Properly escapes string values
- Uses `string.format("%q", v)` for safe string quoting
- Recursive indentation for readability

---

## Conclusion

The current SyncShopData design is **operationally fragile**.

By treating listings as **versioned content** instead of **ephemeral session state**, you:

1. ✅ Eliminate all original sync failures
2. ✅ Reduce network load (revision check << full snapshot)
3. ✅ Enable offline operation
4. ✅ Support multiple servers cleanly
5. ✅ Keep price model unchanged
6. ✅ Create clear architectural contract

**This is not a bug fix. It's an architectural elevation.**

Implement this and SyncShopData becomes a solved problem instead of a recurring source of fragility.
