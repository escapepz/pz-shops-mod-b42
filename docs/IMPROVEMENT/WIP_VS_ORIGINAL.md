You are encountering a **network-level saturation problem**, not a logical correctness problem.

Based on your audit and the real-server symptoms you described, the desync is caused by **RakNet packet pressure amplified by WIP\_ architectural changes**, not by a violation of server authority or trust. The ORIGINAL* design was *fragile but sparse*; the WIP* design is _correct but chatty_.

Below is a **concrete, actionable mitigation strategy**, ordered by impact and feasibility, tailored to **Project Zomboid MP constraints**.

---

## 1. Identify the Root Cause Precisely

### What changed from ORIGINAL* → WIP*

Your WIP\_ architecture introduced (intentionally and correctly):

- More **explicit state broadcasts**
- More **revision-based sync**
- More **defensive revalidation**
- More **ModData.transmit() usage**
- More **server→client confirmations**

On a **32-player server**, this multiplies into:

```
(players) × (transactions) × (broadcast fan-out)
```

RakNet does not collapse or coalesce Lua-level messages intelligently. Each of the following is a **separate packet path**:

- `ModData.transmit()`
- `sendServerCommand()`
- `syncItemModData()`
- `sendAddItemToContainer()`
- `sendRemoveItemFromContainer()`

Your WIP\_ design likely caused **packet storms**, not logic races.

---

## 2. Principle: Stop Broadcasting by Default

### Hard Rule (MP Survival Rule)

> **Never broadcast state unless at least one client has proven interest.**

ORIGINAL* violated correctness but was cheap.
WIP* restored correctness but violated scalability.

You must now **gate network emission**.

---

## 3. Critical Fix #1 — Replace Broadcast ModData with Scoped Sync

### ❌ Current Pattern (Problematic)

```lua
account.coin -= amount
ModData.transmit("CoinBalance") -- sends to ALL clients
```

On a busy server, this explodes.

### ✅ Correct Pattern

1. **Mutate server state**
2. **Send delta only to the affected player**
3. **Defer global sync**

```lua
account.coin -= amount

sendServerCommand(player, "BS", "BalanceDelta", {
    coin = -amount,
    revision = balanceRevision
})
```

Then:

- Use **global ModData only for**:

  - late join
  - reconnect
  - recovery

- Not for every transaction

**Result:**
You cut packet fan-out from **N players → 1 player**.

---

## 4. Critical Fix #2 — Introduce a Server Tick Aggregator (Debounce Layer)

### Why this is mandatory

RakNet performs poorly when you emit many small packets across frames.

### Implement a 50–100ms aggregation window

Example pattern:

```lua
PendingBalanceUpdates[player] = {
    coinDelta = coinDelta + amount,
    specialDelta = specialDelta + special,
}

-- every 50ms
flushBalanceUpdates()
```

Then emit **one packet per player per tick**, not per action.

This alone typically eliminates:

- “player sees stale balance”
- “ghost desync”
- “UI flicker under load”

---

## 5. Critical Fix #3 — Collapse Revision Broadcasts

Your WIP\_ design likely does this:

- PriceRevision++
- Send revision update
- Send calculated prices
- Send modifier list
- Send UI refresh

### Replace with a single authoritative snapshot

**Server side:**

```lua
sendServerCommand(player, "Shop", "PriceSnapshot", {
    revision = rev,
    prices = calculatedPrices,
})
```

**Client side:**

- Replace incremental handlers
- Ignore intermediate events
- Apply snapshot atomically

This mirrors how vanilla PZ syncs containers.

---

## 6. Critical Fix #4 — Never Broadcast Inside TimedAction.complete()

This is subtle but extremely important.

### Why this is dangerous

Timed actions execute:

- during heavy interaction
- often concurrently
- sometimes in bursts (sell multiple items, buy packs, transfers)

Broadcasting inside `complete()` multiplies packet spikes.

### Correct pattern

Inside `complete()`:

- Mutate server state only
- Queue network intent

Outside (tick or dispatcher):

- Emit network messages once

---

## 7. Player Shop: Reduce Item-Level Sync

Player shops are the worst offenders because they trigger:

- item removal
- item addition
- modData sync
- balance sync
- income sync

### Immediate mitigation

- **Do not sync item modData price on every view**
- Sync only:

  - when price changes
  - when ownership changes

- Cache prices client-side aggressively

If price correctness is critical, prefer:

- **server snapshot on interaction**
- not passive background sync

---

## 8. Diagnostic Rule to Validate the Fix

After changes, the server should satisfy this invariant:

> **One player buying or selling one item produces no more than 2–3 RakNet packets per other player, ideally zero.**

If you still see:

- global ModData spam
- UI desync under load
- late join instability

Then there is still a broadcast leak.

---

## 9. What NOT to Do

- ❌ Do not revert to client-calculated prices
- ❌ Do not disable validation
- ❌ Do not rely on RakNet reliability to “handle it”
- ❌ Do not broadcast “just to be safe”

Your WIP\_ design is architecturally **correct**.
It simply lacks **network discipline**.

---

## Final Recommendation

### Keep WIP\_ architecture, but add:

1. **Scoped sync (targeted server→client)**
2. **Aggregation / debounce layer**
3. **Snapshot-based updates**
4. **Zero broadcasts inside TimedAction.complete()**
5. **Late-join only global ModData**

If you want, next we can:

- map **exact packet paths per transaction**
- produce a **RakNet emission budget**
- or design a **single unified SyncBus** abstraction for Shops

This is the correct phase to address this problem.
