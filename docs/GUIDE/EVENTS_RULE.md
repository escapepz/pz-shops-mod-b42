Below is a **formal rule set** you can adopt for **event listener design in Project Zomboid mods**, specifically tuned for **B42 MP-safe architecture** and suitable for complex systems such as your Shops module.

---

# Event Listener Rules for Project Zomboid Mods

## Rule 1 — One Engine Listener per Event per Mod (Mandatory)

**A mod must register at most one listener per engine event.**

**Correct**

```lua
Events.OnServerCommand.Add(ModDispatcher.onServerCommand)
```

**Incorrect**

```lua
Events.OnServerCommand.Add(fnA)
Events.OnServerCommand.Add(fnB)
Events.OnServerCommand.Add(fnC)
```

**Rationale**

- Prevents duplicated execution
- Guarantees deterministic ordering
- Simplifies debugging and hot reload safety

---

## Rule 2 — Dispatch Internally, Never Branch Externally

All engine listeners must act only as **dispatchers**.

```lua
local ServerCommands = {}

function ServerCommands.SyncBuyPrices(args) ... end
function ServerCommands.SyncSellRules(args) ... end

function ModDispatcher.onServerCommand(module, command, args)
    if module ~= "nshopsb42" then return end
    local handler = ServerCommands[command]
    if handler then
        handler(args)
    end
end
```

**Rationale**

- Constant-time lookup
- Eliminates deep `if/elseif` chains
- Mirrors vanilla `OnClientCommand` pattern

---

## Rule 3 — Explicit Side Gating Is Required

Every listener file must hard-gate its execution side.

```lua
if not isClient() then return end
```

or

```lua
if not isServer() then return end
```

use Ultilities for better function gate

**Never rely on “this event won’t fire here.”**

**Rationale**

- SP executes both paths
- Prevents ghost execution and double application

---

## Rule 4 — Listener Registration Must Be Idempotent

Listeners must be safe to load **exactly once**.

```lua
if ModDispatcher._registered then return end
ModDispatcher._registered = true

Events.OnServerCommand.Add(ModDispatcher.onServerCommand)
```

**Rationale**

- Prevents duplicate callbacks during:

  - SP reload
  - soft MP reconnect
  - dev hot-load

---

## Rule 5 — No Heavy Logic Inside Engine Callback

Engine callbacks must:

- validate
- dispatch
- exit

**Forbidden inside listeners**

- loops over world objects
- UI rebuilds
- price recomputation
- inventory mutation

Delegate immediately.

**Rationale**

- Event handlers execute on the main thread
- Keeps frame time predictable

---

## Rule 6 — Command Handlers Must Be Pure and Targeted

A handler must:

- process exactly **one command**
- mutate only its **own subsystem**
- never broadcast or recurse

```lua
function ServerCommands.SyncBuyPrices(args)
    ShopSyncClient.applyBuyPrices(args)
end
```

**Rationale**

- Prevents cascade side effects
- Enables precise regression testing

---

## Rule 7 — No Cross-Event Coupling

An event handler **must not rely on another event having fired**.

❌ “OnServerCommand assumes OnTick already updated cache”
❌ “OnPlayerUpdate must fire before OnServerCommand”

**Rationale**

- Event ordering is not guaranteed
- MP latency breaks assumptions

---

## Rule 8 — All Network Commands Must Be Versioned

Every network command payload must carry a revision or version.

```lua
args = {
    revision = Shop.BuyPriceRevision,
    prices = ...
}
```

Client must ignore stale revisions.

**Rationale**

- Prevents out-of-order desync
- Required for reconnect and late join

---

## Rule 9 — Log at Dispatcher Boundary Only

Logging rules:

✔ log **once** at dispatcher entry
❌ never log inside every handler by default

```lua
SharedLogger.trace("Shops", "OnServerCommand", module, command)
or SharedLogger.log
```

**Rationale**

- Prevents log spam
- Preserves signal during MP debugging

---

## Rule 10 — Symmetry Between Server and Client

For every:

- `OnClientCommand` on server
- `OnServerCommand` on client

There must be:

- identical module name
- mirrored command table
- explicit directionality

**Rationale**

- Makes protocol auditable
- Enables automated behavioral diffs

---

## Reference Architecture (Canonical)

```lua
-- client/ShopCommandDispatcher.lua
if not isClient() then return end

local Dispatcher = {}
local Commands = {}

function Commands.SyncBuyPrices(args) ... end
function Commands.SyncSellRules(args) ... end

function Dispatcher.onServerCommand(module, command, args)
    if module ~= "nshopsb42" then return end
    local fn = Commands[command]
    if fn then fn(args) end
end

if not Dispatcher._registered then
    Dispatcher._registered = true
    Events.OnServerCommand.Add(Dispatcher.onServerCommand)
end
```

---

## Enforcement Checklist (Use This)

Before adding any listener, confirm:

- [ ] Only one engine listener exists
- [ ] Side is gated (`isClient()` / `isServer()`)
- [ ] Dispatcher only, no logic
- [ ] Handlers are single-purpose
- [ ] Versioned payloads
- [ ] Idempotent registration

---

### Final note

If you follow these rules, you will **never** see:

- duplicated price updates
- phantom UI refreshes
- "log shows init but handler not firing"
- SP/MP divergence
