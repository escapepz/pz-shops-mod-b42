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

-- Initialize state flags for server handshake in SHOPSB42 namespace
SHOPSB42.serverReady = false
SHOPSB42.hasRequestedData = false
SHOPSB42.hasReceivedData = false  -- Set by dispatcher when SyncShopData arrives
SHOPSB42.requestRetryCount = 0
SHOPSB42.lastRequestTick = 0

-- Reset sync flags on reconnect
local function onConnected()
	local SharedLogger = SHOPSB42.SharedLogger
	SharedLogger.log("Shops", "[Client Init onConnected] ENTRY")

	SHOPSB42.serverReady = false
	SHOPSB42.hasRequestedData = false

	SharedLogger.log("Shops", "[Client Init onConnected] EXIT")
end

-- Load sprite cursor UI on game start (when vanilla ISBuildingObject is available)
-- Modules use lazy-load pattern: class derivation happens on first call
local function onGameStart()
	local SharedLogger = SHOPSB42.SharedLogger
	SharedLogger.log("Shops", "[Client Init onGameStart] ENTRY")

	local ShopSpriteCursorUIModule = require("nshopsb42/transactions/ShopSpriteCursorUI")
	ShopSpriteCursorUIModule.ensureInitialized()
	SharedLogger.log("Shops", "[Client Init] ShopSpriteCursorUI loaded and initialized")

	-- Initialize shop sync client
	SharedLogger.log("Shops", "[Client Init onGameStart] Initializing ShopSyncClient...")
	local ShopSyncClient = SHOPSB42.ShopSyncClient
	ShopSyncClient.Initialize()
	SharedLogger.log("Shops", "[Client Init onGameStart] ShopSyncClient initialized")

	-- TEST: Send a simple "ping" command to verify the network path works
	if not SHOPSB42.hasRequestedData then
		SHOPSB42.hasRequestedData = true
		SHOPSB42.requestRetryCount = 0
		SHOPSB42.lastRequestTick = 0
		
		-- First, test with a minimal command
		local success0, err0 = pcall(function()
			sendClientCommand("nshopsb42", "TestPing", {})
		end)

		if success0 then
			SharedLogger.log("Shops", "[Client Init onGameStart] TestPing sent")
		else
			SharedLogger.log("Shops", "[Client Init onGameStart] ERROR sending TestPing: " .. tostring(err0))
		end
		
		-- Then send the actual request
		local success, err = pcall(function()
			sendClientCommand("nshopsb42", "RequestShopData", {})
		end)

		if success then
			SharedLogger.log("Shops", "[Client Init onGameStart] RequestShopData sent (player is in-game)")
		else
			SharedLogger.log("Shops", "[Client Init onGameStart] ERROR sending RequestShopData: " .. tostring(err))
		end
	end

	SharedLogger.log("Shops", "[Client Init onGameStart] EXIT")
end

-- Retry RequestShopData every 60 ticks (3 seconds) if not received from server
-- This handles the case where the initial send was silently dropped
local function onPlayerUpdateRetry(player)
	if not player or SHOPSB42.hasReceivedData then return end
	
	if not SHOPSB42.hasRequestedData then return end
	
	local SharedLogger = SHOPSB42.SharedLogger
	SHOPSB42.lastRequestTick = SHOPSB42.lastRequestTick + 1
	
	-- Retry every 60 ticks (approximately 3 seconds), max 3 retries
	if SHOPSB42.lastRequestTick >= 60 and SHOPSB42.requestRetryCount < 3 then
		SHOPSB42.requestRetryCount = SHOPSB42.requestRetryCount + 1
		SHOPSB42.lastRequestTick = 0
		
		local success, err = pcall(function()
			sendClientCommand("nshopsb42", "RequestShopData", {})
		end)
		
		if success then
			SharedLogger.log("Shops", "[Client] RequestShopData retry #" .. SHOPSB42.requestRetryCount)
		else
			SharedLogger.log("Shops", "[Client] ERROR on retry #" .. SHOPSB42.requestRetryCount .. ": " .. tostring(err))
		end
	end
end

Events.OnConnected.Add(onConnected)
Events.OnGameStart.Add(onGameStart)
Events.OnPlayerUpdate.Add(onPlayerUpdateRetry)
