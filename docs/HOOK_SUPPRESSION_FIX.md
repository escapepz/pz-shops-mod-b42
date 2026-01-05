# Hook Suppression Architecture Fix

## Problem Statement

The original implementation checked the suppression flag at **execution time**:

```lua
-- BROKEN: Execution-time check
function ShopDefaultItems.loadDefaultBuyItems()
    if Shop._suppressDefaults then
        return  -- Too late - callback is already registered
    end
    require("nshopsb42/ShopItems/Food")
end

function ShopDefaultItems.registerHooks()
    ShopEvents.registerOnShopRegisterItems(ShopDefaultItems.loadDefaultBuyItems)  -- ← Registered unconditionally
end
```

**Consequence**: The hook is registered regardless of suppression intent. When `triggerOnShopRegisterItems()` executes, it will always invoke the callback.

---

## Root Cause Analysis

From log `2026-01-04_04-27_Shops.txt`:

```
Line 16: [ShopsHooksExample] Suppressing vanilla default items.
Line 32: Hooks registered for item registration: 2.
Line 34: Executing callback 1.
Lines 35-59: Vanilla items loaded (Apple, Banana, Axe, etc.)
```

**Why this happened:**
1. ShopsHooksExample set `SHOPSB42.Config.suppressDefaults = true`
2. ShopInitServer.Initialize() called
3. ShopDefaultItems.registerHooks() registered hook **unconditionally**
4. finalizeNow() executed registered hooks in order
5. loadDefaultBuyItems() checked suppressDefaults at execution time, but was too late

**The check never had a chance to prevent registration.**

---

## Architectural Principle

> **Hooks are declarations, not suggestions.**
> 
> If a behavior must be suppressible, it must not be registered in the first place.

Checking the flag during execution is semantically equivalent to:
- Register the callback
- Execute it
- But have it exit early

This is wasteful and confusing. It signals "this might be wanted" when the real intent is "this is conditional."

---

## The Fix: Registration-Time Gating

Check the suppression flag **before** registering the hook:

```lua
-- CORRECT: Registration-time check
function ShopDefaultItems.registerHooks()
    if not Utilities.IsServerOrSinglePlayer() then
        return
    end

    -- Gate registration based on suppression flag
    if SHOPSB42.Config.suppressDefaults == true then
        SharedLogger.log("Shops", "[ShopDefaultItems] Suppression flag detected - default hooks NOT registered")
        return  -- Never register at all
    end

    -- Only register if suppression is false
    if ShopEvents and ShopEvents.registerOnShopRegisterItems then
        ShopEvents.registerOnShopRegisterItems(ShopDefaultItems.loadDefaultBuyItems)
    end

    if ShopSellEvents and ShopSellEvents.registerOnShopRegisterSellItems then
        ShopSellEvents.registerOnShopRegisterSellItems(ShopDefaultItems.loadDefaultSellItems)
    end
end
```

The callback bodies are **now unconditional** (no suppression check needed):

```lua
function ShopDefaultItems.loadDefaultBuyItems()
    if not Utilities.IsServerOrSinglePlayer() then
        return
    end
    
    require("nshopsb42/ShopItems/Food")
    require("nshopsb42/ShopItems/Weapons")
    require("nshopsb42/ShopItems/FirstAid")
    require("nshopsb42/ShopItems/Vehicles")
    require("nshopsb42/ShopItems/Event")
end
```

---

## Behavioral Guarantees

### Before Fix
```
suppress flag set = true  →  Hook registered  →  Hook executes, checks flag, exits early
suppress flag set = false →  Hook registered  →  Hook executes, loads items
```

**Problem**: Unconditional registration wastes CPU and obscures intent.

### After Fix
```
suppress flag = true  →  Hook NOT registered  →  Never executes
suppress flag = false →  Hook registered  →  Executes, loads items
```

**Benefit**: Clear, deterministic, efficient.

---

## Timing Requirements

The suppression flag must be set **before** `ShopDefaultItems.registerHooks()` is called:

1. **External mod initializes** (early, in mod init)
   ```lua
   SHOPSB42.Config.suppressDefaults = true
   ```

2. **ShopInitServer.Initialize() called** (in Events.OnServerStarted)
   ```lua
   ShopDefaultItems.registerHooks()  -- Checks flag, decides to register or not
   ```

3. **ShopFinalizeHandler.finalizeNow() called**
   ```lua
   ShopEvents.triggerOnShopRegisterItems()  -- Executes only registered hooks
   ```

---

## Expected Log Output

### With Suppression Disabled (default)
```
[ShopInitServer] Calling registerHooks()...
[ShopBuyInit] Hooks registered for item registration: 2.
[ShopBuyInit] Phase 1: Executing 2 hook(s)...
[ShopEvents] Executing callback 1.
RegisterItem: Base.Apple...
RegisterItem: Base.Banana...
[ShopsHooksExample] Buy listings registered: 25 items.
[ShopEvents] Executing callback 2.
[ShopBuyInit] Phase 2: Registering 33 items...
```

### With Suppression Enabled
```
[ShopDefaultItems] Suppression flag detected - default hooks NOT registered
[ShopInitServer] Calling registerHooks()...
[ShopBuyInit] Hooks registered for item registration: 1.
[ShopBuyInit] Phase 1: Executing 1 hook(s)...
[ShopEvents] Executing callback 1.
[ShopsHooksExample] Buy listings registered: 25 items.
[ShopBuyInit] Phase 2: Registering 25 items...
```

Notice: "Hooks registered: **1**" (not 2) → only ShopsHooksExample callback is in registry.

---

## Files Changed

| File | Change | Reason |
|------|--------|--------|
| `ShopDefaultItems.lua` | Move suppression check from callback bodies to `registerHooks()` | Prevent registration |
| `EXTERNAL_MOD_INTEGRATION.md` | Document registration-time semantics | Clarify correct usage |

---

## Backward Compatibility

**Breaking Change**: No.

External mods that set `SHOPSB42.Config.suppressDefaults = true` before `ShopInitServer.Initialize()` will continue to work exactly as intended—only more efficiently.

Mods that never set the flag are unaffected (defaults still load).

---

## Verification

After deploying this fix, confirm via server logs:

1. **With suppression enabled**:
   - Look for: `[ShopDefaultItems] Suppression flag detected`
   - Verify: Only external mod hooks appear in registry
   - Verify: No vanilla items logged during item registration

2. **With suppression disabled**:
   - Look for: Vanilla items (Apple, Banana, Axe, etc.) logged
   - Verify: Both default and external hooks in registry
   - No suppression message logged
