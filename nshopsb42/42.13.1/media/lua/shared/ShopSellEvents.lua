-- ShopSellEvents.lua
-- Sell item registration event dispatcher (B42-compliant custom event)
-- 
-- This is a Lua callback dispatcher, not an engine event.
-- Mods register callbacks here during load, they are called during Shop.FinalizeSellRegistry()

ShopSellEvents = ShopSellEvents or {}
ShopSellEvents.OnShopRegisterSellItems = {}

-- Register a callback to be executed during sell registry initialization
function ShopSellEvents.registerOnShopRegisterSellItems(callback)
	if type(callback) ~= "function" then
		error("[ShopSellEvents] registerOnShopRegisterSellItems requires a function")
	end
	table.insert(ShopSellEvents.OnShopRegisterSellItems, callback)
end

-- Execute all registered sell item registration callbacks
function ShopSellEvents.triggerOnShopRegisterSellItems()
	for _, callback in ipairs(ShopSellEvents.OnShopRegisterSellItems) do
		callback()
	end
end
