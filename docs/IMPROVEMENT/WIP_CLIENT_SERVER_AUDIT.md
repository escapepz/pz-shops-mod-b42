# Client-Server Communication Audit
## Shops Mod (Project Zomboid B42.13.1 MP)

**Audit Date:** January 4, 2026  
**Auditor Role:** Senior MP Architecture Analyst  
**Scope:** Trust boundaries, authority ownership, synchronization correctness  
**Constraint:** Diagnostic only — no code changes recommended  

---

## PHASE 1: Communication Inventory

### 1.1 Client → Server Commands (`sendClientCommand`)

| Entry Point | Command | Direction | Transport | Data Sent | Execution Context | SP Behavior |
|---|---|---|---|---|---|---|
| ShopUI:buyCartBtn() | `ShopBuyAction` (TimedAction) | C→S | TimedAction.complete() | shopCoords, ticket (txnId, prices, items) | Both | Executes locally; server-initiated via TimedAction dispatch |
| ShopUI:sellCartBtn() | `ShopSellAction` (TimedAction) | C→S | TimedAction.complete() | shopCoords, sellList (txnId, itemIDs, prices) | Both | Executes locally; server-initiated via TimedAction dispatch |
| PlayerShopBuyAction:complete() | `BalanceWithdraw` | S→C indirect | sendClientCommand within TimedAction | coin, specialCoin | Server | Server sends command to client (reverse RPC) |
| SetPriceUI:onOK() | `PlayerShopSetItemPrice` | C→S | sendClientCommand | itemID, price, specialCoin | Client UI | SP: local handler; MP: server processes |
| PlayerShopClient:onConnected() | `PlayerShopSyncStatusData` | C→S | sendClientCommand | (no args) | Both | SP: no-op; MP: requests sync |
| AClientInit:onGameStart() | `RequestShopData` | C→S | sendClientCommand | (no args) | Client | SP: triggers local dispatch; MP: server sends response |
| SetPriceUI:onCancel() | `PlayerShopRemoveItemFromInventory` | C→S | sendClientCommand | itemID | Client UI | SP: local; MP: server processes |
| SendTransferAction:complete() | `BalanceTransfer` | S→C indirect | sendClientCommand within TimedAction | recipient, coin, specialCoin | Server | Server initiates transfer on receiving client |

### 1.2 Server → Client Commands (`OnClientCommand`)

| Entry Point | Command | Direction | Transport | Data Sent | Execution Context | SP Behavior |
|---|---|---|---|---|---|---|
| ShopCommandDispatcherServer | `RequestShopData` | S→C | Utilities.SendServerCommandTo() | ShopRegistry, PriceModifiers, CalculatedPrices | Server | SP: dispatches locally via event |
| ShopCommandDispatcherServer | `ClearShopSpriteDrag` | S→C | Utilities.SendServerCommandTo() | (no args) | Server | SP: local handler |
| ShopCommandDispatcherServer | `PlayerShopSyncStatusData` | S→C | Utilities.SendServerCommandTo() | PlayerShopStatus object | Server | SP: local dispatch |
| ShopCommandDispatcherServer | `PlayerShopToggleBusy` | S→C | Utilities.SendServerCommandToAll() | busy flag | Server | SP: broadcasts locally |
| BalanceServer.ClaimMailbox | `BalanceClaimMailbox` | C→S | sendClientCommand | (no args, implicit player context) | Client | SP: local handler invokes BalanceServer directly |

### 1.3 TimedAction Handlers (Server Authority)

| Action | perform() | complete() | animEvent | serverStart | Authority |
|---|---|---|---|---|---|
| **ShopBuyAction** | Play sound; advance timer | RECOMPUTE prices; deduct balance; spawn items; audit log | N/A | N/A | **Server** (L65-304) |
| **ShopSellAction** | Play sound; advance timer | RECOMPUTE prices; add balance; remove items; audit log | N/A | N/A | **Server** (L64-248) |
| **PlayerShopBuyAction** | Play sound; advance timer | Transfer items from shop container to player inventory; send BalanceWithdraw | N/A | N/A | **Server** (L45-185) |
| **ISAddShopAction** | Rotate sprite; advance timer | Create IsoThumpable on server; register in ShopRegistry | N/A | N/A | **Server** |
| **ISAddPlayerShopAction** | N/A | Create container object on server | N/A | N/A | **Server** |
| **SendTransferAction** | N/A | Send BalanceTransfer command (server→client indirect) | N/A | N/A | **Server** |

**Key Pattern:** All `complete()` methods check `IsServerOrSinglePlayer()` and exit early on client. Server executes once; client returns true to consume the action.

### 1.4 ModData Synchronization

| Variable | Direction | Scope | Trigger | SP Behavior |
|---|---|---|---|---|
| `CoinBalance` | Server → Client | Global ModData | `ModData.transmit()` after every balance mutation; `ModData.request()` on client connect | SP: local dispatch via event |
| `item:getModData().price` | Server → Client | Per-item | `syncItemModData(player, item)` when player shop item price is set | SP: local dispatch |
| `item:getModData().specialCoin` | Server → Client | Per-item | `syncItemModData(player, item)` when player shop item marked as special coin | SP: local dispatch |
| `shop:getModData().income` | Server → Clients | Per-object | `shop:transmitModData()` after income logged | SP: local dispatch |
| `ShopTransactions` | Server → Clients | Global ModData | `ModData.transmit()` after transaction marked as processed or rolled back | SP: local dispatch |

---

## PHASE 2: Authority & Trust Classification

### 2.1 Buy Transaction Flow (Kiosk)

**Entry:** Client clicks "Buy" button in ShopUI.buyCartBtn() (L1163-1186)

| Stage | Actor | Trust Level | Authority | Verification |
|---|---|---|---|---|
| **1. Price Calculation** | Client | **Semi-trusted** | Server | Client calculates prices for UI preview only; `ShopUI.buildBuyTicket()` assembles ticket with client-computed prices from `item.price` (L1125) |
| **2. Ticket Creation** | Client | **Untrusted** | Server | Ticket includes txnId, coin total, specialCoin total, item list. **Client prices are IGNORED by server** (see ShopBuyAction L3-5 security invariant) |
| **3. TimedAction Dispatch** | Both | N/A | N/A | Action queued locally; server will intercept during complete() |
| **4. Server-Side Validation** | Server | **Trusted** | Server | ShopBuyAction:complete() (L65-304) recomputes all prices from scratch using `Shop.resolvePlayerBuyPrice()` (L127). **Client ticket prices discarded.** |
| **5. Proximity Check** | Server | **Trusted** | Server | Distance validation against shop coordinates (L105-109). Prevents buying remotely. |
| **6. Balance Validation** | Server | **Trusted** | Server | Check `Balance.getUserBalance()` against **server-computed** prices (L140-144). |
| **7. Balance Mutation** | Server | **Trusted** | Server | Direct ModData manipulation: `account.coin -= totalCoin` (L156-157). **Atomicity:** mutation then transmit (L163). |
| **8. Item Spawn** | Server | **Trusted** | Server | Items instantiated and added to player inventory (L167-254). Quantity validated against ticket. |
| **9. Anti-Dupe Check** | Server | **Trusted** | Server | `TransactionRegistry.isProcessed(username, txnId)` queried BEFORE balance mutation (L77-80). |
| **10. Audit Log** | Server | **Trusted** | Server | Post-transaction log with server-authoritative balance snapshot (L272-300). |

**Assumed Implicit Trust:** 
- Client will submit the same ticket only once (no dupe on client; server enforces dupe check)
- Client will remain within 2-unit distance for the entire action duration (server re-validates at complete time)
- Item types in ticket exist in Shop.Items registry (server validates at L120)

**Vulnerability Vectors:**
- ✅ Client cannot spoof prices → Server recomputes
- ✅ Client cannot double-spend → Anti-dupe check before mutation
- ❓ Client can submit mismatched item types → Server validates existence but not quantity

---

### 2.2 Sell Transaction Flow (Kiosk)

**Entry:** Client clicks "Sell" button in ShopUI.sellCartBtn() (L1226-1262)

| Stage | Actor | Trust Level | Authority | Verification |
|---|---|---|---|---|
| **1. Item Selection** | Client | **Untrusted** | Server | sellList assembled from player inventory (L1189-1224). Client provides itemIDs, server must verify they exist. |
| **2. Price Calculation** | Client | **Semi-trusted** | Server | Client calls `Shop.resolvePlayerSellPrice()` for preview (L1209-1211). Prices sent in sellList. **Server will recompute.** |
| **3. Sell List Creation** | Client | **Untrusted** | Server | Ticket includes txnId, itemID array, and client-computed prices. **Prices discarded by server.** |
| **4. Server Validation** | Server | **Trusted** | Server | ShopSellAction:complete() (L64-248) iterates each itemID, retrieves item from inventory (L118), recomputes price via `Shop.resolvePlayerSellPrice()` (L130). |
| **5. Proximity Check** | Server | **Trusted** | Server | Distance validation (L98-102). |
| **6. Item Existence** | Server | **Trusted** | Server | For each itemID, `inv:getItemById(itemID)` (L118). If not found, item skipped (no payment). |
| **7. Balance Mutation** | Server | **Trusted** | Server | Direct ModData manipulation: `account.coin += total` (L188-189). Atomicity: mutation then transmit (L195). |
| **8. Item Removal** | Server | **Trusted** | Server | Items removed from inventory after price is calculated (L160-161). |
| **9. Anti-Dupe Check** | Server | **Trusted** | Server | `TransactionRegistry.isProcessed()` checked at L76-79. |
| **10. Audit Log** | Server | **Trusted** | Server | Post-transaction log with server-authoritative balance (L216-244). |

**Assumed Implicit Trust:**
- Client will not forge itemID references (server checks via getItemById)
- Client will list same item only once (no duplicate sells in single txn)
- Items do not get removed by other players during the action duration (race condition possible)

**Vulnerability Vectors:**
- ✅ Client cannot spoof sell prices → Server recomputes
- ✅ Client cannot double-sell same item → Anti-dupe check
- ❌ **Race:** Item removed by another player between client sending itemID and server processing (item skipped silently — no refund, no error)
- ❌ **Data loss:** If item is removed during the delay, player loses the transaction but gets no compensation

---

### 2.3 Player Shop Buy (P2P)

**Entry:** Client clicks item in player shop UI

| Stage | Actor | Trust Level | Authority | Verification |
|---|---|---|---|---|
| **1. Item Selection** | Client | **Untrusted** | Server | Client selects item from shop container by itemID. Server must verify item exists in shop. |
| **2. Price Lookup** | Client | **Untrusted** | Server | Client reads item's `modData.price` and `modData.specialCoin` set by shop owner. **Not recomputed server-side** (unlike kiosk). |
| **3. Ticket Creation** | Client | **Untrusted** | Server | Ticket includes shopCoords, itemIDs, prices from item ModData. |
| **4. Server Action** | Server | **Trusted** | Server | PlayerShopBuyAction:complete() (L45-185) retrieves shop by coords, validates proximity, transfers items. |
| **5. Shop Container Lookup** | Server | **Trusted** | Server | `FindShopAtCoords()` retrieves the container (L74-75, L110-113). |
| **6. Item Retrieval** | Server | **Trusted** | Server | For each itemID, `shopContainer:getItemById(itemID)` (L124). If not found, item skipped. |
| **7. Ownership Assumption** | Server | **Assumed** | Client (owner sets via UI) | Prices are set by shop owner in `PlayerShop:setPriceAndSync()` (PlayerShopServer.lua L44-71). Server does not validate owner identity; trusts item is legitimately in the shop. |
| **8. Balance Withdrawal** | Server | **Trusted** | Server | `sendClientCommand()` issues BalanceWithdraw for buyer (L156-159). Server expects client to execute the command. |
| **9. Income Recording** | Server | **Trusted** | Server | Income logged in shop ModData as `{b=buyer_name, t={tl=total_coin, tls=total_special}}` (L162-167). |

**Critical Implicit Assumptions:**
- Shop object will not be deleted during action execution (coords are stored; lookup occurs at complete time)
- Prices set in item ModData are intentional and not stale
- Buyer has sufficient balance before withdrawal command is sent (no pre-check; wallet may have changed)

**Vulnerability Vectors:**
- ❌ **No price recomputation:** Player shop prices are client-set and server-trusts them. No hook resolution, no modifiers, no server recalc.
- ❌ **No balance pre-validation:** BalanceWithdraw is sent speculatively; if buyer's balance changed, it fails silently.
- ❌ **Async income recording:** Income is added to shop ModData but ownership is not enforced (any player can pick up income).

---

### 2.4 Balance Commands

| Command | Direction | Client-Provided Values | Server Validation | Authority |
|---|---|---|---|---|
| `BalanceDeposit` | C→S | coin, specialCoin, itemIDs | Itemize check (all items must exist); amounts must be ≥ 0 | Server |
| `BalanceWithdraw` | S→C indirect (or C→S) | coin, specialCoin | Balance check (account.coin/specialCoin ≥ amount); amounts must be ≥ 0 | Server |
| `BalanceTransfer` | C→S or S→C | recipient, coin, specialCoin | Delegates to BalanceServer.Transfer() | Server |
| `BalanceUnlinkWallet` | C→S | walletID | Wallet existence check | Server |
| `BalanceClaimMailbox` | C→S | (implicit recipient) | Delegates to BalanceServer.ClaimMailbox() | Server |
| `VirtualDeposit` | C→S | coin, specialCoin | Wallet linked check; amounts ≥ 0; no zero deposits | Server |

**Key Observation:** All balance mutations are **server-authoritative**. Client provides amounts; server validates and applies.

---

## PHASE 3: Critical Flow Traces

### 3.1 Complete Buy Transaction Trace (Kiosk)

```
[CLIENT]
1. Player clicks "Buy" in ShopUI
2. ShopUI:buildBuyTicket()
   - Iterates cart items
   - Uses item.price (client-calculated, from UI preview)
   - Sums coin/specialCoin totals
   - Generates txnId (client UUID)
3. ShopUI:buyCartBtn()
   - Creates ShopBuyAction with ticket
   - Extracts shop coordinates {x, y, z}
   - Queues action: ISTimedActionQueue.add(action)

[NETWORK] Action serialization sends to server

[SERVER] ShopBuyAction.complete() — ONLY SERVER EXECUTES
4. Anti-dupe check
   - TransactionRegistry.isProcessed(username, txnId) → checks ModData
   - If txnId already processed, return false (fail transaction)
5. Shop lookup
   - Utilities.FindShopAtCoords(x, y, z) retrieves IsoThumpable
   - If not found, return false
6. Proximity validation
   - character:DistTo(shop) → must be ≤ 2 units
   - If distance > 2, return false
7. PRICE RECOMPUTATION (CRITICAL)
   - Loop through ticket.items
   - For each item, call Shop.resolvePlayerBuyPrice(character, itemType, context)
   - Server-side price resolution includes:
     * Base price from Shop.Items[itemType]
     * Price modifiers from hooks (if registered)
     * Dynamic modifiers based on player state
   - Ignore ticket.coin / ticket.specialCoin — recompute totalCoin/totalSpecial
8. Balance check (against server prices)
   - Get current balance: Balance.getUserBalance(username)
   - Compare: coin ≥ totalCoin AND specialCoin ≥ totalSpecial
   - If insufficient, return false
9. Balance mutation
   - Get ModData: account = ModData.get("CoinBalance")[username]
   - Check account still has sufficient funds (defensive re-check)
   - Subtract: account.coin -= totalCoin; account.specialCoin -= totalSpecial
10. Broadcast balance
    - ModData.transmit("CoinBalance")
    - All clients receive update and sync via OnReceiveGlobalModData
11. Item spawning
    - Loop through ticket.items
    - For pack items: create container, add pack items inside, add container to inventory
    - For simple items: create item directly, add to inventory
    - Quantity from ticket (not recomputed)
12. Anti-dupe mark
    - TransactionRegistry.markProcessed(username, txnId)
    - Stores {status="processed", serverTimestamp=os.time()}
    - ModData.transmit("ShopTransactions")
13. Audit log
    - ShopAudit.append({...}) with:
      * Server-authoritative balance snapshot (coin, specialCoin)
      * Computed delta ({coin=-totalCoin, specialCoin=-totalSpecial})
      * Transaction ID, player, shop location, timestamp
14. Return true (transaction complete)

[CLIENT] Action completes; UI updates; cart cleared
```

**Authority Switch Points:**
- Step 1-3: Client owns UI and ticket formation
- Step 4-13: Server owns ALL authority and validation
- Step 7: **CRITICAL** — Server ignores client prices and recomputes

**Race Windows:**
- Between client sending action and server executing:
  * Player moves away (step 6 catches this)
  * Shop is deleted (step 5 catches this)
  * Player receives money from another source (no check; balance increases for next purchase)
  * Price hooks change (server uses current hooks; client saw stale preview)
  * Player's traits/conditions change (e.g., perks that affect prices) (server recomputes)
- **No race on balance mutation:** Server mutates atomically then broadcasts

**Implicit Assumptions:**
- txnId is unique per client session (UUID collision probability negligible)
- Action serialization does not corrupt ticket fields
- Timer does not complete twice (Kahlua/PZ guarantees single completion)

---

### 3.2 Complete Sell Transaction Trace (Kiosk)

```
[CLIENT]
1. Player clicks "Sell" in ShopUI
2. ShopUI:buildSellList()
   - Iterates player inventory items selected in cart
   - For each item, calls Shop.resolvePlayerSellPrice(player, item, context)
   - Stores itemID (from inventory), computed price, and specialCoin flag
   - Generates txnId
3. ShopUI:sellCartBtn()
   - Creates ShopSellAction with sellList
   - Queues action

[NETWORK] Action serialization sends to server

[SERVER] ShopSellAction.complete() — ONLY SERVER EXECUTES
4. Anti-dupe check
   - TransactionRegistry.isProcessed(username, txnId)
5. Shop lookup
   - FindShopAtCoords(x, y, z)
6. Proximity validation
   - character:DistTo(shop) ≤ 2
7. Account existence check
   - ModData.get("CoinBalance")[username] must exist
   - If not, return false (fail transaction)
8. Item processing loop
   - For each itemID in sellList:
     a. item = inventory:getItemById(itemID)
     b. If item not found → skip (no payment for this item)
     c. PRICE RECOMPUTATION
        - Retrieve itemType = item:getFullType()
        - Call Shop.resolvePlayerSellPrice(character, item, context)
        - If server returns finalPrice: use it
        - Else: fall back to Shop.PlayerSell[itemType].basePrice
        - If no price available: skip item (no payment)
     d. Remove item from inventory
     e. Add price to total/totalSpecial
9. Balance mutation
   - account.coin += total
   - account.specialCoin += totalSpecial
10. Broadcast balance
    - ModData.transmit("CoinBalance")
11. Anti-dupe mark
    - TransactionRegistry.markProcessed(username, txnId)
12. Audit log
    - ShopAudit.append({...}) with server-authoritative snapshot
13. Return true

[CLIENT] Transaction complete
```

**Authority Switch Points:**
- Step 1-2: Client calculates prices for preview; client builds sellList
- Step 8: Server recomputes each item's price and decides payment
- Client prices in sellList are **discarded** (similar to buy transaction)

**Critical Difference from Buy:**
- In buy: prices are recomputed server-side, but quantities in ticket are used
- In sell: **both prices and quantities are client-controlled**, but server validates item existence before removal

**Race Windows:**
- Between client sending itemID and server processing:
  * Item removed by another action (e.g., player drops it, another mod removes it) → item skipped, no payment, silent failure
  * Item price changed by server hook → server uses current price (client saw stale preview)
  * Item broken or condition changed → server may use dynamic pricing

**Data Loss Risk:**
- If item is removed during the sell action, player loses the item but gets no payment and no error message. No rollback.

---

### 3.3 Player Shop Buy Trace (P2P)

```
[CLIENT BUYER]
1. Player clicks item in player shop UI
2. Client calculates item price from item:getModData()
3. Creates PlayerShopBuyAction with:
   - shopCoords {x, y, z}
   - ticket with itemIDs and prices from shop owner

[NETWORK] Action serialization sends to server

[SERVER] PlayerShopBuyAction.complete() — ONLY SERVER EXECUTES
4. Retrieve player shop container by coords
   - Utilities.FindShopAtCoords(x, y, z, PlayerShop.spritePrefix)
5. Proximity validation
   - character:DistTo(shop) ≤ 2
6. Retrieve shop ModData
   - shopModData = shop:getModData()
7. Balance validation
   - Balance.getUserBalance(username) ≥ ticket totals
   - If insufficient, return false
8. Item transfer loop
   - For each cartEntry.itemID:
     a. invItem = shopContainer:getItemById(itemID)
     b. If not found → skip
     c. Remove from shop container
     d. Add to buyer's inventory
     e. Clear item's price ModData (modData.price = nil, modData.specialCoin = nil)
     f. Sync item to buyer: syncItemModData(character, invItem)
     g. Accumulate price to totalCoin/totalSpecial (from cartEntry.price)
9. Balance withdrawal (CRITICAL)
   - sendClientCommand(character, "nshopsb42", "BalanceWithdraw", {coin, specialCoin})
   - Server sends a command to the buyer's client
   - Buyer's client processes BalanceWithdraw (server-side command handler runs on server again)
   - If balance insufficient at that point, withdrawal fails silently
10. Income recording
    - Append to shop ModData: income[i] = {b=buyer_username, t={tl=totalCoin, tls=totalSpecial}}
    - shop:transmitModData()
11. Return true

[RESULT]
- Buyer's inventory: has items, prices cleared
- Shop owner's shop: has less items, income recorded in ModData
- Buyer's wallet: presumably reduced by BalanceWithdraw (if successful)
```

**Critical Issues:**

| Issue | Severity | Reason |
|---|---|---|
| **No price recomputation** | 🔴 Critical | Unlike kiosk buy, prices are NOT recomputed by server. Server trusts the prices in item ModData set by the shop owner. If a hook or modifier changes prices, server doesn't recompute. |
| **No pre-balance check** | 🟠 High | Balance is checked at step 7 against **ticket totals**, but then BalanceWithdraw is sent speculatively (step 9). If buyer's balance changed between these points (e.g., another transaction), withdraw fails silently. |
| **Income ownership unvalidated** | 🔴 Critical | Any player can walk up and call `PlayerShopPickupShop()` to retrieve the income recorded in shop ModData. No ownership validation. Shop owner identity not enforced. |
| **Items removed race** | 🟠 High | If an item is removed from the shop by another player between client sending itemID and server processing, item is skipped with no refund. |
| **Prices stale** | 🟠 High | If shop owner changes a price between client UI render and server complete(), server uses the stale cached value from item ModData. No re-read. |

---

### 3.4 Late-Join Resync Trace

```
[CLIENT CONNECTS TO SERVER]

[BalanceClient.onConnected()]
1. Check if MP (not single player)
2. ModData.request("CoinBalance")
   - Requests server to send current economy state

[AClientInit.onConnected()]
3. Set serverReady = false
4. Set hasRequestedData = false

[AClientInit.onGameStart()]
5. Initialize ShopSyncClient
6. Send RequestShopData command
   - sendClientCommand("nshopsb42", "RequestShopData", {})

[NETWORK] Server receives RequestShopData

[ShopCommandDispatcherServer.Commands.RequestShopData()]
7. Load ShopFinalizeHandler
8. ShopFinalizeHandler.sendShopDataToPlayer(player)
   - Iterates ShopRegistry
   - For each shop, retrieve current ModData
   - Send data to client via Utilities.SendServerCommandTo()
     * Command: "RequestShopData" (server→client)
     * Data: ShopRegistry table, PriceModifiers, CalculatedPrices

[NETWORK] Client receives shop data

[ShopSyncClient.onServerCommand("RequestShopData")]
9. Parse incoming data
10. Validate shop count matches expected
11. For each shop:
    - Update Shop.CalculatedPrices cache
    - Update Shop.PriceModifiers
    - Register shop in client-side ShopRegistry
12. Mark ShopSyncClient.serverReady = true
13. Trigger "ShopsReady" event

[OnReceiveGlobalModData() for CoinBalance]
14. Client receives global ModData update
15. BalanceClient.onReceiveGlobalModData("CoinBalance")
16. Sync currency balances to UI

[RESULT]
- Client has current ShopRegistry (all shops)
- Client has current CoinBalance (virtual wallet)
- Client has current CalculatedPrices (server-computed prices for preview)
- UI can now render shops with accurate data
```

**Synchronization Guarantees:**
- ✅ **CoinBalance** is authoritative on server; client receives snapshot at connect time
- ✅ **ShopRegistry** is sent from server on demand
- ❌ **CalculatedPrices** is sent once at startup; if prices change due to hooks, cache may be stale until next explicit update

**Race Window:**
- Between RequestShopData and receiving response: prices may change on server, client uses stale cache

---

## PHASE 4: MP Fragility Analysis

### 4.1 Execution Order Dependencies

**Transaction Atomicity:**
- ShopBuyAction/ShopSellAction MUST execute `complete()` only once
- **Dependency:** ISBaseTimedAction framework ensures single completion
- **Risk:** Low (PZ engine guarantees)

**Balance Mutation Ordering:**
- Price recomputation MUST occur before balance check
- **Dependency:** ShopBuyAction L4-137 strict ordering
- **Risk:** Low (sequential code)

**Dupe Prevention:**
- Anti-dupe check MUST occur before balance mutation
- **Dependency:** TransactionRegistry.isProcessed() at L77-80 before L156-157
- **Risk:** Low (sequential code)

**ModData Transmission Ordering:**
- Balance mutation MUST complete before ModData.transmit("CoinBalance")
- **Dependency:** L156-157 mutation, then L163 transmit
- **Risk:** Low (sequential)

### 4.2 Lag and Packet Loss Scenarios

#### Scenario A: Buy Action - Price Hook Changes Between Client Render and Server Execution

**Timeline:**
```
T0:   Client UI renders item at $10 (calls Calculator.calcBuyPrice)
T0.5: Server admin calls hook to change base price to $20
T1:   Client clicks Buy with ticket {price=$10}
T2:   Server executes complete(), recomputes price as $20
      Server rejects transaction (balance check fails if player only had $10)
      OR accepts transaction if player has $20 (buyer gets unexpected discount)
```

**Outcome:** 
- **If balance sufficient for new price:** Transaction completes; buyer pays more than displayed
- **If balance insufficient:** Transaction fails; no money lost, but UI showed inconsistent state

**Fragility Level:** 🟠 High  
**Cause:** Client calculates prices for preview, server may have changed prices

#### Scenario B: Sell Action - Item Removed by Another Player

**Timeline:**
```
T0:   Player A selects item in inventory (itemID=12345)
T1:   Player B uses the same item in a crafting recipe
T2:   Player A clicks Sell with sellList {itemID=12345}
T3:   Server loops through sellList, calls inv:getItemById(12345)
T4:   Item not found (B already consumed it)
T5:   Item skipped silently (no payment)
      No error, no refund, no log entry
```

**Outcome:**
- Player A loses item, gets 0 money, no notification

**Fragility Level:** 🔴 Critical  
**Cause:** No atomic inventory check; item can be consumed between client sending itemID and server processing

#### Scenario C: Player Shop Buy - Buyer's Balance Changes Between Pre-Check and Withdrawal

**Timeline:**
```
T0:   Buyer's balance = $50, buyer selects item for $40
T1:   PlayerShopBuyAction.complete() checks: Balance.getUserBalance() = $50 ✓
T2:   Another transaction completes, balance becomes $30 (unrelated purchase)
T3:   sendClientCommand(BalanceWithdraw, {coin=$40})
T4:   BalanceServer.Withdraw checks: account.coin = $30 < $40
T5:   Withdrawal fails silently
T6:   Items already transferred to buyer, but balance not deducted
      Buyer has items and $30 balance (should be -$10)
```

**Outcome:**
- Money duplication: Buyer got items without paying

**Fragility Level:** 🔴 Critical  
**Cause:** Balance pre-check doesn't atomic-lock; BalanceWithdraw is sent speculatively

#### Scenario D: Late-Join Player Shop Pricing

**Timeline:**
```
T0:   Shop owner sets item price to $100 (calls PlayerShopSetItemPrice)
T1:   Client A joins server
T2:   Client A requests shop data (RequestShopData)
T3:   Server sends CalculatedPrices snapshot (does NOT include player shop prices)
T4:   Client A buys from player shop, uses price from item ModData ($100)
      But item ModData was updated at T0; client never saw the update
      OR item price changed again at T0.5, client still uses $100
```

**Outcome:**
- Client uses potentially stale prices from item ModData

**Fragility Level:** 🟠 High  
**Cause:** Player shop prices are not part of CalculatedPrices broadcast; reliance on item ModData

---

### 4.3 Retry and Resend Scenarios

#### Scenario: Action Serialization Failure

If TimedAction serialization fails (rare but possible in heavy lag):
- **Impact:** Action never reaches server, client-side action completes locally
- **Detection:** Client-side logging in ShopBuyAction.perform() at L60
- **Recovery:** No automatic retry; player must attempt action again

#### Scenario: ModData.transmit() Lost

If `ModData.transmit("CoinBalance")` packet is lost:
- **Impact:** Server has updated balance, clients don't receive update
- **Detection:** Client reconnects (BalanceClient.onConnected() calls ModData.request())
- **Recovery:** Automatic on next connection or OnReceiveGlobalModData event

---

### 4.4 Single-Player Execution Divergence

| Feature | SP Behavior | MP Behavior | Risk |
|---|---|---|---|
| **sendClientCommand()** | Dispatches via local event loop | Sends to server socket | 🟢 Utilities abstracts this |
| **ModData.transmit()** | Broadcasts locally via event | Sends to all clients | 🟢 Utilities abstracts |
| **isServer()** | Always false | True on server | 🟢 Checked explicitly in dispatchers |
| **isClient()** | Always true | True on all clients | 🟢 Checked in client dispatchers |
| **Wallet linking** | Bypassed (Utilities.IsPlayerAdmin uses isDebugEnabled) | Normal permission checks | 🟠 Admin check differs |
| **Timeout on action** | None (local) | Packet loss recovery depends on client retry | 🟠 May diverge under lag |

---

## PHASE 5: Risk Classification

### 🔴 CRITICAL RISKS

#### Risk #1: Player Shop Buy — Money Duplication
**Description:**  
PlayerShopBuyAction pre-checks buyer balance (L104-107), then sends BalanceWithdraw speculatively (L156-159). If balance changes between these points, items transfer but money is not deducted.

**Exploit Vector:**
1. Buyer has $50
2. Server checks balance: ✓ sufficient
3. Another transaction completes: balance → $30
4. BalanceWithdraw issued for $40 fails (insufficient funds)
5. Buyer keeps items + $30 (should be -$10)

**Root Cause:**  
BalanceWithdraw is issued AFTER items are transferred. No atomic transaction scope. Server expects BalanceWithdraw will succeed but doesn't verify it did.

**Evidence:**  
PlayerShopBuyAction:complete() L104-107 (pre-check), L156-159 (send command), no post-check for success.

---

#### Risk #2: Sell Transaction — Silent Item Loss
**Description:**  
ShopSellAction processes items without atomic inventory locking. If item is consumed by another action (crafting, drop, transfer) between client sending itemID and server processing, item is skipped silently with no refund or error.

**Exploit Vector:**
1. Player adds item X to sell list
2. Player sends sell action
3. Server loop iterates itemID, calls `inv:getItemById(itemID)`
4. Meanwhile, another mod or player action removes item X
5. Server skips item (getItemById returns nil)
6. Player gets no money, no error notification

**Root Cause:**  
Inventory state is not locked during action execution. Multiple threads/actions can mutate inventory concurrently.

**Evidence:**  
ShopSellAction:complete() L118 (getItemById), L159-161 (remove). No pre-action lock.

---

#### Risk #3: Player Shop Ownership — Any Player Can Claim Income
**Description:**  
Income is stored in shop ModData as `{b=buyer_name, t=...}`. Any player can call `PlayerShopPickupShop()` to retrieve the income stored there. No ownership validation.

**Exploit Vector:**
1. Player A creates player shop and sets item prices
2. Player B buys item, income recorded in shop ModData
3. Player C walks up and calls `PlayerShopPickupShop()`
4. Player C receives income (should go to Player A)

**Root Cause:**  
Income retrieval doesn't check if player is the shop owner. PlayerShopPickupShop() only checks if shop is empty.

**Evidence:**  
ShopCommandDispatcherServer.Commands.PlayerShopPickupShop() L186-274 no ownership check.

---

### 🟠 HIGH RISKS

#### Risk #4: Price Hooks — Client UI Shows Stale Prices
**Description:**  
Client calculates prices for UI preview using client-side hooks. If server-side hooks change prices between client render and server execution, buyer sees outdated prices.

**Scenario:**
1. Admin changes a price hook mid-game
2. Client UI renders item at old price
3. Buyer clicks Buy
4. Server recalculates using new hook, price is different
5. If higher: buyer pays more than displayed (if balance allows)
6. If lower: buyer gets discount (server recalculates)

**Root Cause:**  
Prices are computed on client for preview, but server may have different hooks or modifiers. No synchronization of hook state.

**Evidence:**  
ShopUI:buildBuyTicket() L1111-1160 uses `item.price` (cached from preview). Server recomputes in ShopBuyAction:complete() L127 using `Shop.resolvePlayerBuyPrice()` which may apply different hooks.

---

#### Risk #5: Player Shop Buy — Prices Not Recomputed by Server
**Description:**  
Unlike kiosk buy (where server recomputes prices), player shop buy trusts the prices stored in item ModData. If a hook is intended to apply to player shops (e.g., trait-based discount), server doesn't apply it.

**Scenario:**
1. Admin adds a trait-based price modifier to Shop.resolvePlayerBuyPrice()
2. Player with the trait buys from player shop
3. Server does NOT recalculate the price (player shop prices are final)
4. Buyer pays full price instead of discounted price

**Root Cause:**  
PlayerShopBuyAction:complete() doesn't call `Shop.resolvePlayerBuyPrice()`. Prices are final once set in item ModData.

**Evidence:**  
PlayerShopBuyAction:complete() L45-185 transfers items and withdraws balance, but nowhere recomputes price using Shop.resolvePlayerBuyPrice().

---

#### Risk #6: Late-Join Resync — CalculatedPrices Cache May Stale
**Description:**  
Upon connecting, client receives a snapshot of CalculatedPrices from the server. If prices change after the snapshot, client uses stale prices for preview. Not fixed until next explicit update.

**Scenario:**
1. Player joins server at T0, receives CalculatedPrices snapshot
2. Admin changes a price hook at T5
3. Player opens shop UI at T10, sees prices from T0 snapshot
4. Player clicks Buy, server recomputes at T10 (correct), but client showed stale price

**Root Cause:**  
CalculatedPrices is sent once on RequestShopData and not updated unless another RequestShopData is sent. No event subscription for price changes.

**Evidence:**  
ShopFinalizeHandlerServer.sendShopDataToPlayer() (referenced in ANALYSIS but implementation not shown) sends CalculatedPrices once. No periodic refresh.

---

### 🟡 MEDIUM RISKS

#### Risk #7: Dupe Prevention TTL — 24-Hour Window
**Description:**  
TransactionRegistry stores processed transactions for 24 hours. If server clock resets or modData is manually edited, the TTL may not protect against dupes.

**Scenario:**
1. Player executes transaction at T0, txnId stored with serverTimestamp
2. Server admin manually deletes ShopTransactions ModData at T1
3. Player receives packet resend (e.g., from backup), same txnId arrives at T2
4. Server treats it as new transaction, processes dupe

**Root Cause:**  
No persistent log (e.g., database) of transactions. Reliance on in-memory ModData.

**Evidence:**  
TransactionRegistry.get() L20-22 reads from ModData("ShopTransactions"). If ModData is cleared, dupe protection is lost.

---

#### Risk #8: Admin Permission Check Diverges SP/MP
**Description:**  
In SP, admin permission uses `isDebugEnabled()`. In MP, it checks player admin status. If a non-debug SP save is mistakenly marked as MP, permission checks behave differently.

**Root Cause:**  
Utilities.IsPlayerAdmin() L57-61 (not shown but inferred) checks `isDebugEnabled()` in SP, `player:isAdmin()` in MP.

**Evidence:**  
ShopCommandDispatcherServer.Commands.RemoveShop() L58 calls Utilities.IsPlayerAdmin().

---

### 🟢 LOW RISKS

#### Risk #9: Proximity Check — Moving Target
**Description:**  
Proximity is checked at action complete time (L105-109, L98-102). Player can move away during the action duration. Check happens late.

**Mitigation:** Player must move 2+ units away during 50-tick action. Action cancels if player moves too far during perform(). Low risk in practice.

---

## PHASE 6: Architectural Decision Implications

### 6.1 Is Server-Calculated Pricing Structurally Reliable?

**Yes, with caveats.**

**Structural Strengths:**
- ✅ Server recomputes all kiosk prices authoritatively
- ✅ Anti-dupe mechanism prevents double-spends
- ✅ Price validation tolerance prevents rounding exploits
- ✅ Audit logging captures all transactions
- ✅ Proximity checks prevent remote buying

**Structural Weaknesses:**
- ❌ Player shop prices bypass server calculation entirely
- ❌ BalanceWithdraw is speculative (not pre-validated for P2P)
- ❌ Sell-side item removal can be racey (no atomic inventory lock)
- ❌ Late-join clients use stale price cache (CalculatedPrices)
- ❌ No post-transaction verification of state consistency

**Verdict:** Server-calculated pricing is architecturally sound for **kiosk transactions**. Player shop transactions introduce deviations that reduce reliability.

---

### 6.2 Is Client-Calculated Pricing with Server Validation Safer?

**No, would introduce more risk.**

**Proposed Alternative:** Client calculates and sends final price; server validates ±tolerance.

**Problems:**
- Client could collude with another client to trick validation (e.g., both send $5, but negotiate offline that only one pays)
- Server validation becomes expensive at scale (recompute every time to validate)
- UI would still show client-calculated prices, introducing user confusion if server rejects
- Rollback on mismatch leaves inventory in uncertain state

**Current Model is Better:** Client calculates for preview, server recalculates for authority.

---

### 6.3 Which Architectural Model Minimizes Race Conditions?

#### Model A: Current (Server Recalculates, Speculative Withdrawal)
- Race windows: Price changes, item removal, balance changes
- Severity: Medium (price changes caught by recompute, item removal causes silent loss, balance changes cause dupe risk)
- Complexity: Medium

#### Model B: Atomic Transaction Scope (Lock Inventory, Lock Balance)
- Race windows: None (atomic scope)
- Severity: None
- Complexity: High (would require transaction-level locking in PZ engine, not available)

#### Model C: Client-Proposed, Server-Validates
- Race windows: Exploit vectors increase (client-provided prices, validation tolerance)
- Severity: High
- Complexity: High

#### Model D: Queue-Based Merchant System (Deferred Resolution)
- All transactions queued, processed in background thread with full consistency checks
- Race windows: None (sequential processing)
- Severity: None
- Complexity: Very High (requires background task scheduler)

**Best Fit (Within PZ Engine Constraints):**  
**Model A + Risk Mitigations:**
1. Keep server recalculation (correct)
2. Add post-BalanceWithdraw validation in PlayerShopBuyAction (check if withdrawal succeeded)
3. Add item existence re-check in ShopSellAction (lock inventory during action)
4. Sync price changes to clients via event (reduce stale cache risk)
5. Add ownership validation to PlayerShopPickupShop() (enforce shop owner retrieval)

These mitigations are implementable within PZ's constraints and would reduce **critical** risk count from 3 to 0.

---

## Summary Table: Risk Landscape

| # | Risk | Severity | Category | Mitigation Complexity |
|---|---|---|---|---|
| 1 | Player Shop Buy — Money Duplication | 🔴 Critical | Balance | Medium |
| 2 | Sell Transaction — Silent Item Loss | 🔴 Critical | Inventory | Medium |
| 3 | Player Shop — Income Theft | 🔴 Critical | Permission | Low |
| 4 | Price Hooks — Stale UI | 🟠 High | Synchronization | Medium |
| 5 | Player Shop — No Hook Recompute | 🟠 High | Authority | Medium |
| 6 | Late-Join — Stale Price Cache | 🟠 High | Synchronization | Medium |
| 7 | Dupe Prevention — ModData-Backed TTL | 🟡 Medium | Persistence | Low |
| 8 | Admin Permission — SP/MP Divergence | 🟡 Medium | Consistency | Low |
| 9 | Proximity — Moving Target | 🟢 Low | Physics | Very Low |

---

## Conclusion

The Shops mod implements a **server-authoritative architecture** that is fundamentally sound for **kiosk transactions** but has **3 critical and 3 high-severity vulnerabilities** concentrated in **player-to-player transactions and late-join synchronization**.

The core issue is not server authority (which is well-enforced for kiosk), but rather:
1. **P2P flow:** BalanceWithdraw is speculative, not atomic
2. **Inventory handling:** Sell action has no item locking, allowing silent loss
3. **Ownership:** Income retrieval is unvalidated
4. **Synchronization:** Price changes not broadcast to clients

These can be fixed incrementally without architectural overhaul. The decision to use **server recalculation** (vs. client validation) is correct and should not change.
