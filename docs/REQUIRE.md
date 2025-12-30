Below is a **concise, authoritative guide** for using `require()` correctly in **Project Zomboid (B42 / Multiplayer)**, aligned with how the engine actually loads Lua.

This is written as a **ruleset you can apply mechanically** when designing or reviewing a mod.

---

# Project Zomboid — `require()` Usage Guide (B42 / MP)

## Core Facts (Non-Negotiable)

1. **Project Zomboid loads all `.lua` files automatically**
2. **`require()` does NOT load files**
3. **`require()` only controls execution order and dependencies**
4. **File scope is decided by folder (`client / server / shared`), not by `require()`**
5. **Misusing `require()` causes silent MP bugs, not crashes**

---

## What `require()` Actually Does in PZ

In Project Zomboid, `require()` is used to:

- Force **a file’s side effects to execute before another file**
- Guarantee **globals, registries, hooks, or patches exist**
- Prevent **dependency race conditions**

It does **not**:

- Make a file “load”
- Change scope
- Change MP sync behavior

---

## When You MUST Use `require()`

Use `require()` **only** when **at least one** of the following is true.

### 1. The file has side effects

Examples:

- Registers events
- Mutates global tables
- Installs patches
- Registers items, shops, currencies

```lua
require "nshopsb42/core/ShopRegistry"
require "nshopsb42/sales/ShopSellRegistry"
```

---

### 2. The file defines globals relied upon elsewhere

```lua
require "nshopsb42/core/Shop" -- defines Shop, Shop.Tab, constants
```

If another file does:

```lua
Shop.Tab.Buy
```

Then **Shop must be required first**.

---

### 3. The file installs hooks or patches

```lua
require "patches/ISTransferActionPatch"
```

Hook files must run:

- Once
- After all dependencies
- Before gameplay starts

Never leave hook timing to implicit load order.

---

### 4. The file performs initialization or finalization

```lua
require "ShopFinalizeHandlerServer"
ShopFinalizeHandler.finalizeNow()
```

Finalizers **must be last**.

---

## When You SHOULD NOT Use `require()`

Do **not** use `require()` for files that:

- Only define functions
- Only define constants
- Only define data tables
- Have no execution side effects

### Example (NO require needed)

```lua
-- Constants.lua
MyMod.MAX_PRICE = 500
```

This file can load implicitly.

---

## Init Files: Correct Pattern

### Purpose

Init files:

- Enforce order
- Coordinate side effects
- Execute once

### Server Init (example)

```lua
-- server/nshopsb42/ShopInitServer.lua
if not isServer() then return end

require "nshopsb42/core/Shop"
require "nshopsb42/core/ShopRegistry"

require "nshopsb42/sales/ShopSellRegistry"
require "nshopsb42/events/ShopEvents"

require "nshopsb42/sales/ShopSellInit"

require "patches/ISTransferActionPatch"

ShopFinalizeHandler.finalizeNow()
```

This is **correct usage**.

---

## Require Path Rules (Critical)

`require()` paths are:

- Relative to `media/lua/`
- Without `.lua`
- Case-sensitive on Linux servers

### Correct

```lua
require "nshopsb42/core/Shop"
```

### Incorrect

```lua
require "server/nshopsb42/Shop"
require "Shop.lua"
require "media/lua/nshopsb42/Shop"
```

---

## Client / Server / Shared Interaction Rules

### Allowed

| File Location | Can require    |
| ------------- | -------------- |
| client        | shared, client |
| server        | shared, server |
| shared        | shared only    |

### Forbidden (will silently break)

- `client` requiring `server`
- UI files calling server-only APIs
- server files depending on client state

---

## Guarding Init Files (MANDATORY)

Every Init-style file **must guard its execution**.

```lua
if not isServer() then return end
```

or

```lua
if not isClient() then return end
```

Files load everywhere; logic must not.

---

## Avoiding Double Execution

Never rely on:

```lua
if alreadyInitialized then return end
```

Instead:

- Centralize initialization in **one Init file**
- Require everything from there
- Call finalization once

---

## Common Anti-Patterns (Do Not Do This)

### ❌ Requiring everything everywhere

```lua
require "A"
require "B"
require "C"
```

This causes:

- Order ambiguity
- Double execution assumptions
- Hard-to-debug MP issues

---

### ❌ Using require as a loader

```lua
-- WRONG mental model
require "MyMod"
```

PZ already loaded it.

---

### ❌ Relying on implicit load order for hooks

Hooks must be explicitly required.

---

## Safe Mental Model (Memorize This)

> **Implicit load loads definitions** > **`require()` enforces side effects**

If a file:

- Must run **before** something → require it
- Must run **after** everything → require it last
- Only defines helpers → do not require it

---

## Final Checklist

- [ ] Only Init files use `require()` heavily
- [ ] Hooks are explicitly required
- [ ] Registries are required before use
- [ ] Finalizers run once, last
- [ ] No client ↔ server cross-requires
- [ ] Paths are namespaced and correct

---
