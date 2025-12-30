-- ShopEvents.lua (Shared)
-- Item registration event dispatcher
-- Extends SHOPSB42 namespace (no new globals)

local SharedLogger = require("nshopsb42/utils/SharedLogger")

SHOPSB42.ShopEvents = SHOPSB42.ShopEvents or {}
local ShopEvents = SHOPSB42.ShopEvents

ShopEvents.OnShopRegisterItems = ShopEvents.OnShopRegisterItems or {}

function ShopEvents.registerOnShopRegisterItems(callback)
	if type(callback) ~= "function" then
		error("[ShopEvents] registerOnShopRegisterItems requires a function")
	end
	SharedLogger.log("Shops", "[ShopEvents] Registering OnShopRegisterItems callback")
	table.insert(ShopEvents.OnShopRegisterItems, callback)
end

function ShopEvents.triggerOnShopRegisterItems()
	SharedLogger.log(
		"Shops",
		"[ShopEvents] Triggering OnShopRegisterItems - " .. #ShopEvents.OnShopRegisterItems .. " callbacks"
	)
	for i, callback in ipairs(ShopEvents.OnShopRegisterItems) do
		SharedLogger.log("Shops", "[ShopEvents] Executing callback " .. i)
		callback()
	end
end

return ShopEvents
