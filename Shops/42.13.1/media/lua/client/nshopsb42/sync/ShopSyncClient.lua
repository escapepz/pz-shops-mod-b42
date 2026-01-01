-- ShopSyncClient.lua
-- Client-side receiver for shop data synchronization
-- Extends SHOPSB42 namespace (no new globals)

local SharedLogger = require("nshopsb42/utils/SharedLogger")

SHOPSB42.ShopSyncClient = SHOPSB42.ShopSyncClient or {}
local ShopSyncClient = SHOPSB42.ShopSyncClient

-- Register server command handlers
function ShopSyncClient.Initialize()
	-- Phase 2.2: Initialize client revision tracking
	local Shop = SHOPSB42.Shop
	Shop.PriceHookRevision = nil  -- Initially unknown
	Shop.PriceModifiers = {}

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

		-- Phase 2.1: Detect revision changes
		local newRevision = data.revision or 0
		local revisionChanged =
			Shop.PriceHookRevision ~= nil
			and newRevision ~= Shop.PriceHookRevision

		Shop.PriceHookRevision = newRevision
		Shop.PriceModifiers = data.modifiers or {}

		SharedLogger.log("Shops", "[ShopSyncClient] Price modifiers updated (revision: " .. newRevision .. ")")

		if revisionChanged then
			SharedLogger.log("Shops", "[ShopSyncClient] Price hook revision changed, triggering onPriceHooksChanged()")
			ShopSyncClient.onPriceHooksChanged()
		end
	end
end

-- Handler for price hook changes (Phase 3.1 + 3.7)
function ShopSyncClient.onPriceHooksChanged()
	local ui = SHOPSB42.UI and SHOPSB42.UI.ShopUI

	if not ui or not ui:isVisible() then
		SharedLogger.log("Shops", "[ShopSyncClient] Shop UI not visible, skipping UI reaction")
		return
	end

	SharedLogger.log("Shops", "[ShopSyncClient] Price hook changed while Shop UI visible, reacting...")

	-- 1. Cancel any local buy/sell actions
	ui:cancelPendingTransactions()

	-- 2. Invalidate and refresh visible rows immediately
	for _, row in ipairs(ui:getVisibleRows()) do
		ui:onRowBecameVisible(row)  -- Triggers lazy recalc
	end

	-- 3. Notify player (Phase 4: localization)
	local haloHelper = SHOPSB42.HaloTextHelper
	if haloHelper and haloHelper.addText then
		haloHelper.addText(
			getPlayer(),
			getText("IGUI_Shop_PricesChanged") or "Shop prices have changed",
			haloHelper.getColorGreen()
		)
	end

	SharedLogger.log("Shops", "[ShopSyncClient] onPriceHooksChanged() complete")
end

return ShopSyncClient
