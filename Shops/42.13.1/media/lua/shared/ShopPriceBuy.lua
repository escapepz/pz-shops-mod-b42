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

	-- Phase 1: Trigger modify hooks (allow mods to add multipliers/modifiers)
	ShopPriceEvents.triggerOnShopModifyBuyPrice(
		player, itemId, base, context, modifiers
	)

	local price = PriceUtils.applyModifiers(base, modifiers)

	-- Phase 2: Trigger override hooks (allow mods to replace price entirely)
	local override =
		ShopPriceEvents.triggerOnShopOverrideBuyPrice(
			player, itemId, price, context
		)

	return override or price
end
