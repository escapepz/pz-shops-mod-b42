-- ShopPriceModifierBuilder.lua
-- Convert registered price hooks into serializable modifier rules
-- Classifies each hook: client-safe vs server-only
-- Extends SHOPSB42 namespace (no new globals)

local SharedLogger = require("nshopsb42/utils/SharedLogger")

SHOPSB42.ShopPriceModifierBuilder = SHOPSB42.ShopPriceModifierBuilder or {}
local Builder = SHOPSB42.ShopPriceModifierBuilder

-- Build price modifier data from registered hooks
-- For server-only mode: calculates actual prices for all items using hooks
-- Returns {buyOverrides, sellOverrides, requiresServer}
function Builder.buildPriceModifiers()
	local Shop = SHOPSB42.Shop
	local ShopPriceEvents = SHOPSB42.ShopPriceEvents

	local modifiers = {
		buyOverrides = {},
		sellOverrides = {},
		requiresServer = false, -- Flag: if true, client should not use cached prices
	}

	local buyHookCount = (ShopPriceEvents.OnShopModifyBuyPrice and #ShopPriceEvents.OnShopModifyBuyPrice or 0)
		+ (ShopPriceEvents.OnShopOverrideBuyPrice and #ShopPriceEvents.OnShopOverrideBuyPrice or 0)
	local sellHookCount = (ShopPriceEvents.OnShopModifySellPrice and #ShopPriceEvents.OnShopModifySellPrice or 0)
		+ (ShopPriceEvents.OnShopOverrideSellPrice and #ShopPriceEvents.OnShopOverrideSellPrice or 0)

	SharedLogger.log(
		"Shops",
		"[PriceModifierBuilder] Registered hooks - Buy: " .. buyHookCount .. ", Sell: " .. sellHookCount
	)

	-- If hooks are registered, we mark prices as server-only (opaque hook functions)
	-- The actual price calculation happens server-side via resolvePlayerBuyPrice / resolvePlayerSellPrice
	if buyHookCount > 0 or sellHookCount > 0 then
		modifiers.requiresServer = true
		SharedLogger.log(
			"Shops",
			"[PriceModifierBuilder] Detected "
				.. buyHookCount
				.. " buy hooks and "
				.. sellHookCount
				.. " sell hooks - marking prices as server-only"
		)
	else
		SharedLogger.log("Shops", "[PriceModifierBuilder] No hooks registered - using base prices")
	end

	return modifiers
end

return Builder
