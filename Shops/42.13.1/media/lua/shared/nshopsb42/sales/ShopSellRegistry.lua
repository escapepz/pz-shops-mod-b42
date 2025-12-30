-- ShopSellRegistry.lua (Shared)
-- Sell item registration system

local SharedLogger = require("nshopsb42/utils/SharedLogger")

SHOPSB42.Shop = SHOPSB42.Shop or {}
local Shop = SHOPSB42.Shop

Shop.Sell = Shop.Sell or {}
Shop._sellPending = Shop._sellPending or {}
Shop._sellLocked = Shop._sellLocked or false

function Shop.RegisterSellItem(itemId, def)
	if Shop._sellLocked then
		return
	end

	if type(itemId) ~= "string" then
		error("[ShopSell] itemId must be string")
	end
	if type(def) ~= "table" then
		error("[ShopSell] definition must be table")
	end

	SharedLogger.log(
		"Shops",
		"[ShopSellRegistry] RegisterSellItem: " .. itemId .. " (price: " .. tostring(def.price) .. ")"
	)

	table.insert(Shop._sellPending, {
		id = itemId,
		def = def,
	})
end
