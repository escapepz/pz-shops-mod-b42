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
	Shop.PriceHookRevision = nil -- Initially unknown
	Shop.PriceModifiers = {}
	Shop.CalculatedPrices = {
		buyPrices = {},
		sellPrices = {},
	}

	-- Track if prices changed while UI was closed
	ShopSyncClient.pricesChangedWhileClosed = false

	Events.OnServerCommand.Add(ShopSyncClient.handleServerCommand)
	SharedLogger.log("Shops", "[ShopSyncClient] Initialized - event listener registered for OnServerCommand")
end

function ShopSyncClient.handleServerCommand(module, command, data)
	if module ~= "Shops" then
		return
	end

	local Shop = SHOPSB42.Shop

	if command == "SyncShopData" then
		SharedLogger.log("Shops", "[ShopSyncClient] Received SyncShopData from server")
		Shop.Items = data.Items or {}
		Shop.PlayerBuy = data.PlayerBuy or {}
		Shop.PlayerSell = data.PlayerSell or {}
		Shop.BuyIsWhitelist = data.BuyIsWhitelist or false
		Shop.SellIsWhitelist = data.SellIsWhitelist or false

		local itemCount = 0
		local buyCount = 0
		local sellCount = 0
		for _ in pairs(Shop.Items) do
			itemCount = itemCount + 1
		end
		for _ in pairs(Shop.PlayerBuy) do
			buyCount = buyCount + 1
		end
		for _ in pairs(Shop.PlayerSell) do
			sellCount = sellCount + 1
		end
		SharedLogger.log(
			"Shops",
			"[ShopSyncClient] Stored items: " .. itemCount .. " total, " .. buyCount .. " buy, " .. sellCount .. " sell"
		)

		-- DEBUG: Log if Base.Apple is in the data
		if Shop.PlayerBuy["Base.Apple"] then
			local price = Shop.PlayerBuy["Base.Apple"].price or "unknown"
			SharedLogger.log("Shops", "[ShopSyncClient] Base.Apple found in PlayerBuy (price=" .. price .. ")")
		end
	elseif command == "SyncPriceModifiers" then
		SharedLogger.log("Shops", "[ShopSyncClient] Received SyncPriceModifiers from server")

		-- Phase 2.1: Detect revision changes
		local newRevision = data.revision or 0
		local oldRevision = Shop.PriceHookRevision
		local revisionChanged = Shop.PriceHookRevision ~= nil and newRevision ~= Shop.PriceHookRevision

		Shop.PriceHookRevision = newRevision
		Shop.PriceModifiers = data.modifiers or {}

		-- Store calculated prices from server (for server-only hooks)
		local calculatedPricesUpdated = false
		if data.calculatedPrices then
			Shop.CalculatedPrices = data.calculatedPrices
			calculatedPricesUpdated = true
			SharedLogger.log("Shops", "[ShopSyncClient] Received calculated prices from server")
		end

		local modCount = 0
		if Shop.PriceModifiers then
			if Shop.PriceModifiers.buyModifiers then
				modCount = modCount + #Shop.PriceModifiers.buyModifiers
			end
			if Shop.PriceModifiers.sellModifiers then
				modCount = modCount + #Shop.PriceModifiers.sellModifiers
			end
		end

		SharedLogger.log(
			"Shops",
			"[ShopSyncClient] Price modifiers updated - old revision: "
				.. tostring(oldRevision)
				.. ", new revision: "
				.. newRevision
				.. ", total modifiers: "
				.. modCount
		)

		-- Trigger UI refresh if revision changed OR calculated prices were sent (live updates)
		if revisionChanged or calculatedPricesUpdated then
			SharedLogger.log("Shops", "[ShopSyncClient] Price data changed, triggering onPriceHooksChanged()")
			-- Mark that prices changed (UI will refresh when opened)
			ShopSyncClient.pricesChangedWhileClosed = true
			ShopSyncClient.onPriceHooksChanged()
		else
			SharedLogger.log("Shops", "[ShopSyncClient] Price hook revision same or first time, no reaction needed")
		end
	else
		SharedLogger.log("Shops", "[ShopSyncClient] Received unknown command: " .. command)
	end
end

-- Handler for price hook changes (Phase 3.1 + 3.7)
function ShopSyncClient.onPriceHooksChanged()
	SharedLogger.log("Shops", "[ShopSyncClient] onPriceHooksChanged() called")

	local ui = SHOPSB42.ShopUI

	-- If UI not initialized or missing required methods, defer
	if not ui or not ui.cancelPendingTransactions or not ui.getVisibleRows or not ui.activeView then
		SharedLogger.log("Shops", "[ShopSyncClient] Shop UI not ready, deferring refresh until UI opens")
		return
	end

	SharedLogger.log("Shops", "[ShopSyncClient] Price hook changed, refreshing UI...")

	-- 1. Cancel any local buy/sell actions
	ui:cancelPendingTransactions()

	-- 2. Invalidate and refresh visible rows immediately
	local visibleRows = ui:getVisibleRows()
	if visibleRows then
		for _, row in ipairs(visibleRows) do
			ui:onRowBecameVisible(row) -- Triggers lazy recalc
		end
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

	-- Clear the flag after handling
	ShopSyncClient.pricesChangedWhileClosed = false
end

-- Called by ShopUI when it opens to check if prices changed while closed
function ShopSyncClient.checkAndHandlePriceChanges()
	if ShopSyncClient.pricesChangedWhileClosed then
		SharedLogger.log("Shops", "[ShopSyncClient] Prices changed while UI was closed, refreshing now")
		ShopSyncClient.onPriceHooksChanged()
	end
end

return ShopSyncClient
