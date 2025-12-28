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
	require("ShopItems.Food")
	require("ShopItems.Weapons")
	require("ShopItems.FirstAid")
	require("ShopItems.Vehicles")
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

	writeLog("Shops", "[ShopInit] FinalizeRegistry starting...")
	writeLog("Shops", "[ShopInit] Hooks registered: " .. #ShopEvents.OnShopRegisterItems)

	-- Phase 0: migrate legacy tables if present
	migrateLegacyShopTables()

	-- Phase 1: allow mods to register via custom event dispatcher
	-- Mods call ShopEvents.registerOnShopRegisterItems() during load
	writeLog("Shops", "[ShopInit] Phase 1: Triggering OnShopRegisterItems hooks")
	ShopEvents.triggerOnShopRegisterItems()

	-- Phase 2: fallback to defaults if no external registrations
	if not Shop._hasExternalRegistrations then
		writeLog("Shops", "[ShopInit] Phase 2: No external registrations, loading defaults")
		loadDefaultItems()
	else
		writeLog("Shops", "[ShopInit] Phase 2: External registrations found, skipping defaults")
	end

	-- Phase 3: commit registry
	writeLog("Shops", "[ShopInit] Phase 3: Committing " .. #Shop._pendingRegistrations .. " items to registry")
	for _, entry in ipairs(Shop._pendingRegistrations) do
		validateItem(entry.id, entry.def)
		Shop.Items[entry.id] = entry.def
	end

	local itemCount = 0
	for _ in pairs(Shop.Items) do itemCount = itemCount + 1 end
	writeLog("Shops", "[ShopInit] FinalizeRegistry complete. Total items: " .. itemCount)

	Shop._pendingRegistrations = nil
	Shop._locked = true
end
