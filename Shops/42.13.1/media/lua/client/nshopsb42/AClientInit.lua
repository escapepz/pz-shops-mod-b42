-- Init.lua (Client)
-- Client-side module initialization with explicit load order
-- This file is in client/ folder, so it only loads on client

-- Load shared core modules first (required for Shop.textures and other shared systems)
require("nshopsb42/core/Shop")
require("nshopsb42/core/ShopRegistry")
require("nshopsb42/sales/ShopSellRegistry")
require("nshopsb42/events/ShopEvents")
require("nshopsb42/sales/ShopSellEvents")

-- Module initialization
local PSClient = require("nshopsb42/PlayerShopClient")

require("nshopsb42/balance/BalanceClient")

-- UI components (load dependencies first, before components that depend on them)
require("nshopsb42/ui/ContainerViewerUI")
require("nshopsb42/ui/BundleViewerUI")
require("nshopsb42/ui/PreviewUI")
require("nshopsb42/ui/ShopUITooltip")
require("nshopsb42/ui/SetPriceUI")
require("nshopsb42/ui/TransferUI")
require("nshopsb42/ui/ShopTabUI")
require("nshopsb42/ui/ShopUI")
require("nshopsb42/ui/IncomeUI")
require("nshopsb42/ui/PlayerShopTabUI")
require("nshopsb42/ui/PlayerShopUI")

-- Context managers (must load after UI components)
require("nshopsb42/context/ShopContext")
require("nshopsb42/context/CurrencyContext")
require("nshopsb42/context/PlayerShopContext")

-- Context menu dispatchers
require("nshopsb42/context/WorldObjectContextMenuDispatcher")
require("nshopsb42/context/InventoryObjectContextMenuDispatcher")

-- Client-side patches
require("nshopsb42/patches/ISInventoryPagePatch")
require("nshopsb42/patches/ISInventoryTransferActionPatch")
require("nshopsb42/patches/ISToolTipInvPatch")

-- Sync client for receiving shop data from server
require("nshopsb42/sync/ShopSyncClient")

-- Event dispatchers (must be loaded after all handlers are defined)
require("nshopsb42/ShopCommandDispatcherClient")
require("nshopsb42/sync/ModDataDispatcherClient")

-- Initialize player shop after all dependencies loaded
PSClient.Initialize()

-- Load sprite cursor UI on game start (when vanilla ISBuildingObject is available)
-- Modules use lazy-load pattern: class derivation happens on first call
local function onGameStart()
	local SharedLogger = SHOPSB42.SharedLogger
	SharedLogger.log("Shops", "[Client Init onGameStart] ENTRY")
	local Utilities = require("nshopsb42/utils/Utilities.lua")
	local ShopSpriteCursorUIModule = require("nshopsb42/transactions/ShopSpriteCursorUI")
	ShopSpriteCursorUIModule.ensureInitialized()
	SharedLogger.log("Shops", "[Client Init] ShopSpriteCursorUI loaded and initialized")

	-- Initialize shop sync client and request data from server
	SharedLogger.log("Shops", "[Client Init onGameStart] Initializing ShopSyncClient...")
	local ShopSyncClient = SHOPSB42.ShopSyncClient
	ShopSyncClient.Initialize()
	SharedLogger.log("Shops", "[Client Init onGameStart] ShopSyncClient initialized")

	-- Request shop data from server (MP) or trigger sync (SP)
	if Utilities.IsClientOrSinglePlayer() then
		SharedLogger.log("Shops", "[Client Init] OnGameStart event triggered")
		local isMP = isMultiplayer()
		SharedLogger.log("Shops", "[Client Init] IsMultiplayer: " .. tostring(isMP))

		-- Log before sending to confirm execution
		SharedLogger.log("Shops", "[Client Init] About to call sendClientCommand()")
		SharedLogger.log("Shops", "[Client Init] Args: module='nshopsb42', command='RequestShopData', data={}")

		local success, err = pcall(function()
			sendClientCommand("nshopsb42", "RequestShopData", {})
		end)

		if success then
			SharedLogger.log(
				"Shops",
				"[Client Init] sendClientCommand executed successfully - data request sent to server"
			)
		else
			SharedLogger.log("Shops", "[Client Init] ERROR: sendClientCommand failed - " .. tostring(err))
		end
		SharedLogger.log("Shops", "[Client Init] Sent RequestShopData command to server")
	else
		SharedLogger.log("Shops", "[Client Init] Not in client/SP context, skipping data request")
	end
	SharedLogger.log("Shops", "[Client Init onGameStart] EXIT")
end

Events.OnGameStart.Add(onGameStart)
