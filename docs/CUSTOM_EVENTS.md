Below is the **correct and B42-safe way to define and use custom events** in **Project Zomboid**, with clear guidance on **when to use a custom event versus when not to**.

---

## 1. What “Custom Event” Means in Project Zomboid

Project Zomboid **does not support registering new engine-level events** (you cannot extend `Events.*` with new event names).

Instead, a _custom event_ in PZ is one of these patterns:

1. **Lua callback dispatcher** (table of listeners)
2. **Command-based event** using `sendClientCommand` / `OnClientCommand`
3. **Timed Action lifecycle hooks** (preferred for gameplay logic)

Choosing the correct pattern is critical in **B42 MP**.

---

## 2. Pattern A — Pure Lua Custom Event (Dispatcher)

Use this for **in-mod communication**, UI logic, or client-side coordination.

### Define a Custom Event Bus

```lua
MyModEvents = MyModEvents or {}
MyModEvents.OnBalanceChanged = MyModEvents.OnBalanceChanged or {}
```

### Register a Listener

```lua
table.insert(MyModEvents.OnBalanceChanged, function(player, newBalance)
    print("Balance updated:", newBalance)
end)
```

### Fire the Event

```lua
for _, callback in ipairs(MyModEvents.OnBalanceChanged) do
    callback(player, balance)
end
```

### When to use

- Client-only logic
- Shared module coordination
- UI refresh triggers

### When **not** to use

- Inventory changes
- World mutations
- Anything authoritative in MP

---

## 3. Pattern B — Client → Server Custom Event (MP-Safe)

This is the **correct replacement** for “custom server events” in B42.

### Client: Trigger the Event

```lua
sendClientCommand(player, "MyMod", "BalanceDeposit", {
    amount = 100,
    itemIDs = itemIDs
})
```

### Server: Handle the Event

```lua
Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "MyMod" then return end
    if command ~= "BalanceDeposit" then return end

    -- validate args
    -- apply server-side logic
end)
```

### Characteristics

- Secure
- Multiplayer-safe
- Explicit validation
- Deterministic execution

**This is the preferred “custom event” mechanism for MP mods.**

---

## 4. Pattern C — Timed Action as a Custom Event

For player-driven actions, a Timed Action is effectively a **structured custom event**.

### Define the Action

```lua
ISMyAction = ISBaseTimedAction:derive("ISMyAction")

function ISMyAction:perform()
    ISBaseTimedAction.perform(self)
end

function ISMyAction:complete()
    -- server-side inventory/world logic
    return true
end
```

### Trigger the Action

```lua
ISTimedActionQueue.add(ISMyAction:new(player))
```

### Why this matters

- Built-in anti-cheat
- Automatic sync
- Correct client/server split

**If your “custom event” affects items or the world, this is usually the right answer.**

---

## 5. Pattern D — Hybrid Event (Recommended Architecture)

This is the **cleanest B42 design**.

```text
UI Event
   ↓
Custom Lua Dispatcher (optional)
   ↓
sendClientCommand
   ↓
Server Validation
   ↓
Timed Action (complete)
   ↓
Server emits Lua dispatcher callbacks
```

This mirrors how **vanilla B42 systems** operate internally.

---

## 6. What You Cannot Do (Important)

❌ You cannot do:

```lua
Events.OnMyCustomEvent.Add(function() end)
```

❌ You cannot sync game state using pure Lua callbacks

❌ You cannot trust client-side custom events in MP

---

## 7. Naming & Organization Best Practices

| Item            | Recommendation                      |
| --------------- | ----------------------------------- |
| Event tables    | `MyModEvents.OnXxx`                 |
| Client commands | Module = mod name                   |
| Command names   | Verb-based (`Deposit`, `BuyItem`)   |
| Files           | `events.lua`, `commands_server.lua` |

---

## 8. Quick Decision Guide

**Ask yourself:**

- UI or notification only? → **Lua dispatcher**
- Needs server authority? → **ClientCommand**
- Player action with duration? → **Timed Action**

---

## 9. Minimal MP-Safe Custom Event Template

```lua
-- client
sendClientCommand(player, "MyMod", "DoThing", {})

-- server
Events.OnClientCommand.Add(function(module, command, player, args)
    if module == "MyMod" and command == "DoThing" then
        -- authoritative logic
    end
end)
```

---
