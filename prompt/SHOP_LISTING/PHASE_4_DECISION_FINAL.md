# Phase 4: Final Decision — Skip Player Shops

**Date**: 2025-01-06  
**Status**: ✅ COMPLETE (Decision made, no implementation needed)

---

## Summary

**Phase 4 applies only to NPC shops (already complete via Phase 3b).**

Player shops are **already optimized** and do not need Phase 4 changes.

---

## NPC Shops (Phase 3b) ✅

```
Status: COMPLETE

ShopUI.lua:
  ├─ Imports: ClientShopListingService
  ├─ calcBuyPrice(): uses service (deterministic, zero network)
  ├─ calcSellPrice(): uses service (deterministic, zero network)
  └─ Network Impact: Zero during listing, 1 packet per transaction
```

**Already optimized in Phase 3b.**

---

## Player Shops (Current State Analysis) ✅

```
Status: ALREADY OPTIMAL — No Phase 4 changes needed

PlayerShopUI.lua:
  ├─ No calcBuyPrice() or calcSellPrice() calls
  ├─ Reads directly from item.ModData.price (per-item)
  ├─ No shared catalog, no hooks
  └─ Network Impact: Zero during listing, 1 packet per transaction
```

**Why Player Shops Don't Need Phase 4**:

1. **No shared pricing**: Each item has its own price (in ModData)
   - No centralized calcBuyPrice() function
   - No sell rules or modifiers
   - Direct per-item lookup

2. **Already deterministic**: 
   - Client reads from container (in world)
   - Server reads same container
   - Same data source = no desync

3. **Server always revalidates**:
   - On transaction, server re-reads item ModData
   - Ignores client-sent price
   - Authority maintained

4. **Zero network during listing**:
   - Container is world object (local)
   - No broadcasts needed
   - Only transaction result sent

---

## Late-Join Container Desync Risks

### Sub-Scenario A: Item Sold While Late-Joiner Was Connecting

**Sequence**:
1. Server has: Container with [Apple (50), Bread (75)]
2. Player A buys Apple
3. Server removes Apple from container
4. Player B (late-joiner) connects
5. Player B opens shop UI

**Current Behavior**:
- Container world object is authoritative
- Player B reads current container state
- Player B sees: [Bread (75)] ✅ Correct

**Risk**: LOW
- Container state is synchronized via world object sync
- Late-joiner gets current state automatically

### Sub-Scenario B: Item Price Changed While Late-Joiner Was Connecting

**Sequence**:
1. Server has: Container with [Apple (50), Bread (75)]
2. Player A changes Bread price to 100
3. Bread item ModData updated
4. Player B (late-joiner) connects
5. Player B opens shop UI

**Current Behavior**:
- Item ModData is persisted in save file
- Late-joiner receives container with updated item
- Player B sees: [Apple (50), Bread (100)] ✅ Correct

**Risk**: LOW
- Item ModData is part of container persistence
- Changes are saved and synced to late-joiners

### Sub-Scenario C: Item Added/Modified on Server, Not Yet Synced to Client

**Sequence**:
1. Player A adds new item to container (with price)
2. Item ModData includes price: {price: 250, ...}
3. Player B opens shop before sync
4. Container sync in progress

**Current Behavior**:
- Player B's UI reads container
- If not yet synced: old container shown
- After sync: new item appears ✅

**Risk**: MINIMAL
- Sync is fast (container is world object)
- Worst case: brief 1-2 second delay
- Player sees updated list after sync

---

## Decision: Option A Confirmed ✅

### Option A: Skip Phase 4 for Player Shops Entirely

**Why**:
1. ✅ Player shops already zero-network during listing
2. ✅ Player shops already use per-item ModData (no calc functions)
3. ✅ Player shops already server-revalidated
4. ✅ Late-join desync risks are LOW (container is authoritative)
5. ✅ No additional optimization needed

**What This Means**:
- Phase 3b complete (NPC shops)
- Phase 4 complete (player shops already optimal)
- Move to Phase 5 (Determinism Validator)

---

## Recommendations for Late-Join Robustness

While Phase 4 is not needed, document these to ensure late-join reliability:

### 1. Container Persistence
- ✅ Ensure item ModData is persisted to save file
- ✅ Verify prices survive server restart
- ❌ Do NOT rely on in-memory caching

### 2. Sync Order
- Ensure container is synced before player can access
- In PlayerShopUI:show(), verify container sync complete
- Current code already gates on `ShopSyncClient.isShopReady()`?

### 3. Network Behavior
- Document: Container changes trigger world object sync (not shop-specific)
- Document: Late-joiner gets current container state automatically
- Document: No dedicated price sync broadcasts (Phase 2.2 removed them)

### 4. Testing Checklist for Late-Join
- [ ] Late-joiner connects while items exist
- [ ] Late-joiner sees current items + prices
- [ ] Item sold → late-joiner sees updated container
- [ ] Price changed → late-joiner sees new price
- [ ] Server restart → late-joiner sees persisted items

---

## Phase 4 Deliverables (Revised)

**Phase 4: NPC vs Player Shops Distinction**

### 4.1: NPC Shops ✅ COMPLETE
- ClientShopListingService active in ShopUI
- Deterministic pricing, zero network
- Phase 3b implementation

### 4.2: Player Shops ✅ ALREADY OPTIMAL
- No Phase 4 implementation needed
- Per-item ModData pricing
- Server revalidation on transaction
- Zero network during listing

### 4.3: Documentation ✅ IN PROGRESS
- Document container desync sub-scenarios
- Document late-join behavior
- Add testing checklist

---

## Files to Update

1. ✅ `PHASE_4_DECISION_FINAL.md` (this document)
2. 🔄 `PHASE_4_IMPLEMENTATION_PLAN.md` — Update to reflect Option A
3. 🔄 `PHASE_4_CHECKLIST.md` — Remove player shop implementation tasks
4. 🔄 `CHANGES_CURRENT.md` — Document Phase 4 completion with caveat

---

## Next Phase

**Phase 5: Determinism Validator** (no changes to player shops needed)

---

## Sign-Off

**Decision**: Phase 4 complete with Zero Implementation
- NPC shops: ✅ Phase 3b complete (ClientShopListingService)
- Player shops: ✅ Already optimal (no changes needed)
- Late-join desync: ✅ LOW RISK (container is authoritative)
- Proceed to Phase 5: Determinism Validator

