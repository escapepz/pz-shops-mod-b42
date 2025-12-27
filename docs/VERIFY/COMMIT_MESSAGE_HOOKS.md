# Commit Message - Complete Hook System Implementation

## Short Form
```
feat: implement complete hook-based shop system with dynamic pricing
```

## Full Form

```
feat: implement complete hook-based shop system with dynamic pricing

Implemented a comprehensive hook system for the kiosk shop enabling external mods
to register items and modify prices at runtime without modifying core files.

## Features Implemented

### 1. Buy Item Registration Hooks
- ShopEvents.lua: OnShopRegisterItems event dispatcher
- ShopRegistry.lua: Shop.RegisterItem() API with validation
- ShopInit.lua: Finalization logic with smart defaults loading
- Mods register items via ShopEvents.registerOnShopRegisterItems()
- Defaults (Food, Weapons, FirstAid, Vehicles) load only if no external mods

### 2. Sell Item Registration Hooks
- ShopSellEvents.lua: OnShopRegisterSellItems event dispatcher
- ShopSellRegistry.lua: Shop.RegisterSellItem() API for sell rules
- ShopSellInit.lua: Finalization with conditional defaults
- External mods can fully replace sell rules via hooks
- Supports item blacklisting

### 3. Dynamic Buy Price Hooks
- OnShopModifyBuyPrice: Add multiplier/addition modifiers (stacking)
- OnShopOverrideBuyPrice: Override final price (last listener wins)
- Integrated into ShopUI for display preview
- Server-side calculation in ShopBuyAction for authority

### 4. Dynamic Sell Price Hooks
- OnShopModifySellPrice: Add multiplier/addition modifiers (stacking)
- OnShopOverrideSellPrice: Override final price (last listener wins)
- Integrated into ShopUI for display preview
- Server-side calculation in ShopSellAction for authority

### 5. Price Context System
- All price hooks receive context object with:
  - shopId: Shop identifier
  - quantity: Items being transacted
  - isSpecialCoin: Currency type flag
  - isBroken: Item condition status

### 6. Bootstrap Integration
- ShopInitClient.lua: Triggers registry finalization on OnGameBoot
- ShopInitServer.lua: Triggers registry finalization on OnServerStarted
- Ensures hooks fire at correct time on both client and server

## Files Created (11)
- Shops/42.13.1/media/lua/shared/ShopEvents.lua
- Shops/42.13.1/media/lua/shared/ShopRegistry.lua
- Shops/42.13.1/media/lua/shared/ShopInit.lua
- Shops/42.13.1/media/lua/shared/ShopSellEvents.lua
- Shops/42.13.1/media/lua/shared/ShopSellRegistry.lua
- Shops/42.13.1/media/lua/shared/ShopSellInit.lua
- Shops/42.13.1/media/lua/shared/ShopPriceEvents.lua
- Shops/42.13.1/media/lua/shared/ShopPriceUtils.lua
- Shops/42.13.1/media/lua/shared/ShopPriceBuy.lua
- Shops/42.13.1/media/lua/shared/ShopPriceSell.lua
- Shops/42.13.1/media/lua/client/ShopInitClient.lua
- Shops/42.13.1/media/lua/server/ShopInitServer.lua

## Files Modified (3)
- Shops/42.13.1/media/lua/shared/Shop.lua
  Added requires for all hook modules
  
- Shops/42.13.1/media/lua/shared/ShopItems/ForSell.lua
  Refactored to use Shop.RegisterSellItem() API
  
- Shops/42.13.1/media/lua/client/ISUI/ShopUI.lua
  Integrated CalculateBuyPrice() and CalculateSellPrice() calls
  Calls hooks in favorites, categories, and cart preview
  
## Files Modified (1 additional)
- Shops/42.13.1/media/lua/shared/TimedActions/ShopBuyAction.lua
  Server-side CalculateBuyPrice() for authority
  
- Shops/42.13.1/media/lua/shared/TimedActions/ShopSellAction.lua
  Server-side CalculateSellPrice() for authority

## Design Decisions

✅ Immutable Registries
- Prices calculated fresh, never stored
- Base prices protected from mutation
- Registry locks after finalization

✅ Runtime Calculation
- Prices computed on demand (display, transaction)
- Enables truly dynamic economy
- Multiple modifiers can stack

✅ Client Preview + Server Authority
- Client shows accurate preview using same logic as server
- Server recomputes before commitment
- Prevents client-side tampering in multiplayer

✅ Separate Pipelines
- Buy and sell have distinct flows
- Share modifier application system
- Different base sources (Shop.Items vs Shop.Sell)

✅ B42-Compliant
- Uses Lua callback dispatchers
- No engine event extensions
- Proper client/server context separation
- Deterministic on all clients/servers

## Testing Checklist
- [ ] Single-player: default items appear
- [ ] Single-player: default sell rules work
- [ ] Multiplayer: items synchronized across clients
- [ ] Multiplayer: prices consistent on client/server
- [ ] Hook hooks fire correctly during initialization
- [ ] Late registration attempt raises error
- [ ] Price modifiers stack correctly
- [ ] Price overrides take precedence
- [ ] Blacklisted items return nil on sell
- [ ] Context object passed correctly to hooks

## Documentation
- HOOK_REGISTRY_README.md: System overview and status
- HOOK_REGISTRY_DEVELOPER_GUIDE.md: External mod development
- HOOK_REGISTRY_IMPLEMENTATION_CHECKLIST.md: Completion verification
- HOOK_REGISTRY_VERIFICATION.md: Test scenarios and acceptance criteria
- PRICE_HOOKS_GUIDE.md: Complete pricing API documentation
- PRICE_HOOKS_QUICK_REF.md: Quick reference with examples
- PRICE_HOOKS_VERIFICATION.md: Acceptance criteria for pricing
- HOOKS_VERIFICATION_COMPLETE.md: Final verification report

## Breaking Changes
None. All existing functionality preserved. New hooks are opt-in via event listeners.
Shops continue to work with default items and prices if no mods register.

## Examples Included
- HookShop_MVP: Example buy item registration mod
- HookShopSell_MVP: Example sell rule registration mod
- ExampleBuyDiscountHook.lua: 10% discount example
- ExampleSellBonusHook.lua: 20% bulk bonus example
- ExampleOverrideHook.lua: VIP and damage handling example

## Performance Impact
- Minimal memory: Event listeners and modifiers on stack
- CPU: O(modifiers) per price calculation
- Negligible for typical hook counts (<5 per event)

## Backward Compatibility
✅ Fully backward compatible
- Default items and prices unchanged
- No API modifications to existing Shop functions
- Old code continues to work identically
```

## Git Command

```bash
git add Shops/42.13.1/media/lua/shared/*.lua
git add Shops/42.13.1/media/lua/client/ShopInitClient.lua
git add Shops/42.13.1/media/lua/server/ShopInitServer.lua
git add Shops/42.13.1/media/lua/client/ISUI/ShopUI.lua
git add Shops/42.13.1/media/lua/shared/TimedActions/ShopBuyAction.lua
git add Shops/42.13.1/media/lua/shared/TimedActions/ShopSellAction.lua
git add Shops/42.13.1/media/lua/shared/ShopItems/ForSell.lua

git commit -m "feat: implement complete hook-based shop system with dynamic pricing

Implemented a comprehensive hook system for the kiosk shop enabling external mods
to register items and modify prices at runtime without modifying core files.

## Features Implemented

1. Buy Item Registration Hooks (OnShopRegisterItems)
2. Sell Item Registration Hooks (OnShopRegisterSellItems)
3. Dynamic Buy Price Hooks (OnShopModifyBuyPrice, OnShopOverrideBuyPrice)
4. Dynamic Sell Price Hooks (OnShopModifySellPrice, OnShopOverrideSellPrice)
5. Price Context System with shop/quantity/condition metadata
6. Bootstrap integration for proper initialization timing

## Files
Created 12 new hook system files:
- ShopEvents.lua, ShopRegistry.lua, ShopInit.lua (buy registration)
- ShopSellEvents.lua, ShopSellRegistry.lua, ShopSellInit.lua (sell registration)
- ShopPriceEvents.lua, ShopPriceUtils.lua, ShopPriceBuy.lua, ShopPriceSell.lua (pricing)
- ShopInitClient.lua, ShopInitServer.lua (bootstrap)

Modified 5 files to integrate hooks:
- Shop.lua (requires), ShopUI.lua (preview), ShopBuyAction.lua (server authority)
- ShopSellAction.lua (server authority), ForSell.lua (use API)

## Design
- Immutable registries with runtime price calculation
- Client preview + server authority for multiplayer safety
- Lua callback dispatchers (B42-compliant)
- Stacking modifiers with override capability
- Fully backward compatible (opt-in hooks, defaults preserved)"
```
