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

-- Initialize player shop and finalize (must be after all dependencies)
PSServer.Initialize()
ShopInitServer.Initialize()

-- Server-initiated handshake: client must request on a properly-timed event
-- The original approach of server-initiated sends has race conditions
-- Instead, we rely on the client to request data at the right time
-- The dispatcher will handle RequestShopData when it arrives
