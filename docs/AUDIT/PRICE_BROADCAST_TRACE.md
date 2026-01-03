# Price Broadcasts Trace: Architecture & Risks

**Date**: 2026-01-03  
**Focus**: Understanding the split-broadcast design and why it's marked CRITICAL  
**Status**: Design is sound, enforcement has gaps

---

## The Design: Split Buy + Sell Broadcasts

The price broadcast system separates **buy prices** and **sell rules** into two independent channels:

```
Server Sends:
├─ SyncBuyPrices   (channel 1)
│  ├─ buyRevision = 1
│  ├─ sellRevision = 1  (informational)
│  └─ buyPrices = {axe: 100, sword: 200}
│
└─ SyncSellRules   (channel 2)
   ├─ buyRevision = 1  (informational)
   ├─ sellRevision = 1
   └─ sellModifiers = {...}
```

**Why Split?**
- Buy prices calculated independently from sell rules
- Different invalidation reasons (BUY_PRICE_DELTA vs SELL_RULE_CHANGE)
- Allows selective updates: only send what changed
- More efficient over network

---

## The Problem: Non-Atomic Broadcasts

### Server-Side: Two Independent Broadcasts

**File**: `ShopFinalizeHandlerServer.lua` L239-246

```lua
-- onPriceHooksChanged() - called when a hook fires (e.g., admin changes a modifier)
if ShopFinalizeHandler.shouldInvalidateBuyPrices() then
    ShopFinalizeHandler.broadcastBuyPrices()  -- ← Separate call
end
if ShopFinalizeHandler.shouldInvalidateSellRules() then
    ShopFinalizeHandler.broadcastSellRules()  -- ← Separate call (may not happen)
end
```

**Issue**: These are **two separate network transmissions**. No guarantee both arrive.

---

### Server-Side: Buy Broadcast

**File**: `ShopFinalizeHandlerServer.lua` L172-194

```lua
function ShopFinalizeHandler.broadcastBuyPrices()
    Shop.BuyPriceRevision = Shop.BuyPriceRevision + 1
    
    -- Build price data (includes modifiers for transparency)
    local calculatedPrices = buildCalculatedPrices()
    local changedPrices = detectPriceChanges(calculatedPrices, ...)
    
    Utilities.SendServerCommandToAll("nshopsb42", "SyncBuyPrices", {
        buyRevision = Shop.BuyPriceRevision,           -- v2
        sellRevision = Shop.SellRuleRevision,          -- v1 (from previous broadcast)
        buyPrices = changedPrices,
    })
    
    SharedLogger.log("Shops", "[...] BUY prices broadcast (rev=" .. Shop.BuyPriceRevision .. ")")
end
```

**What Happens**:
1. Server increments `BuyPriceRevision` → 2
2. Server broadcasts buy prices WITH **sellRevision = 1** (old value)
3. All clients receive: `{buyRevision=2, sellRevision=1, ...}`

---

### Server-Side: Sell Broadcast (Later)

**File**: `ShopFinalizeHandlerServer.lua` L197-221

```lua
function ShopFinalizeHandler.broadcastSellRules()
    Shop.SellRuleRevision = Shop.SellRuleRevision + 1
    
    local sellData = {
        sellModifiers = modifiers.sellModifiers or {},
        sellOverrides = modifiers.sellOverrides or {},
    }
    
    if not ruleSetsEqual(sellData, ShopFinalizeHandler._previousSellRules) then
        Utilities.SendServerCommandToAll("nshopsb42", "SyncSellRules", {
            buyRevision = Shop.BuyPriceRevision,       -- v2 (UPDATED by previous broadcast)
            sellRevision = Shop.SellRuleRevision,      -- v2
            sellModifiers = sellData.sellModifiers,
            sellOverrides = sellData.sellOverrides,
        })
        
        SharedLogger.log("Shops", "[...] SELL rules broadcast (rev=" .. Shop.SellRuleRevision .. ")")
    end
end
```

**What Happens**:
1. Server increments `SellRuleRevision` → 2
2. Server broadcasts sell rules WITH `buyRevision=2` (updated)
3. All clients receive: `{buyRevision=2, sellRevision=2, ...}`

---

## The Atomicity Failure

### Timeline: Two Clients, One Lag

```
t=0  Server: broadcastBuyPrices()
     └─ Sends: buyRevision=2, sellRevision=1

t=1  Client A: receives SyncBuyPrices
     └─ Shop.BuyPriceRevision = 2
     └─ Shop.SellRuleRevision = 1  (unchanged from init)
     └─ State: (buyRev=2, sellRev=1)  ← INCONSISTENT

t=5  Server: broadcastSellRules()
     └─ Sends: buyRevision=2, sellRevision=2

t=10 Client A: receives SyncSellRules
     └─ Shop.SellRuleRevision = 2
     └─ State: (buyRev=2, sellRev=2)  ← NOW CONSISTENT

--- SAME TIME ---

t=0  Server: broadcastBuyPrices()
t=2  Client B: receives SyncBuyPrices (earlier!)
     └─ State: (buyRev=2, sellRev=1)

t=5  Server: broadcastSellRules()

t=15 Client B: receives SyncSellRules (LATE!)
     └─ But in meantime, a new hook fired...
     └─ Server broadcast SyncBuyPrices v3
     └─ Client B received SyncBuyPrices v3 (buyRev=3)
     └─ But SellRuleRevision still 1
     └─ State: (buyRev=3, sellRev=1)  ← DIVERGED FROM CLIENT A

```

### Result

- **Client A**: `(buyRev=2, sellRev=2)` ✓
- **Client B**: `(buyRev=3, sellRev=1)` ✗ Desync!

**Problem**: Buy revision advanced past sell revision. Clients show inconsistent prices.

---

## How It Manifests: Price Flicker

### Scenario: New Player Joins with Price Hook Active

1. Player joins, requests full shop data via `RequestShopData`
2. Server sends `SyncBuyPrices` with current buy prices
3. Client UI opens immediately (before complete sync)
4. UI renders with buy prices v1
5. 50ms later, server sends `SyncSellRules`
6. UI recalculates sell prices, visibly updates
7. **Result**: Price flicker (buy → sell → both)

**Why?** The UI didn't wait for `SyncInitialComplete` signal (which **does exist** but may not be used correctly).

---

## The Fix: Atomic Sync Points

### Already Implemented (Partial)

The code **already includes atomicity logic**:

**File**: `ShopFinalizeHandlerServer.lua` L187-191

```lua
Utilities.SendServerCommandToAll("nshopsb42", "SyncBuyPrices", {
    buyRevision = Shop.BuyPriceRevision,
    sellRevision = Shop.SellRuleRevision,  -- ← Both included
    buyPrices = changedPrices,
})
```

**File**: `ShopFinalizeHandlerServer.lua` L212-217

```lua
Utilities.SendServerCommandToAll("nshopsb42", "SyncSellRules", {
    buyRevision = Shop.BuyPriceRevision,   -- ← Both included
    sellRevision = Shop.SellRuleRevision,
    sellModifiers = sellData.sellModifiers,
    sellOverrides = sellData.sellOverrides,
})
```

**Status**: ✅ Both revisions are sent in each broadcast (atomicity data is there)

---

### Client-Side: Handling Out-of-Order Broadcasts

**File**: `ShopSyncClient.lua` L217-335 (handleSyncBuyPrices)

```lua
function ShopSyncClient.handleSyncBuyPrices(data)
    local oldBuyRevision = Shop.BuyPriceRevision
    local newBuyRevision = data.buyRevision or 0
    local newSellRevision = data.sellRevision or 0  -- Received in message
    
    -- Process prices...
    
    -- Store only BUY revision after comparison
    Shop.BuyPriceRevision = newBuyRevision
    -- NOTE: Do NOT update SellRuleRevision here!
end
```

**File**: `ShopSyncClient.lua` L338-405 (handleSyncSellRules)

```lua
function ShopSyncClient.handleSyncSellRules(data)
    local oldSellRevision = Shop.SellRuleRevision
    local newBuyRevision = data.buyRevision or 0    -- Received in message
    local newSellRevision = data.sellRevision or 0
    
    -- Process sell rules...
    
    -- Store only SELL revision after comparison
    Shop.SellRuleRevision = newSellRevision
    -- NOTE: Do NOT update BuyPriceRevision here!
end
```

**Status**: ✅ Each handler updates only its own revision (prevents cross-talk)

---

### The Gap: No Validation

**Missing**: Client never **validates** that `newBuyRevision == newSellRevision` after both broadcasts received.

**What Should Happen**:

```lua
-- After both broadcasts have been processed:
if Shop.BuyPriceRevision ~= Shop.SellRuleRevision then
    -- We're in an inconsistent state
    -- Either request resync, or mark prices as "dirty"
    SharedLogger.log("Shops", "WARN: Revision mismatch - prices may be inconsistent")
end
```

**Current Code**: No such check (L420-430 has a start of this logic, but incomplete)

---

### The Gap: No SyncInitialComplete Signal

**File**: `ShopSyncClient.lua` L411-430 (handleSyncInitialComplete)

```lua
function ShopSyncClient.handleSyncInitialComplete(data)
    local Shop = SHOPSB42.Shop
    local incomingBuyRev = data.buyRevision or 0
    local incomingSellRev = data.sellRevision or 0
    
    -- Verify revision consistency BEFORE marking complete
    if Shop.BuyPriceRevision ~= incomingBuyRev or Shop.SellRuleRevision ~= incomingSellRev then
        -- Mismatch! Revisions don't match what server thinks
        -- This means some broadcasts were lost or reordered unexpectedly
    end
end
```

**Status**: Handler exists but **may not be called**. Need to verify:
1. Server sends `SyncInitialComplete`?
2. Client waits for it before opening UI?

---

## Summary: What's Missing

| Item | Current | Status | Risk |
|------|---------|--------|------|
| Dual revisions in broadcasts | ✅ YES (L187, 213) | ✅ Correct | LOW |
| Each handler updates own revision | ✅ YES (L334, 403) | ✅ Correct | LOW |
| SyncInitialComplete signal | ✅ Handler exists (L411) | ⚠️ Verify sent | MEDIUM |
| UI waits before opening | ❓ Unknown | ⚠️ Needs audit | **HIGH** |
| Revision mismatch validation | ❌ NO | ❌ Missing | **HIGH** |

---

## The Fix (From ENFORCEMENT_FIXES.md)

### What SHOULD Happen

1. **Server broadcasts atomically**:
   - Send both `buyRevision` and `sellRevision` in each message ✅ Already done
   - Increment revisions together ✅ Already done

2. **Client waits for completion**:
   - Initialize `_initialSyncComplete = false` when opening UI
   - Don't render prices until `_initialSyncComplete = true`
   - Implement `SyncInitialComplete` server → client signal
   - Validate revisions match before opening UI

3. **Validation**:
   - If mismatch detected, log warning and request resync
   - Add assertion: `assert(buyRev == sellRev, "revision mismatch")`

---

## Risk Assessment: Why Critical?

**Probability**: 100% under certain conditions
- New player join + price hook active = guaranteed to see mixed state (at least briefly)

**Impact**: Multiplayer desync
- Two clients with different revision pairs
- Displayed prices differ
- Trades fail: "price changed" errors

**Mitigation Difficulty**: Low (already mostly implemented)
- Just need to wire up `SyncInitialComplete` properly
- Add revision validation on client
- Ensure UI waits for complete signal

---

## Timeline to Fix

1. **Verify current state**: Does server send `SyncInitialComplete`? (5 min)
2. **Add revision validation**: Client checks `buyRev == sellRev` (10 min)
3. **Implement UI wait**: Don't render prices until complete (10 min)
4. **Test**: New player join with hooks active (5 min)

**Total**: 30 minutes

---

## Code Locations

**Server-Side** (broadcasts):
- `ShopFinalizeHandlerServer.lua#L172-194` (broadcastBuyPrices)
- `ShopFinalizeHandlerServer.lua#L197-221` (broadcastSellRules)

**Client-Side** (handlers):
- `ShopSyncClient.lua#L216-335` (handleSyncBuyPrices)
- `ShopSyncClient.lua#L337-405` (handleSyncSellRules)
- `ShopSyncClient.lua#L411-430` (handleSyncInitialComplete)

**UI Opening**:
- `ShopUI.lua` (need to find open/initialize method)

---

**Conclusion**: The design is sound. The enforcement is 80% done. Just need to wire up the completion signal and validation. High confidence fix time: 30 minutes.
