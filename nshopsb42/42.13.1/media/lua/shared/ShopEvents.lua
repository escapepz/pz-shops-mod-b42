-- ShopEvents.lua
-- Item registration event dispatcher (B42-compliant custom event)
-- 
-- This is a Lua callback dispatcher, not an engine event.
-- Mods register callbacks here during load, they are called during Shop.FinalizeRegistry()

ShopEvents = ShopEvents or {}
ShopEvents.OnShopRegisterItems = {}

-- Register a callback to be executed during shop initialization
function ShopEvents.registerOnShopRegisterItems(callback)
	if type(callback) ~= "function" then
		error("[ShopEvents] registerOnShopRegisterItems requires a function")
	end
	table.insert(ShopEvents.OnShopRegisterItems, callback)
end

-- Execute all registered item registration callbacks
function ShopEvents.triggerOnShopRegisterItems()
	for _, callback in ipairs(ShopEvents.OnShopRegisterItems) do
		callback()
	end
end
