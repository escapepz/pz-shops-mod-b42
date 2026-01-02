# Module Loading Analysis - Require() Tracing Report

## Critical Issues Found

### 1. ✅ CORRECT: Timed Action Classes in Shared Folder
**Status: CORRECT LOCATION**

**Per B42.13 API Guide** (`docs/GUIDE/timedaction.md`, line 15):
- **Timed Actions MUST be in `media/lua/shared` folder**
- Reason: Actions execute `perform()` on client and `complete()` on server
- Class definition must exist on **both sides** for NetAction reconstruction

**Timed action modules (correctly in shared/):**
- `Shops/42.13.1/media/lua/shared/nshopsb42/timers/ShopSellAction.lua` ✅
- `Shops/42.13.1/media/lua/shared/nshopsb42/timers/ShopBuyAction.lua` ✅
- `Shops/42.13.1/media/lua/shared/nshopsb42/timers/SendTransferAction.lua` ✅
- `Shops/42.13.1/media/lua/shared/nshopsb42/timers/PlayerShopBuyAction.lua` ✅
- `Shops/42.13.1/media/lua/shared/nshopsb42/timers/ISAddShopAction.lua` ✅
- `Shops/42.13.1/media/lua/shared/nshopsb42/timers/ISAddPlayerShopAction.lua` ✅

**Loading location:**
- ASharedInit.lua (lines 43-49) ✅

**Note**: ISBaseTimedAction dependency is fine because:
- PZ engine loads all `.lua` files automatically (regardless of folder)
- `require()` only controls execution order, not scope
- ISBaseTimedAction is available on both client and server

---

## Summary of Module Categories

### Shared Modules (Correct Location)
These should load on both server and client:
- `nshopsb42/core/Shop.lua` ✅
- `nshopsb42/core/Balance.lua` ✅
- `nshopsb42/core/Currency.lua` ✅
- `nshopsb42/core/ShopRegistry.lua` ✅
- `nshopsb42/core/PlayerShop.lua` ✅
- `nshopsb42/core/TransactionRegistry.lua` ✅
- `nshopsb42/sales/ShopSellRegistry.lua` ✅
- `nshopsb42/sales/ShopSellEvents.lua` ✅
- `nshopsb42/events/ShopEvents.lua` ✅
- `nshopsb42/utils/SharedLogger.lua` ✅
- `nshopsb42/utils/Utilities.lua` ✅
- `nshopsb42/utils/Nfunction.lua` ✅
- `nshopsb42/ShopInit.lua` ✅
- `nshopsb42/ShopDefaultItems.lua` ✅
- `nshopsb42/audit/ShopAudit.lua` ✅
- `nshopsb42/pricing/ShopPrice*.lua` (all) ✅
- `nshopsb42/validation/InventoryTransferValidation.lua` ✅

### Server-Only Modules (Correct Location)
- `nshopsb42/balance/BalanceServer.lua` ✅
- `nshopsb42/balance/BalanceAudit.lua` ✅
- `nshopsb42/logging/LogsServer.lua` ✅
- `nshopsb42/transactions/ShopFinalizeHandlerServer.lua` ✅
- `nshopsb42/transactions/ShopCommandHandlerServer.lua` ✅
- `nshopsb42/transactions/ShopTransactionValidationServer.lua` ✅
- `nshopsb42/PlayerShopServer.lua` ✅
- `nshopsb42/ShopInitServer.lua` ✅
- `nshopsb42/ShopCommandDispatcherServer.lua` ✅
- `nshopsb42/TestPriceHooks.lua` ✅
- `nshopsb42/TestPriceHooksCommand.lua` ✅

### Client-Only Modules (Correct Location)
- `nshopsb42/balance/BalanceClient.lua` ✅
- `nshopsb42/ui/*.lua` (all UI components) ✅
- `nshopsb42/sync/ShopSyncClient.lua` ✅
- `nshopsb42/sync/ModDataDispatcherClient.lua` ✅
- `nshopsb42/context/*.lua` (context menus) ✅
- `nshopsb42/patches/*.lua` (UI patches) ✅
- `nshopsb42/PlayerShopClient.lua` ✅
- `nshopsb42/transactions/ShopSpriteCursorUI.lua` ✅

### Shared Modules (Timed Actions - Special Case)
Per B42.13 API guide, timed actions **must be shared**:
- **`nshopsb42/timers/ShopSellAction.lua`** ✅ (shared - correct location)
- **`nshopsb42/timers/ShopBuyAction.lua`** ✅ (shared - correct location)
- **`nshopsb42/timers/SendTransferAction.lua`** ✅ (shared - correct location)
- **`nshopsb42/timers/PlayerShopBuyAction.lua`** ✅ (shared - correct location)
- **`nshopsb42/timers/ISAddShopAction.lua`** ✅ (shared - correct location)
- **`nshopsb42/timers/ISAddPlayerShopAction.lua`** ✅ (shared - correct location)

---

## Potential Future Issues

### 1. Server-Only Modules Imported in Shared Context
**Current state**: None detected ✅

### 2. Client-Only Modules Imported in Server Context
**Current state**: Only ISBaseTimedAction-dependent classes (NOW FIXED) ✅

### 3. Cross-Loading Patterns
All module loading follows correct patterns:
- ASharedInit.lua → Loads shared modules only ✅
- AServerInit.lua → Loads server modules + shared modules ✅
- AClientInit.lua → Loads client modules + shared modules ✅

---

## Require() Chain Verification

### Valid Chains ✅
1. **Shared modules** can require other shared modules
2. **Server modules** can require shared + server modules
3. **Client modules** can require shared + client modules

### Invalid Chains ❌ (Not Found)
1. Shared modules requiring client modules - NOT FOUND ✅
2. Shared modules requiring server modules - NOT FOUND ✅
3. Server modules requiring client modules - NOT FOUND ✅

---

## Load Order in Each Context

### ASharedInit.lua (Loads on both server & client)
1. SharedLogger ✅
2. Utilities ✅
3. Core modules (Shop, Balance, Currency, etc.) ✅
4. Event systems ✅
5. Item registration ✅

### AServerInit.lua (Server-only)
1. ShopInitServer ✅
2. PlayerShopServer ✅
3. Balance/Audit systems ✅
4. Command handlers ✅
5. Command dispatcher ✅
6. Patches ✅

### AClientInit.lua (Client-only)
1. Shared core modules ✅
2. PlayerShopClient ✅
3. BalanceClient ✅
4. **Timed actions** ✅ (NOW PROPERLY LOADED BEFORE UI)
5. UI components ✅
6. Context managers ✅
7. Patches ✅
8. Sync clients ✅
9. Dispatchers ✅

---

## Conclusion

✅ **Status: CLEAN**

All modules are loaded in correct contexts:
- Timed actions are correctly in **shared/** folder (per B42.13 API guide)
- They are loaded in ASharedInit.lua (lines 43-49)
- This allows proper MP reconstruction with perform() on client and complete() on server
- ISBaseTimedAction dependency is fine (engine loads all `.lua` files automatically)
