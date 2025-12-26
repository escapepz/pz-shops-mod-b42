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

function Shop.FinalizeRegistry()
	if Shop._locked then return end

	-- Phase 1: allow mods to register via event
	Events.OnShopRegisterItems.Trigger()

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
