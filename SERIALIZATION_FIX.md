# B42 Serialization Fix: Non-Serializable Shop Objects

## Problem Statement

Three timed actions were passing **IsoThumpable shop objects** as constructor arguments:
- ShopBuyAction
- ShopSellAction
- PlayerShopBuyAction

When B42 serializes a timed action to transmit from client to server:
1. Engine serializes all non-nil fields
2. IsoThumpable objects **cannot be serialized** (not a JSON-serializable type)
3. Field is dropped or set to nil on server
4. Code calls `self.shop:getSquare()` → **nil pointer error**
5. Action validation fails silently
6. Action marked "bugged"

## Solution

**Replace IsoThumpable object with String shop name** (always serializable)

### Before (BROKEN)

```lua
-- ShopBuyAction.lua:221
function ShopBuyAction:new(character, shop, ticket)
    local o = ISBaseTimedAction.new(ShopBuyAction, character)
    o.shop = shop  -- ❌ IsoThumpable - NOT SERIALIZABLE
    o.ticket = ticket
end

-- ShopUI.lua:779 (caller)
local action = ShopBuyAction:new(self.player, self.shop, ticket)

-- ShopBuyAction.lua:79 (complete)
local shopSquare = self.shop:getSquare()  -- ❌ nil on server
```

### After (FIXED)

```lua
-- ShopBuyAction.lua:221
function ShopBuyAction:new(character, shopName, ticket)
    local o = ISBaseTimedAction.new(ShopBuyAction, character)
    o.shopName = shopName  -- ✓ String - SERIALIZABLE
    o.ticket = ticket
end

-- ShopUI.lua:779 (caller)
local action = ShopBuyAction:new(self.player, self.shop:getName(), ticket)

-- ShopBuyAction.lua:79 (complete)
local shop = SHOPSB42.ShopRegistry:getShop(self.shopName)  -- ✓ Lookup by name
if not shop then
    writeLog("Shops", "[ShopBuyAction:complete] [SERVER] ERROR: Shop not found")
    return false
end
local shopSquare = shop:getSquare()  -- ✓ Works on server
```

---

## Changes Applied

### 1. ShopBuyAction

**File:** `shared/nshopsb42/timers/ShopBuyAction.lua`

#### Constructor (Line 221)
```lua
-- BEFORE
function ShopBuyAction:new(character, shop, ticket)
    o.shop = shop

-- AFTER
function ShopBuyAction:new(character, shopName, ticket)
    o.shopName = shopName  -- String - serializable
    o.ticket = ticket      -- Lua table - serializable
```

#### complete() (Lines 78-96)
```lua
-- BEFORE
local shopSquare = self.shop:getSquare()
local shopId = self.shop:getName()

-- AFTER
local shop = SHOPSB42.ShopRegistry:getShop(self.shopName)
if not shop then
    writeLog("Shops", "[ShopBuyAction:complete] [SERVER] ERROR: Shop not found")
    return false
end
local shopSquare = shop:getSquare()
local shopId = self.shopName
```

**Caller:** `client/nshopsb42/ui/ShopUI.lua:779`
```lua
-- BEFORE
local action = ShopBuyAction:new(self.player, self.shop, ticket)

-- AFTER
local action = ShopBuyAction:new(self.player, self.shop:getName(), ticket)
```

---

### 2. ShopSellAction

**File:** `shared/nshopsb42/timers/ShopSellAction.lua`

#### Constructor (Line 180)
```lua
-- BEFORE
function ShopSellAction:new(character, shop, sellList)
    o.shop = shop

-- AFTER
function ShopSellAction:new(character, shopName, sellList)
    o.shopName = shopName    -- String - serializable
    o.sellList = sellList    -- Lua table - serializable
```

#### complete() (Lines 77-90)
```lua
-- BEFORE
local shopId = self.shop:getName()

-- AFTER
local shop = SHOPSB42.ShopRegistry:getShop(self.shopName)
if not shop then
    writeLog("Shops", "[ShopSellAction:complete] [SERVER] ERROR: Shop not found")
    return false
end
local shopId = self.shopName
```

**Caller:** `client/nshopsb42/ui/ShopUI.lua:829`
```lua
-- BEFORE
local action = ShopSellAction:new(self.player, self.shop, sellList)

-- AFTER
local action = ShopSellAction:new(self.player, self.shop:getName(), sellList)
```

---

### 3. PlayerShopBuyAction

**File:** `shared/nshopsb42/timers/PlayerShopBuyAction.lua`

#### Constructor (Line 145)
```lua
-- BEFORE
function PlayerShopBuyAction:new(character, shop, ticket)
    o.shop = shop

-- AFTER
function PlayerShopBuyAction:new(character, shopName, ticket)
    o.shopName = shopName  -- String - serializable
    o.ticket = ticket      -- Lua table - serializable
```

#### complete() (Lines 52-77)
```lua
-- BEFORE
local shopSquare = self.shop:getSquare()
local shopContainer = self.shop:getContainer()
local shopModData = self.shop:getModData()

-- AFTER
local shop = SHOPSB42.ShopRegistry:getShop(self.shopName)
if not shop then
    writeLog("Shops", "[PlayerShopBuyAction:complete] [SERVER] ERROR: Shop not found")
    return false
end
local shopSquare = shop:getSquare()
local shopContainer = shop:getContainer()
local shopModData = shop:getModData()
```

**Caller:** `client/nshopsb42/ui/PlayerShopUI.lua:508`
```lua
-- BEFORE
local action = PlayerShopBuyAction:new(self.player, shop, ticket)

-- AFTER
local action = PlayerShopBuyAction:new(self.player, shop:getName(), ticket)
```

---

## Serialization Contract

### Allowed Constructor Arguments (B42 Compliant)

| Type | Serializable | Examples |
|------|-------------|----------|
| **String** | ✓ | Shop name, player name, item type |
| **Integer** | ✓ | Coordinates (x, y, z), amounts |
| **Boolean** | ✓ | Flags, directions |
| **Number** | ✓ | Prices, durations |
| **Lua Table** | ✓ | `{items, prices, metadata}` |
| **IsoPlayer** | ⚠️ | Only as 1st arg to ISBaseTimedAction.new() |

### NOT Allowed (B42 Violating)

| Type | Why | Example |
|------|-----|---------|
| **IsoObject** | World objects don't serialize | IsoThumpable, IsoBaseObject |
| **UI Objects** | Client-side only | ISWindow, ISButton |
| **Cursor** | Preview state | ShopSpriteCursor |
| **Tables of Objects** | Recursive non-serializable | `{shop=shop, item=item}` |

---

## Testing Strategy

### Expected Behavior (MP - Buy Action)

**Client Console:**
```
[ShopBuyAction:perform] [CLIENT] time remaining=50
[ShopBuyAction:complete] [CLIENT] ENTRY - txnId=...
[ShopBuyAction:complete] [CLIENT] MP - exiting early
```

**Server Console:**
```
[ShopBuyAction:complete] [SERVER] ENTRY - txnId=...
[ShopBuyAction:complete] [SERVER] SUCCESS - purchase transaction processed
```

### What Indicates Success

✓ Server logs show `[SERVER]` context in complete()  
✓ No "Shop not found" errors  
✓ `[SERVER] SUCCESS` appears at end  
✓ Inventory actually updates  
✓ Currency balance changes  

### What Indicates Failure

✗ `[SERVER] ENTRY` never appears in server logs  
✗ `Shop not found` error logged  
✗ complete() returns false (validation failed)  
✗ Inventory unchanged  
✗ Action marked "bugged"  

---

## Architecture Principle

**B42 Timed Action Rule:**
> Only pass **serializable primitives and tables** as constructor arguments.
> Never pass **world objects** or **UI state**.
> Retrieve world objects in `complete()` using the serialized data.

Pattern:
```lua
-- Client: Create action with identifiers
local action = MyAction:new(player, shopName, amount)

-- Network serialization
-- shopName: String ✓ serializes
-- amount: Number ✓ serializes

-- Server: Reconstruct using identifiers
function MyAction:complete()
    local shop = ShopRegistry:getShop(self.shopName)
    -- Now safe to use shop
end
```

---

## Related Files

### Files Modified (Constructors)
- `shared/nshopsb42/timers/ShopBuyAction.lua`
- `shared/nshopsb42/timers/ShopSellAction.lua`
- `shared/nshopsb42/timers/PlayerShopBuyAction.lua`

### Files Modified (Callers)
- `client/nshopsb42/ui/ShopUI.lua`
- `client/nshopsb42/ui/PlayerShopUI.lua`

### Files NOT Affected
- `shared/nshopsb42/timers/SendTransferAction.lua` (no shop object)
- `shared/nshopsb42/timers/ISAddPlayerShopAction.lua` (cursor-based, no registry lookup)
- `shared/nshopsb42/timers/ISAddShopAction.lua` (admin placement, no registry lookup)

---

## Verification

All three actions now follow B42 serialization rules:

| Action | Constructor Args | Serializable | Status |
|--------|-----------------|--------------|--------|
| ShopBuyAction | character, **shopName**, ticket | ✓ | ✅ FIXED |
| ShopSellAction | character, **shopName**, sellList | ✓ | ✅ FIXED |
| PlayerShopBuyAction | character, **shopName**, ticket | ✓ | ✅ FIXED |

Previous blocker removed. Ready for MP testing.
