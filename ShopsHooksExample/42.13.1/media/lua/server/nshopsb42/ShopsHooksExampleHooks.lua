-- ShopsHooksExampleHooks.lua
-- Hook implementations for ShopsHooksExample (server-only reference example)
-- Demonstrates correct usage of Shops price hook system
-- Extends SHOPSB42 namespace

local SharedLogger = require("nshopsb42/utils/SharedLogger")
local ShopsHooksExampleState = require("nshopsb42/ShopsHooksExampleState")

SHOPSB42.ShopsHooksExampleHooks = SHOPSB42.ShopsHooksExampleHooks or {}
local Hooks = SHOPSB42.ShopsHooksExampleHooks

-- Modify buy price for Base.Apple
-- Demonstrates:
--   - Modifier hook signature and pattern
--   - table.insert() to append multipliers to modifiers array
--   - Multiplier stacking with other hooks
--   - Item filtering by string ID (buy hooks receive itemId, not item object)
-- Why: Fruit items get a category discount, but this stacks with other modifiers
--      (e.g., time-based, reputation-based from other mods)
function Hooks.modifyAppleBuyPrice(player, itemId, basePrice, context, modifiers)
	-- Guard: Only apply to Apple
	if itemId ~= "Base.Apple" then
		return
	end

	-- Guard: Ensure modifiers table exists
	if not modifiers then
		return
	end

	-- Append fruit category discount multiplier
	-- 0.9 = 10% discount (prices multiplied by 0.9)
	table.insert(modifiers, {
		multiplier = ShopsHooksExampleState.appleBuyMultiplier,
		label = "appleFruitDiscount",
	})

	SharedLogger.log(
		"Shops",
		"[ShopsHooksExample] Applied buy modifier to Base.Apple: multiplier=" ..
			ShopsHooksExampleState.appleBuyMultiplier
	)
end

-- Override buy price for Base.Apple (optional)
-- Demonstrates:
--   - Override hook signature and pattern
--   - Return non-nil to override price (short-circuits modifier stacking)
--   - Return nil to skip override and use calculated price
--   - Item filtering by string ID
-- Why: Sometimes we want a fixed price for an item, bypassing all modifiers.
--      This is optional (override is nil by default, so normal pricing applies).
--      When override is active, it completely replaces modifier calculations.
function Hooks.overrideAppleBuyPrice(player, itemId, price, context)
	-- Guard: Only apply to Apple
	if itemId ~= "Base.Apple" then
		return nil
	end

	-- If no override is set, return nil to use calculated price
	local overridePrice = ShopsHooksExampleState.appleOverrideBuyPrice
	if overridePrice == nil then
		return nil
	end

	-- Return override price (short-circuits all modifiers)
	SharedLogger.log(
		"Shops",
		"[ShopsHooksExample] Overriding Apple buy price: " ..
			price .. " -> " .. overridePrice
	)
	return overridePrice
end

-- Modify sell price by item condition
-- Demonstrates:
--   - Sell hook signature differs from buy: receives item object, not itemId string
--   - Use item:getFullType() to get item ID from object
--   - Use item:getCondition() to check item quality (0-100)
--   - Buy vs Sell asymmetry (buy uses itemId string, sell uses item object)
--   - Applies to multiple items (Apple and BaseballBat)
-- Why: Items in poor condition sell for less. This is realistic and common.
--      Sell hooks receive the actual item object, allowing condition checks.
function Hooks.modifySellPriceByCondition(player, item, basePrice, context, modifiers)
	-- Guard: Ensure item and modifiers exist
	if not item or not modifiers then
		return
	end

	-- Get full item type (e.g., "Base.Apple")
	local itemId = item:getFullType()

	-- Guard: Only apply to Apple and BaseballBat
	if itemId ~= "Base.Apple" and itemId ~= "Base.BaseballBat" then
		return
	end

	-- Get item condition (0-100, where 100 is perfect)
	local condition = item:getCondition()

	-- Calculate multiplier based on condition
	-- Good (75-100): 1.0x (full price)
	-- Fair (50-74): 0.85x (15% penalty)
	-- Poor (0-49): 0.5x (50% penalty)
	local multiplier = 1.0
	if condition < 50 then
		multiplier = 0.5
	elseif condition < 75 then
		multiplier = 0.85
	end

	-- Only add modifier if condition reduces price
	if multiplier ~= 1.0 then
		table.insert(modifiers, {
			multiplier = multiplier,
			label = "conditionFactor",
		})

		SharedLogger.log(
			"Shops",
			"[ShopsHooksExample] Applied condition modifier to " ..
				itemId ..
				": condition=" .. condition .. ", multiplier=" .. multiplier
		)
	end
end

return Hooks
