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

	writeLog("Shops", "[ShopSellInit] FinalizeSellRegistry starting...")

	-- Phase 1: allow external mods to register via custom event dispatcher
	-- Mods call ShopSellEvents.registerOnShopRegisterSellItems() during load
	writeLog("Shops", "[ShopSellInit] Phase 1: Triggering OnShopRegisterSellItems hooks")
	ShopSellEvents.triggerOnShopRegisterSellItems()

	-- Phase 2: fallback to defaults if no external registrations
	if not Shop._hasExternalSellRegistrations then
		writeLog("Shops", "[ShopSellInit] Phase 2: No external registrations, loading defaults")
		loadDefaultSellItems()
	else
		writeLog("Shops", "[ShopSellInit] Phase 2: External registrations found, skipping defaults")
	end

	-- Phase 3: commit all pending registrations
	writeLog("Shops", "[ShopSellInit] Phase 3: Committing " .. #Shop._sellPending .. " sell items to registry")
	for _, entry in ipairs(Shop._sellPending) do
		validateSellItem(entry.id, entry.def)
		Shop.PlayerSell[entry.id] = entry.def
	end

	local sellCount = 0
	for _ in pairs(Shop.PlayerSell) do sellCount = sellCount + 1 end
	writeLog("Shops", "[ShopSellInit] FinalizeSellRegistry complete. Total sell items: " .. sellCount)

	Shop._sellPending = nil
	Shop._sellLocked = true
end
