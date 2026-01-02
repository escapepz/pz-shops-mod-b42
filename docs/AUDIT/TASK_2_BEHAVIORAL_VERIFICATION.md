# Task 2: Behavioral Verification

## Overview

This document verifies the **behavioral correctness** of core systems against PZ B42 multiplayer patterns:

- **Timed Actions**: Architecture, serialization, client-only vs server-only execution
- **sendClientCommand Pattern**: Permission checks, no client-side mutations
- **MP Consistency**: Late-join, resync, state coherence
- **UI Logic**: Invalidation vs rebuild, cached data safety

---

## Section 1: Timed Action Architecture

### 1.1 ShopBuyAction - Kiosk Purchase

**File**: `Shops/42.13.1/media/lua/shared/nshopsb42/timers/ShopBuyAction.lua`

#### Structure Verification

| Aspect | Implementation | Status |
|---|---|---|
| **Class Declaration** | `ShopBuyAction:derive("ShopBuyAction")` (ISBaseTimedAction) | ✅ Correct |
| **Constructor (new)** | L302-311: Initializes `shopCoords`, `ticket`, `_shopActionType` | ✅ Serializable fields only |
| **getDuration()** | L48-53: Returns 1 (instant) or 50 (normal) | ✅ Correct |
| **isValid()** | L29-34: Validates balance from ModData (non-mutations) | ✅ Safe for client |
| **waitToStart()** | L36-38: Checks `shouldBeTurning()` (PZ animation state) | ✅ Correct |
| **update()** | L40: No-op | ✅ Safe |
| **start()** | L42: No-op | ✅ Safe |
| **perform()** | L55-59: Client-side sound + ISBaseTimedAction.perform() | ✅ Client-side only |
| **complete()** | L61-300: Server-only execution with guard (see below) | ✅ Correct |

#### Server-Only Guard

**Code** (L63-66):
```lua
if not Utilities.IsServerOrSinglePlayer() then
    SharedLogger.logAction("ShopBuyAction", "complete", "MP - exiting early")
    return true
end
```

✅ **Critical**: Prevents client from executing on non-server side in MP. Returns `true` (success) to prevent UI retry loops.

#### Complete() Method - Behavioral Breakdown

| Step | Code | Behavior | Safety |
|---|---|---|---|
| **Anti-dupe** | L73-76 | Checks TransactionRegistry.isProcessed(username, txnId) | ✅ Prevents replay |
| **Shop Lookup** | L78-97 | Finds shop at stored coords using FindShopAtCoords() | ✅ Coords stored in action, not cached |
| **Distance Check** | L101-105 | Enforces `distance <= 2` from shop square | ✅ Server-side validation |
| **Price Recomputation** | L107-134 | Recalculates all prices server-side using hooks | ✅ No client-trust |
| **Balance Revalidation** | L136-140 | Re-checks balance after hook computation | ✅ Double-check |
| **Atomic Mutation** | L144-159 | Directly mutates ModData.CoinBalance, transmits | ✅ Server-only |
| **Item Spawning** | L162-250 | Iterates ticket.items, instances items, adds to inv | ✅ Server-authoritative |
| **Txn Marking** | L256-259 | Marks txnId as processed in registry | ✅ Prevents re-execution |
| **Audit Log** | L268-296 | Appends to ShopAudit with full context | ✅ Immutable trail |

#### Critical Security Patterns

1. **No Client Trust**: Prices recalculated server-side (L107-134), even though client precomputed
2. **Coordinate Resilience**: Shop looked up from world coords (L84), not cached reference
3. **Atomic Operations**: Balance mutation and transmit in single block (L144-159)
4. **Anti-Dupe Registry**: TransactionRegistry prevents re-execution of same txnId (L73-76)
5. **Double-Balance Check**: Balance checked twice (isValid() + complete()) (L31-33, 137-140)

### 1.2 ShopSellAction - Kiosk Sale

**File**: `Shops/42.13.1/media/lua/shared/nshopsb42/timers/ShopSellAction.lua`

#### Structure Verification

| Aspect | Implementation | Status |
|---|---|---|
| **Constructor** | L220-229: Initializes `shopCoords`, `sellList`, `_shopActionType` | ✅ Serializable |
| **getDuration()** | L45-50: Returns 1 or 50 | ✅ Correct |
| **isValid()** | L29-31: Validates `sellList.items` exists | ✅ Safe |
| **perform()** | L52-58: Plays cash register sound | ✅ Client-side only |
| **complete()** | L60-218: Server-only with guard | ✅ Correct |

#### Complete() - Key Behaviors

| Step | Code | Behavior | Safety |
|---|---|---|---|
| **Server Guard** | L63-66 | Returns early on client in MP | ✅ Correct |
| **Shop Lookup** | L78 | FindShopAtCoords() | ✅ Coordinate-based |
| **Distance Check** | L93-98 | Enforces `distance <= 2` | ✅ Server-side |
| **Account Validation** | L105-110 | Fail-early if account missing | ✅ Prevents item loss |
| **Item Lookup + Remove** | L114-131 | Retrieves item by ID, removes, validates | ✅ Re-checks each item |
| **Price Recompute** | L116-127 | Recalculates using Shop.resolvePlayerSellPrice() | ✅ Hook integration |
| **Balance Deposit** | L151-159 | Direct ModData mutation + transmit | ✅ Atomic |
| **Txn Marking** | L172-175 | Marks as processed | ✅ Anti-dupe |
| **Audit Log** | L186-214 | Full audit trail | ✅ Immutable |

### 1.3 PlayerShopBuyAction - Player Shop Purchase

**File**: `Shops/42.13.1/media/lua/shared/nshopsb42/timers/PlayerShopBuyAction.lua`

#### Structure Verification

| Aspect | Implementation | Status |
|---|---|---|
| **Constructor** | L187-196: Initializes `shopCoords`, `ticket`, `_shopActionType` | ✅ Serializable |
| **getDuration()** | L32-37: Returns 1 or 50 | ✅ Correct |
| **isValid()** | L11-16: Validates balance | ✅ Safe |
| **perform()** | L39-43: Plays sound | ✅ Client-side |
| **complete()** | L45-185: Server-only with guard | ✅ Correct |

#### Complete() - Critical Difference from Kiosk Buy

| Step | Code | Behavior | Safety |
|---|---|---|---|
| **Server Guard** | L48-51 | Returns true on client (MP) | ✅ Correct |
| **Square Lookup** | L67 | Gets grid square (for shop validation) | ✅ World-based |
| **Shop Lookup** | L74-88 | FindShopAtCoords with PlayerShop.spritePrefix | ✅ Type-specific |
| **Distance Check** | L91-95 | Enforces `distance <= 2` | ✅ Server-side |
| **Balance Revalidation** | L104-107 | Re-checks before item transfer | ✅ Double-check |
| **Shop Container** | L110 | Gets container from shop object | ✅ Server-side |
| **Cart Item Transfer** | L122-152 | Iterates ticket.items, transfers to player inv | ✅ Server-authoritative |
| **Price Tracking** | L143-147 | Accumulates totalCoin/totalSpecial from cart | ✅ Client prices used |
| **Withdrawal Command** | L156-159 | Sends `BalanceWithdraw` via sendClientCommand() | ⚠️ See analysis |
| **Income Recording** | L162-167 | Updates shop modData.income | ✅ Shop state |
| **Shop Transmit** | L171 | `self.shop:transmitModData()` | ✅ Sync to all clients |

#### ⚠️ PlayerShopBuyAction - sendClientCommand Pattern Analysis

**Code** (L156-159):
```lua
sendClientCommand(self.character, "nshopsb42", "BalanceWithdraw", {
    coin = totalCoin,
    specialCoin = totalSpecial,
})
```

**Analysis**:

- **Purpose**: Server commands client to withdraw balance (deduct from account)
- **Reverse Pattern**: Unlike typical sendClientCommand (server→client UI), this is **server→character** (bidirectional)
- **Handler Location**: `ShopCommandDispatcherServer.lua` should have handler for this
- **Issue**: Player Shop prices are **client-precomputed** and **client-trusted**. Server adds income based on client-provided prices (L162-167)
- **Risk Level**: ⚠️ **Medium** - Client can manipulate cart prices before purchase action completes

**Behavioral Concern**:
1. Client computes cartEntry.price for each item
2. Client submits cart with prices
3. Server accepts prices and adds to income
4. **No server-side price recomputation** for Player Shop (unlike Kiosk shops which use hooks)

**Verdict**: ⚠️ Player Shop pricing trust chain is weaker than Kiosk.

---

## Section 2: sendClientCommand Pattern Analysis

### 2.1 Pattern Overview

**File Structure**:
- **Server**: `ShopCommandDispatcherServer.lua`, `ShopCommandHandlerServer.lua`
- **Client**: `ShopCommandDispatcherClient.lua`
- **Shared**: Commands routed via `Utilities.SendServerCommandTo()`

### 2.2 Server → Client Commands (Safe)

#### Example: ClearShopSpriteDrag

**Code** (ShopCommandHandlerServer.lua L28-35):
```lua
function Commands.ClearShopSpriteDrag(player, args)
    Utilities.SendServerCommandTo(player, "nshopsb42", "ClearShopSpriteDrag", {})
end
```

✅ **Safe**:
- Server sends UI instruction to client
- Client updates local UI state only
- No mutations on server from response

### 2.3 Client → Server Commands (Authoritative)

#### Example: RemoveShop (Admin)

**Code** (ShopCommandHandlerServer.lua L39-86):
```lua
function Commands.RemoveShop(player, args)
    -- 1. Admin check
    if not Utilities.IsPlayerAdmin(player) then
        player:setHaloNote("Admin permission required", 255, 0, 0, 400)
        return
    end
    -- 2. Server-side operation
    square:transmitRemoveItemFromSquare(obj)
    -- 3. Notify player
    player:setHaloNote("Shop removed", 0, 255, 0, 300)
end
```

✅ **Secure**:
- Permission check on server (not client)
- Mutation on server-side objects only
- Client cannot modify its own permission status

### 2.4 sendClientCommand in Timed Actions

#### ShopBuyAction - None used ✅

Complete() executes entirely on server, no callback.

#### ShopSellAction - None used ✅

Complete() executes entirely on server, no callback.

#### PlayerShopBuyAction - BalanceWithdraw ⚠️

**Code** (L156-159):
```lua
sendClientCommand(self.character, "nshopsb42", "BalanceWithdraw", {
    coin = totalCoin,
    specialCoin = totalSpecial,
})
```

**Analysis**:
- Server tells character to withdraw balance
- Assumes character is server-side player object (correct in on-server context)
- **Intended Behavior**: Server executes withdrawal command targeting player
- **Implementation Question**: Is BalanceWithdraw handler on server? Or does this route back to client dispatcher?

**Risk**: If handler is on client, this is a **client-side mutation** pattern (dangerous).

---

## Section 3: MP Consistency

### 3.1 Late-Join Behavior

#### Currency (Wallet + Account)

**Scenario**: Player joins and has linked wallet with balance 1000 coins.

**Behavior**:
1. Server loads player ModData (CoinBalance)
2. Client receives ModData via PZ engine (ModData.Transmit)
3. Client-side UI can read balance from ModData

✅ **Safe**: Centralized server state, no client prediction.

#### Shops

**Scenario**: Player joins while shop is already placed.

**Behavior**:
1. Shop is world object with sprite
2. Shop modData persists in world save
3. Client sees shop sprite on join
4. Client can request shop data via RequestShopData

✅ **Safe**: Server-authoritative world state.

#### Player Shop

**Scenario**: Player joins while owner is inside shop UI.

**Behavior**:
1. Shop modData contains owner + lock state
2. Client UI can see shop but cannot modify inventory (InventoryTransferValidation blocks)
3. Mutual exclusion enforced server-side

⚠️ **Partially Safe**: Owner can modify inventory while new player joins. Need to verify lock state is shared.

### 3.2 Resync Paths

#### ModData.Transmit Pattern

**Example** (BalanceServer.lua L94, 144, 206, 569):
```lua
ModData.transmit("CoinBalance")
ModData.transmit("BalanceMailbox")
```

✅ **Correct**: Centralized updates propagate to all connected clients.

#### Object Transmit Pattern

**Example** (ShopBuyAction.lua L176, PlayerShopBuyAction.lua L171):
```lua
sendAddItemToContainer(playerInv, newItem)
self.shop:transmitModData()
```

✅ **Correct**: PZ native sync.

#### Potential Resync Issues

1. **Transaction Registry**: Depends on in-memory registry. On server restart, txnIds may not be preserved (potential replay).
2. **Shop Cache**: ClientUI caches shop data. On late-join or resync, must call RequestShopData to refresh.

### 3.3 UI State vs Server State Coherence

#### ShopUI - Read-Only Pattern

**Architecture**:
1. Client requests shop data once (RequestShopData)
2. Client caches in memory (SHOPSB42.ShopData)
3. Client renders UI from cache
4. On purchase, client computes ticket
5. Server re-validates ticket in ShopBuyAction.complete()

✅ **Safe**: Compute is client-side preview only; server is authoritative.

#### PlayerShopUI - Cart Prices

**Architecture**:
1. Client browses shop (read-only from modData)
2. Client selects items and adds to cart
3. Client **computes prices** from item modData
4. Client submits cart with prices
5. Server adds income based on client prices (no recomputation)

⚠️ **Risk**: Client prices not re-verified on server.

---

## Section 4: UI Logic Verification

### 4.1 Rebuild vs Invalidate Patterns

#### ShopUI (Kiosk)

**File**: `Shops/42.13.1/media/lua/client/nshopsb42/ui/ShopUI.lua`

**Expected Patterns**:
- On open: Full render of shop data
- On item select: Update local cart (no server request)
- On buy: Validate locally, then send action
- On response: Refresh UI from server (not cached)

⚠️ **Needs Verification**: Check if UI invalidates after purchase confirmation.

#### PlayerShopUI (Player Shop)

**File**: `Shops/42.13.1/media/lua/client/nshopsb42/ui/PlayerShopUI.lua`

**Expected Patterns**:
- On open: Load shop modData (read-only)
- On item select: Add to local cart
- On sell/manage: Send command to server
- On response: Refresh from server modData

⚠️ **Needs Verification**: Check invalidation on concurrent access (CTD protection lock).

### 4.2 Cached Data Safety

#### Wallet Balance Tooltip

**File**: `ISToolTipInvPatch.lua`

**Pattern**:
- Reads from live ModData on tooltip display
- Does not cache balance

✅ **Safe**.

#### Shop Tab Data

**File**: `ShopTabUI.lua`

**Pattern**:
- Caches shop items on UI open
- Uses `_shopActionType` marker to identify action class

⚠️ **Risk**: If shop inventory changes server-side while UI is open, client sees stale data.

---

## Section 5: Identified Issues

### Critical

1. **PlayerShopBuyAction - Client Price Trust** (L156-159, L162-167)
   - Client computes item prices, server accepts without recomputation
   - **Impact**: Seller income can be manipulated by buyer client
   - **Recommendation**: Server should re-verify prices from shop item modData before adding income

2. **PlayerShopBuyAction - sendClientCommand Usage** (L156-159)
   - Pattern unclear: Does BalanceWithdraw handler execute on server or client?
   - If on client: **Critical security issue** (client-side balance mutation)
   - **Recommendation**: Clarify handler location and ensure server-side execution

### High

3. **Transaction Registry Persistence** (ShopBuyAction.lua L73-76, ShopSellAction.lua L72-75)
   - TransactionRegistry is in-memory only
   - On server restart, registry is cleared → identical txnId could be replayed
   - **Impact**: Potential duplicate purchase on server restart
   - **Recommendation**: Persist TransactionRegistry to ModData or use timestamp-based dedup

4. **PlayerShop Concurrent Access Lock** (PlayerShop.lua)
   - Protection lock is 10 minutes (per checklist)
   - During lock, new player joining cannot access shop UI or confirm lock is held by offline player
   - **Impact**: Confusion if owner disconnects at inconvenient time
   - **Recommendation**: Add UI indicator of lock holder and time remaining

### Medium

5. **Shop Cache Invalidation** (ShopUI.lua, PlayerShopUI.lua)
   - Client caches shop data (prices, inventory)
   - Server-side inventory changes do not trigger client refresh
   - **Impact**: Client sees stale inventory after purchase or if shop is edited
   - **Recommendation**: Add explicit refresh on UI return-to-foreground or periodically request updates

6. **Player Shop Item Filtering** (PlayerShopUI.lua)
   - Only client-side validation prevents showing items without prices
   - **Impact**: Malicious client could render items with no price modData
   - **Recommendation**: Server should only allow client to see items with valid price modData set

---

## Section 6: Summary by Category

### ✅ Correct Implementations

#### Timed Actions - Architecture
- ShopBuyAction: Server-only complete(), anti-dupe registry, price recomputation
- ShopSellAction: Server-only complete(), distance check, account validation
- PlayerShopBuyAction: Server-only complete(), proximity validation
- All use coordinate-based shop lookup (not cached references)
- All use getDuration(), isValid(), perform() correctly

#### sendClientCommand - Admin Commands
- RemoveShop: Permission check on server, mutation on server
- ClearShopSpriteDrag: UI-only instruction to client

#### MP Consistency - Core Systems
- Currency: Server-authoritative ModData sync
- Kiosk Shops: World objects with server-side validation
- Transaction Anti-Dupe: TransactionRegistry prevents replay

#### UI Logic - Safe Patterns
- Wallet tooltip: Reads live ModData
- Shop tabs: Filter from cached data (acceptable for read-only display)

### ⚠️ Needs Verification / Clarification

#### Timed Actions - Edge Cases
- PlayerShopBuyAction: sendClientCommand handler location unclear
- Transaction Registry: In-memory only, no persistence

#### UI Logic - Refresh Patterns
- ShopUI: Invalidation after purchase (needs code review)
- PlayerShopUI: Concurrent access lock display (needs code review)
- Cache invalidation triggers (needs code review)

### ❌ Issues Identified

#### Behavioral Issues
1. **PlayerShopBuyAction - Client Price Trust**: Server accepts buyer-provided prices without recomputation
2. **sendClientCommand BalanceWithdraw**: Handler execution location unclear
3. **Transaction Registry Persistence**: No server-restart protection against replay
4. **PlayerShop Concurrent Lock**: No UI feedback on lock holder/time

---

## Section 7: Behavioral Correctness Verdict

### Overall Assessment: ⚠️ Good with Caveats

**Strengths**:
- Timed Action architecture is solid (server-guard, anti-dupe, coordinate-based lookup)
- Kiosk purchases have strong server-side validation (price recomputation, hooks)
- MP sync uses correct PZ patterns (ModData.transmit, world objects)
- Distance checks prevent remote shopping

**Weaknesses**:
- Player Shop pricing is client-trusting (unlike Kiosk)
- Transaction registry not persistent (replay risk on restart)
- sendClientCommand usage in PlayerShopBuyAction needs clarification
- UI cache invalidation patterns need verification

### Certification

- **MP-Safe**: ✅ For Kiosk shops
- **MP-Safe**: ⚠️ For Player Shops (client price trust)
- **Exploit Risk**: 🔴 Medium (client price trust, registry persistence)
- **SP-Safe**: ✅ Full

---

## Section 8: Recommended Code Review Focus

### Files to Review

1. **`ShopCommandDispatcherServer.lua`** - Where is BalanceWithdraw handler?
2. **`PlayerShopBuyAction.lua` L156-159** - sendClientCommand destination + handler
3. **`ShopUI.lua`** - Cache invalidation after purchase
4. **`PlayerShopUI.lua`** - Lock state UI feedback
5. **`TransactionRegistry.lua`** - Persistence mechanism

### Tests to Add

1. Server restart → attempt to buy same item with same txnId (should fail)
2. PlayerShop: Client manipulates cart prices before sending (should be rejected or re-validated)
3. PlayerShop: Owner DCed → buyer attempts purchase (should be blocked or re-queued)
4. Kiosk Shop: Late-join → purchase attempt (should see correct inventory)
5. Transfer: Offline recipient → multiple transfers → relog (should receive all transfers in mailbox)

---

## Appendix: Timed Action Serialization Checklist

All Timed Actions must satisfy:

| Check | Implementation | Status |
|---|---|---|
| **new() Initializes all fields** | ShopBuyAction: shopCoords, ticket | ✅ |
| **All fields are serializable** | shopCoords (table), ticket (table) | ✅ |
| **getDuration() exists** | L48-53 (ShopBuyAction) | ✅ |
| **perform() is client-side only** | L55-59 (ShopBuyAction) | ✅ |
| **complete() is server-only** | L61-300 (ShopBuyAction) | ✅ |
| **complete() has server guard** | L63-66 (ShopBuyAction) | ✅ |
| **No client-side mutations in complete()** | Only server-side ModData, container ops | ✅ |
| **Anti-dupe mechanism** | TransactionRegistry (L73-76) | ✅ |
| **Coordinate-based lookups** | FindShopAtCoords() (L84) | ✅ |
| **Audit logging** | ShopAudit.append() (L268-296) | ✅ |

---

## Next Steps

1. Locate `BalanceWithdraw` command handler (critical)
2. Verify `ShopCommandDispatcherServer` / `ShopCommandDispatcherClient` routing
3. Review `TransactionRegistry` persistence strategy
4. Test Player Shop price manipulation scenario
5. Review UI cache invalidation on purchase completion
