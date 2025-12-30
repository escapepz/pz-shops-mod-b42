-- ShopFinalizeHandlerServer.lua (Server-only)
-- Server-side finalization handler for item registries
-- Extends SHOPSB42 namespace (no new globals)
-- In MP: Only server registers and finalizes; client receives data

if not isServer() then
	return
end

local SharedLogger = require("nshopsb42/utils/SharedLogger")

local Shop = SHOPSB42.Shop
local ShopEvents = SHOPSB42.ShopEvents
local ShopSellEvents = SHOPSB42.ShopSellEvents
local ShopDefaultItems = SHOPSB42.ShopDefaultItems

-- Finalization handler: locks registries after all items are registered
SHOPSB42.ShopFinalizeHandler = SHOPSB42.ShopFinalizeHandler or {}
local ShopFinalizeHandler = SHOPSB42.ShopFinalizeHandler

ShopFinalizeHandler._finalizationAttempted = ShopFinalizeHandler._finalizationAttempted or false

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
end

-- Register server-side event hooks for item loading
-- These hooks are triggered by ShopInit.lua during finalization
return ShopFinalizeHandler
