-- ShopSyncClient.lua
-- Client-side receiver for shop data synchronization
-- Extends SHOPSB42 namespace (no new globals)

local SharedLogger = require("nshopsb42/utils/SharedLogger")

SHOPSB42.ShopSyncClient = SHOPSB42.ShopSyncClient or {}
local ShopSyncClient = SHOPSB42.ShopSyncClient

-- Register server command handlers
function ShopSyncClient.Initialize()
	Events.OnServerCommand.Add(ShopSyncClient.handleServerCommand)
	SharedLogger.log("Shops", "[ShopSyncClient] Initialized")
end

function ShopSyncClient.handleServerCommand(module, command, data)
	if module ~= "Shops" then
		return
	end

	local Shop = SHOPSB42.Shop

	if command == "SyncShopData" then
		SharedLogger.log("Shops", "[ShopSyncClient] Received SyncShopData")
		Shop.Items = data.Items or {}
		Shop.PlayerBuy = data.PlayerBuy or {}
		Shop.PlayerSell = data.PlayerSell or {}
		Shop.BuyIsWhitelist = data.BuyIsWhitelist or false
		Shop.SellIsWhitelist = data.SellIsWhitelist or false

		local itemCount = 0
		for _ in pairs(Shop.Items) do
			itemCount = itemCount + 1
		end
		SharedLogger.log("Shops", "[ShopSyncClient] Stored " .. itemCount .. " items")
	elseif command == "SyncPriceModifiers" then
		SharedLogger.log("Shops", "[ShopSyncClient] Received SyncPriceModifiers")
		Shop.PriceModifiers = data or {}
		SharedLogger.log("Shops", "[ShopSyncClient] Price modifiers updated")
	end
end

return ShopSyncClient
