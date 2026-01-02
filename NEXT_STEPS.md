# Next Steps - Shop Sync Refactor

## Current Status
✓ Phase 1 & 2 Complete - Debug logging infrastructure in place
⏳ Testing phase - Run game and verify logs

---

## Immediate Action Items

### 1. Test the Changes
**Priority**: CRITICAL - Do this first

- [ ] Build and run both server and client
- [ ] Admin logs in and tries to open shop
- [ ] Collect logs from both `C:\Users\PC\Zomboid\Logs\` and `C:\ZomboidClient1\Logs\`
- [ ] Compare against TESTING_CHECKLIST.md
- [ ] Look for RED FLAGS section items

**Expected outcome**: 
- All trace logs appear in correct order
- Shop opens without "Waiting..." loop
- Item counts match (8 buy, 4 sell)

---

## If Tests PASS ✓

### Option A: Clean Up (Recommended for Release)
- [ ] Remove `writeLog()` statements from all files
- [ ] Keep `SharedLogger.log()` statements (less verbose for production)
- [ ] Test again with reduced logging
- [ ] Mark as ready for production

### Option B: Keep Detailed Logging (For Development)
- [ ] Leave as-is for easier debugging
- [ ] Document that trace logging is enabled
- [ ] Can be toggled via config later

### Option C: Implement Phase 3 (Structural Fix)
If you want cleaner architecture:
- [ ] Create `server/nshopsb42/Init.lua` for server-only initialization
- [ ] Move server-specific requires from shared Init
- [ ] Remove all item registration from client context entirely
- [ ] Test again

---

## If Tests FAIL ✗

### Debug Steps (in order):

1. **Check server handler called**
   - Look for `[ShopInitServer.onClientCommand] ENTRY` in server logs
   - If missing: `Events.OnClientCommand` not firing in MP context
   - Solution: Verify event name, check PZ API docs

2. **Check server responses sent**
   - Look for `SENDING SyncShopData...` in server logs
   - If missing: handler not completing
   - If present but not received on client: network issue

3. **Check client receives data**
   - Look for `RECEIVED SyncShopData` in client logs
   - If missing: client event listener not registered or wrong event
   - Solution: Verify `Events.OnServerCommand` exists

4. **Check guard added correctly**
   - Server should log: `[Shared Init] Server context: loaded item registration modules`
   - Client should log: `[Shared Init] Client context: skipping item registration modules`
   - If not appearing: require() guard not working, check syntax

5. **Check contexts**
   - `Utilities.IsClientOnly()` returning correct values?
   - `Utilities.IsServerOrSinglePlayer()` returning correct values?
   - Add logging to Utilities functions to verify

---

## Detailed Phase 3 Implementation (Optional)

If Phase 1-2 works but you want cleaner structure:

### Create `server/nshopsb42/Init.lua`:
```lua
-- Server-only initialization
local Utilities = require("nshopsb42/utils/Utilities")

if not Utilities.IsServerOrSinglePlayer() then
    error("Server Init loaded on client!")
end

-- Server-specific modules only
require("nshopsb42/ShopDefaultItems")
require("nshopsb42/ShopInit")
require("nshopsb42/sales/ShopSellInit")
require("nshopsb42/ShopInitServer")
require("nshopsb42/transactions/ShopFinalizeHandlerServer")
require("nshopsb42/transactions/ShopTransactionValidationServer")
require("nshopsb42/patches/ISTransferActionPatch")

writeLog("Shops", "[Server Init] Server initialization complete")
```

### Update `shared/nshopsb42/Init.lua`:
```lua
-- Remove these lines (now in server/Init.lua):
-- require("nshopsb42/ShopDefaultItems")
-- require("nshopsb42/ShopInit")
-- require("nshopsb42/sales/ShopSellInit")

-- Keep only truly shared code
```

### Update `server/nshopsb42/ShopInitServer.lua`:
```lua
-- Remove these requires (now in server/Init.lua):
-- require("nshopsb42/core/Shop")
-- require("nshopsb42/ShopInit")
-- etc.

-- Just keep the module code
```

---

## Documentation Updates Needed

After testing passes:
- [ ] Update README with architecture explanation
- [ ] Document client/server separation
- [ ] Add logging guide for debugging
- [ ] Update any API docs that reference initialization

---

## Performance Considerations

Once working:
- [ ] Measure startup time (should be same or faster)
- [ ] Check network traffic (should be same)
- [ ] Profile memory (should be same)
- [ ] Test with many players (should work)

---

## Estimated Timeline

- **Testing**: 30 minutes
- **Fix if needed**: 30-60 minutes depending on failure
- **Phase 3 (optional)**: 30-60 minutes
- **Documentation**: 30 minutes
- **Total**: 2-4 hours

---

## Success Metrics

After all done:
- [ ] Client/server sync works reliably
- [ ] No item registration on client
- [ ] No "Waiting..." loops
- [ ] Clean separation of concerns
- [ ] Comprehensive logging for debugging
- [ ] Tests pass consistently
- [ ] Code ready for production

---

## Long-term Improvements (Not Critical)

- [ ] Create formal test suite for sync
- [ ] Add integration tests for MP
- [ ] Benchmark performance
- [ ] Document network protocol
- [ ] Add admin commands for sync debugging
- [ ] Consider message compression for large shops

---

## Contact/Questions

If something doesn't work:
1. Check TESTING_CHECKLIST.md for red flags
2. Review DEBUG_TRACE_AND_REFACTOR_PLAN.md for architecture
3. Check REFACTOR_IMPLEMENTATION_LOG.md for what was changed
4. Compare logs against expected output
5. Check for Lua syntax errors in modified files

The detailed logging should make it clear where the issue is.

---

## Files Modified Summary

1. `shared/nshopsb42/Init.lua` - Context guard for server modules
2. `server/nshopsb42/ShopInitServer.lua` - Handler trace logging  
3. `server/nshopsb42/transactions/ShopFinalizeHandlerServer.lua` - Response trace logging
4. `client/nshopsb42/Init.lua` - Request trace logging
5. `client/nshopsb42/sync/ShopSyncClient.lua` - Receiver trace logging

**Total lines added**: ~150 logging statements
**Total lines modified**: 5 files
**Risk level**: Low (only added logging, no logic changes)
