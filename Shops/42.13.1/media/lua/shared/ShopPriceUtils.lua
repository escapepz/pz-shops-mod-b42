-- ShopPriceUtils.lua
-- Shared price calculation utilities

local ShopPriceUtils = {}

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
