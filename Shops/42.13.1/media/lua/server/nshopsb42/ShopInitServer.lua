-- ShopInitServer.lua
-- Server-side shop initialization

-- Simple test to verify logging works
writeLog("Shops", "[ShopInitServer] Starting server shop initialization...")

-- Load in explicit order to ensure dependencies are met
-- First: Core constants and logger
local SharedLogger = require("nshopsb42/utils/SharedLogger")
local Utilities = require("nshopsb42/utils/Utilities")
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

-- Seventh: Server-side transaction validation
require("nshopsb42/transactions/ShopTransactionValidationServer")

-- Eighth: Server-side patches
require("nshopsb42/patches/ISTransferActionPatch")

local ShopInitServerModule = {}

function ShopInitServerModule.Initialize()
	SharedLogger.log("Shops", "[ShopInitServer] All modules loaded. Beginning initialization...")

	-- Register hooks (both buy and sell items)
	ShopDefaultItems.registerHooks()

	-- Trigger finalization (server-only)
	SharedLogger.log("Shops", "[ShopInitServer] Calling ShopFinalizeHandler.finalizeNow()")
	ShopFinalizeHandler.finalizeNow()

	local TestPriceHooks = require("nshopsb42/TestPriceHooks")
	TestPriceHooks.initialize()

	local TestPriceHooksCommand = require("nshopsb42/TestPriceHooksCommand")
	TestPriceHooksCommand.register()
end

-- NEW: Handle client requests for shop data (MP and SP)
local function onClientCommand(module, command, player, data)
	if module ~= "Shops" then
		return
	end

	if command ~= "RequestShopData" then
		SharedLogger.log("Shops", "[ShopInitServer] Received non-RequestShopData command: " .. command)
		return
	end

	SharedLogger.log("Shops", "[ShopInitServer] Received RequestShopData from " .. player:getUsername())
	local shop = SHOPSB42.Shop
	SharedLogger.log("Shops", "[ShopInitServer] Shop._finalized: " .. tostring(shop._finalized))
	SharedLogger.log("Shops", "[ShopInitServer] Shop.PriceHookRevision: " .. tostring(shop.PriceHookRevision))

	-- Use cached modifiers from finalization phase
	SharedLogger.log("Shops", "[ShopInitServer] Calling sendShopDataToPlayer...")
	ShopFinalizeHandler.sendShopDataToPlayer(player)
	SharedLogger.log("Shops", "[ShopInitServer] sendShopDataToPlayer completed")
end

Events.OnClientCommand.Add(onClientCommand)

-- NEW: Trigger finalization and build modifiers on game start (server context)
local function onGameStartServer()
	if Utilities.IsServerOrSinglePlayer() then
		SharedLogger.log("Shops", "[ShopInitServer] OnGameStart triggered on server")

		-- Finalization already called in Initialize() via ShopDefaultItems.registerHooks()
		-- But ensure it's finalized
		ShopFinalizeHandler.finalizeNow()

		-- Modifiers are cached by finalizeNow()
		if SHOPSB42.Shop.PriceModifiers then
			SharedLogger.log("Shops", "[ShopInitServer] Price modifiers available for clients")
		end
	end
end

Events.OnGameStart.Add(onGameStartServer)

return ShopInitServerModule
