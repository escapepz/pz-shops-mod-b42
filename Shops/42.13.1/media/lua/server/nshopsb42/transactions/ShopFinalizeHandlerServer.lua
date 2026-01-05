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

-- Helper: Compute buy price WITH modifier tracking for transparency (Phase 2)
local function computeBuyPriceWithModifiers(itemId)
	local item = Shop.Items[itemId]
	if not item then
		return nil
	end

	-- Check if player can buy this item
	if not Shop.canPlayerBuy(itemId) then
		return {
			price = item.basePrice or item.price,
			basePrice = item.basePrice or item.price,
			modifiers = {},
		}
	end

	local base = item.basePrice or item.price
	local modifiers = {}

	-- Trigger modify hooks to collect modifiers
	local ShopPriceEvents = SHOPSB42.ShopPriceEvents
	ShopPriceEvents.triggerOnShopModifyBuyPrice(nil, itemId, base, { type = "sync" }, modifiers)

	-- Apply modifiers
	local PriceUtils = require("nshopsb42/pricing/ShopPriceUtils")
	local price = PriceUtils.applyModifiers(base, modifiers)

	-- Check for overrides (don't include override in modifiers list, just use final price)
	local override = ShopPriceEvents.triggerOnShopOverrideBuyPrice(nil, itemId, price, { type = "sync" })
	---@diagnostic disable-next-line: unnecessary-if
	if override then
		price = override
	end

	return {
		price = price,
		basePrice = base,
		modifiers = modifiers,
	}
end

-- Helper: Calculate prices for ONLY defined items in PlayerBuy + PlayerSell registries (Step 2)
local function buildCalculatedPrices()
	local calculatedPrices = {
		buyPrices = {},
		sellPrices = {},
	}

	---@diagnostic disable-next-line: unnecessary-if
	-- ONLY calculate buy prices for defined items in PlayerBuy registry
	if Shop.PlayerBuy then
		for itemId, config in pairs(Shop.PlayerBuy) do
			if config.enabled then
				local priceData = computeBuyPriceWithModifiers(itemId)
				if priceData then
					calculatedPrices.buyPrices[itemId] = priceData
				end
			end
		end
	end

	---@diagnostic disable-next-line: unnecessary-if
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
-- Now returns full price data WITH modifiers (Phase 2)
local function detectPriceChanges(newCalculatedPrices, previousPrices)
	local changed = {}

	-- Only check items in PlayerBuy registry (defined items)
	if newCalculatedPrices.buyPrices then
		local playerBuy = Shop.PlayerBuy or {}
		for itemId, newPriceData in pairs(newCalculatedPrices.buyPrices) do
			if playerBuy[itemId] then -- ← Only registered items
				local oldPriceData = previousPrices[itemId]
				-- Compare final prices (oldPriceData might be just a number from old format)
				local oldPrice = (type(oldPriceData) == "table") and oldPriceData.price or oldPriceData
				local newPrice = (type(newPriceData) == "table") and newPriceData.price or newPriceData

				if oldPrice ~= newPrice then
					changed[itemId] = newPriceData
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
-- Note: Delta comparison is performed in broadcastSellRules()
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

-- DEPRECATED: Broadcast buy prices to all players (Phase 2.3 - DISABLED IN PHASE 3)
-- Phase 3 uses deterministic client-side pricing via ClientShopListingService
-- Clients calculate preview prices from shared catalog, no network broadcast needed
function ShopFinalizeHandler.broadcastBuyPrices()
	-- PHASE 3B: BROADCAST DISABLED
	-- Reason: Client loads catalog locally and calculates deterministically
	-- No per-player price sync needed during listing, only on transaction (server validates)
	SharedLogger.log(
		"Shops",
		"[ShopFinalizeHandler] broadcastBuyPrices() called but DISABLED (Phase 2.3 deprecated, using Phase 3 deterministic pricing)"
	)
	return
end

-- DEPRECATED: Broadcast sell rules to all players (Phase 2.5 - DISABLED IN PHASE 3)
-- Phase 3 uses deterministic client-side pricing via ClientShopListingService
-- Clients calculate preview prices from shared catalog, no network broadcast needed
function ShopFinalizeHandler.broadcastSellRules()
	-- PHASE 3B: BROADCAST DISABLED
	-- Reason: Client loads catalog locally and calculates deterministically
	-- No per-player price sync needed during listing, only on transaction (server validates)
	SharedLogger.log(
		"Shops",
		"[ShopFinalizeHandler] broadcastSellRules() called but DISABLED (Phase 2.5 deprecated, using Phase 3 deterministic pricing)"
	)
	return
end

-- Callback for price hook mutations (Phase 1.2)
local function onPriceHookAdded()
	---@diagnostic disable-next-line: unnecessary-if
	if Shop._finalized then
		ShopFinalizeHandler.resyncPriceModifiers()
	end
end

-- Callback for runtime price hook changes (test hooks, live updates) (Phase 2.1)
-- Phase 2.2: REMOVED per-player broadcasts
-- Clients calculate prices deterministically using PricingContract + NPCShopCatalog
-- No network sync needed during listing, only on transaction (server validates)
function ShopFinalizeHandler.onPriceHooksChanged()
	SharedLogger.log("Shops", "[ShopFinalizeHandler] onPriceHooksChanged() called (broadcasts removed)")

	---@diagnostic disable-next-line: unnecessary-if
	if not Shop._finalized then
		SharedLogger.log("Shops", "[ShopFinalizeHandler] Shop not finalized yet, aborting")
		return
	end

	-- Phase 2.2: Broadcast calls REMOVED
	-- Reason: Client no longer needs per-player price syncs
	-- Client loads catalog locally and calculates deterministically
	-- Server validates price on actual transaction (Phase 3)

	-- Note: Late-join sync still handled in sendShopDataToPlayer() (one-time handshake)
end

function ShopFinalizeHandler.finalizeNow()
	---@diagnostic disable-next-line: unnecessary-if
	if ShopFinalizeHandler._finalizationAttempted then
		return
	end
	ShopFinalizeHandler._finalizationAttempted = true

	-- Initialize independent revision counters (Phase 1.1)
	Shop.BuyPriceRevision = 0
	Shop.SellRuleRevision = 0

	---@diagnostic disable-next-line: unnecessary-if
	if not Shop._locked then
		SharedLogger.log("Shops", "[ShopFinalizeHandler] Finalizing buy registry...")
		Shop.FinalizeRegistry()
	end

	---@diagnostic disable-next-line: unnecessary-if
	if not Shop._sellLocked then
		SharedLogger.log("Shops", "[ShopFinalizeHandler] Finalizing sell registry...")
		Shop.FinalizeSellRegistry()
	end

	-- NEW: Build and cache price modifiers server-side
	SharedLogger.log("Shops", "[ShopFinalizeHandler] Building price modifiers...")
	local priceModifiers = Builder.buildPriceModifiers()

	-- Store on server for reuse during transactions
	SHOPSB42.Shop.PriceModifiers = priceModifiers

	---@diagnostic disable-next-line: unnecessary-if
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
	SharedLogger.log("Shops", "[ShopFinalizeHandler.sendShopDataToPlayer] ENTRY")

	if not Utilities.IsServerOrSinglePlayer() then
		SharedLogger.log("Shops", "[ShopFinalizeHandler.sendShopDataToPlayer] NOT in server context, aborting")
		SharedLogger.log("Shops", "[ShopFinalizeHandler] sendShopDataToPlayer not in server context, aborting")
		return
	end

	if not player then
		SharedLogger.log("Shops", "[ShopFinalizeHandler.sendShopDataToPlayer] player is nil, aborting")
		SharedLogger.log("Shops", "[ShopFinalizeHandler] sendShopDataToPlayer called with nil player, aborting")
		return
	end

	local username = player:getUsername() or "unknown"
	SharedLogger.log("Shops", "[ShopFinalizeHandler.sendShopDataToPlayer] Starting for player: " .. username)
	SharedLogger.log("Shops", "[ShopFinalizeHandler] sendShopDataToPlayer starting for " .. username)

	local itemCount = 0
	for _ in pairs(Shop.Items) do
		itemCount = itemCount + 1
	end
	SharedLogger.log(
		"Shops",
		"[ShopFinalizeHandler.sendShopDataToPlayer] Preparing SyncShopData with " .. itemCount .. " items"
	)
	SharedLogger.log("Shops", "[ShopFinalizeHandler] Preparing SyncShopData with " .. itemCount .. " items")

	-- Send shop items and config (including default prices for unregistered items)
	local shopData = {
		Items = Shop.Items,
		PlayerBuy = Shop.PlayerBuy,
		PlayerSell = Shop.PlayerSell,
		BuyIsWhitelist = Shop.BuyIsWhitelist,
		SellIsWhitelist = Shop.SellIsWhitelist,
		-- Phase 4 Fix: Sync default prices for fallback calculations on client
		defaultPrice = Shop.defaultPrice,
		defaultPriceBroken = Shop.defaultPriceBroken,
	}

	SharedLogger.log("Shops", "[ShopFinalizeHandler.sendShopDataToPlayer] SENDING SyncShopData...")
	SharedLogger.log("Shops", "[ShopFinalizeHandler] Sending SyncShopData command...")
	local success1, err1 = pcall(function()
		Utilities.SendServerCommandTo(player, "nshopsb42", "SyncShopData", shopData)
	end)
	if not success1 then
		SharedLogger.log(
			"Shops",
			"[ShopFinalizeHandler.sendShopDataToPlayer] ERROR sending SyncShopData: " .. tostring(err1)
		)
	else
		SharedLogger.log("Shops", "[ShopFinalizeHandler.sendShopDataToPlayer] SyncShopData sent successfully")
	end
	SharedLogger.log("Shops", "[ShopFinalizeHandler] SyncShopData sent")

	-- Send buy prices (initial sync) (Phase 2.8)
	SharedLogger.log("Shops", "[ShopFinalizeHandler.sendShopDataToPlayer] Building buy prices...")
	local buyData = buildCalculatedPrices()
	SharedLogger.log(
		"Shops",
		"[ShopFinalizeHandler.sendShopDataToPlayer] SENDING SyncBuyPrices (buyRev="
			.. tostring(Shop.BuyPriceRevision or 0)
			.. ", sellRev="
			.. tostring(Shop.SellRuleRevision or 0)
			.. ")"
	)
	SharedLogger.log(
		"Shops",
		"[ShopFinalizeHandler] Sending SyncBuyPrices (revision: " .. tostring(Shop.BuyPriceRevision or 0) .. ")"
	)

	local success2, err2 = pcall(function()
		Utilities.SendServerCommandTo(player, "nshopsb42", "SyncBuyPrices", {
			buyRevision = Shop.BuyPriceRevision,
			sellRevision = Shop.SellRuleRevision, -- Both revisions for atomicity
			buyPrices = buyData.buyPrices, -- Now includes modifiers for transparency
			isInitialSync = true,
		})
	end)
	if not success2 then
		SharedLogger.log(
			"Shops",
			"[ShopFinalizeHandler.sendShopDataToPlayer] ERROR sending SyncBuyPrices: " .. tostring(err2)
		)
	else
		SharedLogger.log("Shops", "[ShopFinalizeHandler.sendShopDataToPlayer] SyncBuyPrices sent successfully")
	end
	SharedLogger.log("Shops", "[ShopFinalizeHandler] SyncBuyPrices sent")

	-- Send sell rules (initial sync) (Phase 2.8)
	SharedLogger.log("Shops", "[ShopFinalizeHandler.sendShopDataToPlayer] Building sell rules...")
	local modifiers = Builder.buildPriceModifiers()
	SharedLogger.log(
		"Shops",
		"[ShopFinalizeHandler.sendShopDataToPlayer] SENDING SyncSellRules (sellRev="
			.. tostring(Shop.SellRuleRevision or 0)
			.. ")"
	)
	SharedLogger.log(
		"Shops",
		"[ShopFinalizeHandler] Sending SyncSellRules (revision: " .. tostring(Shop.SellRuleRevision or 0) .. ")"
	)

	local success3, err3 = pcall(function()
		Utilities.SendServerCommandTo(player, "nshopsb42", "SyncSellRules", {
			buyRevision = Shop.BuyPriceRevision, -- Both revisions for atomicity
			sellRevision = Shop.SellRuleRevision,
			sellModifiers = modifiers.sellModifiers or {},
			sellOverrides = modifiers.sellOverrides or {},
			isInitialSync = true,
		})
	end)
	if not success3 then
		SharedLogger.log(
			"Shops",
			"[ShopFinalizeHandler.sendShopDataToPlayer] ERROR sending SyncSellRules: " .. tostring(err3)
		)
	else
		SharedLogger.log("Shops", "[ShopFinalizeHandler.sendShopDataToPlayer] SyncSellRules sent successfully")
	end
	SharedLogger.log("Shops", "[ShopFinalizeHandler] SyncSellRules sent")

	-- Send completion signal (Phase 3: completion handshake)
	SharedLogger.log("Shops", "[ShopFinalizeHandler.sendShopDataToPlayer] SENDING SyncInitialComplete...")
	SharedLogger.log("Shops", "[ShopFinalizeHandler] Sending SyncInitialComplete...")
	local success4, err4 = pcall(function()
		Utilities.SendServerCommandTo(player, "nshopsb42", "SyncInitialComplete", {
			buyRevision = Shop.BuyPriceRevision,
			sellRevision = Shop.SellRuleRevision,
			timestamp = getGameTime():getWorldAgeHours(),
		})
	end)
	if not success4 then
		SharedLogger.log(
			"Shops",
			"[ShopFinalizeHandler.sendShopDataToPlayer] ERROR sending SyncInitialComplete: " .. tostring(err4)
		)
	else
		SharedLogger.log("Shops", "[ShopFinalizeHandler.sendShopDataToPlayer] SyncInitialComplete sent successfully")
	end
	SharedLogger.log("Shops", "[ShopFinalizeHandler] SyncInitialComplete sent")

	SharedLogger.log("Shops", "[ShopFinalizeHandler.sendShopDataToPlayer] EXIT - All data synced to " .. username)
	SharedLogger.log("Shops", "[ShopFinalizeHandler] Synced all data to " .. username)
end

-- Register server-side event hooks for item loading
-- These hooks are triggered by ShopInit.lua during finalization
return ShopFinalizeHandler
