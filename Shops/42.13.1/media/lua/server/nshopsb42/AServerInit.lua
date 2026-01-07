-- Init.lua (Server)
-- Server-side module initialization with explicit load order

-- Module initialization
local ShopInitServer = require("nshopsb42/ShopInitServer")
if not ShopInitServer then
	error("Failed to load ShopInitServer module - require returned nil", 2)
end

local PSServer = require("nshopsb42/PlayerShopServer")
if not PSServer then
	error("Failed to load PlayerShopServer module - require returned nil", 2)
end

require("nshopsb42/balance/BalanceServer")
require("nshopsb42/logging/LogsServer")
require("nshopsb42/balance/BalanceAudit")

-- Command handlers (must load after balance and other systems)
require("nshopsb42/transactions/ShopCommandHandlerServer")

-- Command dispatcher (must load after all command handlers are defined)
require("nshopsb42/ShopCommandDispatcherServer")

-- Server-side patches
require("nshopsb42/patches/ISDestroyCursorPatch")

-- Ensure server UUID is generated and transmitted to clients
-- This UUID is used as the cache key for client-side listing snapshots
-- Must persist across server restarts to maintain cache stability
local function ensureShopsServerUUID()
	local SharedLogger = SHOPSB42.SharedLogger
	local SHOPS_SERVER_ID_KEY = "ShopsServerIdentity"

	-- Create or retrieve server identity from ModData
	local data = ModData.getOrCreate(SHOPS_SERVER_ID_KEY)

	if not data.uuid then
		-- First startup: generate UUID (timestamp + random)
		data.uuid = tostring(getTimestamp()) .. "-" .. ZombRand(1000000)
		data.createdAt = getTimestamp()
		data.schema = 1 -- future versioning

		SharedLogger.log("Shops", "[Server Init] Generated new server UUID: " .. data.uuid)
	else
		-- Restart: UUID already exists, verify schema
		SharedLogger.log("Shops", "[Server Init] Loaded existing server UUID: " .. data.uuid)
	end

	-- Transmit UUID to all clients (late-joiners receive via ModData sync)
	ModData.transmit(SHOPS_SERVER_ID_KEY)
end

Events.OnServerStarted.Add(function()
	-- Initialize player shop and finalize (must be after all dependencies)
	PSServer.Initialize()
	ShopInitServer.Initialize()

	-- Ensure server UUID is generated and transmitted
	ensureShopsServerUUID()
end)

-- Server-initiated handshake: client must request on a properly-timed event
-- The original approach of server-initiated sends has race conditions
-- Instead, we rely on the client to request data at the right time
-- The dispatcher will handle RequestShopData when it arrives
