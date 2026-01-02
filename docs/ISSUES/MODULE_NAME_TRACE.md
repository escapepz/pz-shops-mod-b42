# Module Name Trace - Client/Server Commands

## Current State Analysis

### Client -> Server Commands
| Module | Command | File | Line | Expected Handler |
|--------|---------|------|------|------------------|
| `"Shops"` | `"RequestShopData"` | AClientInit.lua | 73 | ShopInitServer.onClientCommand |
| `"PS"` | `"SyncStatusData"` | PlayerShopClient.lua | 19 | PlayerShopServer.PS_OnClientCommand |
| `"PS"` | Various | PlayerShopContext.lua | 120,161,186 | PlayerShopServer.PS_OnClientCommand |
| `"LS"` | `"TransactionShopLog"` | Nfunction.lua | 60 | LogsServer.LS_OnClientCommand |
| `"BS"` | Various | SendTransferAction.lua, etc | 46,156 | BalanceServer.BS_OnClientCommand |
| `"nshopsb42"` | Various | ShopContext.lua | 54 | ShopCommandHandlerServer |

### Server -> Client Responses
| Module | Command | File | Line |
|--------|---------|------|------|
| `"Shops"` | `"SyncShopData"` | ShopFinalizeHandlerServer.lua | 361 |
| `"Shops"` | `"SyncBuyPrices"` | ShopFinalizeHandlerServer.lua | 386 |
| `"Shops"` | `"SyncSellRules"` | ShopFinalizeHandlerServer.lua | 404 |
| `"Shops"` | `"SyncInitialComplete"` | ShopFinalizeHandlerServer.lua | 415 |
| `"Shops"` | Various | ShopSyncClient.lua | 456-468 |

### Server Event Handlers Registered
| Module | Handler | File | Line | Status |
|--------|---------|------|------|--------|
| `"Shops"` | onClientCommand | ShopInitServer.lua | 140 | ✓ Registered |
| `"PS"` | PS_OnClientCommand | PlayerShopServer.lua | 130 | ✓ Registered |
| `"LS"` | LS_OnClientCommand | LogsServer.lua | 37 | ✓ Registered |
| `"BS"` | BS_OnClientCommand | BalanceServer.lua | 760 | ✓ Registered |
| `"nshopsb42"` | ShopCommandHandler | ShopCommandHandlerServer.lua | 72 | ✓ Registered |

## Server Log Analysis

### Received Commands (from 2026-01-02_17-23_Shops.txt)
```
[02-01-26 17:33:01.602] module=ISLogSystem, command=writeLog
[02-01-26 17:33:01.603] module=ISLogSystem, command=writeLog  
[02-01-26 17:33:01.625] module=PS, command=SyncStatusData
```

**Missing:** `module=Shops, command=RequestShopData`

### Issue
- Client sends `"Shops"` module ✓
- Server handler is registered for `"Shops"` module ✓  
- Server NEVER receives `"Shops"` module command ✗
- Server IS receiving other modules (ISLogSystem, PS) ✗ **These shouldn't be there!**

## Root Cause Hypothesis

The fact that server is receiving `ISLogSystem` and `PS` commands but NOT `Shops` suggests:

1. **Race condition**: Client sends before server handler is fully registered
2. **Module name case sensitivity**: "Shops" vs "shops" mismatch
3. **Network layer filtering**: Command is being intercepted before reaching event
4. **Event timing**: Client command fired in wrong context (single player vs multiplayer)
5. **Multiple handler registration issue**: Handlers overwriting each other

## Next Steps
1. Add global logger to trace ALL client commands on server  
2. Check if `Shops` command is being sent at all from client
3. Verify module name casing (Shops vs shops)
4. Check if handler registration order matters
5. Verify Events.OnClientCommand is firing before client sends
