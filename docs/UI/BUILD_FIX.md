I have reviewed **DIFFERENCES_IMPLEMENTATION_VS_DOCS.md** and the conclusion is correct. Your current **Shop / Player Shop placement flow violates the B42 building contract** and will remain fragile in MP until it is restructured.

Below is a **precise technical assessment** followed by a **corrective architecture** you can apply without ambiguity.

---

## Executive Verdict

**Your drag cursor usage is correct.
Your object creation location is not.**

You are currently **creating world objects from the cursor / click path**, which is explicitly disallowed in **B42 MP**. This works in SP only because authority is local.

The document’s findings are accurate .

---

## What Is Correct Today

### ✔ Correct

- Custom drag cursor (`ShopSpriteCursorUI`)
- Client-side placement preview
- Use of sprite-driven construction
- Attempted server involvement for Admin Shop

### ❌ Incorrect (Critical)

- Object creation during cursor placement
- No `ISBuildAction` / timed action
- Inventory mutation detached from object creation
- Missing `transmitCompleteItemToClients()`
- Client-originated object lifecycle in MP

---

## Why This Breaks in MP (B42-Specific)

In **B42**, the engine enforces a **strict authority split**:

| Layer         | Allowed                |
| ------------- | ---------------------- |
| Cursor / Drag | Visual only            |
| Click handler | Queue action only      |
| `perform()`   | Animation only         |
| `complete()`  | **All state mutation** |

Your current implementation bypasses **both**:

- the **Timed Action serialization system**
- the **server-side anti-cheat guardrails**

This is why you observe:

- silent rollbacks
- inventory reappearing
- objects missing after relog
- duplication risk under lag

---

## Correct Architecture (Authoritative)

### 1. Cursor: Preview Only (Keep This)

```lua
getCell():setDrag(cursor, playerNum)
```

**Cursor must never:**

- create IsoObjects
- consume inventory
- send follow-up cleanup commands

---

### 2. Click → Queue Build Action (Missing Today)

On valid placement:

```lua
ISTimedActionQueue.add(
    ISAddPlayerShopAction:new(player, square, sprite, north)
)
```

This is the **only** thing a click should do.

---

### 3. Timed Action (Shared)

```lua
ISAddPlayerShopAction = ISBuildAction:derive("ISAddPlayerShopAction")
```

#### `perform()` (Client)

- animation
- sound
- progress bar

#### `complete()` (Server)

```lua
local shop = IsoThumpable.new(square, sprite, north)
square:AddTileObject(shop)
shop:transmitCompleteItemToClients()

player:getInventory():Remove(item)
sendRemoveItemFromContainer(player:getInventory(), item)
```

This aligns with the official B42 execution model.

---

## Why `sendClientCommand` Is Not Enough

Your Admin Shop path is _closer_, but still wrong.

**Problem:**

- Commands bypass timed action serialization
- No duration
- No rollback safety
- No animation authority
- No unified validation point

**Rule of thumb:**

> If a player places something in the world, it must go through a timed action.

Admin ≠ exception.

---

## Mandatory Fix List (No Optional Items)

1. **Delete object creation from `ShopSpriteCursor`**
2. **Introduce `ISAddShopAction` / `ISAddPlayerShopAction`**
3. **Move inventory removal into `complete()`**
4. **Call `transmitCompleteItemToClients()`**
5. **Use `AddTileObject()`, not `AddSpecialObject()`**
6. **Validate placement twice**

   - cursor (`isValid`)
   - server (`complete()`)

---

## Final Mental Model (Keep This)

> Cursor shows intent
> Action grants permission
> Server makes reality

Anything else will fail in MP—eventually.

---
