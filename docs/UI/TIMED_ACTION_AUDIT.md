# Timed Action Audit Report

## Executive Summary

**STATUS: 4 CRITICAL ISSUES FOUND**

All 6 timed actions have the same fundamental architecture problem:
- They pass **non-serializable IsoThumpable objects** as constructor arguments
- The server receives the action but `self.shop` is **nil**
- Attempts to call `self.shop:getSquare()` fail silently
- Returns `false` (validation failed) instead of processing the transaction

This pattern affects:
1. ShopBuyAction
2. ShopSellAction
3. PlayerShopBuyAction
4. (SendTransferAction - does NOT use shop, partially safe)

---

## Detailed Findings

### Issue #1: Constructor Bug (FIXED)

**Files:** All 6 timed actions
**Status:** ✅ FIXED

**Problem:** Passed `self` instead of class name to `ISBaseTimedAction.new()`

```lua
-- ❌ BEFORE (all 6 files)
local o = ISBaseTimedAction.new(self, character)

-- ✅ AFTER (now fixed)
local o = ISBaseTimedAction.new(ShopBuyAction, character)
```

**Files Fixed:**
- ISAddPlayerShopAction.lua - Line 186
- ISAddShopAction.lua - Line 149
- ShopBuyAction.lua - Line 222
- ShopSellAction.lua - Line 181
- PlayerShopBuyAction.lua - Line 146
- SendTransferAction.lua - Line 57

---

### Issue #2: Non-Serializable Shop Object (CRITICAL - NOT FIXED)

**Severity:** 🔴 CRITICAL
**Files:** ShopBuyAction, ShopSellAction, PlayerShopBuyAction
**Status:** ❌ REQUIRES FIX

#### ShopBuyAction

**Constructor (Line 221):**
```lua
function ShopBuyAction:new(character, shop, ticket)
    local o = ISBaseTimedAction.new(ShopBuyAction, character)
    o.shop = shop          -- ❌ shop is IsoThumpable - NOT SERIALIZABLE
    o.ticket = ticket      -- ✓ ticket is Lua table - serializable
```

**Called from:** `ShopUI.lua:779`
```lua
local action = ShopBuyAction:new(self.player, self.shop, ticket)
```

**Usage in complete() (Line 79):**
```lua
local shopSquare = self.shop:getSquare()  -- ❌ self.shop is nil on server
```

**Impact:** On server, `self.shop` is nil because IsoThumpable cannot serialize. Method call fails, likely returns false.

---

#### ShopSellAction

**Constructor (Line 180):**
```lua
function ShopSellAction:new(character, shop, sellList)
    local o = ISBaseTimedAction.new(ShopSellAction, character)
    o.shop = shop          -- ❌ shop is IsoThumpable - NOT SERIALIZABLE
    o.sellList = sellList  -- ✓ sellList is Lua table - serializable
```

**Called from:** `ShopUI.lua` (similar pattern)

**Usage in complete() (Line 73):**
```lua
local shopSquare = self.shop:getSquare()  -- ❌ self.shop is nil on server
```

**Impact:** Same as ShopBuyAction - server cannot access shop.

---

#### PlayerShopBuyAction

**Constructor (Line 145):**
```lua
function PlayerShopBuyAction:new(character, shop, ticket)
    local o = ISBaseTimedAction.new(PlayerShopBuyAction, character)
    o.shop = shop          -- ❌ shop is IsoThumpable - NOT SERIALIZABLE
    o.ticket = ticket      -- ✓ ticket is Lua table - serializable
```

**Called from:** `PlayerShopUI.lua:508`

**Usage in complete() (Line 51):**
```lua
local shopSquare = self.shop:getSquare()  -- ❌ self.shop is nil on server
```

**Impact:** Same critical failure.

---

### Issue #3: Shop ID Not Available

**Severity:** 🔴 CRITICAL
**Status:** ❌ REQUIRES FIX

All three affected actions need the **shop name/ID** for server-side operations:
- ShopBuyAction: Line 96 `shopId = self.shop:getName()`
- ShopSellAction: Line 85 `shopId = self.shop:getName()`
- PlayerShopBuyAction: Line 71 `shopModData = self.shop:getModData()`

The server cannot retrieve this information because `self.shop` is nil.

---

### Issue #4: SendTransferAction (PARTIALLY SAFE)

**File:** SendTransferAction.lua
**Status:** ⚠️ NEEDS REVIEW

**Constructor (Line 56):**
```lua
function SendTransferAction:new(character, coin, specialCoin, recipient)
    local o = ISBaseTimedAction.new(SendTransferAction, character)
    o.coin = coin               -- ✓ Number - serializable
    o.specialCoin = specialCoin -- ✓ Number - serializable
    o.recipient = recipient     -- ✓ String - serializable
```

**Complete (Line 45):**
```lua
sendClientCommand(self.character, "BS", "Transfer", {...})
```

This action only sends a command, does not access `self.shop`, so it will work. ✓

---

## Root Cause Analysis

### Why This Breaks B42 Serialization

B42 timed actions are **serialized to send from client to server**:

```
Client action created:
  ├─ character: IsoPlayer → ✓ Serializable (by name/ID)
  ├─ shop: IsoThumpable → ❌ NOT SERIALIZABLE
  ├─ ticket: {txnId, coin, items} → ✓ Serializable (Lua table)
  └─ sellList: {txnId, items} → ✓ Serializable (Lua table)

Transmission to server:
  → Engine serializes all non-nil fields
  → Cannot serialize IsoThumpable
  → Field is dropped or set to nil

Server reconstruction:
  → Receives serialized action
  → Recreates action instance
  → self.shop = nil (field was lost)
  → Code calls self.shop:getSquare()
  → CRASH or silent fail
  → Returns false (validation failed)
```

---

## Solution

### For ShopBuyAction, ShopSellAction, PlayerShopBuyAction

**Instead of passing the shop object, pass identifiable data:**

#### Option A: Pass Shop Name (Recommended)

```lua
-- BEFORE
function ShopBuyAction:new(character, shop, ticket)
    local o = ISBaseTimedAction.new(ShopBuyAction, character)
    o.shop = shop            -- ❌ NON-SERIALIZABLE
    o.ticket = ticket
end

-- AFTER
function ShopBuyAction:new(character, shopName, ticket)
    local o = ISBaseTimedAction.new(ShopBuyAction, character)
    o.shopName = shopName    -- ✓ String - SERIALIZABLE
    o.ticket = ticket
end

-- In complete(), retrieve shop by name
function ShopBuyAction:complete()
    if isMultiplayer() and not isServer() then
        return true
    end
    
    -- Get shop from world
    local shop = SHOPSB42.ShopRegistry:getShop(self.shopName)
    if not shop then
        return false
    end
    
    -- Now safe to use shop
    local shopSquare = shop:getSquare()
    ...
end
```

#### Option B: Pass Square Coordinates

```lua
function ShopBuyAction:new(character, shop, ticket)
    local o = ISBaseTimedAction.new(ShopBuyAction, character)
    o.shopName = shop:getName()  -- ✓ String
    o.shopX = shop:getSquare():getX()  -- ✓ Integer
    o.shopY = shop:getSquare():getY()  -- ✓ Integer
    o.shopZ = shop:getSquare():getZ()  -- ✓ Integer
    o.ticket = ticket
end

function ShopBuyAction:complete()
    -- Retrieve shop from coordinates
    local square = getCell():getGridSquare(self.shopX, self.shopY, self.shopZ)
    local shop = square:getSpecialObject(...)
    ...
end
```

---

## Call Chain Analysis

### ShopBuyAction

```
ShopUI.lua:779
  └─ ShopBuyAction:new(player, self.shop [IsoThumpable], ticket)
      └─ Serialization happens
      └─ Server receives action
      └─ ShopBuyAction:complete() runs on server
          └─ self.shop is nil ❌
          └─ self.shop:getSquare() fails ❌
          └─ Returns false
```

### ShopSellAction

```
ShopUI.lua (sell cart)
  └─ ShopSellAction:new(player, self.shop [IsoThumpable], sellList)
      └─ Serialization happens
      └─ Server: self.shop is nil ❌
      └─ Cannot call self.shop:getSquare() ❌
```

### PlayerShopBuyAction

```
PlayerShopUI.lua:508
  └─ PlayerShopBuyAction:new(player, shop [IsoThumpable], ticket)
      └─ Serialization happens
      └─ Server: self.shop is nil ❌
      └─ Cannot call self.shop:getModData() ❌
```

---

## Audit Checklist

### Constructor Contract Violations

| Action | Issue | Severity | Fixed |
|--------|-------|----------|-------|
| ISAddPlayerShopAction | `self` arg instead of class name | HIGH | ✅ |
| ISAddShopAction | `self` arg instead of class name | HIGH | ✅ |
| ShopBuyAction | `self` arg + IsoThumpable arg | CRITICAL | ⚠️ Partial |
| ShopSellAction | `self` arg + IsoThumpable arg | CRITICAL | ⚠️ Partial |
| PlayerShopBuyAction | `self` arg + IsoThumpable arg | CRITICAL | ⚠️ Partial |
| SendTransferAction | `self` arg only (no shop) | HIGH | ✅ |

### Return Values

| Action | `complete()` return | Status |
|--------|-------------------|--------|
| ISAddPlayerShopAction | `return true`/`false` | ✅ Correct |
| ISAddShopAction | `return true`/`false` | ✅ Correct |
| ShopBuyAction | `return true`/`false` | ✅ Correct |
| ShopSellAction | `return true`/`false` | ✅ Correct |
| PlayerShopBuyAction | `return true`/`false` | ✅ Correct |
| SendTransferAction | `return true` | ✅ Correct |

---

## Recommended Action

**Priority 1 (BLOCKING):**
- Fix ShopBuyAction, ShopSellAction, PlayerShopBuyAction to use shop name instead of object

**Priority 2 (Already Fixed):**
- ✅ Constructor `self` bug (all 6 actions)

**Priority 3 (Already Done):**
- ✅ Logging hooks added
- ✅ Return values correct

---

## Test Plan

After fixes:

1. **Single-Player Test:**
   - Buy from shop → Should succeed
   - Sell to shop → Should succeed
   - Buy from player shop → Should succeed

2. **Multiplayer Test:**
   - Client: Buy from shop
   - Server logs: Should see complete() execution
   - Result: Transaction processed, inventory updated

3. **Log Indicators:**
   ```
   ✓ [ShopBuyAction:complete] [SERVER] ENTRY - txnId=...
   ✓ [ShopBuyAction:complete] [SERVER] SUCCESS - purchase...
   ```

   NOT:
   ```
   ✗ Errors about self.shop being nil
   ✗ complete() never called on server
   ✗ Action marked "bugged"
   ```
