# Shops Lua Global Definitions

## Core Shop System Globals

### Shop (Shop.lua)

- **Shop** - Main shop table containing items, tabs, player buying/selling
  - Shop.Items
  - Shop.Tabs
  - Shop.PlayerBuy
  - Shop.PlayerSell
  - Shop.Sell
  - Shop.SellisBlacklist
  - Shop.SellisWhitelist
  - Shop.defaultPrice
  - Shop.defaultPriceBroken
  - Shop.spritePrefix
  - Shop.sprites (FemaleA, FemaleB, MaleA, MaleB)
  - Shop.textures (AddButton, RemoveButton, PreviewButton, Browse, Cart, Sort, MoveAll)
  - Shop.FinalizeRegistry() - function

### Tab (Shop.lua)

- **Tab** - Tab constants
  - Tab.Favorite
  - Tab.Sell
  - Tab.All
  - Tab.Food
  - Tab.Weapons
  - Tab.Vehicles
  - Tab.FirstAid
  - Tab.Event

## Currency & Wallet System

### Currency (Currency.lua)

- **Currency** - Currency management
  - Currency.Wallets - wallet item IDs
  - Currency.BaseCoin = "Shops.CopperCoin"
  - Currency.SpecialCoin = "Shops.EventCoin"
  - Currency.UseSpecialCoin = true
  - Currency.Coins - coin values and types
  - Currency.CoinsTexture - texture definitions
  - Currency.WalletTexture - wallet texture
  - Currency.format(quantity) - function

## Player Shop System

### PlayerShop (PlayerShop.lua)

- **PlayerShop** - Player-owned shop management
  - PlayerShop.Tabs
  - PlayerShop.status
  - PlayerShop.spritePrefix = "playershop\_"
  - PlayerShop.sprites (NoSign, FirstAid, Food, Clothes, Melee, Guns, Ammo, Furniture, Materials, Misc, Freezer)

## Account Balance System

### Balance (Balance.lua)

- **Balance** - Virtual currency account management
  - Balance.getUserAccount(username) - function
  - Balance.getUserBalance(username) - function
  - Balance.getAccountsList() - function
  - Balance.deposit(username, coin, specialCoin) - function

## Registry System

### ShopRegistry (ShopRegistry.lua)

- **Shop.\_pendingRegistrations** - array of pending item registrations
- **Shop.\_hasExternalRegistrations** - boolean flag
- **Shop.\_locked** - boolean flag (prevents registration after lock)
- **Shop.RegisterItem(itemId, def)** - function

## Event System

### ShopEvents (ShopEvents.lua)

- **ShopEvents** - Custom event dispatcher
  - ShopEvents.OnShopRegisterItems - array of callbacks
  - ShopEvents.registerOnShopRegisterItems(callback) - function
  - ShopEvents.triggerOnShopRegisterItems() - function

## UI Text System

### UIText (ShopUIText.lua)

- **UIText** - UI text string constants
  - UIText.ShopUITitle
  - UIText.TransferUITitle
  - UIText.ShopViewOnly
  - UIText.ShopViewItems
  - UIText.AddShop
  - UIText.RemoveShop
  - UIText.AddPlayerShop
  - UIText.AddPlayerShopFreezer
  - UIText.RemovePlayerShop
  - UIText.RemoveItemsPlayerShop
  - UIText.RemoveIncomePlayerShop
  - UIText.ViewIncomePlayerShop
  - UIText.PickupPlayerShop
  - UIText.UnlockContainerPlayerShop
  - UIText.LockContainerPlayerShop
  - UIText.ManagePlayerShop
  - UIText.SetPricePlayerShop
  - UIText.ChangeSign
  - UIText.Income
  - UIText.Get
  - UIText.LootAllCoins
  - UIText.CoinsToAccount
  - UIText.AccountNeeded
  - UIText.Link
  - UIText.Unlink
  - UIText.Transfer
  - UIText.TransferTo
  - UIText.Send
  - UIText.ClaimOfflineMailbox
  - UIText.Shop
  - UIText.Search
  - UIText.ClearCart
  - UIText.BuyCart
  - UIText.Sell
  - UIText.Balance
  - UIText.Total
  - UIText.Cancel
  - UIText.Contains
  - UIText.DropOnFloor

## Utility Functions

### Nfunction (Nfunction.lua)

- **Nfunction** - Local module (returned from file, not global)
  - Nfunction.trimString(str, limit) - function
  - Nfunction.drainablePrice(item, price) - function
  - Nfunction.logShop(coords, action) - function
  - Nfunction.buildLogShop(type, quantity) - function

## Audit Systems

### ShopAudit (ShopAudit.lua)

- **ShopAudit** - Transaction audit log management
  - ShopAudit.getLog() - function
  - ShopAudit.prune() - function
  - ShopAudit.append(entry) - function
  - ShopAudit.queryByTxnId(txnId) - function
  - ShopAudit.queryByPlayer(username) - function
  - Max entries: 5000
  - Max age: 7 days

### BalanceAudit (BalanceAudit.lua - server-only)

- **BalanceAudit** - Currency transfer audit log (local module, returned)
  - BalanceAudit.prune() - function
  - BalanceAudit.append(entry) - function
  - BalanceAudit.logTransfer(sender, recipient, coin, specialCoin) - function
  - BalanceAudit.findEntry(actionId) - function
  - BalanceAudit.getAccountHistory(username) - function
  - BalanceAudit.getAccountStats(username) - function
  - Max entries: 10000
  - Max age: 30 days
  - Records: sender, recipient, coin, specialCoin, timestamp, serverId, actionId

## Summary

**Key Global Tables:**

- Shop
- Tab
- Currency
- PlayerShop
- Balance
- ShopEvents
- ShopAudit
- UIText

**Locked After Initialization:**

- Shop (when Shop.\_locked = true)

**ModData Keys Used:**

- "CoinBalance" - for currency accounts
- "ShopAuditLog" - transaction audit log
- "BalanceAudit" - currency transfer audit log (immutable, append-only)
