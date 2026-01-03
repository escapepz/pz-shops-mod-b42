-- ShopDefaultItems.lua
-- Load default buy and sell items via the hook system (SERVER ONLY)
-- Extends SHOPSB42 namespace (no new globals)
-- Items self-register during require() calls

local Utilities = require("nshopsb42/utils/Utilities")

SHOPSB42.ShopDefaultItems = SHOPSB42.ShopDefaultItems or {}
local ShopDefaultItems = SHOPSB42.ShopDefaultItems

local Shop = SHOPSB42.Shop
local ShopEvents = SHOPSB42.ShopEvents
local ShopSellEvents = SHOPSB42.ShopSellEvents

-- Hook callback: Load default buy items
function ShopDefaultItems.loadDefaultBuyItems()
	if not Utilities.IsServerOrSinglePlayer() then
		return
	end

	require("nshopsb42/ShopItems/Food")
	require("nshopsb42/ShopItems/Weapons")
	require("nshopsb42/ShopItems/FirstAid")
	require("nshopsb42/ShopItems/Vehicles")
	require("nshopsb42/ShopItems/Event")
end

-- Hook callback: Load default sell items
function ShopDefaultItems.loadDefaultSellItems()
	if not Utilities.IsServerOrSinglePlayer() then
		return
	end

	require("nshopsb42/ShopItems/ForSell")
end

-- Register hooks (gates registration based on suppressDefaults flag)
function ShopDefaultItems.registerHooks()
	if not Utilities.IsServerOrSinglePlayer() then
		return
	end

	-- Check suppression flag at REGISTRATION time (not execution time)
	-- This prevents default hooks from being registered in the first place
	if SHOPSB42.Config.suppressDefaults == true then
		local SharedLogger = require("nshopsb42/utils/SharedLogger")
		SharedLogger.log("Shops", "[ShopDefaultItems] Suppression flag detected - default item hooks NOT registered")
		return
	end

	if ShopEvents and ShopEvents.registerOnShopRegisterItems then
		ShopEvents.registerOnShopRegisterItems(ShopDefaultItems.loadDefaultBuyItems)
	end

	if ShopSellEvents and ShopSellEvents.registerOnShopRegisterSellItems then
		ShopSellEvents.registerOnShopRegisterSellItems(ShopDefaultItems.loadDefaultSellItems)
	end
end

return ShopDefaultItems
