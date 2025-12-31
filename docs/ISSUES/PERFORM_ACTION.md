This symptom is **well-known in B42** and it is **not random**.
When the log says **“bugged action”** and `perform()` is never called, it means the **Timed Action failed validation during network reconstruction** and was **discarded before execution**.

Below is the **precise diagnosis checklist**, in order of likelihood.

---

## Root Cause: Timed Action Cannot Be Reconstructed on Server

In B42, **MP timed actions are serialized and rebuilt on the server using the arguments of `new()`**.
If _anything_ in that process is invalid, the engine logs _bugged action_ and aborts.

---

## 1. ❌ `new()` Arguments Do NOT Match Fields (MOST COMMON)

### Rule (Strict in B42)

Every argument passed to `new()` **must be assigned verbatim to a field of the same semantic value**.

### ❌ Invalid (Very Common Mistake)

```lua
function ISAddPlayerShopAction:new(player, square, sprite, north)
    local o = ISBaseTimedAction.new(self, player)
    o.square = square
    o.spriteName = sprite   -- ❌ argument name mismatch
    o.maxTime = 100
    return o
end
```

The server rebuilds using:

```lua
ISAddPlayerShopAction:new(player, square, sprite, north)
```

But it **cannot infer `spriteName`**, so reconstruction fails.

### ✅ Correct

```lua
function ISAddPlayerShopAction:new(player, square, sprite, north)
    local o = ISBaseTimedAction.new(self, player)
    o.square = square
    o.sprite = sprite       -- ✅ exact semantic match
    o.north  = north
    o.maxTime = o:getDuration()
    return o
end
```

**If this rule is violated → `perform()` is never called.**

---

## 2. ❌ Passing Unsupported Types to `new()`

Only **engine-serializable types** are allowed.

### ✅ Allowed (Examples)

- `IsoPlayer`
- `IsoGridSquare`
- `InventoryItem`
- `String`
- `Boolean`
- `Integer`
- `KahluaTableImpl`

### ❌ NOT Allowed

- Cursor objects
- Lua tables with functions
- UI objects
- Custom class instances
- Closures

### ❌ Common Shop Mistake

```lua
ISAddPlayerShopAction:new(player, cursor, sprite, north) -- ❌ cursor
```

### ✅ Correct

```lua
ISAddPlayerShopAction:new(player, square, sprite, north)
```

If **any argument is unsupported**, the action is marked **bugged** immediately.

---

## 3. ❌ Timed Action File Is Not in `shared`

In MP, timed actions **must exist on both client and server**.

### ✅ Correct Location

```
media/lua/shared/ISAddPlayerShopAction.lua
```

### ❌ Wrong

```
media/lua/client/ISAddPlayerShopAction.lua
```

If the server cannot load the class → action is bugged → no `perform()`.

---

## 4. ❌ `getDuration()` Missing or Returns Invalid Value

### Required

```lua
function ISAddPlayerShopAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 100 -- > 0
end
```

### ❌ Invalid

- Returning `nil`
- Returning `0`
- Returning negative values (except `-1` explicitly)

If duration is invalid → action never starts.

---

## 5. ❌ Constructor Mutates Values After Serialization

### ❌ Bad

```lua
o.maxTime = 100
o.maxTime = o.maxTime * player:getPerkLevel(...) -- ❌ diverges
```

The server rebuilds using raw args, **not post-logic**.

### ✅ Correct

```lua
o.maxTime = o:getDuration()
```

All dynamic logic must be inside `getDuration()`.

---

## 6. ❌ `perform()` Defined Incorrectly

### Required Signature

```lua
function ISAddPlayerShopAction:perform()
    ISBaseTimedAction.perform(self)
end
```

### ❌ Common Mistakes

- Missing call to `ISBaseTimedAction.perform(self)`
- Typo in method name
- Defining `perform(self, arg)` (extra args)

---

## 7. ❌ Action Is Queued While Cursor Is Still Active

This one is subtle.

If you call:

```lua
ISTimedActionQueue.add(action)
```

**while `setDrag()` is still active**, the engine may cancel the action.

### Safe Pattern

```lua
getCell():setDrag(nil)
ISTimedActionQueue.add(action)
```

---

## Minimal “Known-Good” Template (Use This)

```lua
ISAddPlayerShopAction = ISBuildAction:derive("ISAddPlayerShopAction")

function ISAddPlayerShopAction:new(character, square, sprite, north)
    local o = ISBuildAction.new(self, character)
    o.character = character
    o.square = square
    o.sprite = sprite
    o.north = north
    o.maxTime = o:getDuration()
    return o
end

function ISAddPlayerShopAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 120
end

function ISAddPlayerShopAction:perform()
    ISBuildAction.perform(self)
end

function ISAddPlayerShopAction:complete()
    if not isServer() then return true end

    local obj = IsoThumpable.new(self.square, self.sprite, self.north)
    self.square:AddTileObject(obj)
    obj:transmitCompleteItemToClients()

    return true
end
```

If **this template works**, any deviation in your current code is the bug.

---

## Final Diagnosis Summary

When you see:

> **bugged action** > **perform() never called**

It means **one of these is true**:

1. `new()` args ≠ fields
2. Unsupported argument type
3. File not in `shared`
4. `getDuration()` invalid
5. Constructor mutates serialized values
6. `perform()` signature broken
7. Cursor not cleared before queuing

This is deterministic, not random.

If you want, paste your **exact `ISAddPlayerShopAction:new()`** and I will pinpoint the exact failing line immediately.
