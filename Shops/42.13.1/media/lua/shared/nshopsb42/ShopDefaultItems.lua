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

	-- Load item definitions from each category
	local itemSources = {
		"nshopsb42/ShopItems/Food",
		"nshopsb42/ShopItems/Weapons",
		"nshopsb42/ShopItems/FirstAid",
		"nshopsb42/ShopItems/Vehicles",
		"nshopsb42/ShopItems/Event",
	}

	for _, source in ipairs(itemSources) do
		local items = require(source)
		if items then
			for _, entry in ipairs(items) do
				if entry.id and entry.config then
					Shop.RegisterItem(entry.id, entry.config)
				end
			end
		end
	end
end

-- Hook callback: Load default sell items
function ShopDefaultItems.loadDefaultSellItems()
	if not Utilities.IsServerOrSinglePlayer() then
		return
	end

	-- Load sell item definitions
	local items = require("nshopsb42/ShopItems/ForSell")
	if items then
		for _, entry in ipairs(items) do
			if entry.id and entry.config then
				Shop.RegisterSellItem(entry.id, entry.config)
			end
		end
	end
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
