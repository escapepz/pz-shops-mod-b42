-- ShopPriceBuy.lua
-- Buy price calculation pipeline

local PriceUtils = require("ShopPriceUtils")

function Shop.CalculateBuyPrice(player, itemId, context)
	local item = Shop.Items[itemId]
	if not item then
		error("[ShopBuy] Unknown item: " .. tostring(itemId))
	end

	local base = item.price
	local modifiers = {}

	Events.OnShopModifyBuyPrice.Trigger(
		player, itemId, base, context, modifiers
	)

	local price = PriceUtils.applyModifiers(base, modifiers)

	local override =
		Events.OnShopOverrideBuyPrice.Trigger(
			player, itemId, price, context
		)

	return override or price
end
