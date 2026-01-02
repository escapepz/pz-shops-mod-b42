-- ShopFinalizeHandlerServer.lua (Server-only)
-- Server-side finalization handler for item registries
-- Extends SHOPSB42 namespace (no new globals)
-- In MP: Only server registers and finalizes; client receives data

local SharedLogger = require("nshopsb42/utils/SharedLogger")
local Builder = require("nshopsb42/pricing/ShopPriceModifierBuilder")
local Utilities = require("nshopsb42/utils/Utilities")

local Shop = SHOPSB42.Shop
local ShopEvents = SHOPSB42.ShopEvents
local ShopSellEvents = SHOPSB42.ShopSellEvents
local ShopDefaultItems = SHOPSB42.ShopDefaultItems

-- Finalization handler: locks registries after all items are registered
SHOPSB42.ShopFinalizeHandler = SHOPSB42.ShopFinalizeHandler or {}
local ShopFinalizeHandler = SHOPSB42.ShopFinalizeHandler

ShopFinalizeHandler._finalizationAttempted = ShopFinalizeHandler._finalizationAttempted or false

-- Track previous calculated prices for delta detection (Step 1)
ShopFinalizeHandler._previousBuyPrices = {}
ShopFinalizeHandler._previousSellPrices = {}

-- Track previous sell rules for delta detection (Phase 1.2)
ShopFinalizeHandler._previousSellRules = {
	sellModifiers = {},
	sellOverrides = {},
}

-- Helper: Calculate prices for ONLY defined items in PlayerBuy + PlayerSell registries (Step 2)
local function buildCalculatedPrices()
	local calculatedPrices = {
		buyPrices = {},
		sellPrices = {},
	}

	-- ONLY calculate buy prices for defined items in PlayerBuy registry
	if Shop.PlayerBuy then
		for itemId, config in pairs(Shop.PlayerBuy) do
			if config.enabled then
				local buyPrice = Shop.resolvePlayerBuyPrice(nil, itemId, { type = "sync" })
				if buyPrice then
					calculatedPrices.buyPrices[itemId] = buyPrice
				end
			end
		end
	end

	-- ONLY calculate sell prices for defined items in PlayerSell registry
	-- (Note: Still need item objects for sell price hooks, may defer)
	if Shop.PlayerSell then
		for itemId, config in pairs(Shop.PlayerSell) do
			if config.enabled and not config.blacklisted then
				-- Sell price calculation deferred to client for now
				-- Client will use modifiers from this broadcast
			end
		end
	end

	return calculatedPrices
end

-- Detect price changes by comparing new prices with previous state (Step 3)
local function detectPriceChanges(newCalculatedPrices, previousPrices)
	local changed = {}

	-- Only check items in PlayerBuy registry (defined items)
	if newCalculatedPrices.buyPrices then
		for itemId, newPrice in pairs(newCalculatedPrices.buyPrices) do
			if Shop.PlayerBuy[itemId] then -- ← Only registered items
				local oldPrice = previousPrices[itemId]
				if oldPrice ~= newPrice then
					changed[itemId] = newPrice
					SharedLogger.log(
						"Shops",
						"[PriceDelta] Changed: " .. itemId .. " from " .. tostring(oldPrice) .. " to " .. newPrice
					)
				end
			end
		end
	end

	return changed
end

-- Helper: Check if buy prices should be recalculated (Phase 2.2)
function ShopFinalizeHandler.shouldInvalidateBuyPrices()
	local ShopPriceEvents = SHOPSB42.ShopPriceEvents
	local buyHookCount = (#ShopPriceEvents.OnShopModifyBuyPrice or 0) + (#ShopPriceEvents.OnShopOverrideBuyPrice or 0)
	return buyHookCount > 0
end

-- Helper: Check if sell rules should be recalculated (Phase 2.4)
function ShopFinalizeHandler.shouldInvalidateSellRules()
	local ShopPriceEvents = SHOPSB42.ShopPriceEvents
	local sellHookCount = (#ShopPriceEvents.OnShopModifySellPrice or 0)
		+ (#ShopPriceEvents.OnShopOverrideSellPrice or 0)
	return sellHookCount > 0
end

-- Helper: Compare sell rule sets (Phase 2.6)
local function ruleSetsEqual(a, b)
	-- Simple check: if JSON strings match, rules are same
	local aJson = tostring(a.sellModifiers) .. tostring(a.sellOverrides)
	local bJson = tostring(b.sellModifiers) .. tostring(b.sellOverrides)
	return aJson == bJson
end

-- Helper: Deep copy table (Phase 2.5)
local function deepCopy(tbl)
	if type(tbl) ~= "table" then
		return tbl
	end
	local result = {}
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			result[k] = deepCopy(v)
		else
			result[k] = v
		end
	end
	return result
end

-- Broadcast buy prices to all players (Phase 2.3)
function ShopFinalizeHandler.broadcastBuyPrices()
	Shop.BuyPriceRevision = Shop.BuyPriceRevision + 1

	local modifiers = Builder.buildPriceModifiers()
	Shop.PriceModifiers = modifiers

	local calculatedPrices = buildCalculatedPrices()
	local changedPrices = detectPriceChanges(calculatedPrices, ShopFinalizeHandler._previousBuyPrices)
	ShopFinalizeHandler._previousBuyPrices = calculatedPrices.buyPrices or {}

	Utilities.SendServerCommandToAll("Shops", "SyncBuyPrices", {
		revision = Shop.BuyPriceRevision,
		buyPrices = changedPrices, -- Delta: only changed items
	})

	SharedLogger.log("Shops", "[ShopFinalizeHandler] BUY prices broadcast (rev=" .. Shop.BuyPriceRevision .. ")")
end

-- Broadcast sell rules to all players (Phase 2.5)
function ShopFinalizeHandler.broadcastSellRules()
	Shop.SellRuleRevision = Shop.SellRuleRevision + 1

	local modifiers = Builder.buildPriceModifiers()

	-- Extract sell-specific data
	local sellData = {
		sellModifiers = modifiers.sellModifiers or {},
		sellOverrides = modifiers.sellOverrides or {},
	}

	-- Delta detection (compare with previous rules)
	if not ruleSetsEqual(sellData, ShopFinalizeHandler._previousSellRules) then
		ShopFinalizeHandler._previousSellRules = deepCopy(sellData)

		Utilities.SendServerCommandToAll("Shops", "SyncSellRules", {
			revision = Shop.SellRuleRevision,
			sellModifiers = sellData.sellModifiers,
			sellOverrides = sellData.sellOverrides,
		})

		SharedLogger.log("Shops", "[ShopFinalizeHandler] SELL rules broadcast (rev=" .. Shop.SellRuleRevision .. ")")
	end
end

-- Callback for price hook mutations (Phase 1.2)
local function onPriceHookAdded()
	if Shop._finalized then
		ShopFinalizeHandler.resyncPriceModifiers()
	end
end

-- Callback for runtime price hook changes (test hooks, live updates) (Phase 2.1)
function ShopFinalizeHandler.onPriceHooksChanged()
	SharedLogger.log("Shops", "[ShopFinalizeHandler] onPriceHooksChanged() called")

	if not Shop._finalized then
		SharedLogger.log("Shops", "[ShopFinalizeHandler] Shop not finalized yet, aborting")
		return
	end

	-- Split into independent buy and sell broadcasts
	if ShopFinalizeHandler.shouldInvalidateBuyPrices() then
		ShopFinalizeHandler.broadcastBuyPrices()
	end
	if ShopFinalizeHandler.shouldInvalidateSellRules() then
		ShopFinalizeHandler.broadcastSellRules()
	end
end

function ShopFinalizeHandler.finalizeNow()
	if ShopFinalizeHandler._finalizationAttempted then
		return
	end
	ShopFinalizeHandler._finalizationAttempted = true

	-- Initialize independent revision counters (Phase 1.1)
	Shop.BuyPriceRevision = 0
	Shop.SellRuleRevision = 0

	if not Shop._locked then
		SharedLogger.log("Shops", "[ShopFinalizeHandler] Finalizing buy registry...")
		Shop.FinalizeRegistry()
	end

	if not Shop._sellLocked then
		SharedLogger.log("Shops", "[ShopFinalizeHandler] Finalizing sell registry...")
		Shop.FinalizeSellRegistry()
	end

	-- NEW: Build and cache price modifiers server-side
	SharedLogger.log("Shops", "[ShopFinalizeHandler] Building price modifiers...")
	local priceModifiers = Builder.buildPriceModifiers()

	-- Store on server for reuse during transactions
	SHOPSB42.Shop.PriceModifiers = priceModifiers

	if priceModifiers.requiresServer then
		SharedLogger.log("Shops", "[ShopFinalizeHandler] WARNING: Some hooks require server-side calculation")
	end

	SharedLogger.log("Shops", "[ShopFinalizeHandler] Price modifiers built and cached")

	-- Register hook listeners for post-finalization changes (Phase 1.2)
	if ShopEvents.OnShopModifyBuyPrice then
		ShopEvents.OnShopModifyBuyPrice:Add(onPriceHookAdded)
	end
	if ShopEvents.OnShopOverrideBuyPrice then
		ShopEvents.OnShopOverrideBuyPrice:Add(onPriceHookAdded)
	end
	if ShopEvents.OnShopModifySellPrice then
		ShopEvents.OnShopModifySellPrice:Add(onPriceHookAdded)
	end
	if ShopEvents.OnShopOverrideSellPrice then
		ShopEvents.OnShopOverrideSellPrice:Add(onPriceHookAdded)
	end

	SharedLogger.log("Shops", "[ShopFinalizeHandler] Hook listeners registered")

	-- Enable live price hook broadcasting to clients
	-- CRITICAL: Only set to true when finalization is complete and prices are stable
	-- This allows mods/code to use onPriceHooksChanged() to live-update prices
	Shop._finalized = true
	SharedLogger.log("Shops", "[ShopFinalizeHandler] Finalization complete - live price hook broadcasting ENABLED")
end

-- Rebuild price modifiers and broadcast to all online players (Phase 2.7)
function ShopFinalizeHandler.resyncPriceModifiers()
	if not Utilities.IsServerOrSinglePlayer() then
		return
	end

	-- Call both broadcast functions independently
	if ShopFinalizeHandler.shouldInvalidateBuyPrices() then
		ShopFinalizeHandler.broadcastBuyPrices()
	end
	if ShopFinalizeHandler.shouldInvalidateSellRules() then
		ShopFinalizeHandler.broadcastSellRules()
	end
end

-- NEW: Send data to a specific player (called when they connect) (Step 5)
function ShopFinalizeHandler.sendShopDataToPlayer(player)
	if not Utilities.IsServerOrSinglePlayer() then
		SharedLogger.log("Shops", "[ShopFinalizeHandler] sendShopDataToPlayer not in server context, aborting")
		return
	end

	if not player then
		SharedLogger.log("Shops", "[ShopFinalizeHandler] sendShopDataToPlayer called with nil player, aborting")
		return
	end

	SharedLogger.log("Shops", "[ShopFinalizeHandler] sendShopDataToPlayer starting for " .. player:getUsername())

	local itemCount = 0
	for _ in pairs(Shop.Items) do
		itemCount = itemCount + 1
	end
	SharedLogger.log("Shops", "[ShopFinalizeHandler] Preparing SyncShopData with " .. itemCount .. " items")

	-- Send shop items and config
	local shopData = {
		Items = Shop.Items,
		PlayerBuy = Shop.PlayerBuy,
		PlayerSell = Shop.PlayerSell,
		BuyIsWhitelist = Shop.BuyIsWhitelist,
		SellIsWhitelist = Shop.SellIsWhitelist,
	}

	SharedLogger.log("Shops", "[ShopFinalizeHandler] Sending SyncShopData command...")
	Utilities.SendServerCommandTo(player, "Shops", "SyncShopData", shopData)
	SharedLogger.log("Shops", "[ShopFinalizeHandler] SyncShopData sent")

	-- Send buy prices (initial sync) (Phase 2.8)
	local buyData = buildCalculatedPrices()
	SharedLogger.log(
		"Shops",
		"[ShopFinalizeHandler] Sending SyncBuyPrices (revision: " .. tostring(Shop.BuyPriceRevision or 0) .. ")"
	)

	Utilities.SendServerCommandTo(player, "Shops", "SyncBuyPrices", {
		revision = Shop.BuyPriceRevision,
		buyPrices = buyData.buyPrices,
		isInitialSync = true,
	})
	SharedLogger.log("Shops", "[ShopFinalizeHandler] SyncBuyPrices sent")

	-- Send sell rules (initial sync) (Phase 2.8)
	local modifiers = Builder.buildPriceModifiers()
	SharedLogger.log(
		"Shops",
		"[ShopFinalizeHandler] Sending SyncSellRules (revision: " .. tostring(Shop.SellRuleRevision or 0) .. ")"
	)

	Utilities.SendServerCommandTo(player, "Shops", "SyncSellRules", {
		revision = Shop.SellRuleRevision,
		sellModifiers = modifiers.sellModifiers or {},
		sellOverrides = modifiers.sellOverrides or {},
		isInitialSync = true,
	})
	SharedLogger.log("Shops", "[ShopFinalizeHandler] SyncSellRules sent")

	SharedLogger.log("Shops", "[ShopFinalizeHandler] Synced all data to " .. player:getUsername())
end

-- Register server-side event hooks for item loading
-- These hooks are triggered by ShopInit.lua during finalization
return ShopFinalizeHandler
