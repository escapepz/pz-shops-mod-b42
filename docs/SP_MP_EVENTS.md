Below is a **practical, engine-accurate classification** of **Project Zomboid events that will never trigger in Singleplayer (SP)**, **why they do not**, and what to use instead. This is specific to **B42 / 42.13+ behavior**.

---

# Events That Never Trigger in Singleplayer

The core rule is simple:

> **If an event depends on a remote peer, network state, or server lifecycle separation, it will never fire in SP.**

SP has **no remote clients**, **no server start lifecycle**, and **no connection state changes**.

---

## 1. Multiplayer Connection Lifecycle Events ❌

These require **remote clients**.

| Event                       | Why it never fires in SP      |
| --------------------------- | ----------------------------- |
| `Events.OnClientConnect`    | No remote clients exist       |
| `Events.OnClientDisconnect` | No remote clients exist       |
| `Events.OnClientAdded`      | Player already exists locally |
| `Events.OnClientRemoved`    | No removal lifecycle          |
| `Events.OnPlayerJoin`       | Player is spawned directly    |
| `Events.OnPlayerLeave`      | Player never “leaves”         |

**SP equivalent:**
None. The player exists immediately.

---

## 2. Server Lifecycle Events ❌

These only exist for **dedicated servers**.

| Event                     | Why                          |
| ------------------------- | ---------------------------- |
| `Events.OnServerStarted`  | No standalone server process |
| `Events.OnServerShutdown` | SP exits JVM directly        |
| `Events.OnServerSaving`   | SP saves via world tick      |

**SP alternative:**

- `Events.OnGameStart`
- `Events.OnLoadMapZones`
- `Events.EveryTenMinutes`

---

## 3. Network / Sync Boundary Events ❌

These depend on **network replication**.

| Event                    | Reason                          |
| ------------------------ | ------------------------------- |
| `Events.OnReceiveChunk`  | No chunk streaming over network |
| `Events.OnChunkSend`     | No outbound chunk packets       |
| `Events.OnWorldMessage`  | No server broadcast             |
| `Events.OnServerMessage` | No network messaging            |

---

## 4. Admin / Permission Events ❌

These require **server-admin roles**.

| Event                             | Reason                        |
| --------------------------------- | ----------------------------- |
| `Events.OnAdminStatusChanged`     | SP player is implicitly admin |
| `Events.OnModeratorStatusChanged` | No role system                |

---

## 5. Client-Side Network Events ❌

These only fire on **remote clients**.

| Event                    | Reason                          |
| ------------------------ | ------------------------------- |
| `Events.OnConnectFailed` | No connection attempt           |
| `Events.OnDisconnect`    | No network drop                 |
| `Events.OnServerCommand` | No server → client network send |

⚠ **Important distinction**
`Events.OnClientCommand` **DOES fire in SP**
`Events.OnServerCommand` **DOES NOT**

---

## 6. Events That _Do_ Fire in SP (Often Confused)

These **do fire** and are safe:

| Event                    | Fires in SP |
| ------------------------ | ----------- |
| `Events.OnClientCommand` | ✅          |
| `Events.OnGameStart`     | ✅          |
| `Events.OnCreatePlayer`  | ✅          |
| `Events.OnPlayerUpdate`  | ✅          |
| `Events.OnTick`          | ✅          |
| `Events.OnLoadMapZones`  | ✅          |
| `Events.EveryTenMinutes` | ✅          |

---

## 7. Common Trap (Very Relevant to Mods)

### ❌ Expecting this to fire in SP:

```lua
Events.OnServerCommand.Add(function(module, command, args)
    -- will NEVER fire in SP
end)
```

### ✅ Correct SP+MP-safe replacement:

```lua
Events.OnClientCommand.Add(function(module, command, player, args)
    -- works in SP and MP
end)
```

---

## 8. One-Line Rule You Can Trust

> **If an event name implies “server → client”, “connection”, or “admin role”, it will not fire in SP.**

> **If it implies “client → server” or “game loop”, it will fire in SP.**

---

## 9. Recommended Design Rule (B42)

| Situation                  | Correct Tool                            |
| -------------------------- | --------------------------------------- |
| UI → authority             | `sendClientCommand` + `OnClientCommand` |
| Player action              | Shared Timed Action                     |
| World / inventory mutation | Server-side logic only                  |
| SP testing of MP mod       | Same code path                          |

---

### Final Takeaway

- SP is **not** a special case
- Missing events in SP are **by design**
- Mods must target **unified logic**
- If something works in MP but not SP, you are probably listening to the **wrong event**
