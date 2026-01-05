-- ShopInit.lua (Shared)
-- Registry finalization - hooks-based item loading
-- Extends SHOPSB42 namespace (no new globals)

local SharedLogger = require("nshopsb42/utils/SharedLogger")
local DeterminismTest = require("nshopsb42/pricing/DeterminismTest")

local Shop = SHOPSB42.Shop
local ShopEvents = SHOPSB42.ShopEvents

local function validateItem(id, def)
	assert(def.tab, "[Shop] Missing tab: " .. id)
	assert(def.price, "[Shop] Missing price: " .. id)

	if def.items and type(def.items) == "table" then
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
		SharedLogger.log("Shops", "Legacy Buy/Sell tables detected. Mapped to PlayerBuy/PlayerSell.")
	end
end

function Shop.FinalizeRegistry()
	---@diagnostic disable-next-line: unnecessary-if
	if Shop._locked then
		return
	end

	SharedLogger.log("Shops", "[ShopBuyInit] FinalizeRegistry starting...")
	SharedLogger.log(
		"Shops",
		"[ShopBuyInit] Hooks registered for item registration: " .. #ShopEvents.OnShopRegisterItems
	)

	-- Phase 0: migrate legacy tables if present
	migrateLegacyShopTables()

	-- Phase 1: Execute ALL registered hooks (external mods + Shops defaults)
	SharedLogger.log(
		"Shops",
		"[ShopBuyInit] Phase 1: Executing " .. #ShopEvents.OnShopRegisterItems .. " hook(s) to gather buy items"
	)
	ShopEvents.triggerOnShopRegisterItems()

	-- Phase 2: commit registry
	SharedLogger.log(
		"Shops",
		"[ShopBuyInit] Phase 2: Registering "
			.. #Shop._pendingRegistrations
			.. " items (available for players to buy in NPC shop)"
	)
	Shop.PlayerBuy = Shop.PlayerBuy or {}
	local pendingRegs = Shop._pendingRegistrations or {}
	for _, entry in ipairs(pendingRegs) do
		validateItem(entry.id, entry.def)
		-- Store base price separately so price can change without affecting base
		if not entry.def.basePrice then
			entry.def.basePrice = entry.def.price
		end
		Shop.Items[entry.id] = entry.def
		-- Enable item for player buying
		Shop.PlayerBuy[entry.id] = { enabled = true }
	end

	local itemCount = 0
	for _ in pairs(Shop.Items) do
		itemCount = itemCount + 1
	end
	SharedLogger.log("Shops", "[ShopBuyInit] FinalizeRegistry complete. Total NPC Shop buy items: " .. itemCount)

	-- Phase 5: Run determinism validation (Phase 6 integration)
	SharedLogger.log("Shops", "[ShopBuyInit] Phase 5: Running determinism validation...")
	if DeterminismTest.runComplete() then
		SharedLogger.log("Shops", "[ShopBuyInit] OK Determinism validation PASSED - Safe for multiplayer")
	else
		SharedLogger.log("Shops", "[ShopBuyInit] FAILED Determinism validation FAILED - Check logs for violations")
	end

	Shop._pendingRegistrations = nil
	Shop._locked = true
end

return Shop
