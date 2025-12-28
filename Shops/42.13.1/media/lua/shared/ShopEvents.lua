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
	writeLog("Shops", "[ShopEvents] Registering OnShopRegisterItems callback")
	table.insert(ShopEvents.OnShopRegisterItems, callback)
end

-- Execute all registered item registration callbacks
function ShopEvents.triggerOnShopRegisterItems()
	writeLog("Shops", "[ShopEvents] Triggering OnShopRegisterItems - " .. #ShopEvents.OnShopRegisterItems .. " callbacks")
	for i, callback in ipairs(ShopEvents.OnShopRegisterItems) do
		writeLog("Shops", "[ShopEvents] Executing callback " .. i)
		callback()
	end
end
