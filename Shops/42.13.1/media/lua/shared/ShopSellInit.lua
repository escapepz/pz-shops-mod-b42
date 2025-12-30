-- ShopSellInit.lua
-- Sell registry finalization - hooks-based item loading

local function validateSellItem(id, def)
    if not def.blacklisted then
        assert(def.price, "[ShopSell] Missing price: " .. id)
    end
end

function Shop.FinalizeSellRegistry()
	if Shop._sellLocked then return end

	writeLog("Shops", "[ShopSellInit] FinalizeSellRegistry starting...")

	-- Phase 1: Execute ALL registered hooks (external mods + Shops defaults)
	-- External mods (like ShopsHooksExample) are registered first during load
	-- Shops defaults are registered last and only execute if not blocked by externals
	writeLog("Shops", "[ShopSellInit] Phase 1: Triggering OnShopRegisterSellItems hooks")
	ShopSellEvents.triggerOnShopRegisterSellItems()

	-- Phase 2: commit all pending registrations
	writeLog("Shops", "[ShopSellInit] Phase 2: Committing " .. #Shop._sellPending .. " sell items to registry")
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
