-- ShopRegistry.lua
-- Hook-based item registration system for Project Zomboid shops

Shop = Shop or {}
Shop.Items = Shop.Items or {}

Shop._pendingRegistrations = {}
Shop._hasExternalRegistrations = false
Shop._locked = false

function Shop.RegisterItem(itemId, def)
	if Shop._locked then
		error("[Shop] RegisterItem after registry lock: " .. tostring(itemId))
	end

	if type(itemId) ~= "string" then
		error("[Shop] itemId must be string")
	end
	if type(def) ~= "table" then
		error("[Shop] definition must be table")
	end

	Shop._hasExternalRegistrations = true
	writeLog("Shops", "[ShopRegistry] RegisterItem: " .. itemId .. " (tab: " .. tostring(def.tab) .. ", price: " .. tostring(def.price) .. ")")

	table.insert(Shop._pendingRegistrations, {
		id = itemId,
		def = def
	})
end
