In **Project Zomboid**, `os.time()` behaves according to **standard Lua semantics**, not a Project Zomboid–specific implementation.

---

## How `os.time()` Is Generated

- `os.time()` is provided by the embedded **Lua runtime**
- It ultimately delegates to the **host operating system clock**
- It is **wall-clock time**, not game time

**It has no awareness of:**

- In-game days or hours
- Game speed
- Pausing
- Server tick rate

---

## Format and Meaning

### Return value

```lua
local t = os.time()
```

- **Type:** number (integer)
- **Format:** Unix timestamp
- **Unit:** seconds
- **Epoch:** `1970-01-01 00:00:00 UTC`

Example:

```lua
1735891200
```

This represents the number of seconds elapsed since the Unix epoch.

---

## With Date Table (Optional)

```lua
local now = os.time({
    year  = 2026,
    month = 1,
    day   = 3,
    hour  = 8,
    min   = 0,
    sec   = 0
})
```

- Interpreted in **local system time**
- Converted internally to a Unix timestamp

---

## Timezone Behavior (Important)

- `os.time()` uses the **local timezone of the machine**

  - Client machine in SP
  - Server machine in MP

- No automatic UTC normalization

To inspect components:

```lua
local t = os.time()
local date = os.date("*t", t)   -- local time
local utc  = os.date("!*t", t)  -- UTC
```

---

## Multiplayer Implications (Critical)

This is where misuse often causes bugs.

### ⚠ Authority mismatch

- **Client `os.time()` ≠ Server `os.time()`**
- Different:

  - Timezones
  - System clocks
  - Drift

### Therefore:

- **Never** use `os.time()` on the client for:

  - Cooldowns
  - Expiry
  - Pricing windows
  - Validation logic

- Always compute and store timestamps **server-side**
- Send values to clients as data only

---

## Comparison With Game Time (Common Confusion)

| Function                           | Meaning                                      |
| ---------------------------------- | -------------------------------------------- |
| `os.time()`                        | Real-world wall clock                        |
| `getGameTime()`                    | In-game simulation time                      |
| `getGameTime():getWorldAgeHours()` | In-game elapsed hours                        |
| `getTimestampMs()`                 | Engine uptime (milliseconds, not persistent) |

If your logic is **economy-, shop-, or gameplay-related**, you almost always want **game time**, not `os.time()`.

---

## Best-Practice Summary

- **Format:** Unix timestamp (seconds)
- **Source:** OS wall clock
- **Deterministic:** No
- **MP-safe:** Only when server-authoritative
- **Use for:** Logging, audit trails, real-time cooldowns
- **Avoid for:** Gameplay progression tied to in-game time

If you describe your specific use case (e.g. shop reset, price decay, audit log, admin cooldown), I can tell you which time source is correct and why.
