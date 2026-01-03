-- ShopsHooksExampleInit.lua
-- Entry point for ShopsHooksExample mod (server-only reference example)
-- Registers price hooks with Shops price system
-- Extends SHOPSB42 namespace

local SharedLogger = require("nshopsb42/utils/SharedLogger")
local ShopsHooksExampleHooks = require("nshopsb42/ShopsHooksExampleHooks")

SHOPSB42.ShopsHooksExample = SHOPSB42.ShopsHooksExample or {}
local ShopsHooksExample = SHOPSB42.ShopsHooksExample

-- Initialize and register all hooks
function ShopsHooksExample.initialize()
	SharedLogger.log(
		"Shops",
		"[ShopsHooksExample] Initializing server-only reference example"
	)

	-- Get ShopPriceEvents from Shops mod
	local ShopPriceEvents = SHOPSB42.ShopPriceEvents
	if not ShopPriceEvents then
		SharedLogger.log(
			"Shops",
			"[ShopsHooksExample] ERROR: SHOPSB42.ShopPriceEvents not available"
		)
		return
	end

	-- Register modify buy price hook
	-- Applies to: Base.Apple (fruit category discount)
	-- Pattern: Appends multiplier to modifiers array (stacks with other modifiers)
	if ShopPriceEvents.registerOnShopModifyBuyPrice then
		ShopPriceEvents.registerOnShopModifyBuyPrice(
			ShopsHooksExampleHooks.modifyAppleBuyPrice
		)
		SharedLogger.log(
			"Shops",
			"[ShopsHooksExample] Registered: modifyAppleBuyPrice"
		)
	else
		SharedLogger.log(
			"Shops",
			"[ShopsHooksExample] ERROR: registerOnShopModifyBuyPrice not found"
		)
	end

	-- Register override buy price hook
	-- Applies to: Base.Apple (optional fixed price override)
	-- Pattern: Returns final price or nil (short-circuits if non-nil)
	if ShopPriceEvents.registerOnShopOverrideBuyPrice then
		ShopPriceEvents.registerOnShopOverrideBuyPrice(
			ShopsHooksExampleHooks.overrideAppleBuyPrice
		)
		SharedLogger.log(
			"Shops",
			"[ShopsHooksExample] Registered: overrideAppleBuyPrice"
		)
	else
		SharedLogger.log(
			"Shops",
			"[ShopsHooksExample] ERROR: registerOnShopOverrideBuyPrice not found"
		)
	end

	-- Register modify sell price hook
	-- Applies to: Base.Apple, Base.BaseballBat (condition-based discount)
	-- Pattern: Appends multiplier to modifiers array (based on item:getCondition())
	if ShopPriceEvents.registerOnShopModifySellPrice then
		ShopPriceEvents.registerOnShopModifySellPrice(
			ShopsHooksExampleHooks.modifySellPriceByCondition
		)
		SharedLogger.log(
			"Shops",
			"[ShopsHooksExample] Registered: modifySellPriceByCondition"
		)
	else
		SharedLogger.log(
			"Shops",
			"[ShopsHooksExample] ERROR: registerOnShopModifySellPrice not found"
		)
	end

	SharedLogger.log("Shops", "[ShopsHooksExample] All hooks registered successfully")
end

-- Auto-initialize on load
-- Hooks are registered once at startup and persist for the session
-- NOTE: Initial registration does NOT require ShopFinalizeHandler.onPriceHooksChanged()
--       Shops will collect hooks during initialization.
--       If you modify hook state at runtime (e.g., change appleBuyMultiplier),
--       you MUST call ShopFinalizeHandler.onPriceHooksChanged() to trigger resync.
ShopsHooksExample.initialize()

return ShopsHooksExample
