-- Server-side code (create, tryBuild)
if isServer() or not isMultiplayer() then
-- Runs on server in MP, or anywhere in SP
end

-- Client-side code (render, key events)
if isClient() or not isMultiplayer() then
-- Runs on client in MP, or anywhere in SP
end

## Organized by Folder

### **shared/** (18 files, 55 total occurrences)

**utils/**

- Utilities.lua: isClient(3), isServer(2), isMultiplayer(0)
- SharedLogger.lua: isClient(3), isServer(2), isMultiplayer(0)

**timers/**

- ShopSellAction.lua: isClient(2), isServer(2), isMultiplayer(1)
- ShopBuyAction.lua: isClient(2), isServer(2), isMultiplayer(1)
- SendTransferAction.lua: isClient(2), isServer(2), isMultiplayer(0)
- PlayerShopBuyAction.lua: isClient(2), isServer(2), isMultiplayer(1)
- ISAddShopAction.lua: isClient(2), isServer(2), isMultiplayer(1)
- ISAddPlayerShopAction.lua: isClient(2), isServer(2), isMultiplayer(1)

**ShopItems/**

- Weapons.lua: isClient(0), isServer(0), isMultiplayer(1)
- Vehicles.lua: isClient(0), isServer(0), isMultiplayer(1)
- ForSell.lua: isClient(0), isServer(0), isMultiplayer(1)
- Food.lua: isClient(0), isServer(0), isMultiplayer(1)
- FirstAid.lua: isClient(0), isServer(0), isMultiplayer(1)
- Event.lua: isClient(0), isServer(0), isMultiplayer(1)

**core/**

- Balance.lua: isClient(1), isServer(0), isMultiplayer(0)
- TransactionRegistry.lua: isClient(0), isServer(0), isMultiplayer(3)

**audit/**

- ShopAudit.lua: isClient(0), isServer(0), isMultiplayer(3)

**root**

- ShopDefaultItems.lua: isClient(0), isServer(0), isMultiplayer(1)

---

### **server/** (1 file, 1 occurrence)

- ShopCommandHandlerServer.lua: isClient(0), isServer(0), isMultiplayer(1)

---

### **client/** (2 files, 5 occurrences)

- CurrencyContext.lua: isClient(0), isServer(0), isMultiplayer(3)
- BalanceClient.lua: isClient(0), isServer(0), isMultiplayer(1)
-
