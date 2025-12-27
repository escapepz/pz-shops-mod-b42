-- ShopPriceBuy.lua
-- Player buying from kiosk cost calculation pipeline

local PriceUtils = require("ShopPriceUtils")

function Shop.canPlayerBuy(fullType)
	local cfg = Shop.PlayerBuy[fullType]
	return cfg and cfg.enabled
end

function Shop.getPlayerBuyCost(fullType)
	local cfg = Shop.PlayerBuy[fullType]
	if not cfg then return nil end
	return cfg.price, cfg.currency
end

function Shop.resolvePlayerBuyPrice(player, itemId, context)
	local item = Shop.Items[itemId]
	if not item then
		error("[ShopBuy] Unknown item: " .. tostring(itemId))
	end

	-- Check if player can buy this item
	if not Shop.canPlayerBuy(itemId) then
		return nil
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
