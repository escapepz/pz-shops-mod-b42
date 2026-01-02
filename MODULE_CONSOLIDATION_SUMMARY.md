# Module Consolidation to nshopsb42

## Summary
Refactored all external module references (PS, BS, LS, shops) into a single `nshopsb42` module to eliminate fragmented command routing.

## Changes Made

### Server-side (ShopCommandDispatcherServer.lua)
- **Removed** multi-module support (PS, BS, LS, shops)
- **Simplified** dispatcher to only accept `nshopsb42` module
- **Renamed** all PlayerShop commands with `PlayerShop` prefix:
  - `ToggleBusy` → `PlayerShopToggleBusy`
  - `SyncStatusData` → `PlayerShopSyncStatusData`
  - `ChangeSprite` → `PlayerShopChangeSprite`
  - `SetItemPrice` → `PlayerShopSetItemPrice`
  - `RemoveItemFromInventory` → `PlayerShopRemoveItemFromInventory`
  - `PickupShop` → `PlayerShopPickupShop`

- **Renamed** all Balance commands with `Balance` prefix:
  - `CreateAccount` → `BalanceCreateAccount`
  - `VirtualDeposit` → `BalanceVirtualDeposit`
  - `Deposit` → `BalanceDeposit`
  - `Transfer` → `BalanceTransfer`
  - `Withdraw` → `BalanceWithdraw`
  - `UnlinkWallet` → `BalanceUnlinkWallet`
  - `ClaimMailbox` → `BalanceClaimMailbox`
  - `Rollback` → `BalanceRollback`

- **Renamed** Logging commands with `Logs` prefix:
  - `TransactionShopLog` → `LogsTransactionShopLog`

- **Updated** all server command broadcasts to use `nshopsb42` module

### Client-side (ShopCommandDispatcherClient.lua)
- **Removed** multi-module support (PS, BS)
- **Simplified** dispatcher to only accept `nshopsb42` module
- **Renamed** PlayerShop commands:
  - `PS_ToggleBusy` → `PlayerShopToggleBusy`
  - `PS_SyncStatusData` → `PlayerShopSyncStatusData`

- **Renamed** Balance commands:
  - `BS_TransferReceived` → `BalanceTransferReceived`
  - `BS_MailboxReceived` → `BalanceMailboxReceived`

### Updated Client Files
1. **SetPriceUI.lua** - Changed `"PS"` to `"nshopsb42"` and `"SetItemPrice"` to `"PlayerShopSetItemPrice"`
2. **PlayerShopClient.lua** - Changed `"PS"` to `"nshopsb42"` and `"SyncStatusData"` to `"PlayerShopSyncStatusData"`
3. **PlayerShopContext.lua** - Updated all PS_ command calls:
   - `PickupShop` → `PlayerShopPickupShop`
   - `ToggleBusy` → `PlayerShopToggleBusy`
   - `ChangeSprite` → `PlayerShopChangeSprite`

### Updated Server Files (SendServerCommandTo calls)
1. **PlayerShopServer.lua** - Changed broadcast module references:
   - `Utilities.SendServerCommandToAll("PS", ...)` → `Utilities.SendServerCommandToAll("nshopsb42", "PlayerShopToggleBusy", ...)`
   - `Utilities.SendServerCommandTo(player, "PS", ...)` → `Utilities.SendServerCommandTo(player, "nshopsb42", "PlayerShopSyncStatusData", ...)`

2. **BalanceServer.lua** - Changed notification module references:
   - `Utilities.SendServerCommandTo(..., "BS", "TransferReceived", ...)` → `Utilities.SendServerCommandTo(..., "nshopsb42", "BalanceTransferReceived", ...)`
   - `Utilities.SendServerCommandTo(..., "BS", "MailboxReceived", ...)` → `Utilities.SendServerCommandTo(..., "nshopsb42", "BalanceMailboxReceived", ...)`

## Benefits
- ✅ Single source of truth for module commands
- ✅ Eliminated "UNKNOWN command" errors from legacy PS/BS/LS modules
- ✅ Consistent naming convention with domain prefixes (PlayerShop, Balance, Logs)
- ✅ Simplified dispatcher logic
- ✅ Reduced maintenance burden

## Impact
- All commands must now use `sendClientCommand("nshopsb42", ...)` format
- All handler function names follow `<Domain><Action>` pattern
- No breaking changes to game functionality, only internal routing
