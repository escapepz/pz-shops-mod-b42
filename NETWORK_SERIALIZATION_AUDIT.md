# Network Serialization Audit

## Executive Summary
Comprehensive audit of all client-server network communication found **1 critical issue (now fixed)** and **no active vulnerabilities** in command dispatching. The codebase follows strict serialization patterns using primitive data types for all network parameters.

---

## Critical Issue Found & Fixed

### ❌ Timed Action Serialization (ShopBuyAction, ShopSellAction, PlayerShopBuyAction)
**Status:** FIXED in commit with shop coordinates refactoring

**Issue:** Game objects (IsoObject shop references) were passed as constructor parameters during action instantiation. During network reconstruction, these became `nil`, causing null pointer dereference.

**Error:**
```
attempted index: getSquare of non-table: null
```

**Files Fixed:**
- `ShopBuyAction.lua` - Changed parameter from `shop` object to `shopCoords` table
- `ShopSellAction.lua` - Changed parameter from `shop` object to `shopCoords` table
- `PlayerShopBuyAction.lua` - Changed parameter from `shop` object to `shopCoords` table
- `ShopUI.lua` - Client-side extraction of coords before action dispatch
- `PlayerShopUI.lua` - Client-side extraction of coords before action dispatch

**Root Cause:** Timed actions are reconstructed by the engine during network serialization. Only primitive data types (numbers, booleans, strings, tables) can be serialized. Game objects cannot cross the client-server boundary.

---

## Clean Patterns (No Issues Found)

### ✅ Command Dispatching (ShopCommandDispatcher)

**Client → Server (`OnClientCommand`):**
```lua
-- SAFE: Sends primitive data only
sendServerCommand(player, "nshopsb42", "CommandName", {
    x = 100, y = 50, z = 0,           -- coordinates
    index = 5,                         -- object index
    itemID = "Base.Apple",             -- item identifier string
    coin = 500,                        -- primitive number
})
```

**Server → Client (`OnServerCommand`):**
```lua
-- SAFE: Sends tables with primitives only
sendServerCommand("nshopsb42", "SyncShopData", {
    Items = { ... },                   -- tables of data
    PlayerBuy = { ... },
    BuyIsWhitelist = false,            -- boolean
})
```

**Pattern Rules:**
- Never pass `IsoObject`, `IsoPlayer`, `IsoGridSquare`, or similar
- Use coordinates `{x, y, z}` + index for object lookup
- Use `username` or `steamID` for player identification
- Use item type strings (`"Base.Apple"`) for inventory items
- All values in args table must be primitives (number, string, boolean) or tables thereof

**Files Audited:**
- `ShopCommandDispatcherServer.lua` - All handlers follow pattern ✅
- `ShopCommandDispatcherClient.lua` - All handlers follow pattern ✅
- `Utilities.lua` (SendServerCommandTo, SendClientCommand wrappers) - Properly documented ✅

### ✅ Object Resolution Pattern

Server resolves objects after receiving primitive parameters:
```lua
-- Resolve square from coordinates
local square = getWorld():getCell():getGridSquare(args.x, args.y, args.z)

-- Resolve object from index
local obj = square:getObjects():get(args.index)

-- Resolve player from character (in timed actions)
local username = self.character:getUsername()

-- Resolve item from inventory ID
local item = playerInventory:getItemById(args.itemID)
```

**Files Using This Pattern (All Safe):**
- `ShopCommandDispatcherServer.lua` - Line 65-84 (RemoveShop)
- `ShopBuyAction.lua` - Line 79-92 (complete method)
- `ShopSellAction.lua` - Line 136-151 (complete method)
- `PlayerShopServer.lua` - getShopObject pattern

### ✅ ModData Synchronization

Global state synchronized via `ModData.transmit()`:
```lua
-- Direct table sync - only primitives
ModData.set("CoinBalance", {
    username = { coin = 500, specialCoin = 100 }
})
ModData.transmit("CoinBalance")
```

**Safe because:**
- Only primitive data structures (numbers, strings, tables)
- No game objects stored in ModData
- `transmit()` handles serialization automatically

**Files Using This Pattern:**
- `Balance.lua` - Coin balance storage
- `ModDataDispatcherClient.lua` - Handles sync events

### ✅ Character Parameter in sendClientCommand

`SendTransferAction` passes character correctly:
```lua
-- SAFE: Built-in PZ function handles character → username conversion
sendClientCommand(self.character, "BS", "Transfer", {
    coin = self.coin,                  -- primitives only
    specialCoin = self.specialCoin,
    recipient = self.recipient,        -- string username
})
```

The `sendClientCommand` function (built-in PZ API) automatically extracts the username from the character object. The args table contains only primitives.

---

## Audit Checklist

| Pattern | Status | Files |
|---------|--------|-------|
| Timed Action Registration | ✅ Fixed | 4 files |
| Timed Action Parameters | ✅ Fixed | 5 files |
| Command Dispatcher Args | ✅ Safe | 2 files |
| Object Resolution | ✅ Safe | 6 files |
| ModData Storage | ✅ Safe | 3 files |
| sendClientCommand usage | ✅ Safe | 1 file |

---

## Prevention Guidelines

To prevent similar issues in future development:

1. **Timed Action Constructors**: Always use primitive parameters or serializable tables
   ```lua
   -- BAD
   function MyAction:new(character, gameObject) end
   
   -- GOOD
   function MyAction:new(character, objectCoords) end
   ```

2. **Command Arguments**: Extract primitives on client before sending
   ```lua
   -- BAD
   sendServerCommand(player, "mod", "cmd", { square = square })
   
   -- GOOD
   sendServerCommand(player, "mod", "cmd", { 
       x = square:getX(), 
       y = square:getY(), 
       z = square:getZ() 
   })
   ```

3. **ModData Storage**: Only store primitives and primitive tables
   ```lua
   -- BAD
   ModData.set("key", { player = playerObject })
   
   -- GOOD
   ModData.set("key", { username = playerName, x = x, y = y })
   ```

4. **Player Identification**: Use username, not player object
   ```lua
   -- BAD
   local sender = transferData.player
   
   -- GOOD
   local sender = transferData.senderUsername
   ```

---

## Date
Audit: 2026-01-03
Status: **1 Critical Issue Fixed, 0 Active Vulnerabilities**
