-- ShopDefaultItems.lua
-- Load default buy and sell items via the hook system
-- Items self-register during require() calls

ShopDefaultItems = ShopDefaultItems or {}

-- Hook callback: Load default buy items
function ShopDefaultItems.loadDefaultBuyItems()
	-- Allow external mods to suppress defaults by setting Shop._suppressDefaults = true
	if Shop._suppressDefaults then
		writeLog("Shops", "[ShopDefaultItems] Default buy items suppressed by external mod")
		return
	end
	
	writeLog("Shops", "[ShopDefaultItems] OnShopRegisterItems hook triggered - loading defaults...")
	require("ShopItems/Food")
	require("ShopItems/Weapons")
	require("ShopItems/FirstAid")
	require("ShopItems/Vehicles")
	require("ShopItems/Event")
	writeLog("Shops", "[ShopDefaultItems] Default buy items loaded")
end

-- Hook callback: Load default sell items
function ShopDefaultItems.loadDefaultSellItems()
	-- Allow external mods to suppress defaults by setting Shop._suppressDefaults = true
	if Shop._suppressDefaults then
		writeLog("Shops", "[ShopDefaultItems] Default sell items suppressed by external mod")
		return
	end
	
	writeLog("Shops", "[ShopDefaultItems] OnShopRegisterSellItems hook triggered - loading defaults...")
	require("ShopItems/ForSell")
	writeLog("Shops", "[ShopDefaultItems] Default sell items loaded")
end

-- Register hooks
function ShopDefaultItems.registerHooks()
	if ShopEvents and ShopEvents.registerOnShopRegisterItems then
		ShopEvents.registerOnShopRegisterItems(ShopDefaultItems.loadDefaultBuyItems)
		writeLog("Shops", "[ShopDefaultItems] Registered buy items hook")
	end

	if ShopSellEvents and ShopSellEvents.registerOnShopRegisterSellItems then
		ShopSellEvents.registerOnShopRegisterSellItems(ShopDefaultItems.loadDefaultSellItems)
		writeLog("Shops", "[ShopDefaultItems] Registered sell items hook")
	end
end

-- Auto-initialize on load
ShopDefaultItems.registerHooks()

return ShopDefaultItems
