-- ShopFinalizeHandlerServer.lua (Server-only)
-- Server-side finalization handler for item registries
-- Extends SHOPSB42 namespace (no new globals)
-- In MP: Only server registers and finalizes; client receives data

local SharedLogger = require("nshopsb42/utils/SharedLogger")
local Builder = require("nshopsb42/pricing/ShopPriceModifierBuilder")

local Shop = SHOPSB42.Shop
local ShopEvents = SHOPSB42.ShopEvents
local ShopSellEvents = SHOPSB42.ShopSellEvents
local ShopDefaultItems = SHOPSB42.ShopDefaultItems

-- Finalization handler: locks registries after all items are registered
SHOPSB42.ShopFinalizeHandler = SHOPSB42.ShopFinalizeHandler or {}
local ShopFinalizeHandler = SHOPSB42.ShopFinalizeHandler

ShopFinalizeHandler._finalizationAttempted = ShopFinalizeHandler._finalizationAttempted or false

-- Callback for price hook mutations (Phase 1.2)
local function onPriceHookAdded()
	if Shop._finalized then
		Shop.PriceHookRevision = Shop.PriceHookRevision + 1
		ShopFinalizeHandler.resyncPriceModifiers()
	end
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
end

-- Rebuild price modifiers and broadcast to all online players (Phase 1.3)
function ShopFinalizeHandler.resyncPriceModifiers()
	if not isServer() then return end

	local modifiers = Builder.buildPriceModifiers()
	Shop.PriceModifiers = modifiers

	for _, player in ipairs(getOnlinePlayers()) do
		sendServerCommandTo(
			player,
			"Shops",
			"SyncPriceModifiers",
			{
				revision = Shop.PriceHookRevision,
				modifiers = modifiers
			}
		)
	end

	SharedLogger.log("Shops", "[ShopFinalizeHandler] Price modifiers resynced to all players (revision: " .. Shop.PriceHookRevision .. ")")
end

-- NEW: Send data to a specific player (called when they connect)
function ShopFinalizeHandler.sendShopDataToPlayer(player)
	if not isServer() then
		return
	end

	local Shop = SHOPSB42.Shop

	-- Send shop items and config
	local shopData = {
		Items = Shop.Items,
		PlayerBuy = Shop.PlayerBuy,
		PlayerSell = Shop.PlayerSell,
		BuyIsWhitelist = Shop.BuyIsWhitelist,
		SellIsWhitelist = Shop.SellIsWhitelist,
	}

	sendServerCommandTo(player, "Shops", "SyncShopData", shopData)

	-- Send cached price modifiers
	local priceModifiers = Shop.PriceModifiers or {}
	sendServerCommandTo(player, "Shops", "SyncPriceModifiers", {
		revision = Shop.PriceHookRevision,
		modifiers = priceModifiers
	})

	SharedLogger.log("Shops", "[ShopFinalizeHandler] Synced shop data to " .. player:getUsername())
end

-- Register server-side event hooks for item loading
-- These hooks are triggered by ShopInit.lua during finalization
return ShopFinalizeHandler
