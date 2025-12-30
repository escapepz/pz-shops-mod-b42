-- ShopRegistry.lua (Shared)
-- Item registration system - works on both client and server
-- Extends SHOPSB42 namespace (no new globals)

local SharedLogger = require("nshopsb42/utils/SharedLogger")

SHOPSB42.Shop = SHOPSB42.Shop or {}
SHOPSB42.Shop.Items = SHOPSB42.Shop.Items or {}

local Shop = SHOPSB42.Shop

Shop._pendingRegistrations = Shop._pendingRegistrations or {}
Shop._locked = Shop._locked or false

function Shop.RegisterItem(itemId, def)
	if Shop._locked then
		return
	end

	if type(itemId) ~= "string" then
		error("[Shop] itemId must be string")
	end
	if type(def) ~= "table" then
		error("[Shop] definition must be table")
	end

	SharedLogger.log(
		"Shops",
		"RegisterItem: " .. itemId .. " (tab: " .. tostring(def.tab) .. ", price: " .. tostring(def.price) .. ")"
	)

	table.insert(Shop._pendingRegistrations, {
		id = itemId,
		def = def,
	})
end

return Shop
