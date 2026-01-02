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
		SharedLogger.log("Shops", "[CLIENT] [ShopSyncClient] Error rebuilding active tab: " .. tostring(result))
	end

	-- Clear the flag since UI refresh was successful
	ShopSyncClient.pricesChangedWhileClosed = false
	return true
end

-- Register server command handlers
function ShopSyncClient.Initialize()
	-- Phase 3.1: Initialize independent revision tracking
	local Shop = SHOPSB42.Shop
	Shop.BuyPriceRevision = nil
	Shop.SellRuleRevision = nil
	
	-- Initialize CalculatedPrices with proper namespace (Phase 3+)
	-- Ensure we preserve any existing data and create stable references
	Shop.CalculatedPrices = Shop.CalculatedPrices or {}
	Shop.CalculatedPrices.buyPrices = Shop.CalculatedPrices.buyPrices or {}
	Shop.CalculatedPrices.sellPrices = Shop.CalculatedPrices.sellPrices or {}
	
	-- Expose as top-level references for backward compatibility and direct access
	-- This ensures ShopUI can access prices via Shop.BuyPrices directly
	Shop.BuyPrices = Shop.CalculatedPrices.buyPrices
	Shop.SellPrices = Shop.CalculatedPrices.sellPrices
	
	Shop.SellModifiers = {}
	Shop.SellOverrides = {}

	-- Track if prices changed while UI was closed
	ShopSyncClient.pricesChangedWhileClosed = false

	Events.OnServerCommand.Add(ShopSyncClient.handleServerCommand)
	SharedLogger.log("Shops", "[ShopSyncClient] Initialized - event listener registered for OnServerCommand")
end

-- Handle SyncBuyPrices broadcast (Phase 3.3)
function ShopSyncClient.handleSyncBuyPrices(data)
	SharedLogger.log("Shops", "[ShopSyncClient] Received SyncBuyPrices from server")

	local Shop = SHOPSB42.Shop
	local oldRevision = Shop.BuyPriceRevision
	local newRevision = data.revision or 0

	Shop.BuyPriceRevision = newRevision

	if data.isInitialSync then
		-- Initial sync: store all prices
		Shop.CalculatedPrices.buyPrices = data.buyPrices or {}
		SharedLogger.log("Shops", "[ShopSyncClient] Initial BUY price sync (rev=" .. newRevision .. ")")
	elseif data.buyPrices then
		-- Delta update: merge changed prices
		for itemId, price in pairs(data.buyPrices) do
			Shop.CalculatedPrices.buyPrices[itemId] = price
		end
		SharedLogger.log(
			"Shops",
			"[ShopSyncClient] Delta BUY price update (rev=" .. tostring(oldRevision) .. "->" .. newRevision .. ")"
		)
	end

	-- Trigger UI refresh if revision changed
	if oldRevision ~= nil and newRevision ~= oldRevision then
		ShopSyncClient.onBuyPricesChanged()
	end
end

-- Handle SyncSellRules broadcast (Phase 3.4)
function ShopSyncClient.handleSyncSellRules(data)
	SharedLogger.log("Shops", "[ShopSyncClient] Received SyncSellRules from server")

	local Shop = SHOPSB42.Shop
	local oldRevision = Shop.SellRuleRevision
	local newRevision = data.revision or 0

	Shop.SellRuleRevision = newRevision
	Shop.SellModifiers = data.sellModifiers or {}
	Shop.SellOverrides = data.sellOverrides or {}

	SharedLogger.log(
		"Shops",
		"[ShopSyncClient] SELL rules updated (rev=" .. tostring(oldRevision) .. "->" .. newRevision .. ")"
	)

	-- Trigger UI refresh if revision changed
	if oldRevision ~= nil and newRevision ~= oldRevision then
		ShopSyncClient.onSellRulesChanged()
	end
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
	elseif command == "SyncBuyPrices" then
		ShopSyncClient.handleSyncBuyPrices(data)
	elseif command == "SyncSellRules" then
		ShopSyncClient.handleSyncSellRules(data)
	else
		SharedLogger.log("Shops", "[ShopSyncClient] Unknown command: " .. command)
	end
end

-- Split refresh handlers (Phase 3.5)
function ShopSyncClient.onBuyPricesChanged()
	SharedLogger.log("Shops", "[ShopSyncClient] Buy prices changed, refreshing UI")
	ShopSyncClient._notifyAndRefreshUI()
end

function ShopSyncClient.onSellRulesChanged()
	SharedLogger.log("Shops", "[ShopSyncClient] Sell rules changed, refreshing UI")
	ShopSyncClient._notifyAndRefreshUI()
end

-- Helper: Notify player and refresh UI (Phase 3.5)
function ShopSyncClient._notifyAndRefreshUI()
	-- 1. Notify player first
	local player = getPlayer()
	if player then
		player:setHaloNote(getText("IGUI_Shop_PricesChanged") or "Shop prices have changed", 0, 255, 0, 400)
	end

	-- 2. Refresh UI (if UI is open)
	-- - Invalidates caches for inactive tabs (will rebuild on activation)
	-- - Recalculates visible rows in the active tab only
	ShopSyncClient.refreshUIForPriceChange()
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
