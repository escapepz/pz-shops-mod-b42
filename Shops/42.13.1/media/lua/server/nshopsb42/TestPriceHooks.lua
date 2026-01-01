-- TestPriceHooks.lua
-- Test hooks for Base.Apple (buy and sell) to verify live price hook updates
-- Server-side only
-- Extends SHOPSB42 namespace (no new globals)

local SharedLogger = require("nshopsb42/utils/SharedLogger")
local Utilities = require("nshopsb42/utils/Utilities")
local ShopPriceEvents = SHOPSB42.ShopPriceEvents

SHOPSB42.TestPriceHooks = SHOPSB42.TestPriceHooks or {}
local TestPriceHooks = SHOPSB42.TestPriceHooks

-- State: control test behavior
TestPriceHooks.enabled = false
TestPriceHooks.appleMultiplier = 1.0 -- 1.0 = normal, 2.0 = double price, etc.
TestPriceHooks.appleSellMultiplier = 1.0 -- Sell price multiplier

-- Initialize test hooks (call from server init)
function TestPriceHooks.initialize()
	SharedLogger.log("Shops", "[TestPriceHooks] Initializing test hooks for Base.Apple (buy and sell)")

	-- Register modify buy price hook
	ShopPriceEvents.registerOnShopModifyBuyPrice(function(player, itemId, basePrice, context, modifiers)
		TestPriceHooks.modifyAppleBuyPrice(itemId, basePrice, modifiers)
	end)

	-- Register modify sell price hook
	ShopPriceEvents.registerOnShopModifySellPrice(function(player, item, basePrice, context, modifiers)
		TestPriceHooks.modifyAppleSellPrice(item, basePrice, modifiers)
	end)

	SharedLogger.log("Shops", "[TestPriceHooks] Test hooks registered (buy + sell)")
end

-- Modify Base.Apple buy price
function TestPriceHooks.modifyAppleBuyPrice(itemId, basePrice, modifiers)
	if not TestPriceHooks.enabled then
		return
	end

	if itemId ~= "Base.Apple" then
		return
	end

	if not modifiers then
		return
	end

	table.insert(modifiers, { multiplier = TestPriceHooks.appleMultiplier })
	SharedLogger.log(
		"Shops",
		"[TestPriceHooks] Applied buy price modifier to Base.Apple: multiplier=" .. TestPriceHooks.appleMultiplier
	)
end

-- Modify Base.Apple sell price
function TestPriceHooks.modifyAppleSellPrice(item, basePrice, modifiers)
	if not TestPriceHooks.enabled then
		return
	end

	if not item or item:getFullType() ~= "Base.Apple" then
		return
	end

	if not modifiers then
		return
	end

	table.insert(modifiers, { multiplier = TestPriceHooks.appleSellMultiplier })
	SharedLogger.log(
		"Shops",
		"[TestPriceHooks] Applied sell price modifier to Base.Apple: multiplier=" .. TestPriceHooks.appleSellMultiplier
	)
end

-- Set apple buy price multiplier and trigger resync
function TestPriceHooks.setAppleMultiplier(multiplier)
	SharedLogger.log("Shops", "[TestPriceHooks.setAppleMultiplier] ENTRY: multiplier=" .. tostring(multiplier))

	if not Utilities.IsServerOrSinglePlayer() then
		SharedLogger.log("Shops", "[TestPriceHooks.setAppleMultiplier] Not server, aborting")
		return
	end

	TestPriceHooks.enabled = true
	TestPriceHooks.appleMultiplier = multiplier

	SharedLogger.log("Shops", "[TestPriceHooks] Apple BUY price multiplier set to: " .. multiplier)
	SharedLogger.log("Shops", "[TestPriceHooks] TestPriceHooks.enabled=" .. tostring(TestPriceHooks.enabled))
	SharedLogger.log(
		"Shops",
		"[TestPriceHooks] TestPriceHooks.appleMultiplier=" .. tostring(TestPriceHooks.appleMultiplier)
	)

	-- Notify Shops that hooks changed
	local ShopFinalizeHandler = SHOPSB42.ShopFinalizeHandler
	if ShopFinalizeHandler == nil then
		SharedLogger.log("Shops", "[TestPriceHooks] ERROR: SHOPSB42.ShopFinalizeHandler is nil")
		return
	end

	if ShopFinalizeHandler.onPriceHooksChanged == nil then
		SharedLogger.log("Shops", "[TestPriceHooks] ERROR: ShopFinalizeHandler.onPriceHooksChanged is nil")
		return
	end

	SharedLogger.log("Shops", "[TestPriceHooks] Calling ShopFinalizeHandler.onPriceHooksChanged()...")
	ShopFinalizeHandler.onPriceHooksChanged()
	SharedLogger.log("Shops", "[TestPriceHooks] onPriceHooksChanged() call completed")
end

-- Set apple sell price multiplier and trigger resync
function TestPriceHooks.setAppleSellMultiplier(multiplier)
	if not Utilities.IsServerOrSinglePlayer() then
		return
	end

	TestPriceHooks.enabled = true
	TestPriceHooks.appleSellMultiplier = multiplier

	SharedLogger.log("Shops", "[TestPriceHooks] Apple SELL price multiplier set to: " .. multiplier)

	-- Notify Shops that hooks changed
	local ShopFinalizeHandler = SHOPSB42.ShopFinalizeHandler
	if ShopFinalizeHandler and ShopFinalizeHandler.onPriceHooksChanged then
		SharedLogger.log("Shops", "[TestPriceHooks] Calling ShopFinalizeHandler.onPriceHooksChanged()...")
		ShopFinalizeHandler.onPriceHooksChanged()
	else
		SharedLogger.log(
			"Shops",
			"[TestPriceHooks] ERROR: ShopFinalizeHandler not available or onPriceHooksChanged not defined"
		)
	end
end

-- Disable test hook
function TestPriceHooks.disable()
	TestPriceHooks.enabled = false
	TestPriceHooks.appleMultiplier = 1.0
	TestPriceHooks.appleSellMultiplier = 1.0

	SharedLogger.log("Shops", "[TestPriceHooks] Test hooks disabled (buy and sell reset)")

	-- Notify Shops that hooks changed
	local ShopFinalizeHandler = SHOPSB42.ShopFinalizeHandler
	if ShopFinalizeHandler and ShopFinalizeHandler.onPriceHooksChanged then
		SharedLogger.log("Shops", "[TestPriceHooks] Calling ShopFinalizeHandler.onPriceHooksChanged()...")
		ShopFinalizeHandler.onPriceHooksChanged()
	else
		SharedLogger.log(
			"Shops",
			"[TestPriceHooks] ERROR: ShopFinalizeHandler not available or onPriceHooksChanged not defined"
		)
	end
end

return TestPriceHooks
