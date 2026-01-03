Your analysis is correct, and the exploit vector is real. The root cause is precisely what you identified: **a server-side trust fallback that consumes client-supplied economic data under failure conditions**. In multiplayer economic systems, that is a hard security violation.

Below is a structured recommendation and a clear decision.

---

## Executive Recommendation

**Adopt a hybrid of Option 1 (server-authoritative fallback) and Option 2 (hard reject), with Option 3 explicitly rejected.**

More precisely:

> **The server must never consume `entry.price` under any circumstance.**
> If the server cannot deterministically compute a sell price, it must either:
>
> 1. **Fallback to a server-authoritative base price only**, _or_
> 2. **Reject the transaction outright**, depending on the failure class.

---

## Why This Is the Correct Choice

### Why Option 3 Is Fundamentally Unsafe (Do NOT Use)

> **“Validate client price against base+tolerance” is still trusting the client.**

This approach fails under adversarial conditions:

- A malicious client can:

  - Inflate base price via stacked modifiers
  - Exploit rounding, overflow, or tolerance windows

- Validation logic becomes complex and brittle
- You still accept **client-originated economic intent**

In authoritative MP design, **the client never proposes prices**. Period.

---

## Correct Trust Model (Authoritative Economics)

| Layer  | Responsibility            | Trust             |
| ------ | ------------------------- | ----------------- |
| Client | UI, intent, selection     | ❌ Untrusted      |
| Server | Price resolution, payment | ✅ Sole authority |

Any deviation from this guarantees exploits—this one just happens to be obvious.

---

## Recommended Fix Design (Precise)

### Step 1: Classify Failure Types

There are **two distinct failure classes**, and they must be handled differently.

#### A. Recoverable Failure (Hooks unavailable, instance missing)

Examples:

- Price hooks require item instance
- Modifier registry not initialized yet

➡ **Fallback to base price (server-side only)**

#### B. Logic Failure (Impossible to price safely)

Examples:

- No base price exists
- Item not registered
- Sell entry malformed

➡ **Reject transaction**

---

### Step 2: Replace the Unsafe Pattern

#### ❌ Current (Exploit-able)

```lua
local itemPrice = finalPrice or entry.price
```

#### ✅ Correct (Authoritative)

```lua
local finalPrice = Shop.resolvePlayerSellPrice(player, item, shopId)

if finalPrice ~= nil then
    itemPrice = finalPrice
else
    local def = Shop.PlayerSell[itemId]
    if not def or not def.basePrice then
        SharedLogger.log("Shops",
            "[SECURITY] Reject sell: unpriceable item " .. tostring(itemId))
        return false
    end

    itemPrice = def.basePrice
    SharedLogger.log("Shops",
        "[SECURITY] Price fallback to base for " .. itemId)
end
```

**Key properties:**

- `entry.price` is never read
- All pricing is server-derived
- Failure paths are explicit and auditable

---

## Why This Will Not Break Legitimate Gameplay

You already identified the core reason:

> Hooks that _require_ item instances cannot safely run server-side in some flows.

That is not a justification to trust the client.
It is a signal that **base price is the only safe fallback**.

If a modder writes a hook that cannot be evaluated server-side, the correct outcome is:

- Reduced fidelity pricing (base price)
- Not compromised security

---

## Additional Mandatory Actions (You Should Do These)

### 1. Apply the Fix Everywhere

Search for **any usage of client-provided price fields**, including:

- `PlayerShopSellAction`
- Any future admin or kiosk flows

If a price comes from the client, it must be ignored.

---

### 2. Delete or Wire `ShopTransactionValidationServer.lua`

You already noticed the red flag:

> **Exists but never called**

This file currently provides **false confidence**.

Either:

- Integrate it into the sell pipeline **as a hard gate**, or
- Remove it entirely

Dead security code is worse than no security code.

---

### 3. Add a One-Line Invariant Comment (Important)

This prevents future regressions.

```lua
-- SECURITY INVARIANT:
-- Server must never consume client-provided prices under any circumstance.
```

This matters more than it looks.

---

## Final Decision

**Choose Option 1 + Option 2 (hybrid):**

- **Base-price fallback for recoverable failures**
- **Hard reject for unpriceable transactions**
- **Zero trust in client prices**

This aligns with:

- Project Zomboid's MP anti-cheat architecture
- Timed-action server authority model
- Secure economic system design
