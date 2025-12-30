-- ShopSellRegistry.lua
-- Sell registry owner - tracks external participation and prevents late registration

Shop = Shop or {}
Shop.Sell = Shop.Sell or {}

Shop._sellPending = {}
Shop._sellLocked = false

function Shop.RegisterSellItem(itemId, def)
	if Shop._sellLocked then
		-- Item already registered via hooks, skip silently
		writeLog("Shops", "[ShopSellRegistry] RegisterSellItem ignored (registry locked): " .. tostring(itemId))
		return
	end

	if type(itemId) ~= "string" then
		error("[ShopSell] itemId must be string")
	end

	if type(def) ~= "table" then
		error("[ShopSell] definition must be table")
	end

	writeLog("Shops", "[ShopSellRegistry] RegisterSellItem: " .. itemId .. " (price: " .. tostring(def.price) .. ")")

	table.insert(Shop._sellPending, {
		id = itemId,
		def = def
	})
end
