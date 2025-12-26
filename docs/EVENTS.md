Below is a **concise, B42.13-accurate guide** for defining and selecting the **correct Lua events** when developing a **Project Zomboid** mod. The focus is on **what event to use, where it runs (client/server/shared), and common B42 pitfalls**.

---

## 1. Core Principle in B42

In **Build 42**, event correctness is primarily about **execution context**:

- **Client**: UI, context menus, animations, sounds.
- **Server**: Inventory, world state, authority, anti-cheat.
- **Shared**: Definitions and logic that must serialize correctly (e.g., Timed Actions).

Using the _right event in the wrong context_ is the most common cause of silent rollbacks and desyncs.

---

## 2. Event Categories and Correct Usage

### A. Game Lifecycle Events

Use these for initialization and data registration.

| Event                        | Context     | Purpose                                                       |
| ---------------------------- | ----------- | ------------------------------------------------------------- |
| `Events.OnGameBoot.Add`      | Shared      | Earliest hook. Safe for constants, registries, static tables. |
| `Events.OnGameStart.Add`     | Client / SP | Player session start. UI setup, client caches.                |
| `Events.OnServerStarted.Add` | Server      | Server-only initialization, ModData setup.                    |

**Correct example**

```lua
Events.OnGameBoot.Add(function()
    MyMod = MyMod or {}
end)
```

---

### B. Player & World Tick Events

Use sparingly; they run frequently.

| Event                       | Context | Purpose                                     |
| --------------------------- | ------- | ------------------------------------------- |
| `Events.OnPlayerUpdate.Add` | Client  | Per-player client logic (UI hints, checks). |
| `Events.OnTick.Add`         | Shared  | Global ticking logic (avoid heavy work).    |

**Guideline**: Never mutate inventory or world objects here in MP.

---

### C. UI & Context Menu Events

Client-only by design.

| Event                                         | Context | Purpose                        |
| --------------------------------------------- | ------- | ------------------------------ |
| `Events.OnFillInventoryObjectContextMenu.Add` | Client  | Right-click inventory actions. |
| `Events.OnFillWorldObjectContextMenu.Add`     | Client  | World object interactions.     |

**Correct pattern**

```lua
Events.OnFillInventoryObjectContextMenu.Add(function(player, context, items)
    context:addOption("My Action", items, function()
        sendClientCommand(player, "MyMod", "DoAction", {})
    end)
end)
```

---

### D. Client → Server Authority Events

Mandatory for MP-safe state changes.

| Event                        | Context | Purpose                            |
| ---------------------------- | ------- | ---------------------------------- |
| `Events.OnClientCommand.Add` | Server  | Receive validated client requests. |

**Correct server handler**

```lua
Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "MyMod" then return end
    if command == "DoAction" then
        -- server-side inventory or world change
    end
end)
```

---

### E. Timed Action Events (Critical in B42)

Timed Actions are **the preferred and safest mechanism** for item/world manipulation.

| Phase           | Runs On         | Allowed                    |
| --------------- | --------------- | -------------------------- |
| `perform()`     | Client          | Animation, sound, UI only  |
| `complete()`    | Server          | Inventory & world mutation |
| `serverStart()` | Server          | Long actions setup         |
| `animEvent()`   | Client + Server | Periodic logic             |

**Rule**:

> If inventory changes outside `complete()` → expect rollback.

---

## 3. Registry vs Event (Common Confusion)

Some things **are not events anymore** in B42.

| Task                | Correct Mechanism                |
| ------------------- | -------------------------------- |
| Item tags           | `ItemTag.register()`             |
| Item types          | `ItemType.register()`            |
| Professions, traits | `CharacterProfession.register()` |

These **must** be in:

```
media/registries.lua
```

Not in any event.

---

## 4. Common B42 Mistakes (and Fixes)

**❌ Using inventory logic in client events**

- Fix: Move logic to `OnClientCommand` or Timed Action `complete()`.

**❌ Using `OnGameStart` for server data**

- Fix: Use `OnServerStarted`.

**❌ Creating items directly on client**

- Fix: Create on server and sync.

**❌ Heavy logic in `OnTick`**

- Fix: Use explicit actions or commands.

---

## 5. Decision Cheat-Sheet

**Ask yourself:**

1. Does this change inventory/world state? → **Server / Timed Action**
2. Is this UI or player interaction? → **Client event**
3. Is this a definition (ID, tag, type)? → **Registry**
4. Does this require anti-cheat safety? → **OnClientCommand**

---

## 6. Recommended Minimal Pattern (B42-Safe)

1. **Client**

   - Context menu event
   - `sendClientCommand(...)`

2. **Server**

   - `Events.OnClientCommand`
   - Validate
   - Apply changes
   - Sync

3. **Timed Actions**

   - For anything player-driven and long-running

---
