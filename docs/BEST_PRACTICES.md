Below is a **concise but rigorous set of Lua development best practices**, with emphasis on **Project Zomboid (B42.x) modding** and multiplayer-safe design. The guidance is structured from general Lua fundamentals down to engine-specific constraints you are already encountering.

---

## 1. Core Lua Best Practices (Language-Level)

### 1.1 Explicit Scope Control

Always use `local` unless a symbol is intentionally global.

```lua
local function calculatePrice(base, multiplier)
    return base * multiplier
end
```

**Rationale**

- Prevents namespace pollution
- Avoids silent overrides between mods
- Improves GC performance

---

### 1.2 Avoid Implicit Globals (Hard Rule)

Lua will happily create globals on typo.

```lua
price = 10   -- BAD (global)
local price = 10 -- GOOD
```

**Recommendation**

- Treat _any_ unintended global as a bug
- Prefix intentional globals with your mod ID only when unavoidable

---

### 1.3 Defensive Nil Checks

Never assume external objects exist.

```lua
if not item or not item:getContainer() then
    return
end
```

Especially critical when:

- Reading `ModData`
- Accessing `ItemTag`, `Type`, or registry-backed identifiers
- Running in MP where order-of-load differs

---

## 2. File & Module Organization (Mod-Scale)

### 2.1 One Responsibility per File

Each Lua file should answer **one question**.

**Good**

```
BalanceServer.lua     → account math
PlayerShopContext.lua → context menu logic
ShopAudit.lua         → logging & audit
```

**Bad**

```
ShopUtils.lua → 900 lines of unrelated helpers
```

---

### 2.2 Deterministic Load Order

Respect Project Zomboid’s Lua load phases:

```
media/
 ├─ registries.lua        (ALWAYS first)
 ├─ lua/
 │   ├─ shared/
 │   ├─ client/
 │   └─ server/
```

Rules:

- **Registries go ONLY in `media/registries.lua`**
- Never reference registry-backed IDs before that file loads
- Do not rely on file name ordering inside folders

---

## 3. Multiplayer-Safe Design (Critical for B42)

### 3.1 Client ≠ Authority

Clients must **never**:

- Create inventory items
- Remove inventory items
- Modify world objects
- Change authoritative balances

These belong to:

- `TimedAction:complete()`
- `Events.OnClientCommand` handlers (server-side)

---

### 3.2 Timed Actions: Mandatory Split

Always separate:

| Method       | Side   | Purpose                   |
| ------------ | ------ | ------------------------- |
| `perform()`  | Client | animation, sound, UI      |
| `complete()` | Server | inventory, ModData, world |

**Never mutate items in `perform()`**

---

### 3.3 Always Sync After Mutation

Any server-side change must be transmitted:

```lua
sendAddItemToContainer(inv, item)
sendRemoveItemFromContainer(inv, item)
syncItemModData(item)
```

Failure to do so results in:

- Ghost items
- Rollbacks
- “Stale inventory” bugs you already observed

---

## 4. Registries & Identifiers (B42+)

### 4.1 Never Hardcode Unregistered IDs

All of the following **must be registered** before use:

- `ItemTag`
- `ItemType`
- `WeaponCategory`
- `MoodleType`
- etc.

Failure mode:

- `containsTag()` crashes
- `Type mismatch: string vs ItemTag`
- Context menus silently missing

---

### 4.2 Treat Registry IDs as Immutable

Once published:

- Never rename
- Never delete
- Only extend behavior

Breaking registry IDs causes save corruption.

---

## 5. ModData Discipline

### 5.1 Server Owns ModData

Rules:

- Server writes
- Client reads (unless explicitly synced)

```lua
local data = item:getModData()
data.owner = username
syncItemModData(item)
```

---

### 5.2 Never Trust Client ModData

Client ModData is:

- Editable
- Replayable
- Forgeable

Always validate on server.

---

## 6. Hooking & Compatibility Strategy

### 6.1 Avoid Method Replacement

Do **not** overwrite vanilla functions unless unavoidable.

**Bad**

```lua
function ISInventoryTransferAction.start(...)
```

**Preferred**

- Event listeners
- Context menu injection
- Guard checks (`isValid`, permission gates)

Reason:

- Last-loaded mod wins
- Breaks SafeHouse, admin mods, UI mods

---

### 6.2 If You Must Patch

Then:

- Wrap original
- Preserve return values
- Fail closed, not open

```lua
local _old = ISInventoryTransferAction.isValid
function ISInventoryTransferAction:isValid()
    if not checkPermission(self) then
        return false
    end
    return _old(self)
end
```

---

## 7. Logging & Diagnostics

### 7.1 No `print()` in Production

Use:

- `DebugLog.General()` (client)
- File-based logging (server)

Ensure logs are:

- Namespaced
- Actionable
- Removable for release

---

### 7.2 Log State, Not Emotions

**Bad**

```
"Something went wrong"
```

**Good**

```
"[Shop][TransferDenied] user=Bob container=PlayerShop owner=Alice"
```

---

## 8. Performance & Stability

### 8.1 Avoid Per-Tick Logic

Never use:

- `Events.OnTick`
- UI redraw logic with heavy computation

Cache results and update only on:

- Selection change
- Page change
- Explicit user action

---

### 8.2 UI: Virtualize Large Lists

For item lists:

- Paginate
- Filter server-side where possible
- Never render thousands of rows at once

---

## 9. Final Golden Rules

1. **Server is truth**
2. **Registries first, scripts later**
3. **No item mutation on client**
4. **Sync everything you change**
5. **One file, one responsibility**
6. **Compatibility beats cleverness**

---
