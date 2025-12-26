# Hook-Based Shop Registry - Implementation Summary

## Overview
Implemented a deterministic, hook-based shop registry system that allows external mods to register shop items without modifying core mod files. All items now register through `Shop.RegisterItem()` API with a fallback to defaults if no external registrations occur.

## Files Created (10)

### Core Registry (3 files)
1. **Shops/42.13.1/media/lua/shared/ShopRegistry.lua**
   - Shop registration API: `Shop.RegisterItem(itemId, def)`
   - Pending registration queue
   - External registration detection flag
   - Registry lock mechanism

2. **Shops/42.13.1/media/lua/shared/ShopEvents.lua**
   - Event definition: `Events.OnShopRegisterItems`
   - Entry point for external mods

3. **Shops/42.13.1/media/lua/shared/ShopInit.lua**
   - Registry finalization function
   - Conditional default loading
   - Item validation
   - Three-phase initialization (trigger event → load defaults → commit & lock)

### Initialization Hooks (2 files)
4. **Shops/42.13.1/media/lua/client/ShopInitClient.lua**
   - Hooks registry finalization to `OnGameBoot`

5. **Shops/42.13.1/media/lua/server/ShopInitServer.lua**
   - Hooks registry finalization to `OnServerStarted`

### Default Items Updated (5 files)
6. **Shops/42.13.1/media/lua/shared/ShopItems/Food.lua**
7. **Shops/42.13.1/media/lua/shared/ShopItems/Weapons.lua**
8. **Shops/42.13.1/media/lua/shared/ShopItems/FirstAid.lua**
9. **Shops/42.13.1/media/lua/shared/ShopItems/Vehicles.lua**
10. **Shops/42.13.1/media/lua/shared/ShopItems/Event.lua**

All default items converted from direct `Shop.Items[...] = {...}` to `Shop.RegisterItem(...)`

### MVP External Hooks Mod (2 files)
11. **Shops/common/HookShop_MVP/mod.info**
    - Declares dependency on Shops
    - Demonstrates external mod structure

12. **Shops/common/HookShop_MVP/media/lua/shared/HookShop_Register.lua**
    - Registers 2 items via `OnShopRegisterItems` event
    - Proves system works without core file edits
    - Shows defaults are skipped when external registration occurs

## Files Modified (1)

**Shops/42.13.1/media/lua/shared/Shop.lua**
- Added requires for ShopRegistry, ShopEvents, ShopInit
- Maintains all existing Tab definitions and textures

## Behavior Changes

### Before
```lua
Shop.Items["Base.Crowbar"] = {
    tab = Tab.Weapons,
    price = 250
}
```

### After
```lua
Shop.RegisterItem("Base.Crowbar", {
    tab = Tab.Weapons,
    price = 250
})
```

## System Flow

```
Boot/ServerStart
  ↓
OnGameBoot / OnServerStarted fires
  ↓
Shop.FinalizeRegistry() called
  ↓
Events.OnShopRegisterItems.Trigger()
  ↓
External mods register items (optional)
  ↓
IF no external registrations:
  └─→ loadDefaultItems() loads all 5 default files
  └─→ Each file calls Shop.RegisterItem()
  ↓
Pending registrations committed to Shop.Items
  ↓
Registry locked (_locked = true)
```

## Key Properties

| Property | Value |
|----------|-------|
| **Deterministic** | ✓ Registry finalizes once at startup |
| **MP-Safe** | ✓ All clients/servers sync automatically |
| **Non-Invasive** | ✓ External mods don't need core edits |
| **Backward Compatible** | ✓ Item structure unchanged |
| **Validated** | ✓ All items validated before commit |
| **Locked** | ✓ No late mutations possible |

## Testing Scenarios

### Scenario 1: Default Only (MVP Mod Disabled)
- Shop.Items contains all 5 default items
- `_hasExternalRegistrations = false`

### Scenario 2: MVP Mod (MVP Mod Enabled)
- Shop.Items contains only Katana + MedicalPack
- Defaults completely skipped
- `_hasExternalRegistrations = true`

### Scenario 3: Late Registration (Invalid)
- Calling RegisterItem after finalization raises error
- Registry unchanged

## Next Steps (Post-MVP)

These features were explicitly NOT implemented (per design):
- Hot reload
- Runtime mutation  
- Per-tab merging
- Admin overrides
- UI refresh logic

These are appropriate for future extensions after core registry stabilizes.

## Documentation

- **HOOK_REGISTRY_VERIFICATION.md** - Detailed verification matrix
- **IMPLEMENTATION_SUMMARY.md** - This file
- **Inline code comments** - Added to all new files

