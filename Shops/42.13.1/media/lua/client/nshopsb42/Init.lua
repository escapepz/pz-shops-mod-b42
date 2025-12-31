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

-- Shop sprite cursor UI (client-side visual placement)
require("nshopsb42/transactions/ShopSpriteCursorUI")

-- Client-side patches
require("nshopsb42/patches/ISInventoryPagePatch")
require("nshopsb42/patches/ISInventoryTransferActionPatch")
require("nshopsb42/patches/ISToolTipInvPatch")

-- Initialize player shop after all dependencies loaded
PSClient.Initialize()
