-- ShopPriceSell.lua
-- Player selling to kiosk payout calculation pipeline
-- Extends SHOPSB42 namespace (no new globals)

local PriceUtils = require("nshopsb42/pricing/ShopPriceUtils")

local Shop = SHOPSB42.Shop
local ShopPriceEvents = SHOPSB42.ShopPriceEvents

function Shop.canPlayerSell(fullType)
	local cfg = Shop.PlayerSell[fullType]
	return cfg and cfg.enabled and not cfg.blacklisted
end

function Shop.getPlayerSellPayout(fullType)
	local cfg = Shop.PlayerSell[fullType]
	if not cfg then
		return nil
	end
	return cfg.price or cfg.basePrice, cfg.currency
end

function Shop.resolvePlayerSellPrice(player, item, context)
	local id = item:getFullType()

	-- Check if player can sell this item
	if not Shop.canPlayerSell(id) then
		return nil
	end

	local rule = Shop.PlayerSell[id]
	local base = rule.basePrice or rule.price

	local modifiers = {}

	-- Phase 1: Trigger modify hooks (allow mods to add multipliers/modifiers)
	ShopPriceEvents.triggerOnShopModifySellPrice(player, item, base, context, modifiers)

	local price = PriceUtils.applyModifiers(base, modifiers)

	-- Phase 2: Trigger override hooks (allow mods to replace price entirely)
	local override = ShopPriceEvents.triggerOnShopOverrideSellPrice(player, item, price, context)

	return override or price
end

return Shop
