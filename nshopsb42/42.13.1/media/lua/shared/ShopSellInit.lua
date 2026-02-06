-- ShopSellInit.lua
-- Sell finalization logic - triggers hooks, loads defaults conditionally, locks registry

local function validateSellItem(id, def)
    if not def.blacklisted then
        assert(def.price, "[ShopSell] Missing price: " .. id)
    end
end

local function loadDefaultSellItems()
    require("ShopItems.ForSell")
end

function Shop.FinalizeSellRegistry()
	if Shop._sellLocked then return end

	-- Phase 1: allow external mods to register via custom event dispatcher
	-- Mods call ShopSellEvents.registerOnShopRegisterSellItems() during load
	ShopSellEvents.triggerOnShopRegisterSellItems()

	-- Phase 2: fallback to defaults if no external registrations
	if not Shop._hasExternalSellRegistrations then
		loadDefaultSellItems()
	end

	-- Phase 3: commit all pending registrations
	for _, entry in ipairs(Shop._sellPending) do
		validateSellItem(entry.id, entry.def)
		Shop.PlayerSell[entry.id] = entry.def
	end

	Shop._sellPending = nil
	Shop._sellLocked = true
end
