-- ShopDefaultItems.lua
-- Load default buy and sell items via the hook system (SERVER ONLY)
-- Extends SHOPSB42 namespace (no new globals)
-- Items self-register during require() calls

if isMultiplayer() and not isServer() then
	return
end

SHOPSB42.ShopDefaultItems = SHOPSB42.ShopDefaultItems or {}
local ShopDefaultItems = SHOPSB42.ShopDefaultItems

local Shop = SHOPSB42.Shop
local ShopEvents = SHOPSB42.ShopEvents
local ShopSellEvents = SHOPSB42.ShopSellEvents

-- Hook callback: Load default buy items
function ShopDefaultItems.loadDefaultBuyItems()
	-- Allow external mods to suppress defaults by setting Shop._suppressDefaults = true
	if Shop._suppressDefaults then
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
	-- Allow external mods to suppress defaults by setting Shop._suppressDefaults = true
	if Shop._suppressDefaults then
		return
	end

	require("nshopsb42/ShopItems/ForSell")
end

-- Register hooks
function ShopDefaultItems.registerHooks()
	if ShopEvents and ShopEvents.registerOnShopRegisterItems then
		ShopEvents.registerOnShopRegisterItems(ShopDefaultItems.loadDefaultBuyItems)
	end

	if ShopSellEvents and ShopSellEvents.registerOnShopRegisterSellItems then
		ShopSellEvents.registerOnShopRegisterSellItems(ShopDefaultItems.loadDefaultSellItems)
	end
end

return ShopDefaultItems
