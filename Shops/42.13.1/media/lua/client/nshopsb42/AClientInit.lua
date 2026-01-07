-- Init.lua (Client)
-- Client-side module initialization with explicit load order
-- This file is in client/ folder, so it only loads on client

-- Load shared core modules first (required for Shop.textures and other shared systems)
require("nshopsb42/core/Shop")
require("nshopsb42/core/ShopRegistry")
require("nshopsb42/sales/ShopSellRegistry")
require("nshopsb42/events/ShopEvents")
require("nshopsb42/sales/ShopSellEvents")

-- Phase 2: Load disk cache module (for persistence support)
local ListingCache = require("nshopsb42/listing/ListingCache")

-- Phase 3: Load bootstrap module for offline-ready UI initialization
local ListingBootstrap = require("nshopsb42/listing/ListingBootstrap")

-- Module initialization
local PSClient = require("nshopsb42/PlayerShopClient")

require("nshopsb42/balance/BalanceClient")

-- Phase 3: Client-side listing service (deterministic preview pricing)
require("nshopsb42/ui/ClientShopListingService")

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
SHOPSB42.hasReceivedData = false -- Set by dispatcher when SyncShopData arrives
SHOPSB42.requestRetryCount = 0
SHOPSB42.lastRequestTick = 0
-- Phase 1: Track server revision for versioning support
SHOPSB42.serverRevision = 0
-- Phase 2: Track cached listing status
SHOPSB42.cachedListing = nil -- Will be populated by ListingCache.loadSnapshot() in onGameStart
SHOPSB42.cachedRevision = 0
-- Phase 3: Track bootstrap completion
SHOPSB42.listingBootstrapComplete = false

-- Reset sync flags on reconnect
local function onConnected()
	local SharedLogger = SHOPSB42.SharedLogger
	SharedLogger.log("Shops", "[Client Init onConnected] ENTRY")

	SHOPSB42.serverReady = false
	SHOPSB42.hasRequestedData = false
	-- Phase 1: Reset revision tracking on reconnect
	SHOPSB42.serverRevision = 0
	-- Phase 2: Reload cached listing (in case server changed)
	local serverId = getServer() and getServer():getLocalServerIdentifier() or "unknown"
	SHOPSB42.cachedListing = ListingCache.loadSnapshot(serverId)
	if SHOPSB42.cachedListing then
		SHOPSB42.cachedRevision = SHOPSB42.cachedListing.revision or 0
	else
		SHOPSB42.cachedRevision = 0
	end

	SharedLogger.log("Shops", "[Client Init onConnected] EXIT")
end

-- Load sprite cursor UI on game start (when vanilla ISBuildingObject is available)
-- Modules use lazy-load pattern: class derivation happens on first call
local function onGameStart()
	local SharedLogger = SHOPSB42.SharedLogger
	SharedLogger.log("Shops", "[Client Init onGameStart] ENTRY")

	-- Phase 2: Load cached listing from disk (if exists)
	local serverId = getServer() and getServer():getLocalServerIdentifier() or "unknown"
	SHOPSB42.cachedListing = ListingCache.loadSnapshot(serverId)
	if SHOPSB42.cachedListing then
		SHOPSB42.cachedRevision = SHOPSB42.cachedListing.revision or 0
		SharedLogger.log(
			"Shops",
			"[Client Init onGameStart] Loaded cached listing revision " .. SHOPSB42.cachedRevision
		)
	else
		SHOPSB42.cachedRevision = 0
		SharedLogger.log("Shops", "[Client Init onGameStart] No cached listing found")
	end

	local ShopSpriteCursorUIModule = require("nshopsb42/transactions/ShopSpriteCursorUI")
	ShopSpriteCursorUIModule.ensureInitialized()
	SharedLogger.log("Shops", "[Client Init] ShopSpriteCursorUI loaded and initialized")

	-- Phase 3: Bootstrap listing from cache or shared default (UI ready immediately)
	SharedLogger.log("Shops", "[Client Init onGameStart] Bootstrap phase 3 - initializing from cache/default...")
	local bootstrapSuccess = ListingBootstrap.bootstrap()
	if bootstrapSuccess then
		SharedLogger.log("Shops", "[Client Init onGameStart] Bootstrap successful, initializing UI...")
		ListingBootstrap.initializeUI()
		SharedLogger.log("Shops", "[Client Init onGameStart] UI initialized and ready (no network wait)")
	else
		SharedLogger.log("Shops", "[Client Init onGameStart] WARNING: Bootstrap failed, will use server SyncShopData")
		-- Fallback: wait for SyncShopData from server
		-- This is the pre-Phase 3 behavior if bootstrap somehow fails
	end

	-- Initialize shop sync client
	SharedLogger.log("Shops", "[Client Init onGameStart] Initializing ShopSyncClient...")
	local ShopSyncClient = SHOPSB42.ShopSyncClient
	ShopSyncClient.Initialize()
	SharedLogger.log("Shops", "[Client Init onGameStart] ShopSyncClient initialized")

	---@diagnostic disable-next-line: unnecessary-if
	-- Phase 4: Send revision query (lightweight handshake)
	if not SHOPSB42.hasRequestedData then
		SHOPSB42.hasRequestedData = true
		SHOPSB42.requestRetryCount = 0
		SHOPSB42.lastRequestTick = 0

		-- Phase 4: Query server revision only (cold path handshake)
		local success, err = pcall(function()
			sendClientCommand("nshopsb42", "QueryListingRevision", {
				clientRevision = SHOPSB42.serverRevision or 0,
			})
		end)

		if success then
			SharedLogger.log(
				"Shops",
				"[Client Init onGameStart] QueryListingRevision sent (client revision="
					.. (SHOPSB42.serverRevision or 0)
					.. ")"
			)
		else
			SharedLogger.log("Shops", "[Client Init onGameStart] ERROR sending QueryListingRevision: " .. tostring(err))
		end
	end

	SharedLogger.log("Shops", "[Client Init onGameStart] EXIT")
end

-- Phase 4: Retry QueryListingRevision every 60 ticks (3 seconds) if not received from server
-- This handles the case where the initial send was silently dropped
local function onPlayerUpdateRetry(player)
	if not player or SHOPSB42.hasReceivedData then
		return
	end

	---@diagnostic disable-next-line: unnecessary-if
	if not SHOPSB42.hasRequestedData then
		return
	end

	local SharedLogger = SHOPSB42.SharedLogger
	SHOPSB42.lastRequestTick = SHOPSB42.lastRequestTick + 1

	---@diagnostic disable-next-line: unnecessary-if
	-- Retry every 60 ticks (approximately 3 seconds), max 3 retries
	if SHOPSB42.lastRequestTick >= 60 and SHOPSB42.requestRetryCount < 3 then
		SHOPSB42.requestRetryCount = SHOPSB42.requestRetryCount + 1
		SHOPSB42.lastRequestTick = 0

		local success, err = pcall(function()
			sendClientCommand("nshopsb42", "QueryListingRevision", {
				clientRevision = SHOPSB42.serverRevision or 0,
			})
		end)

		if success then
			SharedLogger.log("Shops", "[Client] QueryListingRevision retry #" .. SHOPSB42.requestRetryCount)
		else
			SharedLogger.log(
				"Shops",
				"[Client] ERROR on retry #" .. SHOPSB42.requestRetryCount .. ": " .. tostring(err)
			)
		end
	end
end

Events.OnConnected.Add(onConnected)
Events.OnGameStart.Add(onGameStart)
Events.OnPlayerUpdate.Add(onPlayerUpdateRetry)
