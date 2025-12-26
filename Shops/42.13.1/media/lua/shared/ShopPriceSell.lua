-- ShopPriceSell.lua
-- Sell price calculation pipeline

local PriceUtils = require("ShopPriceUtils")

function Shop.CalculateSellPrice(player, item, context)
	local id = item:getFullType()
	local rule = Shop.Sell[id]

	if rule and rule.blacklisted then
		return nil
	end

	local base =
		rule and rule.price or Shop.defaultPrice

	local modifiers = {}

	-- Phase 1: Trigger modify hooks (allow mods to add multipliers/modifiers)
	ShopPriceEvents.triggerOnShopModifySellPrice(
		player, item, base, context, modifiers
	)

	local price = PriceUtils.applyModifiers(base, modifiers)

	-- Phase 2: Trigger override hooks (allow mods to replace price entirely)
	local override =
		ShopPriceEvents.triggerOnShopOverrideSellPrice(
			player, item, price, context
		)

	return override or price
end
