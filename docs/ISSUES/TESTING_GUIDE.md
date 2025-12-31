# Phase 5-7 Testing Guide

## Status: Ready for Singleplayer Testing

All code changes complete. IDE warnings are false positives (Project Zomboid base class signatures not recognized by Lua analyzer).

---

## Phase 5: Singleplayer Testing ✅ START HERE

### Preparation
1. Load the mod in Project Zomboid B42.13.1 Singleplayer
2. Enable debug mode: `Core:setDebug(true)` or use configuration
3. Open console: Press Ctrl+Shift+D to toggle console
4. Tail logs or monitor: `Shops.log` / server logs

### Test 1: Player Shop Placement (Basic)

**Prerequisite:** Player inventory contains "Player Shop" item (tag: `shops:PlayerShop`)

**Steps:**
1. Right-click on ground → context menu appears
2. Select "Add Player Shop" → drag cursor appears (green outline)
3. Move cursor around → observe validit feedback
4. Click on valid location → ACTION SHOULD QUEUE (watch log for ISAddPlayerShopAction)
5. **EXPECTED:**
   - Animation plays (progress bar)
   - Shop object appears on map
   - Item consumed from inventory
   - Log shows: `[ISAddPlayerShopAction:complete] Placing player shop...`
   - Log shows: `[ISAddPlayerShopAction:complete] Transmitted to clients`

**Failure Modes:**
- ❌ No animation → `ISAddPlayerShopAction:perform()` not running
- ❌ Object appears mid-animation then disappears → transmitComplete not called
- ❌ Item still in inventory → inventory sync failed
- ❌ Log shows `[ShopSpriteCursor:create]` → old code path executed

---

### Test 2: Player Shop Placement (Freezer Variant)

**Prerequisite:** Player inventory contains "Player Shop (Freezer)" item (tag: `shops:PlayerShopFreezer`)

**Steps:**
1. Right-click on ground → context menu
2. Select "Add Player Shop (Freezer)" → drag cursor
3. Click placement → action queues
4. **EXPECTED:**
   - Animation plays
   - Freezer variant appears on map
   - Item consumed
   - Log shows: `isFreezer=true`
   - Log shows: `[ISAddPlayerShopAction:complete] Configured as freezer`

---

### Test 3: Admin Shop Placement

**Prerequisite:** Player is admin/debug mode enabled

**Steps:**
1. Admin: Right-click on ground
2. Select "Add Shop" → sprite submenu appears
3. Choose a sprite variant → drag cursor
4. Click placement → action queues
5. **EXPECTED:**
   - Animation plays
   - Admin shop object appears
   - Log shows: `[ISAddShopAction:complete] Admin shop placed`
   - Log shows: `[ISAddShopAction:complete] Transmitted to clients`
   - NO item consumed (different from player shop)

---

### Test 4: Validation - Invalid Placement

**Steps:**
1. Try to place shop on occupied square (on NPC, in building)
2. **EXPECTED:**
   - Cursor shows red (invalid)
   - Placement rejected in `complete()` validation
   - Log shows: `[ISAddPlayerShopAction:complete] Square not free at X,Y`
   - OR: `[ISAddPlayerShopAction:complete] Square is solid at X,Y`

---

### Test 5: Inventory Depletion

**Prerequisite:** Have multiple Player Shop items

**Steps:**
1. Place first shop
2. Verify item consumed
3. Place second shop
4. **EXPECTED:**
   - Each placement consumes exactly one item
   - No duplication
   - Inventory shows correct count

---

### Test 6: Save/Load Persistence (SP)

**Steps:**
1. Place shop
2. Save game
3. Reload save
4. **EXPECTED:**
   - Shop still exists at same location
   - Ownership preserved (mod data intact)
   - Income tracking intact

**Failure:**
- ❌ Shop missing → AddTileObject() failed (used AddSpecialObject())
- ❌ Shop visible but location wrong → transmitComplete didn't work

---

## Phase 6: Multiplayer Testing

### Setup
- Host: B42.13.1 dedicated or listen server
- Client 1: Player 1 (admin)
- Client 2: Player 2 (player)
- Enable console logging on all

### Test 1: Player Shop Sync (P2P Visibility)

**Steps:**
1. P1: Place player shop
2. P2: Observe (should see immediately)
3. P1: Check mod data (ownership should be P1's username)
4. **EXPECTED:**
   - Shop visible to P2 immediately (no lag)
   - Ownership correct
   - Container type correct (normal vs freezer)

**Failure:**
- ❌ Shop invisible to P2 → transmitCompleteItemToClients() failed
- ❌ Shop appears late → sync issue
- ❌ Ownership shows wrong player → modData not transmitted

---

### Test 2: Admin Shop Sync (Multi-Client)

**Steps:**
1. P1 (admin): Place admin shop
2. P2: Observe
3. **EXPECTED:**
   - Both players see same shop immediately
   - No ownership metadata (admin shops don't have owner)

---

### Test 3: Inventory Sync (P2P)

**Steps:**
1. P1: Place shop (item in inv = 1, then place, inv = 0)
2. P2: Observe P1's inventory
3. **EXPECTED:**
   - P2 sees P1's inventory update to 0 immediately
   - No item reappearing after disconnect

**Failure:**
- ❌ Item visible in P2's view of P1 inventory after placement → sendRemoveItemFromContainer() failed

---

### Test 4: Lag/Packet Loss Simulation

**Steps:**
1. Use network throttle or mod simulation
2. P1: Place shop during lag
3. **EXPECTED:**
   - Action queues (doesn't execute immediately)
   - Once lag clears, server processes action
   - Shop appears once (no duplication under lag)
   - Item only consumed once

**Failure:**
- ❌ Multiple shops created → race condition from direct creation path
- ❌ Item consumed but shop missing → timed action serialization failed

---

### Test 5: Disconnect/Relog

**Steps:**
1. P1: Place shop
2. P1: Disconnect
3. P1: Reconnect
4. **EXPECTED:**
   - Shop still exists (world state persisted)
   - Ownership unchanged
   - Item remains removed from inventory

**Failure:**
- ❌ Shop gone → not persisted to save file (AddTileObject issue)
- ❌ Item reappears → inventory rollback occurred

---

## Phase 7: Edge Cases

### Test 1: Inventory Full

**Setup:** Player inventory is full

**Steps:**
1. Try to place shop
2. **EXPECTED:**
   - Action still processes (placement succeeds)
   - Item is removed from inventory
   - Action succeeds (no inventory-full error)

---

### Test 2: Insufficient Permissions (MP)

**Setup:** Non-admin tries to place admin shop

**Steps:**
1. Non-admin: Try "Add Shop" menu
2. **EXPECTED:**
   - Menu not visible, OR
   - Action processes then fails in complete()
   - Log shows: `[ISAddShopAction:complete] Non-admin attempted`
   - No shop created

---

### Test 3: Simultaneous Placement

**Setup:** 2 players try to place on same square simultaneously

**Steps:**
1. P1 & P2 both drag cursor to same location
2. Both click to place
3. **EXPECTED:**
   - Both actions queue
   - One succeeds (first to complete on server)
   - One fails in validation (square no longer free)
   - Both players informed via halo note

---

### Test 4: Placement on Moving Object

**Setup:** NPC walking through placement location

**Steps:**
1. Cursor preview shows green (valid)
2. NPC walks into square
3. Player clicks to place
4. **EXPECTED:**
   - Validation in complete() rejects (square no longer free)
   - Log shows: `Square not free at X,Y`
   - No shop created

---

### Test 5: Cancel During Animation

**Setup:** Action in progress

**Steps:**
1. Place shop (animation starts)
2. Press Escape or move (try to stop action)
3. **EXPECTED:**
   - Action cancels properly
   - No shop created
   - Item not consumed
   - No partial state

---

## Log Analysis

### Success Pattern (Expected in Logs):

```
[PlayerShop.addPlayerShop.tryBuild] Queuing ISAddPlayerShopAction for sprite=nshops_shop_sign_01_0
[ISAddPlayerShopAction:new] Created action for sprite=nshops_shop_sign_01_0 isFreezer=false
[ISAddPlayerShopAction:perform] ... (animation)
[ISAddPlayerShopAction:complete] Placing player shop at 100,200 sprite=nshops_shop_sign_01_0
[ISAddPlayerShopAction:complete] IsoThumpable created
[ISAddPlayerShopAction:complete] Shop added to tile
[ISAddPlayerShopAction:complete] Transmitted to clients
[ISAddPlayerShopAction:complete] Item removed from inventory
[ISAddPlayerShopAction:complete] Player shop placement complete
```

### Failure Patterns (Indicates Bug):

```
[DEPRECATED] ShopSpriteCursor:create() should not be called  ← OLD CODE PATH RUNNING
[DEPRECATED] PSServer.PlacePlayerShop should not be called  ← OLD HANDLER CALLED
```

---

## Checklist

### Singleplayer (Phase 5)
- [ ] Test 1: Player shop placement basic
- [ ] Test 2: Player shop freezer variant
- [ ] Test 3: Admin shop placement
- [ ] Test 4: Invalid placement validation
- [ ] Test 5: Inventory depletion
- [ ] Test 6: Save/load persistence

### Multiplayer (Phase 6)
- [ ] Test 1: Player shop sync
- [ ] Test 2: Admin shop sync
- [ ] Test 3: Inventory sync
- [ ] Test 4: Lag simulation
- [ ] Test 5: Disconnect/relog

### Edge Cases (Phase 7)
- [ ] Test 1: Inventory full
- [ ] Test 2: Insufficient permissions
- [ ] Test 3: Simultaneous placement
- [ ] Test 4: Placement on moving object
- [ ] Test 5: Cancel during animation

---

## Troubleshooting

### Issue: "This function requires 9 arguments but receiving X"

**Cause:** IDE analyzer warning (false positive)
**Resolution:** Ignore - Project Zomboid base class not recognized by analyzer
**Status:** Does not affect runtime

### Issue: Action not queuing

**Check:**
1. Are context menus appearing?
2. Does cursor show?
3. Is SharedLogger logging the tryBuild call?
4. Check ISTimedActionQueue for errors

### Issue: Shop appears then disappears

**Likely Cause:** transmitCompleteItemToClients() not called
**Debug:** Search logs for "Transmitted to clients"
**Expected:** Line should appear before "Item removed"

### Issue: Item not consumed

**Likely Cause:** sendRemoveItemFromContainer() failed or skipped
**Debug:** Search logs for "Item removed from inventory"
**Check:** Is item tag detection working?

---

## Rollback Instructions (If Critical Issue)

```bash
cd Shops/42.13.1/media/lua

# Option 1: Revert last 8 files
git checkout HEAD -- \
  shared/nshopsb42/timers/ISAddPlayerShopAction.lua \
  shared/nshopsb42/timers/ISAddShopAction.lua \
  shared/nshopsb42/Init.lua \
  client/nshopsb42/context/PlayerShopContext.lua \
  client/nshopsb42/context/ShopContext.lua \
  shared/nshopsb42/transactions/ShopSpriteCursorUI.lua \
  shared/nshopsb42/transactions/ShopSpriteCursor.lua \
  server/nshopsb42/PlayerShopServer.lua

# Option 2: Full revert to last stable
git revert HEAD
```

---

**Next Step:** Begin Phase 5 testing in singleplayer
