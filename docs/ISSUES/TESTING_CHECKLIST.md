# Testing Checklist - Shop Sync Fix

## How to Test

1. **Start server and client instances**
2. **Admin logs in and opens shop UI**
3. **Check both log files during startup and when opening shop**

---

## Server Log Verification Checklist

### Startup Phase (look for these lines):
- [ ] `[Shared Init] Server context: loaded item registration modules`
- [ ] `[SERVER] RegisterItem: Base.HairDyeBlonde...` (item registration)
- [ ] `[SERVER] RegisterItem:...` (multiple items)
- [ ] `[ShopFinalizeHandler] Finalization complete - live price hook broadcasting ENABLED`
- [ ] `[ShopInitServer] Registering onClientCommand handler for Shops.RequestShopData`
- [ ] `[ShopInitServer] onClientCommand handler registered successfully`

### When Client Requests Data (look for these lines):
- [ ] `[ShopInitServer.onClientCommand] ENTRY - module=Shops, command=RequestShopData`
- [ ] `[ShopInitServer.onClientCommand] PROCESSING RequestShopData from admin`
- [ ] `[ShopInitServer.onClientCommand] Shop._finalized=true`
- [ ] `[ShopInitServer.onClientCommand] Shop state: Items=8, PlayerBuy=8`
- [ ] `[ShopInitServer.onClientCommand] Shop.BuyPriceRevision=0`
- [ ] `[ShopInitServer.onClientCommand] Calling sendShopDataToPlayer...`
- [ ] `[ShopFinalizeHandler.sendShopDataToPlayer] ENTRY`
- [ ] `[ShopFinalizeHandler.sendShopDataToPlayer] Starting for player: admin`
- [ ] `[ShopFinalizeHandler.sendShopDataToPlayer] SENDING SyncShopData...`
- [ ] `[ShopFinalizeHandler.sendShopDataToPlayer] SyncShopData sent successfully`
- [ ] `[ShopFinalizeHandler.sendShopDataToPlayer] SENDING SyncBuyPrices...`
- [ ] `[ShopFinalizeHandler.sendShopDataToPlayer] SyncBuyPrices sent successfully`
- [ ] `[ShopFinalizeHandler.sendShopDataToPlayer] SENDING SyncSellRules...`
- [ ] `[ShopFinalizeHandler.sendShopDataToPlayer] SyncSellRules sent successfully`
- [ ] `[ShopFinalizeHandler.sendShopDataToPlayer] SENDING SyncInitialComplete...`
- [ ] `[ShopFinalizeHandler.sendShopDataToPlayer] SyncInitialComplete sent successfully`
- [ ] `[ShopFinalizeHandler.sendShopDataToPlayer] EXIT - All data synced to admin`

**Expected Count**: 8 buy items + 4 sell items registered

---

## Client Log Verification Checklist

### Startup Phase (look for these lines):
- [ ] `[Shared Init] Client context: skipping item registration modules (will receive via sync)`
- [ ] `[CLIENT] [ShopBuyInit] Phase 2: Registering 0 items` (0 items on client - correct!)
- [ ] `[CLIENT] [ShopSellInit] Phase 2: Registering 0 items` (0 items on client - correct!)

### When OnGameStart Triggers (look for these lines):
- [ ] `[Client Init onGameStart] ENTRY`
- [ ] `[Client Init] ShopSpriteCursorUI loaded and initialized`
- [ ] `[Client Init onGameStart] Initializing ShopSyncClient...`
- [ ] `[Client Init onGameStart] ShopSyncClient initialized`
- [ ] `[Client Init] OnGameStart event triggered`
- [ ] `[Client Init] IsMultiplayer: true`
- [ ] `[Client Init] About to call sendClientCommand()`
- [ ] `[Client Init] Args: module='Shops', command='RequestShopData', data={}`
- [ ] `[Client Init] sendClientCommand executed successfully - data request sent to server`
- [ ] `[Client Init onGameStart] EXIT`

### When Server Responds (look for these lines):
- [ ] `[ShopSyncClient.handleServerCommand] RECEIVED SyncShopData from server`
- [ ] `[ShopSyncClient] SyncShopData stored: 8 total items, 8 buy, 4 sell`
- [ ] `[ShopSyncClient] Base.Apple found in PlayerBuy (price=15)`
- [ ] `[ShopSyncClient.handleServerCommand] RECEIVED SyncBuyPrices from server`
- [ ] `[ShopSyncClient.handleServerCommand] RECEIVED SyncSellRules from server`
- [ ] `[ShopSyncClient.handleServerCommand] RECEIVED SyncInitialComplete from server`

### When Opening Shop UI (should NOT see):
- ✓ NO repeated `[ShopUI:show] Shop not yet synced from server. Waiting....` messages
- ✓ NO errors about nil items or missing data

---

## Red Flags (If You See These, Investigation Needed)

### On Server:
- ❌ `[ShopInitServer.onClientCommand] ENTRY` missing → handler not called
- ❌ `Module mismatch` → wrong module name being sent
- ❌ `Command mismatch` → wrong command name being sent
- ❌ `ERROR in sendShopDataToPlayer:` → exception occurred during send
- ❌ `NOT in server context` → Utilities.IsServerOrSinglePlayer() returned false

### On Client:
- ❌ No `[Client Init] About to call sendClientCommand()` → onGameStart not triggering
- ❌ `ERROR: sendClientCommand failed` → network send failed
- ❌ No `RECEIVED` messages → responses not arriving
- ❌ Repeated `Shop not yet synced from server. Waiting....` → sync never completed

---

## Log Location

- **Server**: Look in server's Zomboid log folder
- **Client**: Look in `C:\ZomboidClient1\Logs\` or equivalent

---

## Expected Item Counts

- Buy items: **8** (HairDyeBlonde, Bag, SurvivalPack, Bandaid, Apple, OatsRaw, Crowbar, CarNormal)
- Sell items: **4** (KeyRing, BaseballBat, CreditCard, PillsBeta)

If you see different counts, something is wrong with registration.

---

## Success Criteria

✓ All server trace messages appear in order  
✓ All client trace messages appear in order  
✓ Item counts match (8 buy, 4 sell)  
✓ No error messages  
✓ Shop UI opens without "Waiting..." loop  
✓ Shop displays items correctly

---

## Quick Debug Commands

If you need to check current shop state in Lua console:

```lua
-- Check if shop is finalized
print(SHOPSB42.Shop._finalized)

-- Check item counts
local count = 0
for k,v in pairs(SHOPSB42.Shop.PlayerBuy) do count = count + 1 end
print("Buy items: " .. count)

-- Check if client is ready
print(SHOPSB42.ShopSyncClient.isShopReady())

-- Check revisions
print("BuyRev: " .. tostring(SHOPSB42.Shop.BuyPriceRevision))
print("SellRev: " .. tostring(SHOPSB42.Shop.SellRuleRevision))
```

---

## If Tests Pass

- Delete trace logging (optional - can leave for debugging)
- Implement Phase 3 (optional - separate server init)
- Mark refactor as complete

## If Tests Fail

- The detailed logs should show exactly where the chain breaks
- Check red flags section above
- Review DEBUG_TRACE_AND_REFACTOR_PLAN.md for more context
