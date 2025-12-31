-- ShopSellInit.lua (Shared)
-- Sell registry finalization - hooks-based item loading
-- Extends SHOPSB42 namespace (no new globals)

local SharedLogger = require("nshopsb42/utils/SharedLogger")

local Shop = SHOPSB42.Shop
local ShopSellEvents = SHOPSB42.ShopSellEvents

local function validateSellItem(id, def)
	if not def.blacklisted then
		assert(def.price, "[ShopSell] Missing price: " .. id)
	end
end

function Shop.FinalizeSellRegistry()
	if Shop._sellLocked then
		return
	end

	SharedLogger.log("Shops", "[ShopSellInit] FinalizeSellRegistry starting...")
	SharedLogger.log(
		"Shops",
		"[ShopSellInit] Hooks registered for item registration: " .. #ShopSellEvents.OnShopRegisterSellItems
	)

	-- Phase 1: Execute ALL registered hooks
	SharedLogger.log(
		"Shops",
		"[ShopSellInit] Phase 1: Executing "
			.. #ShopSellEvents.OnShopRegisterSellItems
			.. " hook(s) to gather sell items"
	)
	ShopSellEvents.triggerOnShopRegisterSellItems()

	-- Phase 2: commit all pending registrations
	SharedLogger.log(
		"Shops",
		"[ShopSellInit] Phase 2: Registering "
			.. #Shop._sellPending
			.. " items (available for players to sell to NPC shop)"
	)
	for _, entry in ipairs(Shop._sellPending) do
		validateSellItem(entry.id, entry.def)
		Shop.PlayerSell[entry.id] = entry.def
	end

	local sellCount = 0
	for _ in pairs(Shop.PlayerSell) do
		sellCount = sellCount + 1
	end
	SharedLogger.log("Shops", "[ShopSellInit] FinalizeSellRegistry complete. Total NPC Shop sell items: " .. sellCount)

	Shop._sellPending = nil
	Shop._sellLocked = true
end

return Shop
