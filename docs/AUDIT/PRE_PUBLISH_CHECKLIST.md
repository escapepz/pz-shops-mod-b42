# Pre-Publish Checklist: Shopsb42 Mod

**Date**: 2026-01-03  
**Target**: Early Release (Condition-Based)  
**Status**: ⚠️ CONDITIONAL — 9 items must be completed before publish

---

## Terminology

- **NPC Shop** / **Kiosk**: Admin-created fixed shop tile with NPC sprite (items have fixed prices in shop inventory)
- **Player Shop**: Player-owned shop container (items have prices stored on item ModData, purchasable by other players)
- **Admin**: Server administrator with permission to place/delete NPC Shops
- **Player**: Regular player who can craft/own/manage Player Shops

---

## Critical Blockers (Must Fix)

**Note**: Item #4 (Deleted Shop) was initially marked CRITICAL, but investigation shows **server is safe**. Downgraded to MEDIUM cosmetic fix. Only 3 items actually block early publish.

### 1. 🔴 CRITICAL: Apply Price Broadcast Fixes
**Issue**: Price data split into two non-atomic broadcasts (buy + sell)  
**Impact**: Players see price flicker on join; multiplayer desync under load  
**Location**: `ShopFinalizeHandlerServer.lua` + `ShopSyncClient.lua`  
**Fix**: See `/docs/ISSUES/REGRESS/ENFORCEMENT_FIXES.md`  
**Estimate**: 30 min  
**Status**: ❌ **NOT APPLIED**

**Checklist**:
- [ ] Add `buyOverrides` field to `SyncBuyPrices` broadcast
- [ ] Add `buyRevision` + `sellRevision` tracking (dual revisions)
- [ ] Send both revisions in every broadcast (atomic)
- [ ] Implement `SyncInitialComplete` signal
- [ ] Test: No price flicker on new player join
- [ ] Test: Two clients converge to same prices under concurrent mods

---

### 2. 🔴 CRITICAL: Verify & Fix Transaction ID Generation
**Issue**: txnId uniqueness unclear; replay vulnerability on server restart  
**Impact**: Duplicate purchases if server restarts during txn dedup  
**Location**: `TransactionRegistry.lua` + txnId generation source (unknown)  
**Risk**: In-memory only; no persistence after restart  
**Estimate**: 30 min (verification + persistence)  
**Status**: ⚠️ **PARTIALLY TESTED**

**Checklist**:
- [ ] Locate where `ticket.txnId` is generated (search codebase)
- [ ] Verify txnId is cryptographically unique (not timestamp)
- [ ] Add test: 1000 sequential purchases generate 1000 unique IDs
- [ ] Implement persistence: Save processed txnIds to ModData
  - Option A: ModData.get("ShopTransactionLog") + cleanup old entries
  - Option B: Integrate timestamp-based dedup (24h window)
- [ ] Test: Duplicate purchase rejected after server restart

---

### 3. 🔴 CRITICAL: Add Concurrency Control to Player Shop Edits
**Issue**: No version tracking on item ModData; two admins editing simultaneously → desync  
**Impact**: Different clients see different prices permanently  
**Location**: `ShopCommandDispatcherServer.lua#139` (PlayerShopSetItemPrice)  
**Estimate**: 1 hour  
**Status**: ❌ **NOT IMPLEMENTED**

**Checklist**:
- [ ] Add `_version` field to item ModData
- [ ] On update: Check version matches current; reject if stale
- [ ] Broadcast updated version with price change
- [ ] Test: Two admins edit simultaneously → both see final state
- [ ] Test: Concurrent edits don't cause infinite loops

---

### 4. 🟠 MEDIUM (Not CRITICAL): Handle Deleted Shop State
**Issue**: Player can edit prices on deleted shop, but server doesn't crash  
**Impact**: Stale UI showing deleted shop, but **server is safe**  
**Location**: `ShopCommandDispatcherServer.lua#51` (RemoveShop) + `PlayerShopServer.lua#44` (SetItemPrice)  
**Technical Detail**: `SetItemPrice` stores price on item's ModData, NOT on shop object. Shop deletion doesn't prevent price updates.  
**Estimate**: 30 min (cosmetic fix only)  
**Status**: ⚠️ **Working but inelegant**

**Server Impact**: ✅ **None** — Price updates work regardless of shop deletion  
**Client Impact**: ⚠️ Stale UI — Player sees deleted shop in UI, can still edit prices

**Checklist**:
- [ ] Client-side: Close UI when player receives shop delete event
- [ ] Optional: Send shop delete signal to all clients (low priority, ship after v1.0)
- [ ] Test: Delete shop → player can still edit prices via stale UI (this is OK, prices persist on items)

---

### 5. 🟠 HIGH: Add Balance Transaction Serialization
**Issue**: Parallel `complete()` calls can execute simultaneously; no mutual exclusion  
**Impact**: Inventory duplication under lag; balance deduction races  
**Location**: `ShopBuyAction.complete()` + `ShopSellAction.complete()`  
**Estimate**: 1.5 hours  
**Status**: ⚠️ **PARTIAL** (anti-dupe exists, no mutex)

**Checklist**:
- [ ] Identify: Are parallel timed actions actually possible? (confirm with PZ docs)
- [ ] If yes: Implement server-side balance mutation lock
- [ ] Test: Buy 10 items rapidly with 100ms latency → no duplication
- [ ] Test: Concurrent buy + sell on same player → correct final state

---

### 6. 🟠 HIGH: Implement Transaction Logging
**Issue**: No audit trail for balance mutations; can't detect/recover from crashes  
**Impact**: Balance lost if server crashes during write  
**Location**: `BalanceServer.lua` (all mutations)  
**Estimate**: 2 hours  
**Status**: ❌ **NOT IMPLEMENTED**

**Checklist**:
- [ ] Create transaction log (ModData or file-based)
- [ ] Log every balance mutation: (username, oldBalance, newBalance, reason, timestamp)
- [ ] On server restart: Verify no orphaned transactions
- [ ] Test: Kill server during balance write → log shows inconsistency → operator can fix
- [ ] Document: How to recover from balance inconsistency

---

## High-Priority Items (Strongly Recommended)

### 7. 🟠 HIGH: Fix "Loot All Coins" Implementation
**Issue**: Feature marked complete but logic unclear; no visible container scan  
**Impact**: Players can't reliably loot coins from multiple containers  
**Location**: `CurrencyContext.lua` (action dispatcher)  
**Estimate**: 1 hour  
**Status**: ⚠️ **AMBIGUOUS**

**Checklist**:
- [ ] Verify: What does "Loot All Coins" actually do?
- [ ] If incomplete: Implement container scanning (nearby objects + floor)
- [ ] Test: Place coins in 3 containers, use Loot → all collected
- [ ] Test: No duplication of coins

---

### 8. 🟠 HIGH: Verify Wallet Placement Validation
**Issue**: Checklist says "wallet must be in main inventory"; code validation unclear  
**Impact**: Wallet in wrong slot → account creation fails mysteriously  
**Location**: `BalanceServer.lua` CreateAccount() L67  
**Estimate**: 30 min  
**Status**: ⚠️ **PARTIALLY IMPLEMENTED**

**Checklist**:
- [ ] Confirm: Does code validate wallet is in main inventory? (check ISBaseCharacter slots)
- [ ] If not: Add validation + error message
- [ ] Test: Try to link wallet from backpack → fails with clear message
- [ ] Test: Move to main inventory → succeeds

---

### 9. 🟡 MEDIUM: Update Pinkslip Car Viewer for B42
**Issue**: Car viewer blocked on pinkslip mod not being updated to B42  
**Impact**: Car purchases can't preview vehicle  
**Location**: `PreviewUI.lua` calls pinkslip APIs  
**Estimate**: Blocked by external mod  
**Status**: ⏳ **BLOCKED**

**Checklist**:
- [ ] Option A: Wait for pinkslip B42 update
- [ ] Option B: Remove car viewer UI element entirely
- [ ] Option C: Gracefully disable (show message: "pinkslip not installed")
- [ ] Decision required before publish

---

## Medium-Priority Items (Before 1.0)

### 10. 📋 Add Concurrency Check: Shop Placement (NPC or Player)
**Issue**: Can two admins place shops (NPC or Player Shop) simultaneously at same location?  
**Impact**: Race condition; unexpected behavior  
**Location**: `ISAddShopAction.lua` (NPC Shop) + `ISAddPlayerShopAction.lua` (Player Shop)  
**Estimate**: 1 hour  
**Status**: ❓ **UNTESTED**

**Checklist**:
- [ ] Determine: Is placement checked server-side for both shop types?
- [ ] Test: Two admins place NPC shop at exact same coord → only one succeeds
- [ ] Test: Two players place Player Shop at exact same coord → only one succeeds
- [ ] If not enforced: Add check

---

### 11. 📋 Document Shop Extension API
**Issue**: Undocumented hooks exist (`OnShopRegisterItems`, `OnShopRegisterSellItems`)  
**Impact**: Modders can't discover extension points  
**Location**: `ShopEvents.lua` + `ShopSellEvents.lua`  
**Estimate**: 30 min  
**Status**: ✅ Hooks coded, ⚠️ Not documented

**Checklist**:
- [ ] Add `OnShopRegisterItems` to HOOKS_CHECKLIST.md with signature
- [ ] Add `OnShopRegisterSellItems` to HOOKS_CHECKLIST.md with signature
- [ ] Provide example mod showing usage
- [ ] Update `/docs/SHOP_EXTENSION_API.md`

---

### 12. 📋 Implement Search Feature Completely
**Issue**: UI has search field, but feature marked incomplete in checklist  
**Impact**: Players can't search shops; QoL missing  
**Location**: `ShopUI.lua` (search field)  
**Estimate**: 1.5 hours  
**Status**: ⏳ **PENDING**

**Checklist**:
- [ ] Implement: Search filters item list by name/category
- [ ] Test: Search "axe" → shows all axes, nothing else
- [ ] Test: Partial match works
- [ ] Test: Case-insensitive

---

## Validation & Testing (Required Before Publish)

### ✅ Single-Player Validation
- [ ] Place NPC Shop (kiosk) → buy items → no crashes
- [ ] Player Shop: craft, place, set prices, lock/unlock
- [ ] Currency: link wallet, transfer, loot coins
- [ ] Sell items to NPC Shop → balance updates
- [ ] Relog → all state persists (shops, prices, balances)

### ✅ Multiplayer Validation  
- [ ] Two players connect → see same NPC Shop inventory
- [ ] One buys from NPC Shop → other sees inventory update
- [ ] New player joins → NPC Shop prices don't flicker
- [ ] Admin modifies NPC Shop → all clients sync
- [ ] One admin deletes NPC Shop → other clients see removal
- [ ] Concurrent price edits on Player Shop don't diverge (both admins editing same item)
- [ ] Player Shop: price edits sync correctly to all observers
- [ ] No duplication under lag (100ms+)
- [ ] Balance consistent after network split

### ✅ Stress Testing
- [ ] 10 rapid purchases (no duplication)
- [ ] Server crash during txn → consistent state on restart
- [ ] 1000 items in shop (no UI lag)
- [ ] Concurrent admins editing 10 shops (no desync)

### ✅ Logging & Observability
- [ ] All errors logged to `Logs/Server/*_Shops.txt`
- [ ] No silent failures
- [ ] Audit trail complete for all transactions
- [ ] SharedLogger used consistently (no writeLog calls)

---

## Summary: What Blocks Early Publish?

| Item | Block? | Fix Time | Impact | Notes |
|------|--------|----------|--------|-------|
| 1. Price Broadcasts | 🔴 YES | 30 min | Critical: UI flicker + desync | - |
| 2. txnId Persistence | 🔴 YES | 30 min | Critical: Replay on restart | - |
| 3. Concurrent Shop Edits | 🔴 YES | 1 hour | Critical: Multiplayer desync | - |
| 4. Deleted Shop Handling | 🟡 NO | 30 min | Cosmetic: Stale UI | Server safe ✅ |
| 5. Balance Serialization | 🟠 NO* | 1.5 hours | High: Single-player OK | Parallelism risk |
| 6. Transaction Log | 🟠 NO* | 2 hours | High: Recovery tool | Crash scenario |
| 7. Loot Coins | 🟠 NO* | 1 hour | High: Feature completeness | Logic unclear |
| 8. Wallet Placement | 🟠 NO* | 30 min | High: UX clarity | Validation weak |
| 9. Pinkslip Car | 🟠 NO | Blocked | Medium: Feature parity | External blocker |
| 10. Shop Placement Race | ⚪ NO | 1 hour | Medium: Edge case | Untested scenario |
| 11. Extension API Docs | ⚪ NO | 30 min | Medium: Developer experience | Non-blocking |
| 12. Search Feature | ⚪ NO | 1.5 hours | Medium: Feature completeness | Non-blocking |

**\* Blocks early release only if targeting multiplayer-only launch. Single-player can ship with these incomplete.**

**REVISED**: Only **3 items block early publish** (down from 4). Total fix time: **2 hours**

---

## Phased Approach

### Phase 1: Critical Fixes (Must Do) ⏱️ **2 hours** (down from 3.5)
```
1. Apply price broadcast fixes     [30 min]
2. Fix txnId persistence          [30 min]
3. Add concurrent edit control    [1 hour]
4. Test all critical paths        [30 min]
```
**Result**: Game is MP-safe, no desync, no duplication, no replay

**Note**: Item #4 (Deleted Shop) not critical — server is safe. Defer to post-launch polish.

---

### Phase 2: High-Priority Fixes (Recommended) ⏱️ **5 hours**
```
5. Add balance mutex              [1.5 hours]
6. Transaction logging            [2 hours]
7. Fix loot coins                 [1 hour]
8. Wallet validation              [30 min]
```
**Result**: Crash-safe, feature-complete, better observability

---

### Phase 3: Medium Priority (Before 1.0) ⏱️ **5 hours**
```
9. Shop placement race check      [1 hour]
10. Extension API docs            [30 min]
11. Complete search feature       [1.5 hours]
12. Pinkslip decision             [decision]
```
**Result**: Polished, documented, extensible

---

## Decision Matrix

### Option A: "Critical Only" (3.5 hours)
**Result**: MP-safe early access  
**Risk**: No crash recovery, no transaction log  
**Recommended for**: Early access label on Steam

### Option B: "Critical + High" (8.5 hours)
**Result**: Robust, crash-safe, observable  
**Risk**: Missing QoL features (search, etc.)  
**Recommended for**: Early access + 1.0 beta label

### Option C: "All Items" (15 hours)
**Result**: Feature-complete, well-documented  
**Risk**: Longer delay to publish  
**Recommended for**: Full 1.0 release

---

## Next Steps

**Immediate Action**: 
1. Decide: Critical only, or include High priority?
2. Pick **one person** to own each critical block
3. Apply fixes in parallel (independent systems)
4. Run validation checklist after each fix

**Timeline to Publish**:
- Critical only: **1 day** (coding + testing)
- Critical + High: **2 days** (coding + testing)  
- All items: **3-4 days** (coding + testing + polish)

---

**Generated**: 2026-01-03  
**Document Owner**: Code Review Agent  
**Last Updated**: (upon completion of any fix)
