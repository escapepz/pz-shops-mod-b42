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

-- Callback for price hook mutations (Phase 1.2)
local function onPriceHookAdded()
	if Shop._finalized then
		Shop.PriceHookRevision = Shop.PriceHookRevision + 1
		ShopFinalizeHandler.resyncPriceModifiers()
	end
end

-- Callback for runtime price hook changes (test hooks, live updates) (Step 4)
function ShopFinalizeHandler.onPriceHooksChanged()
	SharedLogger.log("Shops", "[ShopFinalizeHandler] onPriceHooksChanged() called")

	if not Shop._finalized then
		SharedLogger.log("Shops", "[ShopFinalizeHandler] Shop not finalized yet, aborting")
		return
	end

	Shop.PriceHookRevision = Shop.PriceHookRevision + 1
	SharedLogger.log(
		"Shops",
		"[ShopFinalizeHandler] Incremented revision to: " .. tostring(Shop.PriceHookRevision or 0)
	)

	-- CRITICAL: Rebuild modifiers and calculate prices BEFORE broadcasting
	local modifiers = Builder.buildPriceModifiers()
	Shop.PriceModifiers = modifiers
	SharedLogger.log("Shops", "[ShopFinalizeHandler] Rebuilt modifiers, rebuilding calculated prices...")

	-- Calculate prices for defined items only
	local calculatedPrices = buildCalculatedPrices()

	-- Detect which prices actually changed from previous state (delta detection)
	local changedPrices = detectPriceChanges(calculatedPrices, ShopFinalizeHandler._previousBuyPrices)

	local changeCount = 0
	for _ in pairs(changedPrices) do
		changeCount = changeCount + 1
	end

	local definedItemCount = 0
	if Shop.PlayerBuy then
		for _ in pairs(Shop.PlayerBuy) do
			definedItemCount = definedItemCount + 1
		end
	end

	SharedLogger.log(
		"Shops",
		"[ShopFinalizeHandler] Detected "
		.. changeCount
		.. " price changes out of "
		.. definedItemCount
		.. " defined items"
	)

	-- Store new prices for next comparison
	ShopFinalizeHandler._previousBuyPrices = calculatedPrices.buyPrices or {}

	-- DEBUG: Log sample changed prices
	if calculatedPrices.buyPrices["Base.Apple"] then
		SharedLogger.log(
			"Shops",
			"[ShopFinalizeHandler] Base.Apple calculated buy price: " .. calculatedPrices.buyPrices["Base.Apple"]
		)
	end

	-- Broadcast: Send modifiers (for sell calculations) + changed prices only (optimized)
	Utilities.SendServerCommandToAll("Shops", "SyncPriceModifiers", {
		revision = Shop.PriceHookRevision,
		modifiers = modifiers, -- ← KEEP (needed for sell price hooks)
		changed = changedPrices, -- ← OPTIMIZED: Only changed items
	})

	SharedLogger.log(
		"Shops",
		"[ShopFinalizeHandler] Price hooks changed, revision: " .. tostring(Shop.PriceHookRevision or 0)
	)
end

function ShopFinalizeHandler.finalizeNow()
	if ShopFinalizeHandler._finalizationAttempted then
		return
	end
	ShopFinalizeHandler._finalizationAttempted = true

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

-- Rebuild price modifiers and broadcast to all online players (Phase 1.3) (Step 6)
function ShopFinalizeHandler.resyncPriceModifiers()
	if not Utilities.IsServerOrSinglePlayer() then
		return
	end

	local modifiers = Builder.buildPriceModifiers()
	Shop.PriceModifiers = modifiers

	-- Calculate prices for defined items only
	local calculatedPrices = buildCalculatedPrices()

	-- Detect changes for optimized broadcast
	local changedPrices = detectPriceChanges(calculatedPrices, ShopFinalizeHandler._previousBuyPrices)
	ShopFinalizeHandler._previousBuyPrices = calculatedPrices.buyPrices or {}

	-- Broadcast to all players at once (optimized with delta)
	Utilities.SendServerCommandToAll("Shops", "SyncPriceModifiers", {
		revision = Shop.PriceHookRevision,
		modifiers = modifiers, -- <- KEEP (needed for sell price hooks)
		changed = changedPrices, -- <- OPTIMIZED: Only changed items
	})

	SharedLogger.log(
		"Shops",
		"[ShopFinalizeHandler] Price modifiers resynced to all players (revision: "
		.. tostring(Shop.PriceHookRevision or 0)
		.. ")"
	)
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

	-- Send cached price modifiers with calculated prices (initial sync: full prices)
	local priceModifiers = Shop.PriceModifiers or {}
	local calculatedPrices = buildCalculatedPrices()

	SharedLogger.log(
		"Shops",
		"[ShopFinalizeHandler] Sending SyncPriceModifiers (revision: " .. tostring(Shop.PriceHookRevision or 0) .. ")"
	)

	-- Initial sync: Send full prices + modifiers
	Utilities.SendServerCommandTo(player, "Shops", "SyncPriceModifiers", {
		revision = Shop.PriceHookRevision,
		modifiers = priceModifiers,    -- ← KEEP (needed for sell price calculations)
		calculatedPrices = calculatedPrices, -- ← Full prices on initial sync only
		isInitialSync = true,          -- ← Flag to client
	})
	SharedLogger.log("Shops", "[ShopFinalizeHandler] SyncPriceModifiers sent")

	SharedLogger.log("Shops", "[ShopFinalizeHandler] Synced all data to " .. player:getUsername())
end

-- Register server-side event hooks for item loading
-- These hooks are triggered by ShopInit.lua during finalization
return ShopFinalizeHandler
