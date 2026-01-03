# External Mod Integration Guide - Shops Hook System

## Overview

The Shops mod uses a **callback-based hook system** for external mods to register custom items without loading default items. This document traces the initialization flow and provides the correct integration patterns.

## Initialization Flow

### Timeline: Events.OnServerStarted → Shop Finalization

```
Events.OnServerStarted
  ↓
AServerInit.lua (line 28)
  ├─ PSServer.Initialize()
  └─ ShopInitServer.Initialize()
       ↓
       ShopDefaultItems.registerHooks()
         ├─ ShopEvents.registerOnShopRegisterItems(ShopDefaultItems.loadDefaultBuyItems)
         └─ ShopSellEvents.registerOnShopRegisterSellItems(ShopDefaultItems.loadDefaultSellItems)
       ↓
       ShopFinalizeHandler.finalizeNow()
         ├─ Shop.FinalizeRegistry()
         │   └─ ShopEvents.triggerOnShopRegisterItems()
         │       ├─ Execute DEFAULT items: ShopDefaultItems.loadDefaultBuyItems()
         │       │   └─ Check: if Shop._suppressDefaults then return
         │       └─ Execute EXTERNAL mods callbacks
         ├─ Shop.FinalizeSellRegistry()
         │   └─ ShopSellEvents.triggerOnShopRegisterSellItems()
         │       ├─ Execute DEFAULT items: ShopDefaultItems.loadDefaultSellItems()
         │       │   └─ Check: if Shop._suppressDefaults then return
         │       └─ Execute EXTERNAL mods callbacks
         └─ Cache price modifiers & broadcast to clients
```

## Key Files in Hook System

| File | Purpose | Key Functions |
|------|---------|---|
| `ShopDefaultItems.lua` | Default item loader | `registerHooks()`, `loadDefaultBuyItems()`, `loadDefaultSellItems()` |
| `ShopEvents.lua` | Buy item hook dispatcher | `registerOnShopRegisterItems()`, `triggerOnShopRegisterItems()` |
| `ShopSellEvents.lua` | Sell item hook dispatcher | `registerOnShopRegisterSellItems()`, `triggerOnShopRegisterSellItems()` |
| `ShopInit.lua` | Buy registry finalizer | `Shop.FinalizeRegistry()` |
| `ShopSellInit.lua` | Sell registry finalizer | `Shop.FinalizeSellRegistry()` |
| `ShopFinalizeHandlerServer.lua` | Final sync handler | `finalizeNow()` |

## External Mod Integration Pattern

### Option A: Register During Events.OnServerStarted (RECOMMENDED)

Register your hook **after** `ShopInitServer` is loaded but **before** or **during** the `Events.OnServerStarted` event.

```lua
-- ExternalMod/Init.lua (Server context)
local ShopEvents = SHOPSB42.ShopEvents
local ShopSellEvents = SHOPSB42.ShopSellEvents

Events.OnServerStarted.Add(function()
    -- Register buy items
    ShopEvents.registerOnShopRegisterItems(function()
        -- Your custom item registration code
        SHOPSB42.Shop.RegisterItem("mymod.sword", {
            tab = SHOPSB42.Shop.Tab.Weapons,
            price = 500,
            -- ... item config
        })
    end)
    
    -- Register sell items
    ShopSellEvents.registerOnShopRegisterSellItems(function()
        SHOPSB42.Shop.RegisterSellItem("mymod.sword", {
            price = 250,
            -- ... sell config
        })
    end)
end)
```

### Option B: Direct Hook Registration (If ShopEvents Available)

If you need to register during early initialization:

```lua
-- ExternalMod/Init.lua
if SHOPSB42 and SHOPSB42.ShopEvents then
    SHOPSB42.ShopEvents.registerOnShopRegisterItems(function()
        -- Register buy items
    end)
    SHOPSB42.ShopSellEvents.registerOnShopRegisterSellItems(function()
        -- Register sell items
    end)
end
```

## How to Avoid Loading Default Items

### Method 1: Suppress Defaults (if using ONLY custom items)

Set the suppression flag **before hooks are registered**. Use `SHOPSB42.Config.suppressDefaults`:

```lua
-- In your mod's early initialization (before ShopInitServer.Initialize is called)
if SHOPSB42 then
    SHOPSB42.Config.suppressDefaults = true
end
```

When `ShopDefaultItems.registerHooks()` is called, it checks this flag **at registration time**:

```lua
function ShopDefaultItems.registerHooks()
    -- Suppression check happens HERE (registration time, not execution time)
    if SHOPSB42.Config.suppressDefaults == true then
        SharedLogger.log("Shops", "Suppression flag detected - default hooks NOT registered")
        return  -- Never register the hooks in the first place
    end
    
    -- Only register if suppression is false
    ShopEvents.registerOnShopRegisterItems(ShopDefaultItems.loadDefaultBuyItems)
    ShopSellEvents.registerOnShopRegisterSellItems(ShopDefaultItems.loadDefaultSellItems)
end
```

**Why check at registration time?**
- ✅ Prevents ghost callbacks from being added to the registry
- ✅ No wasted execution of unwanted hooks
- ✅ Clear intent: "don't register this at all"
- ✅ Matches expected mod-override semantics
- ❌ Execution-time checks are insufficient (hook is already registered)

**Why `SHOPSB42.Config` instead of `Shop`?**
- Config is a **policy surface**, not runtime state
- Survives reloads
- Explicit `== true` check prevents accidental re-enabling
- Clear ownership (configuration vs runtime)

### Method 2: Selective Override (Keep Defaults + Add Custom)

Don't suppress defaults. Instead, register your custom items alongside defaults:

```lua
ShopEvents.registerOnShopRegisterItems(function()
    -- Defaults + your custom items
    SHOPSB42.Shop.RegisterItem("mymod.customsword", {
        tab = SHOPSB42.Shop.Tab.Weapons,
        price = 750,
    })
end)
```

## Hook Callback Execution Order

Callbacks registered via `registerOnShopRegisterItems()` are executed in **registration order**:

1. **First**: `ShopDefaultItems.loadDefaultBuyItems` (registered in `ShopDefaultItems.registerHooks()`)
   - Unless `Shop._suppressDefaults = true`
   - Loads: Food, Weapons, FirstAid, Vehicles, Event

2. **Then**: All external mod callbacks (in registration order)
   - Each mod's hook is called via `table.insert(ShopEvents.OnShopRegisterItems, callback)`

3. **After all hooks execute**: Items are committed to `Shop.PlayerBuy` registry

## Price Hooks vs Item Registration Hooks

**Item Registration Hooks** (what we discussed above):
- Called during finalization to **gather item definitions**
- Single execution per server startup
- Used to add items to registries

**Price Modification Hooks**:
- Called at **transaction time** to adjust prices
- Can be registered anytime (live updates supported)
- Examples: `OnShopModifyBuyPrice`, `OnShopOverrideBuyPrice`

## Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| Default items still loading | `_suppressDefaults` not set before hooks register | Set flag in your mod's earliest initialization |
| Custom items not showing | Hook registered too late | Register during `Events.OnServerStarted` |
| Hooks not executing | `ShopEvents` not available | Wait for Shops mod to load first |
| Items registered twice | Hook called multiple times | Ensure hook only registers once per server |

## When Each Hook Phase Runs

```lua
-- Timeline with line numbers from source:

1. AServerInit.lua:28 → Events.OnServerStarted added
   └─ Fires when server starts

2. ShopInitServer.Initialize():45 → ShopDefaultItems.registerHooks()
   └─ HOOKS ARE REGISTERED (not executed yet)

3. ShopFinalizeHandler.finalizeNow():259-267
   ├─ Shop.FinalizeRegistry():40
   │  └─ ShopEvents.triggerOnShopRegisterItems():20
   │     └─ ALL CALLBACKS EXECUTE HERE (defaults + external mods)
   └─ Shop.FinalizeSellRegistry():16
      └─ ShopSellEvents.triggerOnShopRegisterSellItems():17
         └─ ALL SELL CALLBACKS EXECUTE HERE
```

## Best Practice Example: Complete External Mod

```lua
-- MyMod/42.13.1/media/lua/server/mymod/MyModInit.lua

local SharedLogger = require("nshopsb42/utils/SharedLogger")

local MyModInit = {}

function MyModInit.registerShopItems()
    local ShopEvents = SHOPSB42.ShopEvents
    local ShopSellEvents = SHOPSB42.ShopSellEvents
    
    -- Register buy items
    ShopEvents.registerOnShopRegisterItems(function()
        SharedLogger.log("MyMod", "Registering custom buy items")
        
        SHOPSB42.Shop.RegisterItem("mymod.rifle", {
            tab = SHOPSB42.Shop.Tab.Weapons,
            price = 1500,
            name = "Custom Rifle",
        })
        
        SHOPSB42.Shop.RegisterItem("mymod.ammo", {
            tab = SHOPSB42.Shop.Tab.Weapons,
            price = 50,
            name = "Custom Ammo Box",
        })
    end)
    
    -- Register sell items
    ShopSellEvents.registerOnShopRegisterSellItems(function()
        SharedLogger.log("MyMod", "Registering custom sell items")
        
        SHOPSB42.Shop.RegisterSellItem("mymod.rifle", {
            price = 750,
        })
        
        SHOPSB42.Shop.RegisterSellItem("mymod.ammo", {
            price = 25,
        })
    end)
end

Events.OnServerStarted.Add(function()
    if SHOPSB42 and SHOPSB42.ShopEvents then
        MyModInit.registerShopItems()
    else
        SharedLogger.log("MyMod", "WARNING: Shops mod not loaded")
    end
end)

return MyModInit
```

## Reference: ShopDefaultItems.lua Flow

```lua
-- ShopDefaultItems.lua line 48-60
function ShopDefaultItems.registerHooks()
    if not Utilities.IsServerOrSinglePlayer() then
        return
    end
    
    -- Register the callback (not execute yet)
    if ShopEvents and ShopEvents.registerOnShopRegisterItems then
        ShopEvents.registerOnShopRegisterItems(ShopDefaultItems.loadDefaultBuyItems)
    end
    
    if ShopSellEvents and ShopSellEvents.registerOnShopRegisterSellItems then
        ShopSellEvents.registerOnShopRegisterSellItems(ShopDefaultItems.loadDefaultSellItems)
    end
end

-- Called DURING triggerOnShopRegisterItems() execution
-- Lines 16-31
function ShopDefaultItems.loadDefaultBuyItems()
    if not Utilities.IsServerOrSinglePlayer() then
        return
    end
    
    -- THIS IS THE SUPPRESS FLAG CHECK
    if Shop._suppressDefaults then
        return
    end
    
    require("nshopsb42/ShopItems/Food")
    require("nshopsb42/ShopItems/Weapons")
    require("nshopsb42/ShopItems/FirstAid")
    require("nshopsb42/ShopItems/Vehicles")
    require("nshopsb42/ShopItems/Event")
end
```

## Summary

1. **Hook registration** happens in `ShopDefaultItems.registerHooks()` (called ~line 45 of ShopInitServer)
2. **Hook execution** happens during `Shop.FinalizeRegistry()` and `Shop.FinalizeSellRegistry()` (called from `finalizeNow()`)
3. **To avoid defaults**: Set `Shop._suppressDefaults = true` before initialization
4. **To add custom items**: Register callback via `ShopEvents.registerOnShopRegisterItems(callback)`
5. **Safe timing**: Register during `Events.OnServerStarted` to ensure Shops mod is loaded
