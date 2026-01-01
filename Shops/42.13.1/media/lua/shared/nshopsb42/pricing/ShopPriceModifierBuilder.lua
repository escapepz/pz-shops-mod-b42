-- ShopPriceModifierBuilder.lua
-- Convert registered price hooks into serializable modifier rules
-- Classifies each hook: client-safe vs server-only
-- Extends SHOPSB42 namespace (no new globals)

local SharedLogger = require("nshopsb42/utils/SharedLogger")

SHOPSB42.ShopPriceModifierBuilder = SHOPSB42.ShopPriceModifierBuilder or {}
local Builder = SHOPSB42.ShopPriceModifierBuilder

-- Build price modifier data from registered hooks
-- Returns {buyModifiers, sellModifiers, buyOverrides, sellOverrides, requiresServer}
function Builder.buildPriceModifiers()
	local Shop = SHOPSB42.Shop
	local ShopPriceEvents = SHOPSB42.ShopPriceEvents

	local modifiers = {
		buyModifiers = {},
		sellModifiers = {},
		buyOverrides = {},
		sellOverrides = {},
		requiresServer = false  -- Flag: if true, client should not use cached prices
	}

	local buyHookCount = (ShopPriceEvents.OnShopModifyBuyPrice and #ShopPriceEvents.OnShopModifyBuyPrice or 0)
		+ (ShopPriceEvents.OnShopOverrideBuyPrice and #ShopPriceEvents.OnShopOverrideBuyPrice or 0)
	local sellHookCount = (ShopPriceEvents.OnShopModifySellPrice and #ShopPriceEvents.OnShopModifySellPrice or 0)
		+ (ShopPriceEvents.OnShopOverrideSellPrice and #ShopPriceEvents.OnShopOverrideSellPrice or 0)

	SharedLogger.log(
		"Shops",
		"[PriceModifierBuilder] Registered hooks - Buy: " .. buyHookCount .. ", Sell: " .. sellHookCount
	)

	-- STUB: Extract and classify hooks into rule descriptors
	-- For each hook:
	--   1. Determine if it can be converted to a client-safe rule (difficulty, traits, etc.)
	--   2. If convertible: add to modifiers.buyModifiers or modifiers.sellModifiers
	--   3. If not convertible: set modifiers.requiresServer = true
	--   4. Log classification for debugging
	--
	-- Example (to be implemented):
	-- if hook_is_static_multiplier then
	--   table.insert(modifiers.buyModifiers, {
	--     id = "hook_id",
	--     type = "buy",
	--     priority = 100,
	--     condition = { kind = "always" },
	--     effect = { kind = "multiply", value = 0.8 }
	--   })
	-- else
	--   modifiers.requiresServer = true
	-- end

	return modifiers
end

return Builder
