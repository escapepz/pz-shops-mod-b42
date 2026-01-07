# Server UUID Migration Plan

**Status**: Audit + Architecture Definition  
**Priority**: Correctness Fix (Not Optional)  
**Scope**: Cache Key Stability Across Restarts & Reconnects

---

## Problem Statement

The current caching system uses `getLocalServerIdentifier()` as the cache key for disk persistence.

**Why this is architecturally invalid:**

- `getLocalServerIdentifier()` is **connection-scoped**, not world-scoped
- It can change on server restart, client reconnect, or network topology changes
- It was not designed as a persistence key
- This causes:
  - Cache misses after restart (cache files become orphaned)
  - Silent sync retriggers (mistaken for different servers)
  - Revision monotonicity violations
  - Disk cache rendered meaningless

**Correct approach:**

Replace with a **stable, ModData-backed UUID** that is:
- Generated once per world load
- Persisted server-side
- Transmitted to client via ModData
- Used as the authoritative cache key

---

## Current Usage Audit

### Unsafe Call Sites

| File | Line(s) | Function | Usage |
|------|---------|----------|-------|
| `AClientInit.lua` | 90, 105 | `onConnected()`, `onGameStart()` | `getLocalServerIdentifier()` passed to `ListingCache.loadSnapshot()` |
| `ListingCache.lua` | 95-99 | `getCacheFilePath()` | Generates cache file path using server ID |
| `ListingBootstrap.lua` | 27 (indirect) | `selectBestListing()` | Uses cached listing loaded by `AClientInit` |

**Total unsafe call sites:** 2 (direct calls in `AClientInit`), 1 (indirect dependency in `ListingCache`)

### Risk Assessment

**HIGH**: `getCacheFilePath()` directly affects disk persistence  
**MEDIUM**: `AClientInit` call sites are early in bootstrap, but after SharedLogger setup  
**LOW**: `ListingBootstrap` is indirect (depends on prior load)

---

## Architecture: Server UUID Ownership

### 1. Server-Side UUID Generation

**Location**: `Shops/42.13.1/media/lua/server/nshopsb42/AServerInit.lua`

**New event handler** (add to `Events.OnServerStarted`):

```lua
local function ensureShopsServerUUID()
    -- ModData key for server identity
    local SHOPS_SERVER_ID_KEY = "ShopsServerIdentity"
    
    -- Create or retrieve server identity
    local data = ModData.getOrCreate(SHOPS_SERVER_ID_KEY)
    
    if not data.uuid then
        -- First startup: generate UUID
        data.uuid = tostring(getTimestamp()) .. "-" .. ZombRand(1000000)
        data.createdAt = getTimestamp()
        data.schema = 1 -- future versioning
        
        SharedLogger.log("Shops", 
            "[Server Init] Generated new server UUID: " .. data.uuid)
    else
        -- Restart: UUID already exists, verify schema
        SharedLogger.log("Shops", 
            "[Server Init] Loaded existing server UUID: " .. data.uuid)
    end
    
    -- Transmit to all clients (late-joiners receive via ModData sync)
    ModData.transmit(SHOPS_SERVER_ID_KEY)
end

Events.OnServerStarted.Add(ensureShopsServerUUID)
```

**Invariants:**

- Generated exactly once per world load
- Never regenerated unless schema migration
- Persists across server restarts
- Transmitted to all clients automatically

---

### 2. Client-Side Cache Key Resolution

**Location**: `Shops/42.13.1/media/lua/client/nshopsb42/listing/ListingCache.lua`

**Replace**:
```lua
function ListingCache.getCacheFilePath(serverId)
	local safeId = string.gsub(serverId, "[^%w_]", "_")
	return "Lua/shops/listing_snapshot_" .. safeId .. ".lua"
end
```

**With**:
```lua
function ListingCache.getCacheFilePath(serverId)
	if not serverId or serverId == "unknown" then
		SharedLogger.log("Shops", 
			"[ListingCache] WARNING: serverId is nil or unknown, using fallback")
		return "Lua/shops/listing_snapshot_unknown.lua"
	end
	
	-- Safe ID for file path (alphanumeric + underscore + dash + colon)
	local safeId = string.gsub(serverId, "[^%w_:-]", "_")
	return "Lua/shops/listing_snapshot_" .. safeId .. ".lua"
end
```

**Why the change:**

- Accepts the transmitted UUID directly (no need to transform)
- Logs warning if UUID is unavailable (diagnostic aid)
- Retains fallback for edge cases (single-player, early client startup)

---

### 3. Client-Side Bootstrap (AClientInit)

**Location**: `Shops/42.13.1/media/lua/client/nshopsb42/AClientInit.lua`

Uses `getShopsServerUUID()` helper in `onConnected()` and `onGameStart()` to load cached listings before SyncShopData arrives:

```lua
local function getShopsServerUUID()
    local data = ModData.get("ShopsServerIdentity")
    if not data or not data.uuid then
        error("[Shops] Server failed to transmit ShopsServerIdentity - cache key cannot be resolved")
    end
    return data.uuid
end
```

**In `onConnected()` and `onGameStart()`**:
```lua
local serverId = getShopsServerUUID()
SHOPSB42.cachedListing = ListingCache.loadSnapshot(serverId)
```

### 4. Client-Side SyncShopData Handler (ShopCommandDispatcherClient)

**Location**: `Shops/42.13.1/media/lua/client/nshopsb42/ShopCommandDispatcherClient.lua`

When server sends SyncShopData, it includes the server UUID in the command payload:

```lua
local serverId = data.serverUUID
assert(serverId, "[ShopCommandDispatcher:SyncShopData] Server UUID missing from SyncShopData")

local cacheSnapshot = { ... }
local cacheSaved = ListingCache.saveSnapshot(cacheSnapshot, serverId)
```

**Benefits of this two-path approach:**
- Bootstrap path (AClientInit): Gets UUID from ModData to load cached listings early
- Sync path (ShopCommandDispatcherClient): Gets UUID from command payload for cache updates
- No redundant calls
- Clear separation of concerns

---

## Migration Strategy: Not Needed (Development Version)

**Status**: This is a development-only version of Project Zomboid.

In this version:
- `getLocalServerIdentifier()` does not exist
- No legacy caches using the old key scheme
- No migration needed

**For future release versions** (if PZ adds `getLocalServerIdentifier()` later):

The plan would involve:
1. Detecting old cache files by pattern
2. Loading and validating them
3. Migrating to new UUID-based keys (respecting monotonicity)
4. Logging all migrations for audit

For now, the implementation requires the server UUID to be transmitted. If it is missing, the code fails loudly with an assertion error rather than silently falling back to an unavailable API.

---

## Implementation Checklist

### Phase 1: Server-Side UUID Generation

- [x] Add `ensureShopsServerUUID()` to `AServerInit.lua`
- [x] Verify ModData.transmit() is called
- [ ] Test UUID persists across server restart
- [ ] Log server UUID on startup (enable diagnostics)

### Phase 2: Server-Side SyncShopData Payload

- [x] Add serverUUID to shopData table in `ShopFinalizeHandlerServer.lua`
- [x] Ensure UUID is retrieved from ModData before sending

### Phase 3: Client-Side Bootstrap (AClientInit)

- [x] Add `getShopsServerUUID()` helper to get UUID from ModData
- [x] Update `onConnected()` to use helper for cache load
- [x] Update `onGameStart()` to use helper for cache load
- [x] Assert on missing UUID (fail loudly)

### Phase 4: Client-Side SyncShopData Handler (ShopCommandDispatcherClient)

- [x] Update SyncShopData handler to extract serverUUID from command payload
- [x] Assert on missing serverUUID in command
- [x] Use transmitted UUID for cache persistence

### Phase 5: ListingCache Robustness

- [x] Update `getCacheFilePath()` to require UUID
- [x] Assert on nil serverId
- [ ] Test cache load/save with new UUID

### Phase 6: Testing & Validation

- [ ] Build project (`npm run build`)
- [ ] Test SP mode (UUID generation + persistence)
- [ ] Test MP mode (UUID transmission in SyncShopData)
- [ ] Test reconnect (cache is reused from ModData)
- [ ] Test server restart (cache is preserved)
- [ ] Verify revision monotonicity is maintained

---

## Composite Identity Schema (Future-Proofing)

Once server UUID is stable, consider versioning the cache key:

```lua
-- Composite identity for future schema migrations
local function getCompositeCacheKey(serverId, schemaVersion)
    return serverId .. ":" .. (schemaVersion or 1)
end

-- Usage in getCacheFilePath()
local compositKey = getCompositeCacheKey(serverId, 1)
local safeId = string.gsub(compositKey, "[^%w_:-]", "_")
return "Lua/shops/listing_snapshot_" .. safeId .. ".lua"
```

This allows:

- Graceful schema evolution (new game versions)
- Side-by-side caches during migration
- Clear audit trail of versioning

---

## Success Criteria

✅ Cache key is stable across server restart  
✅ Cache key is stable across client reconnect  
✅ Old caches are preserved (not orphaned)  
✅ Revision monotonicity is maintained  
✅ MP clients receive UUID via ModData  
✅ SP mode generates UUID without errors  
✅ Logging clearly identifies UUID source

---

## References

- **PZ MP Architecture**: Server identity must be owned by server, transmitted via ModData
- **Shops Listing Contract**: Monotonicity depends on stable cache keys
- **AGENTS.md**: Canonical server identity pattern (once formalized)
