-- ShopTransactionValidationServer.lua (Server-only)
-- Server-side price validation for transactions
-- Ensures client prices match server calculation
-- Extends SHOPSB42 namespace (no new globals)

local SharedLogger = require("nshopsb42/utils/SharedLogger")
local Calculator = require("nshopsb42/pricing/ShopPriceCalculatorShared")

SHOPSB42.ShopTransactionValidationServer = SHOPSB42.ShopTransactionValidationServer or {}
local Validator = SHOPSB42.ShopTransactionValidationServer

-- Price tolerance in currency units (accounts for rounding differences)
Validator.PRICE_TOLERANCE = 1

-- Validate buy transaction price
-- Returns: (isValid, serverPrice, mismatch)
function Validator.validateBuyPrice(player, itemId, clientPrice)
	if not player or not itemId then
		return false, nil, "Invalid parameters"
	end

	local Shop = SHOPSB42.Shop

	-- Recalculate server price using same rules
	local serverPrice = Calculator.calcBuyPrice(itemId, player, Shop.PriceModifiers or {})

	-- If server-only calculation, serverPrice will be nil
	-- In that case, fall back to base price (server is authority)
	if not serverPrice then
		serverPrice = (Shop.Items[itemId] and Shop.Items[itemId].price) or 0
	end

	-- Validate: allow small tolerance for rounding
	local diff = math.abs(serverPrice - clientPrice)
	if diff > Validator.PRICE_TOLERANCE then
		-- Price mismatch - reject transaction
		SharedLogger.log(
			"Shops",
			"[SECURITY] Buy price mismatch for " .. player:getUsername()
			.. ": itemId=" .. itemId .. " client=" .. clientPrice .. " server=" .. serverPrice .. " diff=" .. diff
		)
		return false, serverPrice, diff
	end

	-- Prices match within tolerance, proceed
	return true, serverPrice, 0
end

-- Validate sell transaction price
-- Returns: (isValid, serverPrice, mismatch)
function Validator.validateSellPrice(player, item, clientPrice)
	if not player or not item then
		return false, nil, "Invalid parameters"
	end

	local Shop = SHOPSB42.Shop

	-- Recalculate server price using same rules
	local serverPrice = Calculator.calcSellPrice(item, player, Shop.PriceModifiers or {})

	-- If server-only calculation, serverPrice will be nil
	-- In that case, fall back to base price (server is authority)
	if not serverPrice then
		local itemId = item:getFullType()
		serverPrice = (Shop.PlayerSell[itemId] and Shop.PlayerSell[itemId].price) or 0
	end

	-- Validate: allow small tolerance for rounding
	local diff = math.abs(serverPrice - clientPrice)
	if diff > Validator.PRICE_TOLERANCE then
		-- Price mismatch - reject transaction
		SharedLogger.log(
			"Shops",
			"[SECURITY] Sell price mismatch for " .. player:getUsername()
			.. ": item=" .. item:getFullType() .. " client=" .. clientPrice .. " server=" .. serverPrice .. " diff=" .. diff
		)
		return false, serverPrice, diff
	end

	-- Prices match within tolerance, proceed
	return true, serverPrice, 0
end

return Validator
