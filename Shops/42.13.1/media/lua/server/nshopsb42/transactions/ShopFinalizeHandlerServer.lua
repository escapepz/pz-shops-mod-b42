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

-- Helper: Calculate all item prices for server-only hooks (calculated once for all players)
local function buildCalculatedPrices()
	local calculatedPrices = {
		buyPrices = {},
		sellPrices = {},
	}

	-- Calculate buy prices for all items
	-- Use nil player for generic calculation (hooks should not depend on specific player)
	if Shop.Items then
		for itemId, itemData in pairs(Shop.Items) do
			local buyPrice = Shop.resolvePlayerBuyPrice(nil, itemId, { type = "sync" })
			if buyPrice then
				calculatedPrices.buyPrices[itemId] = buyPrice
			end
		end
	end

	-- Calculate sell prices for all sell items
	-- PlayerSell maps item IDs to sell configs, not actual item objects
	-- For sell price calculation, we need item objects, so we skip this for now
	-- The UI will calculate sell prices dynamically using inventory items

	return calculatedPrices
end

-- Callback for price hook mutations (Phase 1.2)
local function onPriceHookAdded()
	if Shop._finalized then
		Shop.PriceHookRevision = Shop.PriceHookRevision + 1
		ShopFinalizeHandler.resyncPriceModifiers()
	end
end

-- Callback for runtime price hook changes (test hooks, live updates)
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

	-- Calculate prices once (not per-player, since hooks don't vary by player)
	local calculatedPrices = buildCalculatedPrices()

	local buyPriceCount = 0
	if calculatedPrices.buyPrices then
		for _ in pairs(calculatedPrices.buyPrices) do
			buyPriceCount = buyPriceCount + 1
		end
	end
	SharedLogger.log(
		"Shops",
		"[ShopFinalizeHandler] Calculated " .. buyPriceCount .. " buy prices, broadcasting to all players..."
	)

	-- DEBUG: Log some calculated prices for verification
	if calculatedPrices.buyPrices["Base.Apple"] then
		SharedLogger.log(
			"Shops",
			"[ShopFinalizeHandler] Base.Apple calculated buy price: " .. calculatedPrices.buyPrices["Base.Apple"]
		)
	end

	-- Broadcast to all players at once
	Utilities.SendServerCommandToAll("Shops", "SyncPriceModifiers", {
		revision = Shop.PriceHookRevision,
		modifiers = modifiers,
		calculatedPrices = calculatedPrices,
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

-- Rebuild price modifiers and broadcast to all online players (Phase 1.3)
function ShopFinalizeHandler.resyncPriceModifiers()
	if not Utilities.IsServerOrSinglePlayer() then
		return
	end

	local modifiers = Builder.buildPriceModifiers()
	Shop.PriceModifiers = modifiers

	-- Calculate prices once (not per-player, since hooks don't vary by player)
	local calculatedPrices = buildCalculatedPrices()

	-- Broadcast to all players at once
	Utilities.SendServerCommandToAll("Shops", "SyncPriceModifiers", {
		revision = Shop.PriceHookRevision,
		modifiers = modifiers,
		calculatedPrices = calculatedPrices,
	})

	SharedLogger.log(
		"Shops",
		"[ShopFinalizeHandler] Price modifiers resynced to all players (revision: "
			.. tostring(Shop.PriceHookRevision or 0)
			.. ")"
	)
end

-- NEW: Send data to a specific player (called when they connect)
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

	-- Send cached price modifiers with calculated prices
	local priceModifiers = Shop.PriceModifiers or {}
	local calculatedPrices = buildCalculatedPrices()

	SharedLogger.log(
		"Shops",
		"[ShopFinalizeHandler] Sending SyncPriceModifiers (revision: " .. tostring(Shop.PriceHookRevision or 0) .. ")"
	)
	Utilities.SendServerCommandTo(player, "Shops", "SyncPriceModifiers", {
		revision = Shop.PriceHookRevision,
		modifiers = priceModifiers,
		calculatedPrices = calculatedPrices,
	})
	SharedLogger.log("Shops", "[ShopFinalizeHandler] SyncPriceModifiers sent")

	SharedLogger.log("Shops", "[ShopFinalizeHandler] Synced all data to " .. player:getUsername())
end

-- Register server-side event hooks for item loading
-- These hooks are triggered by ShopInit.lua during finalization
return ShopFinalizeHandler
