-- ShopPriceUtils.lua
-- Shared price calculation utilities
-- Extends SHOPSB42 namespace (no new globals)

SHOPSB42.ShopPriceUtils = SHOPSB42.ShopPriceUtils or {}
local ShopPriceUtils = SHOPSB42.ShopPriceUtils

function ShopPriceUtils.applyModifiers(base, modifiers)
	local price = base

	for _, m in ipairs(modifiers) do
		if m.multiplier then
			price = price * m.multiplier
		end
		if m.add then
			price = price + m.add
		end
	end

	price = math.floor(price)
	return math.max(0, price)
end

return ShopPriceUtils
