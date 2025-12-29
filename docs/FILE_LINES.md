In Lua development—particularly for **Project Zomboid modding**—“file lines” usually refers to **how Lua files are structured, read, and executed line-by-line**, and how line numbers matter for debugging, stack traces, and maintenance. Below is a precise breakdown.

---

## 1. How Lua Executes File Lines

Lua executes a file **top to bottom, line by line**, at load time.

```lua
local a = 10        -- executed immediately
local b = a + 5     -- executed immediately
```

Key implications:

- Code **outside functions runs immediately** when the file is loaded
- Code **inside functions runs only when called**
- Order matters

---

## 2. File-Level Code vs Function-Level Code

### 2.1 File-Level (Executed on Load)

```lua
MyMod = MyMod or {}     -- runs when file loads
MyMod.value = 5
```

Used for:

- Table initialization
- Event registration
- Constants
- Registry calls

**Risk**:
If this code references something not yet loaded, it will show a line error immediately.

---

### 2.2 Function-Level (Executed on Call)

```lua
function MyMod.doThing()
    print("Hello")
end
```

Used for:

- Logic
- UI callbacks
- Timed actions
- Commands

Safer for cross-file dependencies.

---

## 3. Line Numbers in Errors (Critical for Debugging)

Example error:

```
ERROR: attempted index of non-table
file: PlayerShopContext.lua line #159
```

This means:

- The exact **Lua source line**
- The variable on that line was `nil` or not a table
- The bug is **at that line**, not where the function was defined

### Best Practice

Always open the file and inspect:

- The exact line
- The line above (often where data was assigned)
- External calls feeding into that line

---

## 4. Best Practices for File Line Structure

### 4.1 Group Lines by Purpose (Recommended Order)

```lua
-- 1. Guards
if not isClient() then return end

-- 2. Locals & requires
local UI = {}
local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)

-- 3. Constants
UI.PAGE_SIZE = 25

-- 4. Functions
function UI.create()
end

-- 5. Event registration (last)
Events.OnGameStart.Add(UI.create)
```

This makes line numbers **predictable and readable**.

---

### 4.2 Avoid Long Files (Line Count Guideline)

| File Type        | Recommended Max |
| ---------------- | --------------- |
| UI files         | ~400 lines      |
| Logic files      | ~300 lines      |
| Server logic     | ~250 lines      |
| Shared utilities | ~200 lines      |

If a file grows beyond this:

- Split by responsibility
- Errors become harder to locate
- MP bugs become harder to reason about

---

## 5. Defensive Line Coding (Prevent Line Errors)

### 5.1 Never Chain Without Guards

**Bad (line crash-prone):**

```lua
local owner = item:getModData().owner
```

**Good:**

```lua
local data = item and item:getModData()
local owner = data and data.owner
```

This prevents:

```
attempted index of non-table
```

---

### 5.2 One Logical Operation per Line

**Bad:**

```lua
if item and item:getContainer() and item:getContainer():getParent() then
```

**Good:**

```lua
if not item then return end
local container = item:getContainer()
if not container then return end
```

Why:

- Easier debugging
- Cleaner stack traces
- Faster isolation of faulty lines

---

## 6. Comments and Line Stability

### 6.1 Comment Above the Line, Not Inline

**Preferred**

```lua
-- Prevent non-owner item removal
if not isOwner(player, container) then
    return false
end
```

Inline comments shift line meaning during refactors and make stack traces harder to follow.

---

## 7. Line Numbers and Multiplayer Bugs

In MP:

- A client error line ≠ server error line
- Same file may load twice (client + server)
- Always confirm **side** when debugging a line

Recommendation:

```lua
if isClient() then
    writeLog("customLogFile","[Shop][CLIENT] line hit")
end
```

---

## 8. Golden Rules for File Lines

1. **Top-level code runs immediately**
2. **Order matters**
3. **Errors point to the failing line, not the root cause**
4. **Shorter files = faster debugging**
5. **Guard before you index**
6. **One responsibility per section**

---
