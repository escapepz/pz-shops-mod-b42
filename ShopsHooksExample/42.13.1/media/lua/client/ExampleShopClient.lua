-- ExampleShopClient.lua
-- Client-side utilities for Example Shop mod
-- Price display and discounts are handled automatically by Shops/ShopUI.lua
-- This module provides optional helper functions for custom client logic

require("ExampleShop")

ExampleShopClient = ExampleShopClient or {}

-- ========== UI INFORMATION DISPLAY ==========

-- Get player VIP tier with color coding
function ExampleShopClient.getVIPTierDisplay(reputation)
	local tier = "Standard"
	local color = { r = 0.7, g = 0.7, b = 0.7 } -- Gray

	if reputation >= 500 then
		tier = "Gold"
		color = { r = 1.0, g = 0.84, b = 0.0 } -- Gold
	elseif reputation >= 250 then
		tier = "Silver"
		color = { r = 0.75, g = 0.75, b = 0.75 } -- Silver
	elseif reputation >= 100 then
		tier = "Bronze"
		color = { r = 0.80, g = 0.50, b = 0.20 } -- Bronze
	end

	return { tier = tier, color = color }
end

-- Display VIP benefits to player (console output)
function ExampleShopClient.showVIPBenefits(player)
	if not player then return end

	local reputation = ExampleShop.getPlayerReputation(player)
	local tierInfo = ExampleShopClient.getVIPTierDisplay(reputation)

	local message = "=== VIP Status ===\n"
	message = message .. "Tier: " .. tierInfo.tier .. "\n"
	message = message .. "Reputation: " .. reputation .. "\n"

	-- VIP discount % matches modifyBuyPriceVIP hook (lines 207-229 in ExampleShop.lua)
	local discount = 0
	if reputation >= 500 then
		discount = 15 -- Gold VIP: -15%
	elseif reputation >= 250 then
		discount = 10 -- Silver VIP: -10%
	elseif reputation >= 100 then
		discount = 5 -- Bronze VIP: -5%
	end

	if discount > 0 then
		message = message .. "Buy Discount: -" .. discount .. "%"
	else
		message = message .. "Buy Discount: None"
	end

	ExampleShop.log(message)
end

-- ========== SHOP UI NOTES ==========

-- IMPORTANT: Price display and discount calculation
-- The Shops/ShopUI.lua automatically:
-- 1. Calls Shop.resolvePlayerBuyPrice() for each item during UI render
-- 2. Stores basePrice = original unmodified price
-- 3. Stores price = result after applying all modifier hooks
-- 4. Calculates and displays: discount% = (basePrice - price) / basePrice * 100
--
-- Example flow:
-- - Hook registers modifyBuyPriceByCategory: +30% weapon markup
-- - Hook registers modifyBuyPriceByTime: -5% morning discount
-- - Hook registers modifyBuyPriceVIP: -15% gold discount
-- - Base price: 100
-- - Applied multipliers: 1.3 * 0.95 * 0.85 = 1.0465
-- - Final price: 104 (before rounding)
-- - UI displays: "100 [strikethrough] 104 -4%"
--
-- If discount % shows as 0, verify:
-- - Hooks are registered in ExampleShop.registerHooks()
-- - modifyBuyPriceVIP/Time/Category add to modifiers array
-- - Shop.resolvePlayerBuyPrice() is called (happens in ShopUI line 440)

-- ========== INITIALIZATION ==========

ExampleShop.log("Client module loaded")

return ExampleShopClient
