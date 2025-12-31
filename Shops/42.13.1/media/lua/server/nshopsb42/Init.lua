-- Init.lua (Server)
-- Server-side module initialization with explicit load order

-- Module initialization
local ShopInitServer = require("nshopsb42/ShopInitServer")
local PSServer = require("nshopsb42/PlayerShopServer")

require("nshopsb42/balance/BalanceServer")
require("nshopsb42/logging/LogsServer")
require("nshopsb42/transactions/ShopSpriteCursor")
require("nshopsb42/balance/BalanceAudit")

-- Server-side patches
require("nshopsb42/patches/ISDestroyCursorPatch")

-- Initialize player shop and finalize (must be after all dependencies)
PSServer.Initialize()
ShopInitServer.Initialize()
