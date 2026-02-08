-- ShopInit.lua
-- Registry finalization and default item loading

local function validateItem(id, def)
	assert(def.tab, "[Shop] Missing tab: " .. id)
	assert(def.price, "[Shop] Missing price: " .. id)

	if def.items then
		for _, e in ipairs(def.items) do
			assert(e.item, "[Shop] Pack entry missing item: " .. id)
		end
	end
end

local function loadDefaultItems()
    pcall(function()
		require("ShopItems/Food")()
		require("ShopItems/Weapons")()
		require("ShopItems/FirstAid")()
		require("ShopItems/Vehicles")()
	end)
end

local function migrateLegacyShopTables()
	local migratedBuy = false
	local migratedSell = false

	if Shop.Buy and not Shop.PlayerBuy then
		Shop.PlayerBuy = Shop.Buy
		migratedBuy = true
	end

	if Shop.Sell and not Shop.PlayerSell then
		Shop.PlayerSell = Shop.Sell
		migratedSell = true
	end

	if migratedBuy or migratedSell then
		print("[Shops] Legacy Buy/Sell tables detected. Mapped to PlayerBuy/PlayerSell.")
	end
end

function Shop.FinalizeRegistry()
	if Shop._locked then return end

	-- Phase 0: migrate legacy tables if present
	migrateLegacyShopTables()

	-- Phase 1: allow mods to register via custom event dispatcher
	-- Mods call ShopEvents.registerOnShopRegisterItems() during load
	ShopEvents.triggerOnShopRegisterItems()

	-- Phase 2: fallback to defaults if no external registrations
	if not Shop._hasExternalRegistrations then
		loadDefaultItems()
	end

	-- Phase 3: commit registry
	for _, entry in ipairs(Shop._pendingRegistrations) do
		validateItem(entry.id, entry.def)
		Shop.Items[entry.id] = entry.def
	end

	Shop._pendingRegistrations = nil
	Shop._locked = true
end
