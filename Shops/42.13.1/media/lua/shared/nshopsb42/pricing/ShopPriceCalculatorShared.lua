-- ShopPriceCalculatorShared.lua
-- Shared price calculation using data-driven modifier rules
-- Safe for both client preview and server validation
-- Extends SHOPSB42 namespace (no new globals)

local SharedLogger = require("nshopsb42/utils/SharedLogger")

SHOPSB42.ShopPriceCalculatorShared = SHOPSB42.ShopPriceCalculatorShared or {}
local Calculator = SHOPSB42.ShopPriceCalculatorShared

-- Evaluate a condition descriptor
-- Returns: boolean (whether condition is met)
local function evaluateCondition(condition, player, item, context)
	if not condition then
		return true
	end

	local kind = condition.kind

	if kind == "always" then
		return true
	elseif kind == "difficulty_ge" then
		local level = condition.params and condition.params.level or 1
		return getCore():getDifficulty() >= level
	elseif kind == "item_condition_ge" then
		if not item then
			return true
		end
		local percent = condition.params and condition.params.percent or 0
		local ratio = item:getCondition() / item:getMaxCondition()
		return (ratio * 100) >= percent
	elseif kind == "player_trait" then
		if not player then
			return false
		end
		local traitName = condition.params and condition.params.traitName
		if not traitName then
			return false
		end
		return player:HasTrait(traitName)
	elseif kind == "server_only" then
		return false -- Client cannot evaluate; should not reach here
	end

	return true
end

-- Evaluate an effect descriptor and return resulting price
-- Returns: number (the modified price)
local function applyEffect(price, effect, item)
	if not effect then
		return price
	end

	local kind = effect.kind

	if kind == "multiply" then
		local value = effect.value or 1
		return price * value
	elseif kind == "add" then
		local value = effect.value or 0
		return price + value
	elseif kind == "set" then
		local value = effect.value or price
		return value
	end

	return price
end

-- Calculate buy price for item using data-driven rules
-- Returns: number (price) or nil if unable to calculate
function Calculator.calcBuyPrice(itemId, player, modifiers)
	modifiers = modifiers or {}

	if not SHOPSB42.Shop.Items or not SHOPSB42.Shop.Items[itemId] then
		return nil
	end

	-- Return nil if server-only evaluation required
	if modifiers.requiresServer then
		return nil
	end

	local base = SHOPSB42.Shop.Items[itemId].price

	-- Check overrides first
	if modifiers.buyOverrides and modifiers.buyOverrides[itemId] then
		return modifiers.buyOverrides[itemId]
	end

	local price = base

	-- Sort by priority and apply modifiers
	local sortedMods = {}
	if modifiers.buyModifiers then
		for _, mod in ipairs(modifiers.buyModifiers) do
			if mod.type == "buy" or not mod.type then
				table.insert(sortedMods, mod)
			end
		end
	end

	-- Sort by priority (lower first)
	table.sort(sortedMods, function(a, b)
		return (a.priority or 100) < (b.priority or 100)
	end)

	-- Apply each modifier if condition is met
	for _, mod in ipairs(sortedMods) do
		if evaluateCondition(mod.condition, player, nil, {}) then
			price = applyEffect(price, mod.effect)
		end
	end

	return math.floor(math.max(0, price))
end

-- Calculate sell price for item using data-driven rules
-- Returns: number (price) or nil if unable to calculate
function Calculator.calcSellPrice(item, player, modifiers)
	modifiers = modifiers or {}

	if not item then
		return nil
	end

	local itemId = item:getFullType()

	-- Return nil if server-only evaluation required
	if modifiers.requiresServer then
		return nil
	end

	if not SHOPSB42.Shop.PlayerSell or not SHOPSB42.Shop.PlayerSell[itemId] then
		return nil
	end

	local base = SHOPSB42.Shop.PlayerSell[itemId].price

	-- Check overrides first
	if modifiers.sellOverrides and modifiers.sellOverrides[itemId] then
		return modifiers.sellOverrides[itemId]
	end

	local price = base

	-- Sort by priority and apply modifiers
	local sortedMods = {}
	if modifiers.sellModifiers then
		for _, mod in ipairs(modifiers.sellModifiers) do
			if mod.type == "sell" or not mod.type then
				table.insert(sortedMods, mod)
			end
		end
	end

	-- Sort by priority (lower first)
	table.sort(sortedMods, function(a, b)
		return (a.priority or 100) < (b.priority or 100)
	end)

	-- Apply each modifier if condition is met
	for _, mod in ipairs(sortedMods) do
		if evaluateCondition(mod.condition, player, item, {}) then
			price = applyEffect(price, mod.effect, item)
		end
	end

	return math.floor(math.max(0, price))
end

return Calculator
