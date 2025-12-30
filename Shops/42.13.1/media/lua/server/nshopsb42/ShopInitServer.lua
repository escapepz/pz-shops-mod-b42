-- ShopInitServer.lua
-- Server-side shop initialization

if not isServer() then
	return
end

-- Simple test to verify logging works
writeLog("Shops", "[ShopInitServer] Starting server shop initialization...")

-- Load in explicit order to ensure dependencies are met
-- First: Core constants and logger
local SharedLogger = require("nshopsb42/utils/SharedLogger")
require("nshopsb42/core/Shop") -- Must be first to define Tab constants and Shop global

-- Second: Registry implementation
require("nshopsb42/core/ShopRegistry")
require("nshopsb42/sales/ShopSellRegistry")

-- Third: Event system
local ShopEvents = require("nshopsb42/events/ShopEvents")
local ShopSellEvents = require("nshopsb42/sales/ShopSellEvents")

-- Fourth: Initialization/finalization
require("nshopsb42/ShopInit")
require("nshopsb42/sales/ShopSellInit")

-- Fifth: Default items (depends on all above)
local ShopDefaultItems = require("nshopsb42/ShopDefaultItems")

-- Sixth: Server-side finalization (must be last - registers hooks and finalizes)
local ShopFinalizeHandler = require("nshopsb42/transactions/ShopFinalizeHandlerServer")

-- Seventh: Server-side patches
require("nshopsb42/patches/ISTransferActionPatch")

local ShopInitServerModule = {}

function ShopInitServerModule.Initialize()
	SharedLogger.log("Shops", "[ShopInitServer] All modules loaded. Beginning initialization...")

	-- Register hooks (both buy and sell items)
	ShopDefaultItems.registerHooks()

	-- Trigger finalization (server-only)
	SharedLogger.log("Shops", "[ShopInitServer] Calling ShopFinalizeHandler.finalizeNow()")
	ShopFinalizeHandler.finalizeNow()
end

return ShopInitServerModule
