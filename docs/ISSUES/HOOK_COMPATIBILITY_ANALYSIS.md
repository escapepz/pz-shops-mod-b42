# Shops Mod v42.13.1 - Hook Compatibility Analysis

## Overview
This document details all vanilla function hooks found in the Shops mod and identifies potential backward compatibility issues with other mods.

---

## VANILLA FUNCTION HOOKS IDENTIFIED

### 1. **ISInventoryTransferAction.start()**
**Location**: `Shops/42.13.1/media/lua/client/patches/ISInventoryTransferActionPatch.lua`

**Type**: Instance Method Override

**Hook Method**: Direct method replacement with cached original

```lua
local oldStart = ISInventoryTransferAction.start
function ISInventoryTransferAction:start()
    -- Custom logic
    oldStart(self)
end
```

**Purpose**: Validates shop ownership before allowing inventory transfers

**Risk Level**: 🔴 **HIGH**

**Compatibility Issues**:
- **SafeHouse mod** - Also hooks `ISInventoryTransferAction` for safehouse permissions
- **Trade/Commerce mods** - May intercept transfers for trade mechanics
- **Permission-based mods** - Any mod implementing custom transfer restrictions
- **Multiplayer permission mods** - Mods checking player permissions

**Breaking Pattern**: Sequential execution is lost. Only Shops' validation runs, then original. If another mod also patches this method, only the last patch loads.

---

### 2. **ISInventoryPage.isRemoveButtonVisible()**
**Location**: `Shops/42.13.1/media/lua/client/patches/ISInventoryPagePatch.lua`

**Type**: Instance Method Override

**Hook Method**: Direct method replacement with cached original

```lua
local oldIsRemoveButtonVisible = ISInventoryPage.isRemoveButtonVisible
function ISInventoryPage:isRemoveButtonVisible()
    -- Custom logic
    return oldIsRemoveButtonVisible(self)
end
```

**Purpose**: Hides inventory remove button for shop-owned containers

**Risk Level**: 🔴 **HIGH**

**Compatibility Issues**:
- **SafeHouse mod** - Also modifies button visibility for safehouse containers
- **Container Permission mods** - Mods restricting container access
- **UI mods** - Any UI mod modifying inventory page buttons
- **Locked Container mods** - Mods with custom container locking mechanics

**Breaking Pattern**: Last loaded patch wins. No chaining of multiple UI permission checks.

---

### 3. **ISToolTipInv.render()**
**Location**: `Shops/42.13.1/media/lua/client/patches/ISToolTipInvPatch.lua`

**Type**: Instance Method Override

**Hook Method**: Direct method replacement with cached original

```lua
local oldRender = ISToolTipInv.render
function ISToolTipInv:render()
    injectTooltip(self)
    oldRender(self)
end
```

**Purpose**: Injects custom shop/wallet information into item tooltips

**Risk Level**: 🟡 **MEDIUM-HIGH**

**Compatibility Issues**:
- **Enhanced Tooltips mod** - Modifies tooltip rendering and layout
- **Item Info Display mods** - Any mod that augments tooltip content
- **Price Display mods** - Mods showing custom item pricing info
- **Localization mods** - Mods modifying tooltip text rendering
- **Accessibility mods** - Mods modifying font/size configs

**Breaking Pattern**: The render method suppresses food tooltips during ShopUI/PlayerShopUI usage. Other mods expecting tooltips to render may be confused.

---

### 4. **ISTransferAction.transferItem()**
**Location**: `Shops/42.13.1/media/lua/server/patches/ISTransferActionPatch.lua`

**Type**: Instance Method Override (Server-side)

**Hook Method**: Direct method replacement with cached original

```lua
local OriginalTransferItem = ISTransferAction.transferItem
function ISTransferAction:transferItem(character, item, srcContainer, destContainer, dropSquare)
    -- Custom validation
    return OriginalTransferItem(self, ...)
end
```

**Purpose**: Server-side validation of shop ownership before allowing transfers

**Risk Level**: 🔴 **HIGH**

**Compatibility Issues**:
- **Multiplayer permission mods** - Server-side permission validation mods
- **Item value/weight system mods** - Mods intercepting transfers to apply mechanics
- **Trading system mods** - Custom trade/exchange mechanics
- **Container security mods** - Server-side container protection mods

**Breaking Pattern**: Server-side transfer chain is broken. Critical for multiplayer security.

---

### 5. **ISDestroyCursor.canDestroy()**
**Location**: `Shops/42.13.1/media/lua/server/patches/ISDestroyCursorPatch.lua`

**Type**: Instance Method Override

**Hook Method**: Direct method replacement with cached original

```lua
local oldCanDestroy = ISDestroyCursor.canDestroy
function ISDestroyCursor:canDestroy(object)
    -- Custom logic
    return oldCanDestroy(self, object)
end
```

**Purpose**: Prevents non-admin destruction of shop objects

**Risk Level**: 🟡 **MEDIUM**

**Compatibility Issues**:
- **Destruction restriction mods** - Mods protecting certain objects from destruction
- **Building permission mods** - Mods checking building ownership
- **Admin panel enhancement mods** - Mods modifying destruction behavior
- **Protected areas mods** - Mods preventing destruction in specific zones

**Breaking Pattern**: Destruction checks are sequential. Last patch wins.

---

## CUSTOM EVENT HOOKS (Safe)

These are NOT vanilla hooks and use proper event registration:

### ✅ Events.OnServerStarted
- Used properly via `Events.OnServerStarted.Add(callback)`
- **Status**: SAFE - No compatibility issues

### ✅ Events.OnGameBoot
- Used properly via `Events.OnGameBoot.Add(callback)`
- **Status**: SAFE - No compatibility issues

### ✅ Events.OnClientCommand
- Used properly via `Events.OnClientCommand.Add(callback)`
- **Status**: SAFE - No compatibility issues

### ✅ Events.OnInitGlobalModData
- Used properly via `Events.OnInitGlobalModData.Add(callback)`
- **Status**: SAFE - No compatibility issues

### ✅ Events.OnPreFillInventoryObjectContextMenu
- Used properly via event registration
- **Status**: SAFE - No compatibility issues

### ✅ Events.OnPreFillWorldObjectContextMenu
- Used properly via event registration
- **Status**: SAFE - No compatibility issues

### ✅ Events.OnFillInventoryObjectContextMenu
- Used properly via event registration
- **Status**: SAFE - No compatibility issues

### ✅ Events.OnFillWorldObjectContextMenu
- Used properly via event registration
- **Status**: SAFE - No compatibility issues

### ✅ Custom Callback System (ShopPriceEvents, ShopSellEvents, ShopEvents)
- Properly implemented using custom event dispatcher pattern
- **Status**: SAFE - Allows multiple mods to register callbacks

---

## CRITICAL COMPATIBILITY CONFLICTS

### **[CRITICAL] ISInventoryTransferAction Conflict**
**Affected Mods**: SafeHouse, Container Permission systems, Trade mods
**Severity**: 🔴 **CRITICAL**

**Problem**: 
- Shops patches `ISInventoryTransferAction.start()` on client
- Shops patches `ISInventoryTransferAction.transferItem()` on server
- If SafeHouse or similar mods also patch these methods, only ONE patch loads
- The other mod's patch is completely overwritten

**Symptoms of Conflict**:
- Shop ownership checks may be bypassed by SafeHouse mods
- SafeHouse ownership checks may prevent legitimate shop transfers
- Transfer validation doesn't chain; it's all-or-nothing

**Example**:
```lua
-- If SafeHouse loads AFTER Shops:
-- Shops' oldStart is saved
-- SafeHouse saves Shops' method as oldStart
-- ISInventoryTransferAction.start now calls SafeHouse's wrapper
-- Which calls Shops' method
-- SAFE: Chaining works left-to-right (last load = outermost wrapper)

-- If SafeHouse loads BEFORE Shops:
-- SafeHouse saves original as oldStart
-- Shops saves SafeHouse's method as oldStart (WRONG!)
-- ISInventoryTransferAction.start now calls Shops' wrapper
-- Which calls SafeHouse's method
-- But Shops unknowingly called SafeHouse's method instead of original
-- May create double-validation or bypass issues
```

---

### **[CRITICAL] ISInventoryPage UI Hook Conflict**
**Affected Mods**: SafeHouse, UI enhancement mods, permission mods
**Severity**: 🔴 **CRITICAL**

**Problem**:
- Shops patches `ISInventoryPage.isRemoveButtonVisible()` to hide buttons for shop containers
- SafeHouse likely also patches this for safehouse containers
- Load order determines which mod's rules apply

**Symptoms of Conflict**:
- Remove buttons may be visible/hidden incorrectly
- Permission logic from one mod ignored
- No way for both mods to apply their rules simultaneously

---

### **[HIGH] ISToolTipInv Render Conflict**
**Affected Mods**: Enhanced Tooltip mods, Item Info Display mods
**Severity**: 🟡 **HIGH**

**Problem**:
- Shops patches tooltip rendering to suppress food items in shop UI
- Other tooltip enhancement mods may expect tooltips to always render
- Custom layout calculations in other mods may be disrupted

**Symptoms of Conflict**:
- Tooltip suppression logic from one mod ignored
- Tooltip positioning/layout issues
- Missing tooltip information from other mods

---

### **[CRITICAL] ISTransferAction Server-side Conflict**
**Affected Mods**: Any multiplayer permission system
**Severity**: 🔴 **CRITICAL**

**Problem**:
- Server-side transfer validation is mission-critical for multiplayer security
- If multiple mods patch transfer validation, only last patch loads
- Could allow bypassing safety checks or create permission conflicts

**Symptoms of Conflict**:
- Players transferring items they shouldn't be able to
- Multiplayer permission mods failing silently
- Security vulnerabilities in transfer validation

---

## RECOMMENDED SOLUTIONS

### **SHORT-TERM FIXES** (For Backward Compatibility)

1. **Use addClassicCallback Instead of Direct Patches**
   ```lua
   -- INSTEAD OF:
   local oldStart = ISInventoryTransferAction.start
   function ISInventoryTransferAction:start()
       ... 
       oldStart(self)
   end
   
   -- USE:
   local function ISInventoryTransferAction_start_wrapper(originalMethod)
       return function(self)
           -- Shops logic
           if not ShopsValidation(self) then return end
           return originalMethod(self)
       end
   end
   addClassicCallback("ISInventoryTransferAction.start", ISInventoryTransferAction_start_wrapper)
   ```

2. **Implement Mod Detection & Graceful Degradation**
   ```lua
   local function isModLoaded(modName)
       -- Check if another mod is loaded
       return getModList and getModList():contains(modName)
   end
   
   if not isModLoaded("SafeHouse") then
       -- Only apply patch if SafeHouse isn't loaded
       patchISInventoryTransferAction()
   end
   ```

3. **Create Abstraction Layer**
   ```lua
   -- Instead of patching vanilla methods directly:
   -- Create wrapper module that both mods call
   ShopsPermissionSystem = {
       canTransferItem = function(player, srcContainer, destContainer)
           -- Shops-specific logic
       end
   }
   ```

### **LONG-TERM FIXES** (Best Practice)

1. **Use PZ's Event System Exclusively**
   - Replace all vanilla function patches with custom event callbacks
   - Implement custom events like:
     - `Shops.Events.OnBeforeTransfer`
     - `Shops.Events.OnTooltipRender`
     - Allow other mods to register callbacks

2. **Implement Chainable Hook System**
   ```lua
   ShopsHooks = {
       callbacks = {},
       register = function(self, hookName, callback)
           if not self.callbacks[hookName] then
               self.callbacks[hookName] = {}
           end
           table.insert(self.callbacks[hookName], callback)
       end,
       call = function(self, hookName, ...)
           if not self.callbacks[hookName] then return end
           for _, callback in ipairs(self.callbacks[hookName]) do
               callback(...)
           end
       end
   }
   ```

3. **Document All Hooks Publicly**
   - Create public API for mod compatibility
   - Allow other mods to safely extend Shops behavior
   - Version the API for backward compatibility

---

## LOAD ORDER DEPENDENCY

**Current Issues**:
```
Load Order Matters:
┌─────────────────────┬──────────────────────┬─────────────────────┐
│ Loads First         │ Loads Second         │ Result              │
├─────────────────────┼──────────────────────┼─────────────────────┤
│ SafeHouse           │ Shops                │ Shops wins          │
│ Shops               │ SafeHouse            │ SafeHouse wins      │
│ Shops               │ UI Enhancement       │ UI Enhancement wins │
└─────────────────────┴──────────────────────┴─────────────────────┘
```

**Status**: 🔴 **FRAGILE** - Mod load order determines functionality

---

## SUMMARY TABLE

| Hooked Function | Type | Risk | Compatibility Issues | Solution |
|---|---|---|---|---|
| ISInventoryTransferAction.start() | Direct Patch | 🔴 HIGH | SafeHouse, Permission mods | Use Events/Callbacks |
| ISInventoryPage.isRemoveButtonVisible() | Direct Patch | 🔴 HIGH | UI mods, SafeHouse | Use Events/Callbacks |
| ISToolTipInv.render() | Direct Patch | 🟡 MEDIUM | Tooltip mods | Use Events/Callbacks |
| ISTransferAction.transferItem() | Direct Patch | 🔴 HIGH | Permission systems | Use Events/Callbacks |
| ISDestroyCursor.canDestroy() | Direct Patch | 🟡 MEDIUM | Destruction mods | Use Events/Callbacks |

---

## RECOMMENDATIONS FOR MOD CREATORS

If creating mods that need to interact with Shops:

1. **Don't patch vanilla methods directly** - Use Shops' custom event system
2. **Register callbacks with ShopEvents/ShopPriceEvents** - Follows proper pattern
3. **Check for conflicts** - Detect if other permission mods are loaded
4. **Provide fallback logic** - Handle cases where Shops isn't loaded
5. **Test load order combinations** - Verify works with common mod combinations

---

## FILES AFFECTED

### Client-side Patches
- `Shops/42.13.1/media/lua/client/patches/ISInventoryTransferActionPatch.lua`
- `Shops/42.13.1/media/lua/client/patches/ISInventoryPagePatch.lua`
- `Shops/42.13.1/media/lua/client/patches/ISToolTipInvPatch.lua`

### Server-side Patches
- `Shops/42.13.1/media/lua/server/patches/ISTransferActionPatch.lua`
- `Shops/42.13.1/media/lua/server/patches/ISDestroyCursorPatch.lua`

---

**Last Updated**: 2025-12-28
**Analysis Version**: 1.0
