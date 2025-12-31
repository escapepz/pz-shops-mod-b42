Yes. For **B42 multiplayer**, the rule is strict:

> **Any Timed Action that must execute `complete()` on the server MUST live in the `shared` folder.**

Below is the **authoritative breakdown**, including **when guards are required and when they are harmful**.

---

## 1. Folder Placement Rule (Non-Negotiable)

### Correct Locations

| Folder             | Purpose                                  |
| ------------------ | ---------------------------------------- |
| `media/lua/shared` | **Timed Actions (client + server)**      |
| `media/lua/client` | UI, cursors, context menus               |
| `media/lua/server` | Event handlers, OnClientCommand, systems |

### Consequence of Wrong Placement

If a timed action is in `client`:

- `perform()` runs
- server **never loads the class**
- NetAction cannot be reconstructed
- action becomes **bugged**
- `complete()` never executes
- no error, no warning

This is by design.

---

## 2. Guard Rules for Timed Actions (Very Important)

### ❌ DO NOT guard the file itself

**This is wrong and will break MP:**

```lua
-- ❌ NEVER DO THIS
if not isServer() then return end
```

or:

```lua
if isClient() then return end
```

Why:

- The server must load the class definition
- The client must load the class definition
- Guards at file scope prevent reconstruction

---

## 3. Where Guards ARE Allowed (Correct Usage)

Guards are allowed **inside methods**, not at file scope.

### Correct Pattern

```lua
function ISAddPlayerShopAction:perform()
    if isServer() then return end -- optional safety
    -- animations / sounds / UI
    ISBaseTimedAction.perform(self)
end
```

```lua
function ISAddPlayerShopAction:complete()
    if not isServer() then return true end
    -- server-only logic
    return true
end
```

This is **safe and recommended**.

---

## 4. Mandatory Execution Contract (Burn This In)

| Method       | Runs On | May Mutate World |
| ------------ | ------- | ---------------- |
| `new()`      | both    | ❌ no            |
| `isValid()`  | both    | ❌ no            |
| `perform()`  | client  | ❌ no            |
| `complete()` | server  | ✅ yes           |

Singleplayer:

- `perform()` → `complete()` both run locally

Multiplayer:

- `perform()` client
- `complete()` server

---

## 5. Common Guard Mistakes That Cause “Bugged Action”

### ❌ Guarding `new()`

```lua
function ISAddPlayerShopAction:new(...)
    if not isServer() then return end -- ❌ fatal
end
```

Result:

- Server reconstructs `nil`
- Action silently fails

---

### ❌ Guarding `complete()` Incorrectly

```lua
function ISAddPlayerShopAction:complete()
    if not isServer() then return end -- ❌ returns nil
end
```

Must always return `true` or `false`.

Correct:

```lua
function ISAddPlayerShopAction:complete()
    if not isServer() then return true end
    -- logic
    return true
end
```

---

## 6. Should You Guard at All?

### Minimal Recommendation (Best Practice)

- **Do not guard `new()`**
- **Do not guard `isValid()`**
- **Optionally guard `perform()`**
- **Always guard `complete()`**

This yields:

- Maximum safety
- No desync
- No silent invalidation

---

## 7. Reference Minimal Safe Template

```lua
-- media/lua/shared/ISAddPlayerShopAction.lua

ISAddPlayerShopAction = ISBaseTimedAction:derive("ISAddPlayerShopAction")

function ISAddPlayerShopAction:new(player, square, sprite)
    local o = ISBaseTimedAction.new(self, player)
    o.square = square
    o.sprite = sprite
    o.maxTime = o:getDuration()
    return o
end

function ISAddPlayerShopAction:isValid()
    return self.square ~= nil
end

function ISAddPlayerShopAction:getDuration()
    return self.character:isTimedActionInstant() and 1 or 200
end

function ISAddPlayerShopAction:perform()
    ISBaseTimedAction.perform(self)
end

function ISAddPlayerShopAction:complete()
    if not isServer() then return true end
    -- server object creation
    return true
end
```

---

## 8. Final Answer (Short Version)

- **Yes**, all timed actions that touch inventory or world **must be in `shared`**
- **No**, never guard the file itself
- **Yes**, guard logic inside `perform()` and `complete()`
- **Always** return `true` from `complete()`
