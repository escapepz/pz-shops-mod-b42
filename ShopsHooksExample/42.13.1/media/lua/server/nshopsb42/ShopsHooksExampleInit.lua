-- ShopsHooksExampleInit.lua
-- Entry point for ShopsHooksExample mod (server-only reference example)
-- Registers price hooks, item registration hooks, and listing config
-- Extends SHOPSB42 namespace

local SharedLogger = require("nshopsb42/utils/SharedLogger")
local ShopsHooksExampleHooks = require("nshopsb42/ShopsHooksExampleHooks")
local ShopsHooksExampleItems = require("nshopsb42/ShopsHooksExampleItems")

SHOPSB42.ShopsHooksExample = SHOPSB42.ShopsHooksExample or {}
local ShopsHooksExample = SHOPSB42.ShopsHooksExample

-- Initialize and register all hooks
function ShopsHooksExample.initialize()
	SharedLogger.log(
		"Shops",
		"[ShopsHooksExample] Initializing server-only reference example"
	)

	-- Get event systems from Shops mod
	local ShopEvents = SHOPSB42.ShopEvents
	local ShopSellEvents = SHOPSB42.ShopSellEvents
	local ShopPriceEvents = SHOPSB42.ShopPriceEvents

	if not ShopPriceEvents then
		SharedLogger.log(
			"Shops",
			"[ShopsHooksExample] ERROR: SHOPSB42.ShopPriceEvents not available"
		)
		return
	end

	-- Step 1: Configure listing mode (whitelist vs blacklist)
	-- This must be done before item registration
	ShopsHooksExampleItems.configureListingMode()
	SharedLogger.log("Shops", "[ShopsHooksExample] Configured listing mode")

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

	-- Step 2: Register item registration hooks
	-- These hooks allow our mod to add items to the shop during initialization

	-- Register buy items hook
	if ShopEvents and ShopEvents.registerOnShopRegisterItems then
		ShopEvents.registerOnShopRegisterItems(ShopsHooksExampleItems.registerBuyItems)
		SharedLogger.log("Shops", "[ShopsHooksExample] Registered: registerBuyItems hook")
	else
		SharedLogger.log(
			"Shops",
			"[ShopsHooksExample] ERROR: registerOnShopRegisterItems not found"
		)
	end

	-- Register sell items hook
	if ShopSellEvents and ShopSellEvents.registerOnShopRegisterSellItems then
		ShopSellEvents.registerOnShopRegisterSellItems(ShopsHooksExampleItems.registerSellItems)
		SharedLogger.log("Shops", "[ShopsHooksExample] Registered: registerSellItems hook (blacklist mode)")
	else
		SharedLogger.log(
			"Shops",
			"[ShopsHooksExample] ERROR: registerOnShopRegisterSellItems not found"
		)
	end

	-- Register whitelist sell items hook (if whitelist mode enabled)
	if ShopSellEvents and ShopSellEvents.registerOnShopRegisterSellItems then
		ShopSellEvents.registerOnShopRegisterSellItems(ShopsHooksExampleItems.registerWhitelistSellItems)
		SharedLogger.log("Shops", "[ShopsHooksExample] Registered: registerWhitelistSellItems hook")
	end

	-- Step 3: Register price hooks
	-- These hooks modify prices dynamically based on conditions

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

	-- Log summary
	ShopsHooksExampleItems.printListingModeInfo()
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
