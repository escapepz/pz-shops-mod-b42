Below is a **practical, step-by-step migration guide** to fully namespace your mod’s Lua files so **no vanilla files are overridden and no other mod can accidentally override yours**, while keeping B42 MP behavior correct.

This guide assumes **no intentional vanilla overrides**.

---

# Project Zomboid — Safe Lua Namespacing Guide (B42 / MP-Ready)

## Goal

- Prevent accidental file-path overrides
- Keep load order deterministic
- Preserve multiplayer correctness
- Make your mod future-proof

---

## 1. Target Folder Structure (Final State)

Use a **single unique root folder** for your mod name.

```
media/
└── lua/
    ├── client/
    │   └── MyMod/
    │       ├── Init.lua
    │       ├── UI/
    │       │   └── ShopUI.lua
    │       └── ClientHooks.lua
    │
    ├── server/
    │   └── MyMod/
    │       ├── Init.lua
    │       ├── Commands.lua
    │       └── Persistence.lua
    │
    └── shared/
        └── MyMod/
            ├── Init.lua
            ├── Constants.lua
            ├── Data.lua
            └── Net.lua
```

**Rules**

- `MyMod` must be globally unique (Workshop ID or mod ID preferred)
- Never place files directly under `client/`, `server/`, or `shared/`
- Subfolders are unlimited and safe

---

## 2. Create a Single Global Namespace

**Every mod must own exactly one global table.**

### shared/MyMod/Init.lua

```lua
MyMod = MyMod or {}
MyMod.VERSION = "1.0.0"
```

**Never**

```lua
Shop = {}
Balance = {}
Utils = {}
```

These names **will collide** with other mods.

---

## 3. Use Init Files as Explicit Entry Points

Although all Lua files load automatically, **Init.lua files give you control over load order**.

### shared/MyMod/Init.lua

```lua
require "MyMod/Constants"
require "MyMod/Data"
require "MyMod/Net"
```

### client/MyMod/Init.lua

```lua
require "MyMod/UI/ShopUI"
require "MyMod/ClientHooks"
```

### server/MyMod/Init.lua

```lua
require "MyMod/Commands"
require "MyMod/Persistence"
```

This guarantees:

- Predictable initialization
- No dependency races
- Clean startup

---

## 4. Correct `require()` Paths (Critical)

Lua `require()` paths are **relative to `media/lua/`**, not scope folders.

### Correct

```lua
require "MyMod/Constants"
require "MyMod/UI/ShopUI"
```

### Incorrect

```lua
require "client.MyMod/ShopUI"
require "shared.MyMod.Constants"
```

Scope is determined by **file location**, not `require()`.

---

## 5. Move Existing Files (Migration Steps)

### Step-by-step

1. Create `client/MyMod/`, `server/MyMod/`, `shared/MyMod/`
2. Move files **without renaming logic**
3. Update all `require()` paths
4. Replace globals with `MyMod.*`
5. Add Init.lua files
6. Test in **SP first**, then MP

---

## 6. Refactor Globals into the Namespace

### Before (unsafe)

```lua
BalanceServer = {}
function BalanceServer.addCoin(player, amt)
```

### After (safe)

```lua
MyMod.BalanceServer = {}

function MyMod.BalanceServer.addCoin(player, amt)
```

This prevents:

- Symbol collision
- Silent replacement
- Load-order bugs

---

## 7. Avoid Function Replacement (Use Wrapping)

### ❌ Dangerous

```lua
function ISInventoryTransferAction:start()
    -- replaced
end
```

### ✅ Safe

```lua
local _oldStart = ISInventoryTransferAction.start

function ISInventoryTransferAction:start()
    if MyMod.shouldBlock(self) then
        return
    end
    return _oldStart(self)
end
```

Always:

- Save the original
- Call it unless explicitly blocked

---

## 8. Client / Server / Shared Rules (B42 MP)

| Folder | Allowed Logic                    |
| ------ | -------------------------------- |
| client | UI, animations, input, visuals   |
| server | Inventory, accounts, persistence |
| shared | Constants, validators, protocol  |

**Never**

- Modify inventory on client
- Trust client-only data
- Call server-only APIs from client files

---

## 9. What This Protects You From

✅ Accidental file overrides
✅ Other mods replacing your Lua files
✅ Vanilla adding new files later
✅ Workshop mod collisions
✅ Load-order chaos

---

## 10. What This Does NOT Protect You From

⚠ Other mods replacing the same vanilla functions
⚠ Mods writing to the same vanilla globals
⚠ Admins forcing incompatible load order

Those require **hook discipline**, not folder structure.

---

## Final Checklist

- [ ] All files under `MyMod/`
- [ ] One global table only
- [ ] Init.lua per scope
- [ ] No vanilla file paths reused
- [ ] No global pollution
- [ ] No direct vanilla replacement unless intentional

---

## Bottom Line

Yes—**this structure is correct, safe, and officially supported**.

It is the **only reliable way** to ensure:

- Your mod never overrides vanilla unintentionally
- Other mods cannot override yours accidentally
- Your code survives B42+ multiplayer changes
