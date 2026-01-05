-- ShopPriceSell.lua
-- Player selling to kiosk payout calculation pipeline
-- Extends SHOPSB42 namespace (no new globals)

local PriceUtils = require("nshopsb42/pricing/ShopPriceUtils")

local Shop = SHOPSB42.Shop
local ShopPriceEvents = SHOPSB42.ShopPriceEvents

function Shop.canPlayerSell(fullType)
	local cfg = Shop.PlayerSell and Shop.PlayerSell[fullType]

	---@diagnostic disable-next-line: unnecessary-if
	-- If item is registered
	if cfg then
		return cfg.enabled and not cfg.blacklisted
	end

	-- Item not registered - check mode
	-- In whitelist mode: only registered items can be sold (default NO)
	-- In blacklist mode: all items can be sold except those explicitly blacklisted (default YES)
	if Shop.SellIsWhitelist then
		return false -- Whitelist mode: unregistered items not allowed
	else
		return true -- Blacklist mode: unregistered items allowed (will use defaultPrice)
	end
end

function Shop.getPlayerSellPayout(fullType)
	local cfg = Shop.PlayerSell and Shop.PlayerSell[fullType]
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

	local rule = Shop.PlayerSell and Shop.PlayerSell[id]
	local base

	---@diagnostic disable-next-line: unnecessary-if
	if rule then
		-- Item is registered - use registered price
		base = rule.basePrice or rule.price
	else
		-- Item not registered - in blacklist mode, use defaultPrice
		-- (canPlayerSell already validated we're in blacklist mode)
		base = context.isBroken and Shop.defaultPriceBroken or Shop.defaultPrice
	end

	local modifiers = {}

	-- Phase 1: Trigger modify hooks (allow mods to add multipliers/modifiers)
	ShopPriceEvents.triggerOnShopModifySellPrice(player, item, base, context, modifiers)

	local price = PriceUtils.applyModifiers(base, modifiers)

	-- Phase 2: Trigger override hooks (allow mods to replace price entirely)
	local override = ShopPriceEvents.triggerOnShopOverrideSellPrice(player, item, price, context)

	return override or price
end

return Shop
