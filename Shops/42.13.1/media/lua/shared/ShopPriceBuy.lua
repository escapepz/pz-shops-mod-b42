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

	-- Check if player can buy this item (if not registered, allow with base price)
	if not Shop.canPlayerBuy(itemId) then
		writeLog("Shops", "[ShopPriceBuy] Item not in PlayerBuy registry: " .. itemId .. ", using base price")
		return item.price
	end

	local base = item.price
	local modifiers = {}

	writeLog("Shops", "[ShopPriceBuy] resolvePlayerBuyPrice called: " .. itemId .. " base=" .. base)
	writeLog("Shops", "[ShopPriceBuy] Modifier hooks available: " .. #ShopPriceEvents.OnShopModifyBuyPrice)
	
	-- Phase 1: Trigger modify hooks (allow mods to add multipliers/modifiers)
	ShopPriceEvents.triggerOnShopModifyBuyPrice(
		player, itemId, base, context, modifiers
	)

	writeLog("Shops", "[ShopPriceBuy] Modifiers count after trigger: " .. #modifiers)
	local price = PriceUtils.applyModifiers(base, modifiers)
	writeLog("Shops", "[ShopPriceBuy] Final price after modifiers: " .. price)

	-- Phase 2: Trigger override hooks (allow mods to replace price entirely)
	local override =
		ShopPriceEvents.triggerOnShopOverrideBuyPrice(
			player, itemId, price, context
		)

	return override or price
end
