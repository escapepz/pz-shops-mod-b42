-- ShopInit.lua
-- Registry finalization - hooks-based item loading

local function validateItem(id, def)
	assert(def.tab, "[Shop] Missing tab: " .. id)
	assert(def.price, "[Shop] Missing price: " .. id)

	if def.items then
		for _, e in ipairs(def.items) do
			assert(e.item, "[Shop] Pack entry missing item: " .. id)
		end
	end
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

	-- Phase 1: Execute ALL registered hooks (external mods + Shops defaults)
	-- External mods (like ShopsHooksExample) are registered first during load
	-- Shops defaults are registered last and only execute if not blocked by externals
	writeLog("Shops", "[ShopInit] Phase 1: Triggering OnShopRegisterItems hooks")
	ShopEvents.triggerOnShopRegisterItems()

	-- Phase 2: commit registry
	writeLog("Shops", "[ShopInit] Phase 2: Committing " .. #Shop._pendingRegistrations .. " items to registry")
	Shop.PlayerBuy = Shop.PlayerBuy or {}
	for _, entry in ipairs(Shop._pendingRegistrations) do
		validateItem(entry.id, entry.def)
		Shop.Items[entry.id] = entry.def
		-- Enable item for player buying
		Shop.PlayerBuy[entry.id] = { enabled = true }
	end

	local itemCount = 0
	for _ in pairs(Shop.Items) do itemCount = itemCount + 1 end
	writeLog("Shops", "[ShopInit] FinalizeRegistry complete. Total items: " .. itemCount)

	Shop._pendingRegistrations = nil
	Shop._locked = true
end
