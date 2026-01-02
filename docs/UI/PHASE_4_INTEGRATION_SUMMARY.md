# Phase 4: Integration - Summary

## Overview
Phase 4 wires all the components created in Phases 1-3 together, ensuring they work in both Single-Player (SP) and Multiplayer (MP) contexts.

## Data Flow Integration

### Initialization Sequence

#### Server (ShopInitServer.lua)
1. **Module Loading** (lines 1-32)
   - Loads shared core modules
   - Loads ShopFinalizeHandlerServer
   - Loads ShopTransactionValidationServer
   - Loads all patches and dependencies

2. **Initialize()** Call (line 17 in server/Init.lua)
   - Registers ShopDefaultItems hooks
   - Calls ShopFinalizeHandler.finalizeNow()
   - Builds and caches price modifiers

3. **OnGameStart Event Handler** (new)
   - Ensures finalization is called if needed
   - Confirms modifiers are available

4. **OnClientCommand Handler** (new)
   - Listens for "RequestShopData" command from clients
   - Calls ShopFinalizeHandler.sendShopDataToPlayer(player)
   - Sends SyncShopData and SyncPriceModifiers to requesting client

#### Client (client/Init.lua)
1. **Module Loading** (lines 1-43)
   - Loads shared core modules
   - Loads ShopSyncClient
   - Loads all UI components

2. **OnGameStart Event Handler** (lines 47-61)
   - Initializes ShopSyncClient
   - Sends RequestShopData to server
   - Triggers server to send sync packets

3. **OnServerCommand Handler** (in ShopSyncClient)
   - Receives SyncShopData → stores in Shop.Items, Shop.PlayerBuy, Shop.PlayerSell
   - Receives SyncPriceModifiers → stores in Shop.PriceModifiers

#### Shared Initialization (shared/Init.lua)
- Requires ShopPriceCalculatorShared
- Requires ShopPriceModifierBuilder
- Available to both client and server

## File Structure

### New Files
1. **Shops/42.13.1/media/lua/shared/nshopsb42/pricing/ShopPriceModifierBuilder.lua**
   - Builds serializable modifier rules from hooks
   - Classifies hooks as client-safe or server-only

2. **Shops/42.13.1/media/lua/shared/nshopsb42/pricing/ShopPriceCalculatorShared.lua**
   - Evaluates data-driven modifier rules
   - Safe for client preview and server validation
   - No executable functions

3. **Shops/42.13.1/media/lua/client/nshopsb42/sync/ShopSyncClient.lua**
   - Handles server commands: SyncShopData, SyncPriceModifiers
   - Stores data in SHOPSB42.Shop

4. **Shops/42.13.1/media/lua/server/nshopsb42/transactions/ShopTransactionValidationServer.lua**
   - Validates buy/sell prices on server
   - Tolerance-based validation (±1)
   - Logs security mismatches

### Modified Files
1. **Shops/42.13.1/media/lua/shared/nshopsb42/Init.lua**
   - Added requires for ShopPriceCalculatorShared and ShopPriceModifierBuilder

2. **Shops/42.13.1/media/lua/server/nshopsb42/ShopInitServer.lua**
   - Added require for ShopTransactionValidationServer
   - Added OnGameStart handler to ensure finalization
   - Added OnClientCommand handler for RequestShopData

3. **Shops/42.13.1/media/lua/server/nshopsb42/transactions/ShopFinalizeHandlerServer.lua**
   - Added modifier building in finalizeNow()
   - Added sendShopDataToPlayer() method

4. **Shops/42.13.1/media/lua/client/nshopsb42/Init.lua**
   - Added require for ShopSyncClient
   - Added OnGameStart handler to initialize ShopSyncClient and request data

5. **Shops/42.13.1/media/lua/client/nshopsb42/ui/ShopUI.lua**
   - Added Calculator require
   - Added calcBuyPrice() and calcSellPrice() helper functions
   - Updated 3 price resolution locations to use calculator with fallback

## Multiplayer Flow (MP)

```
Client OnGameStart
  ├─ ShopSyncClient.Initialize() [registers OnServerCommand handler]
  └─ sendClientCommand("Shops", "RequestShopData", {})

Server OnClientCommand["RequestShopData"]
  └─ ShopFinalizeHandler.sendShopDataToPlayer(player)
      ├─ sendServerCommandTo(player, "SyncShopData", {...})
      └─ sendServerCommandTo(player, "SyncPriceModifiers", {...})

Client OnServerCommand["SyncShopData"]
  └─ Shop.Items, Shop.PlayerBuy, Shop.PlayerSell = data

Client OnServerCommand["SyncPriceModifiers"]
  └─ Shop.PriceModifiers = data

ShopUI.displayBuyPrice()
  ├─ calcBuyPrice(itemId, player, Shop.PriceModifiers)
  │  └─ Uses Calculator.calcBuyPrice()
  └─ Falls back to base price if nil
```

## Single-Player Flow (SP)

```
Server OnGameStart
  └─ ShopFinalizeHandler.finalizeNow()
      ├─ Finalizes registries
      └─ Builds price modifiers → SHOPSB42.Shop.PriceModifiers

Client OnGameStart
  ├─ ShopSyncClient.Initialize()
  └─ sendClientCommand("Shops", "RequestShopData", {})

Server receives RequestShopData (isServer() == true)
  └─ Calls ShopFinalizeHandler.sendShopDataToPlayer(player)
      └─ Sends SyncShopData + SyncPriceModifiers to client

Client receives sync data (same as MP)
  └─ Stores in SHOPSB42.Shop

ShopUI displays prices using Calculator (same as MP)
```

## Key Integration Points

### 1. Server Authority
- Server finalizes registries and builds modifiers
- Server sends modifiers to client
- Server validates all transaction prices
- Client calculation is preview-only

### 2. Consistency
- ShopPriceCalculatorShared used on both client (preview) and server (validation)
- Same rule evaluation logic = same results
- Tolerance of ±1 for floating-point differences

### 3. Network Efficiency
- **Before**: 1 network call per price display (N transactions)
- **After**: 1 initial sync (SyncShopData + SyncPriceModifiers) + UI preview locally
- Reduces traffic significantly

### 4. Fallback Gracefully
- If Calculator returns nil (requiresServer=true), falls back to base price
- Old resolvePlayerBuyPrice/Sell still available as backup
- No breaking changes

### 5. Security
- Client prices are advisory only
- Server always recalculates and validates
- Tolerance check prevents tampering
- Logged mismatches for audit trail

## Testing Checklist

- [ ] Server finalizes once on game start
- [ ] Modifiers built and cached after finalization
- [ ] Client requests shop data on game start
- [ ] Client receives SyncShopData and SyncPriceModifiers
- [ ] Client stores data correctly
- [ ] Buy prices display instantly (no network lag)
- [ ] Sell prices display instantly
- [ ] Server validates prices on transaction
- [ ] Transaction rejected if price tampered (>±1)
- [ ] Works in SP (both client and server code)
- [ ] Works in MP (separate client/server)
- [ ] No double-finalization
- [ ] Logs show proper flow
