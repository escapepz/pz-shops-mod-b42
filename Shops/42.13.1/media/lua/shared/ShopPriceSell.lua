-- ShopPriceSell.lua
-- Player selling to kiosk payout calculation pipeline

local PriceUtils = require("ShopPriceUtils")

function Shop.canPlayerSell(fullType)
	local cfg = Shop.PlayerSell[fullType]
	return cfg and cfg.enabled and not cfg.blacklisted
end

function Shop.getPlayerSellPayout(fullType)
	local cfg = Shop.PlayerSell[fullType]
	if not cfg then return nil end
	return cfg.price, cfg.currency
end

function Shop.resolvePlayerSellPrice(player, item, context)
	local id = item:getFullType()

	-- Check if player can sell this item
	if not Shop.canPlayerSell(id) then
		return nil
	end

	local rule = Shop.PlayerSell[id]
	local base = rule.price

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
