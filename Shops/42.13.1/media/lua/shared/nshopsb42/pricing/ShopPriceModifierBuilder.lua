-- ShopPriceModifierBuilder.lua
-- Convert registered price hooks into serializable modifier rules
-- Classifies each hook: client-safe vs server-only
-- Extends SHOPSB42 namespace (no new globals)

local SharedLogger = require("nshopsb42/utils/SharedLogger")

SHOPSB42.ShopPriceModifierBuilder = SHOPSB42.ShopPriceModifierBuilder or {}
local Builder = SHOPSB42.ShopPriceModifierBuilder

-- Build price modifier data from registered hooks
-- Returns {buyOverrides, sellOverrides, buyModifiers, sellModifiers, requiresServer}
function Builder.buildPriceModifiers()
	local Shop = SHOPSB42.Shop
	local ShopPriceEvents = SHOPSB42.ShopPriceEvents

	local modifiers = {
		buyOverrides = {},
		sellOverrides = {},
		buyModifiers = {},
		sellModifiers = {}, -- Serializable rules for sell price preview
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

	-- Buy hooks require server-only prices (cannot serialize hook functions)
	if buyHookCount > 0 then
		modifiers.requiresServer = true
		SharedLogger.log("Shops", "[PriceModifierBuilder] Buy hooks require server-only price calculation")
	end

	-- Sell hooks are now represented as serializable rules (don't require server for preview)
	if sellHookCount > 0 and #modifiers.sellModifiers == 0 and #modifiers.sellOverrides == 0 then
		-- If sell hooks are registered but no rules extracted, mark as server-only
		modifiers.requiresServer = true
		SharedLogger.log("Shops", "[PriceModifierBuilder] Sell hooks registered but not serializable - server-only")
	elseif #modifiers.sellModifiers > 0 or #modifiers.sellOverrides > 0 then
		SharedLogger.log(
			"Shops",
			"[PriceModifierBuilder] Sell modifiers available for client preview ("
				.. #modifiers.sellModifiers
				.. " rules, "
				.. #modifiers.sellOverrides
				.. " overrides)"
		)
	else
		SharedLogger.log("Shops", "[PriceModifierBuilder] No price hooks registered - using base prices")
	end

	return modifiers
end

return Builder
