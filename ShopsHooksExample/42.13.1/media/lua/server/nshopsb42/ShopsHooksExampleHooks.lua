-- ShopsHooksExampleHooks.lua
-- Hook implementations for ShopsHooksExample (server-only reference example)
-- Demonstrates correct usage of Shops price hook system
-- Safe patterns for external mods to implement price customization
-- Extends SHOPSB42 namespace
--
-- Key Concepts:
--   - Modify hooks: Apply multipliers that stack with other mods (best for balance)
--   - Override hooks: Complete replacement (first non-nil return wins)
--   - Buy hooks: Receive itemId string (no item object available)
--   - Sell hooks: Receive item object (can check condition, type, etc.)
--   - All hooks are logged and safe for external mod use

local SharedLogger = require("nshopsb42/utils/SharedLogger")
local ShopsHooksExampleState = require("nshopsb42/ShopsHooksExampleState")

SHOPSB42.ShopsHooksExampleHooks = SHOPSB42.ShopsHooksExampleHooks or {}
local Hooks = SHOPSB42.ShopsHooksExampleHooks

-- ============================================================================
-- EXAMPLE 1: Modify Buy Price (Stacking Multiplier Pattern)
-- ============================================================================
-- Demonstrates:
--   - Safe hook API: ShopPriceEvents.registerOnShopModifyBuyPrice()
--   - Modifier hook signature and pattern
--   - table.insert() to append multipliers to modifiers array
--   - Multiplier stacking with other hooks (safe for mod combinations)
--   - Item filtering by string ID (buy hooks receive itemId, not item object)
-- Why Modify vs Override:
--   - Modify: Multipliers stack with other mods (best for balance)
--   - Override: Complete replacement (less compatible with other mods)
-- Testing:
--   1. Buy Base.Apple in shop - should cost ~2 (price: 2, multiplier: 0.9 = 1.8 rounded up)
--   2. Check Logs/Server/*_Shops.txt for "Applied buy modifier to Base.Apple"
--   3. Edit ShopsHooksExampleState.appleBuyMultiplier and restart to test changes
function Hooks.modifyAppleBuyPrice(player, itemId, basePrice, context, modifiers)
	-- Guard: Only apply to Apple
	if itemId ~= "Base.Apple" then
		return
	end

	-- Guard: Ensure modifiers table exists
	if not modifiers then
		return
	end

	-- Append fruit category discount multiplier to modifiers array
	-- 0.9 = 10% discount (prices multiplied by 0.9)
	-- This stacks with other mods that also add multipliers
	table.insert(modifiers, {
		multiplier = ShopsHooksExampleState.appleBuyMultiplier,
		label = "appleFruitDiscount",
	})

	SharedLogger.log(
		"Shops",
		"[ShopsHooksExample] Applied buy modifier to Base.Apple: multiplier="
			.. ShopsHooksExampleState.appleBuyMultiplier
	)
end

-- ============================================================================
-- EXAMPLE 2: Override Buy Price (Fixed Price Pattern)
-- ============================================================================
-- Demonstrates:
--   - Safe hook API: ShopPriceEvents.registerOnShopOverrideBuyPrice()
--   - Override hook signature and pattern
--   - Return non-nil to override price (short-circuits modifier stacking)
--   - Return nil to skip override and use calculated price
--   - First non-nil return wins (hook short-circuits)
--   - Item filtering by string ID
-- Why Override vs Modify:
--   - Override: Useful for quest items, event pricing, or fixed prices
--   - Less compatible with other mods (first mod to return wins)
-- Testing:
--   1. With appleOverrideBuyPrice = nil: Modify hook applies, apple costs ~2
--   2. With appleOverrideBuyPrice = 5: Apple costs exactly 5 (overrides multiplier)
--   3. With appleOverrideBuyPrice = 0: Apple cannot be bought
--   4. Check Logs/Server/*_Shops.txt for override messages
function Hooks.overrideAppleBuyPrice(player, itemId, price, context)
	-- Guard: Only apply to Apple
	if itemId ~= "Base.Apple" then
		return nil
	end

	-- If no override is set, return nil to use calculated price (from modifiers)
	local overridePrice = ShopsHooksExampleState.appleOverrideBuyPrice
	if overridePrice == nil then
		return nil
	end

	-- Return override price (short-circuits all modifiers)
	-- This completely replaces the calculated price
	SharedLogger.log("Shops", "[ShopsHooksExample] Overriding Apple buy price: " .. price .. " -> " .. overridePrice)
	return overridePrice
end

-- ============================================================================
-- EXAMPLE 3: Modify Sell Price by Condition (Item Property Pattern)
-- ============================================================================
-- Demonstrates:
--   - Safe hook API: ShopPriceEvents.registerOnShopModifySellPrice()
--   - Sell hook signature differs from buy: receives item object, not itemId string
--   - Use item:getFullType() to get item ID from object
--   - Use item:getCondition() to check item quality (0-100 scale)
--   - Use item:getType() to check item category
--   - Buy vs Sell asymmetry (buy uses itemId string, sell uses item object)
--   - Conditional multiplier based on item properties
--   - Applies to multiple items (Apple and BaseballBat in this example)
-- Why Condition-Based:
--   - Items in poor condition are less valuable
--   - Realistic: worn tools, damaged food worth less
--   - Common pattern for economy mods
-- Testing:
--   1. Sell perfect condition Apple: full price (1)
--   2. Sell worn Apple (condition 50-74): 0.85x price (0.85)
--   3. Sell damaged Apple (condition < 50): 0.5x price (0.5)
--   4. Check Logs/Server/*_Shops.txt for "Applied condition modifier"
function Hooks.modifySellPriceByCondition(player, item, basePrice, context, modifiers)
	-- Guard: Ensure item and modifiers exist
	if not item or not modifiers then
		return
	end

	-- Get full item type (e.g., "Base.Apple", "Base.BaseballBat")
	-- This is needed because sell hooks receive item object, not string
	local itemId = item:getFullType()

	-- Guard: Only apply to Apple and BaseballBat
	if itemId ~= "Base.Apple" and itemId ~= "Base.BaseballBat" then
		return
	end

	-- Get item condition (0-100 scale, where 100 is perfect/new)
	local condition = item:getCondition()

	-- Calculate multiplier based on condition bands
	-- Excellent (75-100): 1.0x (full price) - like new
	-- Good (50-74): 0.85x (15% penalty) - worn but functional
	-- Fair (25-49): 0.5x (50% penalty) - damaged
	-- Poor (0-24): 0.5x (50% penalty) - very damaged
	local multiplier = 1.0
	if condition < 50 then
		multiplier = 0.5
	elseif condition < 75 then
		multiplier = 0.85
	end

	-- Only add modifier if condition reduces price (don't add 1.0x multipliers)
	if multiplier ~= 1.0 then
		table.insert(modifiers, {
			multiplier = multiplier,
			label = "conditionFactor",
		})

		SharedLogger.log(
			"Shops",
			"[ShopsHooksExample] Applied condition modifier to "
				.. itemId
				.. ": condition="
				.. condition
				.. ", multiplier="
				.. multiplier
		)
	end
end

return Hooks
