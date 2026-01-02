# Module Loading Analysis - Require() Tracing Report

## Critical Issues Found

### 1. ✅ FIXED: Timed Action Classes in Shared Folder
**Severity: HIGH** - These depend on `TimedActions/ISBaseTimedAction` (client-only)

**Client-only modules in shared/** folder:
- `Shops/42.13.1/media/lua/shared/nshopsb42/timers/ShopSellAction.lua` - Requires `TimedActions/ISBaseTimedAction`
- `Shops/42.13.1/media/lua/shared/nshopsb42/timers/ShopBuyAction.lua` - Requires `TimedActions/ISBaseTimedAction`
- `Shops/42.13.1/media/lua/shared/nshopsb42/timers/SendTransferAction.lua` - Requires `TimedActions/ISBaseTimedAction`
- `Shops/42.13.1/media/lua/shared/nshopsb42/timers/PlayerShopBuyAction.lua` - Requires `TimedActions/ISBaseTimedAction`
- `Shops/42.13.1/media/lua/shared/nshopsb42/timers/ISAddShopAction.lua` - Requires `TimedActions/ISBaseTimedAction`
- `Shops/42.13.1/media/lua/shared/nshopsb42/timers/ISAddPlayerShopAction.lua` - Requires `TimedActions/ISBaseTimedAction`

**Previous loading locations:**
- ASharedInit.lua (lines 43-46) - Required on both server and client
- AClientInit.lua (lines 18-20) - Duplicate loading

**Status: ✅ FIXED**
- Removed from ASharedInit.lua
- Consolidated in AClientInit.lua (lines 18-21)
- Added comment explaining they're client-only

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
- **`nshopsb42/timers/ShopSellAction.lua`** ✅ (now client-only)
- **`nshopsb42/timers/ShopBuyAction.lua`** ✅ (now client-only)
- **`nshopsb42/timers/SendTransferAction.lua`** ✅ (now client-only)
- **`nshopsb42/timers/PlayerShopBuyAction.lua`** ✅ (now client-only)
- **`nshopsb42/timers/ISAddShopAction.lua`** ✅ (now client-only)
- **`nshopsb42/timers/ISAddPlayerShopAction.lua`** ✅ (now client-only)

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

✅ **Status: CLEAN** (after fix)

All modules are loaded in correct contexts. The only issue (timed actions in shared) has been resolved by:
1. Removing requires from ASharedInit.lua (lines 43-46)
2. Adding requires to AClientInit.lua (lines 18-21) before UI components load
3. Adding explanatory comments about why they're client-only
