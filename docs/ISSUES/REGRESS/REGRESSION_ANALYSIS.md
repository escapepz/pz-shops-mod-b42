# Behavioral Regression Analysis: SHA_A vs SHA_B

**Commits:**
- SHA_A (known-good): `99620f0` - "test ok for BUY, not sell, sell prices change WIP"
- SHA_B (redesigned): `77ecac3` - "Split BUY/SELL Broadcast Implementation"

---

## Executive Summary

SHA_B introduces a **split broadcast architecture** that separates buy and sell price synchronization into independent channels with independent revision counters. This is a significant architectural change with **3 critical behavioral regressions** and **2 compliance gaps** that could affect multiplayer consistency and player experience.

---

## Part 1: Observable Behaviors in SHA_A

### 1.1 Single Unified Broadcast Model

**Behavior Invariant**: All price changes (buy and sell) are broadcast via a single `SyncPriceModifiers` command with a unified `PriceHookRevision` counter.

**Evidence** (ShopFinalizeHandlerServer.lua lines 96-117):
```lua
-- SHA_A: Single broadcast
Shop.PriceHookRevision = Shop.PriceHookRevision + 1
Utilities.SendServerCommandToAll("Shops", "SyncPriceModifiers", {
    revision = Shop.PriceHookRevision,
    modifiers = modifiers,        -- Both buy + sell data
    changed = changedPrices,      -- Delta
})
```

**Client behavior** (ShopSyncClient.lua lines 142-154):
```lua
-- SHA_A: Single revision tracking
Shop.PriceHookRevision = newRevision
-- Trigger UI refresh if revision changed OR prices updated
if revisionChanged or calculatedPricesUpdated then
    ShopSyncClient.onPriceHooksChanged()
end
```

**UI Impact**: Single refresh call affects both tabs.

---

### 1.2 Combined Price Modifiers Storage

**Behavior Invariant**: Server sends all price modifiers (buy + sell) in a single `modifiers` object. Client stores this monolithic structure.

**Evidence** (ShopUI.lua line 57, SHA_A):
```lua
-- SHA_A: Uses combined modifiers for sell calc
local modifiers = Shop.PriceModifiers or {}
local price = Calculator.calcSellPrice(item, player, modifiers)
```

**Guarantee**: `Shop.PriceModifiers` contains both buy and sell hooks/overrides needed for all calculations.

---

### 1.3 Atomic Price Update Cycles

**Behavior Invariant**: When `onPriceHooksChanged()` is triggered on server, all hooks (buy + sell) are evaluated atomically in one cycle, producing one broadcast with one revision number.

**Evidence** (ShopFinalizeHandlerServer.lua lines 80-117):
- Single `onPriceHooksChanged()` function
- Single revision increment
- Single broadcast with unified modifiers

**Guarantee**: No window where buy and sell state diverge.

---

### 1.4 Initial Player Sync (Full State)

**Behavior Invariant**: When a new player joins, the server sends full state in a single `SyncPriceModifiers` broadcast with `isInitialSync=true`, containing all modifiers and calculated prices.

**Evidence** (ShopFinalizeHandlerServer.lua lines 243-266):
```lua
-- SHA_A: Single initial sync command
Utilities.SendServerCommandTo(player, "Shops", "SyncPriceModifiers", {
    revision = Shop.PriceHookRevision,
    modifiers = priceModifiers,
    calculatedPrices = calculatedPrices,  -- Full state
    isInitialSync = true,
})
```

---

## Part 2: Semantic Mapping (SHA_A → SHA_B)

### 2.1 Split of Revision Counters

| SHA_A | SHA_B | Semantic Change |
|-------|-------|-----------------|
| `Shop.PriceHookRevision` (single) | `Shop.BuyPriceRevision` + `Shop.SellRuleRevision` (split) | **Decoupling**: Buy and sell changes now tracked independently |

**Code Location** (ShopFinalizeHandlerServer.lua lines 202-204, SHA_B):
```lua
Shop.BuyPriceRevision = 0
Shop.SellRuleRevision = 0
```

**Impact**: Clients can now ignore sell rule updates if they only care about buy prices, but introduces coordination complexity.

---

### 2.2 Split of Broadcast Commands

| SHA_A | SHA_B | Command Change |
|-------|-------|---|
| `SyncPriceModifiers` | `SyncBuyPrices` + `SyncSellRules` | **Separation**: Two independent network messages |

**Evidence**:
- SHA_A: Lines 104-111 send one command with all data
- SHA_B: Lines 127-143 send `SyncBuyPrices`, lines 146-169 send `SyncSellRules`

**Critical Issue**: Client must handle two separate broadcasts that may arrive out of order.

---

### 2.3 Modifiers Storage Split

| SHA_A | SHA_B | Storage Change |
|-------|-------|---|
| `Shop.PriceModifiers` (monolithic) | `Shop.SellModifiers` + `Shop.SellOverrides` (separated from buy) | **Fragmentation**: Sell rules isolated from buy overrides |

**Evidence** (ShopSyncClient.lua lines 171-172, SHA_B):
```lua
Shop.SellModifiers = {}
Shop.SellOverrides = {}
```

**Problem**: Buy modifiers are no longer explicitly stored. See regression #1.

---

### 2.4 Price Broadcast Content Changes

**SHA_A** sends:
```lua
SyncPriceModifiers = {
    revision = X,
    modifiers = {...},           -- BOTH buy + sell hooks
    changed = {...},             -- Changed prices
    calculatedPrices = {...}     -- Full prices on initial sync
}
```

**SHA_B** sends:
```lua
SyncBuyPrices = {
    revision = X,
    buyPrices = {...}            -- ONLY changed buy prices
}

SyncSellRules = {
    revision = Y,
    sellModifiers = {...},       -- ONLY sell modifier rules
    sellOverrides = {...},       -- ONLY sell overrides
}
```

**Key Delta**: SHA_B removes `calculatedPrices` from broadcasts entirely (see regression #2).

---

## Part 3: Execution Paths - Critical Workflows

### 3.1 Workflow: Hook Registration (Finalization)

#### SHA_A Path:
```
finalizeNow()
  → FinalizeRegistry()
  → FinalizeSellRegistry()
  → Builder.buildPriceModifiers()  [computes combined modifiers]
  → Shop.PriceModifiers = modifiers
  → Register event listeners for Buy + Sell hooks
  → Shop._finalized = true
```

**State After**: `Shop.PriceModifiers` contains complete buy + sell state.

#### SHA_B Path:
```
finalizeNow()
  → FinalizeRegistry()
  → FinalizeSellRegistry()
  → Builder.buildPriceModifiers()  [computes split modifiers]
  → Shop.PriceModifiers = modifiers  [assigned but never used again]
  → Register event listeners for Buy + Sell hooks
  → Shop._finalized = true
```

**State After**: `Shop.PriceModifiers` assigned but subsequent broadcasts only use `Shop.SellModifiers` + `Shop.SellOverrides`. Buy modifiers discarded.

**Regression #1: Buy modifiers lost after finalization.**

---

### 3.2 Workflow: Runtime Price Change (Hook Triggered)

#### SHA_A Path:
```
onPriceHooksChanged()
  → shouldInvalidateBuyPrices() [checks buy hooks]
  → shouldInvalidateSellRules() [checks sell hooks]
  → IF buy OR sell hooks exist:
      → Increment Shop.PriceHookRevision (single)
      → Rebuild modifiers (both buy + sell)
      → Detect price deltas
      → SendServerCommandToAll("SyncPriceModifiers", {revision, modifiers, changed})
  → Single atomic broadcast
```

**Atomicity Guarantee**: All hooks evaluated in single pass, one revision, one broadcast.

#### SHA_B Path:
```
onPriceHooksChanged()
  → IF shouldInvalidateBuyPrices():
      → Increment Shop.BuyPriceRevision
      → broadcastBuyPrices()
        → Rebuild modifiers
        → Detect buy price deltas
        → SendServerCommandToAll("SyncBuyPrices", {revision, buyPrices})
  → IF shouldInvalidateSellRules():
      → Increment Shop.SellRuleRevision
      → broadcastSellRules()
        → Rebuild modifiers
        → SendServerCommandToAll("SyncSellRules", {revision, sellModifiers, sellOverrides})
  → Two separate broadcasts (potentially asynchronous)
```

**Loss of Atomicity**: Buy and sell broadcasts are independent. If server crashes between broadcasts, clients see inconsistent state.

**Regression #2: No synchronization point between buy/sell state on client.**

---

### 3.3 Workflow: New Player Join (Initial Sync)

#### SHA_A Path:
```
Player connects → Server triggered
  → sendShopDataToPlayer()
    → Send SyncShopData
    → Send SyncPriceModifiers {
        revision = PriceHookRevision,
        modifiers = {...all buy + sell...},
        calculatedPrices = {...all prices...},
        isInitialSync = true
      }
  → Client receives SINGLE command with full state
  → All price data loaded before any UI can be shown
```

**Guarantee**: When client's `onServerCommand` completes, all price data is available.

#### SHA_B Path:
```
Player connects → Server triggered
  → sendShopDataToPlayer()
    → Send SyncShopData
    → Send SyncBuyPrices {
        revision = BuyPriceRevision,
        buyPrices = {...},
        isInitialSync = true
      }
    → Send SyncSellRules {
        revision = SellRuleRevision,
        sellModifiers = {...},
        sellOverrides = {...},
        isInitialSync = true
      }
  → Client receives THREE separate commands
  → Shop data available, but buy prices and sell rules arrive as two separate events
```

**Problem**: If client opens UI between second and third command, sell prices will be uncalculated.

**Regression #3: Fragmented initial sync introduces race condition.**

---

### 3.4 Workflow: Price Calculation (Client-Side)

#### SHA_A: Buy Price Calculation
```
calcBuyPrice(itemId, basePrice)
  → Check Shop.CalculatedPrices.buyPrices[itemId]
  → IF found, return (all buy prices available from broadcast)
  → ELSE calculate via Calculator (fallback to base price)
```

**Invariant**: Buy prices come from single source.

#### SHA_B: Buy Price Calculation
```
calcBuyPrice(itemId, basePrice)
  → Check Shop.CalculatedPrices.buyPrices[itemId]  [same as SHA_A]
  → IF found, return
  → ELSE calculate via Calculator
```

**No change in logic, but the source (`Shop.CalculatedPrices.buyPrices`) is now only populated by `SyncBuyPrices`, which may not have arrived yet.**

#### SHA_A: Sell Price Calculation
```
calcSellPrice(item, basePrice)
  → Check Shop.CalculatedPrices.sellPrices[itemId]
  → IF found, return
  → TRY Calculator.calcSellPrice(item, player, Shop.PriceModifiers)
      [PriceModifiers contains BOTH buy + sell hooks, used for rules]
  → FALLBACK to basePrice
```

#### SHA_B: Sell Price Calculation
```
calcSellPrice(item, basePrice)
  → Check Shop.CalculatedPrices.sellPrices[itemId]  [empty in SHA_B]
  → IF found, return
  → TRY Calculator.calcSellPrice(item, player, {
        sellModifiers = Shop.SellModifiers,
        sellOverrides = Shop.SellOverrides
    })
  → FALLBACK to basePrice
```

**Key Issue**: SHA_B explicitly reconstructs the modifiers object from split fields. Buy modifiers are not included, so any sell calculation that depends on buy hooks will fail silently.

---

## Part 4: Behavioral Invariants & Enforcement Check

### INV-1: Atomicity of Price State
**Statement**: A revision change guarantees all related price data (buy + sell) has been updated together.

**SHA_A Enforcement**: ✅ Single `PriceHookRevision`, single broadcast.

**SHA_B Enforcement**: ❌ `BuyPriceRevision` and `SellRuleRevision` can diverge. No atomic invariant.

**Impact**: Multiplayer desync risk. Player A sees new buy prices but old sell rules, Player B sees opposite.

---

### INV-2: Buy Modifiers Availability
**Statement**: When buy prices are calculated server-side, the buy modifiers/hooks must be available for transmission.

**SHA_A Enforcement**: ✅ `Shop.PriceModifiers` contains buy overrides. Broadcast sends it.

**SHA_B Enforcement**: ❌ `Shop.PriceModifiers` assigned in `finalizeNow()` but never used in broadcast functions. Buy modifiers discarded.

**Impact**: If buy prices require hook calculations (not just overrides), clients cannot verify server calculations. Loss of transparency.

---

### INV-3: Initial Sync Completeness
**Statement**: After initial sync, all price data needed for UI display must be available.

**SHA_A Enforcement**: ✅ Single `SyncPriceModifiers` command with `isInitialSync=true` includes full state.

**SHA_B Enforcement**: ❌ Three separate commands. `SyncBuyPrices` and `SyncSellRules` may arrive in any order or incomplete.

**Impact**: Client UI can open with empty price cache, displaying base prices or "loading" state incorrectly.

---

### INV-4: Revision Semantics (Single-Version Invariant)
**Statement**: A single revision number can be used by clients to poll/check if ANY price state has changed.

**SHA_A Enforcement**: ✅ `PriceHookRevision` covers all changes.

**SHA_B Enforcement**: ❌ Clients must track two revisions. Polling for changes requires checking both.

**Impact**: API contract change. Existing code expecting single revision will miss sell rule updates.

---

## Part 5: Identified Regressions

### REGRESSION #1: Loss of Buy Modifiers in Broadcast

**Severity**: HIGH (affects hook-based pricing)

**Behavior Change**: 
- **SHA_A**: Buy modifiers (hooks + overrides) sent in `SyncPriceModifiers.modifiers`
- **SHA_B**: Buy modifiers not sent in any broadcast

**Code Locations**:

**SHA_B Server** (ShopFinalizeHandlerServer.lua line 130):
```lua
local modifiers = Builder.buildPriceModifiers()
Shop.PriceModifiers = modifiers  -- Assigned but never used again
```

**SHA_B Broadcast** (ShopFinalizeHandlerServer.lua lines 137-142):
```lua
Utilities.SendServerCommandToAll("Shops", "SyncBuyPrices", {
    revision = Shop.BuyPriceRevision,
    buyPrices = changedPrices,    -- ONLY changed prices, no modifiers
})
```

**SHA_A Broadcast** (line 104-111):
```lua
Utilities.SendServerCommandToAll("Shops", "SyncPriceModifiers", {
    revision = Shop.PriceHookRevision,
    modifiers = modifiers,         -- INCLUDES buy overrides/hooks
    changed = changedPrices,
})
```

**Missing Enforcement**: 
- Buy hook data structure should be sent if `shouldInvalidateBuyPrices()` returns true
- `SyncBuyPrices` should include a `buyModifiers` or `buyOverrides` field

**Player Impact**: Mods cannot inspect why buy prices changed; server authority is opaque.

---

### REGRESSION #2: No Synchronization Point Between Buy/Sell

**Severity**: CRITICAL (multiplayer desync risk)

**Behavior Change**:
- **SHA_A**: Single broadcast → guaranteed atomic state on all clients
- **SHA_B**: Two independent broadcasts → potential window of inconsistency

**Code Locations**:

**SHA_B Server** (ShopFinalizeHandlerServer.lua lines 179-194):
```lua
function ShopFinalizeHandler.onPriceHooksChanged()
    if ShopFinalizeHandler.shouldInvalidateBuyPrices() then
        ShopFinalizeHandler.broadcastBuyPrices()  -- Broadcast 1
    end
    if ShopFinalizeHandler.shouldInvalidateSellRules() then
        ShopFinalizeHandler.broadcastSellRules()  -- Broadcast 2
    end
end
```

**Scenario** (Client gets partial state):
1. Server broadcasts buy prices (revision 5, sell revision 4)
2. **[Network/Server Crash Point]**
3. Client receives buy prices but not sell rules
4. Client reads `BuyPriceRevision = 5, SellRuleRevision = 4`
5. Player sees new buy prices with old sell rules (mismatch)

**Missing Enforcement**: 
- Both broadcasts should include BOTH revisions
- Client should not act on incomplete state
- Or: Both broadcasts should be sent as a single atomic operation

**Multiplayer Impact**: If 2 players join simultaneously and receive broadcasts in different order, they see different relative states.

---

### REGRESSION #3: Fragmented Initial Sync (Race Condition)

**Severity**: MEDIUM-HIGH (UI display race condition)

**Behavior Change**:
- **SHA_A**: Single `SyncPriceModifiers` with `isInitialSync=true` (atomic)
- **SHA_B**: Three separate commands (`SyncShopData`, `SyncBuyPrices`, `SyncSellRules`)

**Code Locations**:

**SHA_B Server** (ShopFinalizeHandlerServer.lua lines 268-330):
```lua
function ShopFinalizeHandler.sendShopDataToPlayer(player)
    -- Command 1
    Utilities.SendServerCommandTo(player, "Shops", "SyncShopData", shopData)
    
    -- Command 2
    Utilities.SendServerCommandTo(player, "Shops", "SyncBuyPrices", {
        revision = Shop.BuyPriceRevision,
        buyPrices = buyData.buyPrices,
        isInitialSync = true,
    })
    
    -- Command 3
    Utilities.SendServerCommandTo(player, "Shops", "SyncSellRules", {
        revision = Shop.SellRuleRevision,
        sellModifiers = modifiers.sellModifiers,
        sellOverrides = modifiers.sellOverrides,
        isInitialSync = true,
    })
end
```

**Race Condition Window**:
```
Time 0: Client receives SyncShopData ✓
Time 1: Client receives SyncBuyPrices ✓
       [UI code opens shop UI here - sells prices not yet loaded]
Time 2: Client receives SyncSellRules ✓
```

**Missing Enforcement**: 
- Initial sync flag should prevent UI from rendering until all three commands received
- Or: Combine into single SyncInitialState command
- ShopUI.lua should check both `isInitialSync` flags before rendering

**Player Impact**: Players joining may briefly see sell prices as base prices only, then they update when third broadcast arrives, causing UI flicker.

---

### REGRESSION #4: Incomplete ShopUI Integration (Phase 4.1 Comment)

**Severity**: MEDIUM

**Code Location** (ShopUI.lua lines 96-100, SHA_B):
```lua
-- Try using shared calculator for preview (Phase 4.1: use separate modifiers)
local modifiers = {
    sellModifiers = Shop.SellModifiers or {},
    sellOverrides = Shop.SellOverrides or {},
}
```

**Issue**: The reconstructed modifiers object **explicitly omits buy modifiers**. This is intentional per the comment "use separate modifiers", but it means:
- Sell price calculations cannot depend on buy hook state
- No cross-hook dependencies possible
- Architectural constraint not documented as a breaking change

**Missing Enforcement**: 
- No assertion or log that buy modifiers were intentionally dropped
- No test verifying sell calculations still work with this subset

---

### REGRESSION #5: Incomplete Sell Rule Extraction in Builder

**Severity**: MEDIUM

**Code Locations** (ShopPriceModifierBuilder.lua lines 35-82, SHA_B):
```lua
-- Extract serializable sell modifier rules from TestPriceHooks (if available)
local TestPriceHooks = SHOPSB42.TestPriceHooks
if TestPriceHooks and TestPriceHooks.sellModifierRules then
    for _, rule in ipairs(TestPriceHooks.sellModifierRules) do
        if rule.effect and rule.effect.value and rule.effect.value ~= 1.0 then
            -- Only rules with multiplier != 1.0
            table.insert(modifiers.sellModifiers, ruleCopy)
        end
    end
end
```

**Issue**: Builder filters out rules where `multiplier == 1.0`. But:
- A rule with multiplier 1.0 is still a rule (it means "apply 100%")
- Filtering them out means the client loses information about which items have been examined by sell hooks
- If a hook checks `if price > 100 then 1.0 else 0.5`, removing the 1.0 rule means client cannot reconstruct the condition

**Missing Enforcement**: 
- Sell modifier extraction should preserve ALL rules, not just non-identity
- Or: Document that only non-identity rules are sent

---

## Part 6: Compliance Gaps

### COMPLIANCE GAP #1: Missing Buy Modifiers Documentation

**Expected** (in SHA_A behavior): `SyncBuyPrices` should document what `buyModifiers` field is or isn't included.

**Actual** (SHA_B): No `buyModifiers` field. Buy calculation is opaque.

**Impact**: External mods cannot audit buy prices.

**Code Fix Needed**: Add `buyModifiers` or `buyOverrides` to `SyncBuyPrices` command:
```lua
Utilities.SendServerCommandToAll("Shops", "SyncBuyPrices", {
    revision = Shop.BuyPriceRevision,
    buyPrices = changedPrices,
    buyOverrides = modifiers.buyOverrides or {},  -- ADD THIS
})
```

---

### COMPLIANCE GAP #2: Missing Initial Sync Coordination

**Expected** (in SHA_A behavior): Initial sync is atomic. Client knows all data arrived.

**Actual** (SHA_B): Three independent broadcasts. Client doesn't know when sync is complete.

**Code Fix Needed**: Add explicit sync completion signal:

```lua
-- Server side (ShopFinalizeHandlerServer.lua)
function ShopFinalizeHandler.sendShopDataToPlayer(player)
    ... send SyncShopData, SyncBuyPrices, SyncSellRules ...
    
    -- Signal sync complete
    Utilities.SendServerCommandTo(player, "Shops", "SyncInitialComplete", {
        buyRevision = Shop.BuyPriceRevision,
        sellRevision = Shop.SellRuleRevision,
    })
end

-- Client side (ShopSyncClient.lua)
function ShopSyncClient.handleServerCommand(...)
    ...
    elseif command == "SyncInitialComplete" then
        ShopSyncClient._initialSyncComplete = true
        -- Now safe to open UI
    ...
end
```

---

## Part 7: Multiplayer & Authority Implications

### 7.1 Client-Server Authority Violation

**Invariant Expected**: Server broadcasts are authoritative. Clients apply changes atomically.

**SHA_B Violation**: Clients can receive `BuyPriceRevision=5, SellRuleRevision=4`, then later `BuyPriceRevision=5, SellRuleRevision=5`. 

If a player's action validates against state with `SellRuleRevision=4`, but server has `5`, transaction is rejected. 

**Player Sees**: "Sell failed. Price changed." But player only sees buy price changed, not sell.

---

### 7.2 Multiplayer Desync Scenario

**Setup**: Server with 3 connected players, server broadcasts split buy/sell updates.

**Timeline**:
```
T0: Server: "Broadcast buy prices (rev=5)"
T1: Player A receives buy (rev=5)
T2: Server crash & restart
T3: Player B receives buy (rev=5)
T4: Server: [no sell broadcast, server lost the event]
T5: Player C never receives sell prices, stuck with defaults
```

**Result**: Players see different effective catalogs.

**SHA_A**: Single `SyncPriceModifiers` would ensure all-or-nothing state transfer. Server crash loses event entirely, but no partial state.

**SHA_B**: Partial broadcasts possible.

---

### 7.3 Sync Correctness for New Players

**SHA_A Guarantee**: New player receives full state in one command. No UI opens until complete.

**SHA_B Gap**: Three commands. If ShopUI code opens UI after command 1-2, prices are incomplete.

**Code Vulnerability** (ShopUI.lua opening logic):
```lua
if not self.shopDataLoaded then
    -- Opened before SyncShopData? No
    -- Opened before SyncBuyPrices? Maybe prices are nil
    -- Opened before SyncSellRules? Sell modifiers are nil
end
```

---

## Part 8: Summary Table

| Aspect | SHA_A | SHA_B | Status |
|--------|-------|-------|--------|
| **Revision Counter** | Single `PriceHookRevision` | Split `BuyPriceRevision` + `SellRuleRevision` | Decoupled ⚠️ |
| **Broadcast Command** | 1x `SyncPriceModifiers` | 2x `SyncBuyPrices` + `SyncSellRules` | Fragmented ⚠️ |
| **Buy Modifiers Sent** | ✅ In modifiers | ❌ Not sent | **REGRESSION** |
| **State Atomicity** | ✅ Single broadcast | ❌ Two broadcasts | **REGRESSION** |
| **Initial Sync** | ✅ 1 command | ❌ 3 commands | **REGRESSION** |
| **Buy Overrides** | In modifiers | In changedPrices (deltas) | OK |
| **Sell Modifiers** | In modifiers | Explicit `SellModifiers` | OK |
| **Hook Dependency Cross** | Possible (all hooks in modifiers) | Not possible (split) | Breaking Change |

---

## Part 9: Recommendations

### Critical (Must Fix)

1. **[CRITICAL-1]** Add `buyOverrides` field to `SyncBuyPrices` broadcast:
   ```lua
   -- Line 137-142 in ShopFinalizeHandlerServer.lua
   Utilities.SendServerCommandToAll("Shops", "SyncBuyPrices", {
       revision = Shop.BuyPriceRevision,
       buyPrices = changedPrices,
       buyOverrides = modifiers.buyOverrides or {},  -- ADD
   })
   ```
   **Restores**: INV-2 (Buy Modifiers Availability)

2. **[CRITICAL-2]** Add both revisions to each broadcast:
   ```lua
   -- SyncBuyPrices AND SyncSellRules should both include:
   {
       buyRevision = Shop.BuyPriceRevision,    -- Add
       sellRevision = Shop.SellRuleRevision,   -- Add
   }
   ```
   **Restores**: INV-1 (Atomicity awareness)

3. **[CRITICAL-3]** Add explicit initial sync completion:
   ```lua
   -- After sending SyncSellRules in sendShopDataToPlayer()
   Utilities.SendServerCommandTo(player, "Shops", "SyncInitialComplete", {
       buyRevision = Shop.BuyPriceRevision,
       sellRevision = Shop.SellRuleRevision,
   })
   ```
   **Restores**: INV-3 (Initial Sync Completeness)

### High (Should Fix)

4. **[HIGH-1]** Document that buy/sell calculations are now independent:
   - Add to SPLIT_BROADCAST_IMPLEMENTATION_SUMMARY.md
   - Warn mods not to use cross-hook dependencies
   - Note that buy modifiers are opaque on client

5. **[HIGH-2]** Add guard in ShopUI to prevent opening UI until initial sync complete:
   ```lua
   function ShopUI:open()
       if not ShopSyncClient._initialSyncComplete then
           SharedLogger.log("Shops", "[ShopUI] UI open deferred - awaiting initial sync")
           return false  -- Defer
       end
       -- ... proceed with UI
   end
   ```

---

## Conclusion

SHA_B's split architecture removes the atomicity guarantee provided by SHA_A's unified broadcast. While the new design could provide benefits (independent updates), it introduces **three behavioral regressions** and **two compliance gaps** that affect:

1. **Transparency**: Buy modifiers no longer sent to client
2. **Consistency**: No synchronization point between buy/sell state
3. **User Experience**: Initial sync creates race condition
4. **Multiplayer Safety**: Desync risk if broadcasts fail partially

These are not design flaws per se, but **enforcement gaps**. The changes require additional coordination logic to maintain the same invariants SHA_A provided implicitly.

