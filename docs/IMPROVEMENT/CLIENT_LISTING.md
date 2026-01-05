Short answer: **yes, that is a good direction**, but **only if you constrain _what_ is client-read and _when_ the server reasserts authority**.

Below is the correct way to think about **client-side NPC shop listing & pricing** in Project Zomboid MP, without re-introducing exploits or desync.

---

## 1. Clarify the Goal

You are **not** trying to move authority to the client.

You are trying to:

- Reduce RakNet traffic
- Reduce ModData / broadcast churn
- Avoid per-player per-tick sync
- Keep WIP\_ correctness guarantees

So the correct framing is:

> **Client-side = preview & listing** > **Server-side = execution & settlement**

That distinction must remain strict.

---

## 2. What Is Safe to Read Client-Side

### ✅ Safe (Recommended)

These can live in `shared/` and be read client-side **without network sync**:

- NPC shop item catalog (static list)
- Base prices
- Item availability rules
- Category grouping
- UI metadata (icons, names, descriptions)
- Deterministic modifiers that:

  - depend only on immutable data
  - do NOT use time, RNG, global state, or player inventory

Example:

```lua
NPCShop.Items = {
    ["Base.Axe"] = {
        basePrice = 120,
        category = "Tools",
        stock = -1, -- infinite
    }
}
```

Client can render this **without asking the server**.

This alone removes a **huge amount of sync traffic**.

---

### ❌ Not Safe Client-Side (Must Remain Server Authority)

- Final transaction price
- Stock mutation
- Limited stock counts
- Dynamic discounts
- Player-dependent pricing
- Trait-based modifiers (unless server rechecks)
- Time-based pricing
- Any RNG-based pricing
- Any mod hook not strictly deterministic

---

## 3. The Correct Hybrid Model (This Is the Key)

### Phase A — Client-Side Listing (Zero Network)

Client:

- Loads shop catalog from `shared/`
- Calculates **preview price**
- Builds UI
- No ModData
- No broadcasts
- No server messages

This is where you **win performance**.

---

### Phase B — Server-Side Settlement (Authoritative)

When player clicks **Buy / Sell**:

Client sends **minimal intent**:

```lua
sendClientCommand("Shop", "Buy", {
    shopId = "npc_general_store",
    itemType = "Base.Axe",
    quantity = 1,
})
```

No price.
No totals.
No trust.

---

Server does:

1. Recompute price **from the same shared code**
2. Apply server-only modifiers (if any)
3. Validate balance
4. Mutate balance
5. Spawn item
6. Send **only the result** back to the player

```lua
sendServerCommand(player, "Shop", "BuyResult", {
    success = true,
    finalPrice = 120,
    newBalance = 380,
})
```

No global broadcast.

---

## 4. Why This Fixes Your RakNet Desync

### ORIGINAL\_

- Low traffic
- Unsafe
- Silent divergence

### WIP\_

- Correct
- Too chatty
- Broadcast-heavy

### Hybrid Client Listing Model

- Correct
- Quiet
- Scales to 32+ players

**Key savings:**

| Before                    | After             |
| ------------------------- | ----------------- |
| Price sync per player     | Zero              |
| ModData transmit per view | Zero              |
| Global price broadcasts   | Zero              |
| Only on transaction       | 1 targeted packet |

---

## 5. Determinism Requirement (Non-Negotiable)

If you compute preview prices client-side, you **must guarantee determinism**.

### Allowed in shared pricing code

- Table lookups
- Arithmetic
- Static config
- Player traits (read-only)
- Skill levels (read-only)

### Forbidden in shared pricing code

- `ZombRand`
- `os.time`
- `GameTime`
- mutable globals
- iteration over unordered tables
- mod load order dependent hooks

If you cannot guarantee this, then:

> **Client price = hint only** > **Server price = truth**

And UI must tolerate mismatch.

---

## 6. Handling Mismatch Cleanly (UX Without Network Spam)

When server price ≠ client preview:

- Server returns final price
- Client updates UI silently
- If insufficient funds → show error
- Do **not** resync entire shop
- Do **not** broadcast correction

This keeps the system stable under lag and mod churn.

---

## 7. NPC Shops vs Player Shops (Important Distinction)

### NPC Shops

✔ Perfect fit for client-side listing
✔ Mostly static
✔ Easy to keep deterministic

### Player Shops

⚠ More dangerous
⚠ Item ModData driven
⚠ Ownership & price changes frequently

For player shops:

- Still allow client-side listing
- But **force server re-read item price at execution**
- Never trust cached ModData price

---

## 8. Final Recommendation

**Yes, adopt client-side NPC shop listing & pricing from `shared/`.**

But enforce these rules:

1. Client prices are **preview only**
2. Server recomputes on execution
3. No ModData broadcasts for NPC shops
4. No global sync
5. Targeted responses only
6. Deterministic shared pricing code
7. Snapshot, not incremental, on result

This keeps:

- Your WIP\_ architecture intact
- Your economy secure
- Your RakNet traffic under control

If you want, next we can:

- formalize a **PricingContract.lua**
- define a **determinism validator**
- or design a **ShopExecutionEnvelope** pattern to unify NPC + Player shops cleanly
