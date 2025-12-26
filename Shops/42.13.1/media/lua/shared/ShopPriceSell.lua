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

	Events.OnShopModifySellPrice.Trigger(
		player, item, base, context, modifiers
	)

	local price = PriceUtils.applyModifiers(base, modifiers)

	local override =
		Events.OnShopOverrideSellPrice.Trigger(
			player, item, price, context
		)

	return override or price
end
