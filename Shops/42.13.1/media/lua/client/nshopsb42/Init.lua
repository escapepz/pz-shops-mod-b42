-- Init.lua (Client)
-- Client-side module initialization with explicit load order

if not isClient() or isServer() then
	return
end

-- Load shared core modules first (required for Shop.textures and other shared systems)
require("nshopsb42/core/Shop")
require("nshopsb42/core/ShopRegistry")
require("nshopsb42/sales/ShopSellRegistry")
require("nshopsb42/events/ShopEvents")
require("nshopsb42/sales/ShopSellEvents")

-- Module initialization
local PSClient = require("nshopsb42/PlayerShopClient")

require("nshopsb42/balance/BalanceClient")

-- Context managers
require("nshopsb42/context/ShopContext")
require("nshopsb42/context/CurrencyContext")
require("nshopsb42/context/PlayerShopContext")

-- UI components
require("nshopsb42/ui/ShopUI")
require("nshopsb42/ui/ShopTabUI")
require("nshopsb42/ui/TransferUI")
require("nshopsb42/ui/ContainerViewerUI")
require("nshopsb42/ui/PreviewUI")
require("nshopsb42/ui/ShopUITooltip")
require("nshopsb42/ui/SetPriceUI")
require("nshopsb42/ui/IncomeUI")
require("nshopsb42/ui/PlayerShopUI")
require("nshopsb42/ui/PlayerShopTabUI")

-- Client-side patches
require("nshopsb42/patches/ISInventoryPagePatch")
require("nshopsb42/patches/ISInventoryTransferActionPatch")
require("nshopsb42/patches/ISToolTipInvPatch")

-- Initialize player shop after all dependencies loaded
PSClient.Initialize()
