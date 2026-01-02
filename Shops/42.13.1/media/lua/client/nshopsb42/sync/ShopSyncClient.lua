-- ShopSyncClient.lua
-- Client-side receiver for shop data synchronization
-- Extends SHOPSB42 namespace (no new globals)

local SharedLogger = require("nshopsb42/utils/SharedLogger")

SHOPSB42.ShopSyncClient = SHOPSB42.ShopSyncClient or {}
local ShopSyncClient = SHOPSB42.ShopSyncClient

-- Refresh UI components when prices change (cancel actions, refresh rows)
function ShopSyncClient.refreshUIForPriceChange()
	local ui = SHOPSB42.ShopUI.instance

	-- Mark cache as invalidated (will be handled on next access)
	if ui then
		ui.cacheInvalidated = true
		SharedLogger.log("Shops", "[CLIENT] [ShopSyncClient] Marked cache as invalidated for price recalculation")
	end

	if not ui or not ui.panel or not ui.panel.activeView then
		SharedLogger.log("Shops", "[CLIENT] [ShopSyncClient] Shop UI not open, deferring refresh until UI opens")
		return false
	end

	SharedLogger.log("Shops", "[CLIENT] [ShopSyncClient] Price hook changed, refreshing UI...")

	-- Cancel any local buy/sell actions if available
	if ui.cancelPendingTransactions then
		ui:cancelPendingTransactions()
	end

	-- Get active tab (only materialized tab)
	local activeTab = ui.panel.activeView.view
	local activeTabType = activeTab.tabType

	-- Step 1: Invalidate caches for NON-active tabs
	-- These will rebuild fresh when activated next
	if ui.shopItemsCache then
		for tabType, _ in pairs(ui.shopItemsCache) do
			if tabType ~= activeTabType then
				ui.shopItemsCache[tabType] = nil
				SharedLogger.log(
					"Shops",
					"[CLIENT] [ShopSyncClient] Invalidated cache for inactive tab: " .. tostring(tabType)
				)
			end
		end
	end

	-- Step 2: Rebuild the ACTIVE tab using standard ShopUI method
	-- This reuses onActivateView() logic and respects ISScrollingListBox redraw contract
	local success, result = pcall(function()
		if ui.rebuildActiveTab then
			local rebuilt = ui:rebuildActiveTab()
			if rebuilt then
				SharedLogger.log(
					"Shops",
					"[CLIENT] [ShopSyncClient] Rebuilt active tab with updated prices (scroll preserved)"
				)
			end
			return rebuilt
		end
		return false
	end)

	if not success then
		SharedLogger.log(
			"Shops",
			"[CLIENT] [ShopSyncClient] Error rebuilding active tab: " .. tostring(result)
		)
	end

	-- Clear the flag since UI refresh was successful
	ShopSyncClient.pricesChangedWhileClosed = false
	return true
end

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

		-- Always update modifiers (needed for sell price calculations) (Step 7)
		if data.modifiers then
			Shop.PriceModifiers = data.modifiers
			SharedLogger.log("Shops", "[CLIENT] [ShopSyncClient] Updated price modifiers for sell calculations")
		end

		-- Handle both full sync (initial) and delta updates (Step 7)
		local calculatedPricesUpdated = false

		if data.isInitialSync then
			-- Initial sync: full prices for all defined items (don't trigger UI refresh yet)
			SharedLogger.log("Shops", "[CLIENT] [ShopSyncClient] Initial sync - storing full prices (no UI refresh)")
			Shop.CalculatedPrices = data.calculatedPrices or { buyPrices = {}, sellPrices = {} }
			-- Don't set calculatedPricesUpdated = true for initial sync (UI not ready)
		elseif data.changed then
			-- Delta update: only changed prices (Step 7)
			SharedLogger.log("Shops", "[CLIENT] [ShopSyncClient] Delta update - updating changed prices")
			if not Shop.CalculatedPrices then
				Shop.CalculatedPrices = { buyPrices = {}, sellPrices = {} }
			end

			-- Update only changed items
			for itemId, newPrice in pairs(data.changed) do
				Shop.CalculatedPrices.buyPrices[itemId] = newPrice
				SharedLogger.log(
					"Shops",
					"[CLIENT] [ShopSyncClient] Updated price for " .. itemId .. " to " .. newPrice
				)
			end
			calculatedPricesUpdated = true
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
			"[ShopSyncClient] Revision: "
				.. tostring(oldRevision)
				.. " -> "
				.. newRevision
				.. ", modifiers: "
				.. modCount
		)

		-- Trigger UI refresh if revision changed OR calculated prices were updated
		if revisionChanged or calculatedPricesUpdated then
			SharedLogger.log("Shops", "[ShopSyncClient] Price data changed, triggering onPriceHooksChanged()")
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
	SharedLogger.log("Shops", "[CLIENT] [ShopSyncClient] onPriceHooksChanged() called")

	-- 1. Notify player first (Phase 4: localization)
	local player = getPlayer()
	if player then
		player:setHaloNote(getText("IGUI_Shop_PricesChanged") or "Shop prices have changed", 0, 255, 0, 400)
	end

	-- 2. Refresh UI (if UI is open)
	-- - Invalidates caches for inactive tabs (will rebuild on activation)
	-- - Recalculates visible rows in the active tab only
	ShopSyncClient.refreshUIForPriceChange()

	SharedLogger.log("Shops", "[CLIENT] [ShopSyncClient] onPriceHooksChanged() complete")
end

-- Called by ShopUI when it opens to check if prices changed while closed
function ShopSyncClient.checkAndHandlePriceChanges()
	if ShopSyncClient.pricesChangedWhileClosed then
		SharedLogger.log("Shops", "[CLIENT] [ShopSyncClient] Prices changed while UI was closed, refreshing UI now")
		-- Only refresh UI - cache was already updated when price change arrived
		ShopSyncClient.refreshUIForPriceChange()
	end
end

return ShopSyncClient
