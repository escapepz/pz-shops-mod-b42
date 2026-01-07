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

-- DEPRECATED: computeBuyPriceWithModifiers() - removed in Phase 1 cleanup
-- Pricing is now handled by PricingContract.calculateBuyPrice() in transactions
-- Client calculates preview prices deterministically (no server broadcast needed)

-- DEPRECATED: buildCalculatedPrices() - removed in Phase 1 cleanup
-- Reason: Client no longer needs per-player price syncs
-- Server broadcasts (SyncBuyPrices/SyncSellRules) are ignored by client (Phase 3)

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

-- DISABLED: Broadcast buy prices to all players (Phase 2.3 - kept for future live updates)
-- Phase 3 uses deterministic client-side pricing via ClientShopListingService
-- Clients calculate preview prices from shared catalog, no network broadcast needed
--
-- FUTURE CAPABILITY: To enable live price updates (e.g., when mods change prices):
-- 1. Uncomment the network broadcast code below
-- 2. Re-enable calls in sendShopDataToPlayer() and onPriceHooksChanged()
-- 3. Client handlers in ShopSyncClient.handleSyncBuyPrices() will receive updates
-- This infrastructure is intentionally kept for future extensibility
function ShopFinalizeHandler.broadcastBuyPrices()
	-- PHASE 3B: BROADCAST DISABLED FOR PERFORMANCE
	-- Reason: Client loads catalog locally and calculates deterministically
	-- No per-player price sync needed during listing, only on transaction (server validates)
	-- TODO: Re-enable this if implementing live price updates from server
	SharedLogger.log(
		"Shops",
		"[ShopFinalizeHandler] broadcastBuyPrices() called but DISABLED (Phase 3: deterministic pricing active; re-enable for live updates)"
	)
	return
end

-- DISABLED: Broadcast sell rules to all players (Phase 2.5 - kept for future live updates)
-- Phase 3 uses deterministic client-side pricing via ClientShopListingService
-- Clients calculate preview prices from shared catalog, no network broadcast needed
--
-- FUTURE CAPABILITY: To enable live price updates (e.g., when mods change prices):
-- 1. Uncomment the network broadcast code below
-- 2. Re-enable calls in sendShopDataToPlayer() and onPriceHooksChanged()
-- 3. Client handlers in ShopSyncClient.handleSyncSellRules() will receive updates
-- This infrastructure is intentionally kept for future extensibility
function ShopFinalizeHandler.broadcastSellRules()
	-- PHASE 3B: BROADCAST DISABLED FOR PERFORMANCE
	-- Reason: Client loads catalog locally and calculates deterministically
	-- No per-player price sync needed during listing, only on transaction (server validates)
	-- TODO: Re-enable this if implementing live price updates from server
	SharedLogger.log(
		"Shops",
		"[ShopFinalizeHandler] broadcastSellRules() called but DISABLED (Phase 3: deterministic pricing active; re-enable for live updates)"
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
-- Phase 3: Broadcasts DISABLED for deterministic client-side pricing
-- Clients calculate prices deterministically using PricingContract + NPCShopCatalog
-- No network sync needed during listing, only on transaction (server validates)
--
-- FUTURE: To enable live price updates (e.g., when a mod changes prices):
-- 1. Uncomment the broadcastBuyPrices() and broadcastSellRules() calls below
-- 2. These functions will re-enable and broadcast to all online players
-- 3. Client will update Shop.CalculatedPrices with new prices
function ShopFinalizeHandler.onPriceHooksChanged()
	SharedLogger.log("Shops", "[ShopFinalizeHandler] onPriceHooksChanged() called (broadcasts currently disabled)")

	---@diagnostic disable-next-line: unnecessary-if
	if not Shop._finalized then
		SharedLogger.log("Shops", "[ShopFinalizeHandler] Shop not finalized yet, aborting")
		return
	end

	-- Phase 3: Broadcast calls currently DISABLED
	-- Reason: Client no longer needs per-player price syncs for deterministic preview
	-- Client loads catalog locally and calculates deterministically
	-- Server validates price on actual transaction (Phase 3)
	-- TODO: Uncomment these for live price update feature:
	-- ShopFinalizeHandler.broadcastBuyPrices()
	-- ShopFinalizeHandler.broadcastSellRules()

	-- Note: Late-join sync still handled in sendShopDataToPlayer() (one-time handshake)
end

function ShopFinalizeHandler.finalizeNow()
	---@diagnostic disable-next-line: unnecessary-if
	if ShopFinalizeHandler._finalizationAttempted then
		return
	end
	ShopFinalizeHandler._finalizationAttempted = true

	-- Initialize revision counter for SyncShopData (Phase 1: Versioning)
	-- Incremented on every server restart
	Shop.Revision = (Shop.Revision or 0) + 1

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
	-- These listeners call onPriceHookAdded() which can trigger onPriceHooksChanged()
	-- FUTURE: onPriceHooksChanged() can be extended to re-enable broadcastBuyPrices/broadcastSellRules
	-- This infrastructure supports live price updates if needed in the future
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

	-- Enable hook event firing after finalization
	-- CRITICAL: Only set to true when finalization is complete and prices are stable
	-- This allows mods/code to use onPriceHooksChanged() for post-finalization price updates
	-- NOTE: Currently broadcasts are disabled (Phase 3), but hook listeners are active
	-- If a mod adds prices after finalization, onPriceHooksChanged() WILL be called
	-- To implement live updates: uncomment broadcasts in onPriceHooksChanged()
	Shop._finalized = true
	SharedLogger.log(
		"Shops",
		"[ShopFinalizeHandler] Finalization complete - hook listeners active (broadcasts currently disabled)"
	)
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
	-- Include server UUID for stable cache keying (required)
	local serverIdentity = ModData.get("ShopsServerIdentity") or {}
	local shopData = {
		revision = Shop.Revision,
		Items = Shop.Items,
		PlayerBuy = Shop.PlayerBuy,
		PlayerSell = Shop.PlayerSell,
		BuyIsWhitelist = Shop.BuyIsWhitelist,
		SellIsWhitelist = Shop.SellIsWhitelist,
		-- Phase 4 Fix: Sync default prices for fallback calculations on client
		defaultPrice = Shop.defaultPrice,
		defaultPriceBroken = Shop.defaultPriceBroken,
		-- Server UUID for stable cache keying (transmitted in every SyncShopData)
		serverUUID = serverIdentity.uuid,
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

	-- DEPRECATED: SyncBuyPrices broadcast removed in Phase 1 cleanup
	-- Reason: Client now calculates prices deterministically (no server broadcast needed)
	-- Client ignores SyncBuyPrices if received (Phase 3)

	-- DEPRECATED: SyncSellRules broadcast removed in Phase 1 cleanup
	-- Reason: Same as SyncBuyPrices - client calculates deterministically
	-- Client ignores SyncSellRules if received (Phase 3)

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
