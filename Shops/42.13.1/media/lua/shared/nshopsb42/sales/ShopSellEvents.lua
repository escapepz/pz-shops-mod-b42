-- ShopSellEvents.lua (Shared)
-- Sell item registration event dispatcher
-- Extends SHOPSB42 namespace (no new globals)

SHOPSB42.ShopSellEvents = SHOPSB42.ShopSellEvents or {}
local ShopSellEvents = SHOPSB42.ShopSellEvents

ShopSellEvents.OnShopRegisterSellItems = ShopSellEvents.OnShopRegisterSellItems or {}

function ShopSellEvents.registerOnShopRegisterSellItems(callback)
	if type(callback) ~= "function" then
		error("[ShopSellEvents] registerOnShopRegisterSellItems requires a function")
	end
	table.insert(ShopSellEvents.OnShopRegisterSellItems, callback)
end

function ShopSellEvents.triggerOnShopRegisterSellItems()
	for _, callback in ipairs(ShopSellEvents.OnShopRegisterSellItems) do
		callback()
	end
end

return ShopSellEvents
