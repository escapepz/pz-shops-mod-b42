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
TestPriceHooks.batSellMultiplier = 1.0 -- Baseball bat sell price multiplier
TestPriceHooks.appleOverrideBuyPrice = nil -- Override buy price for Apple (nil = disabled)
TestPriceHooks.batOverrideSellPrice = nil -- Override sell price for BaseballBat (nil = disabled)

-- Initialize test hooks (call from server init)
function TestPriceHooks.initialize()
	SharedLogger.log("Shops", "[TestPriceHooks] Initializing test hooks for Base.Apple (buy and sell)")

	-- Register modify buy price hook
	ShopPriceEvents.registerOnShopModifyBuyPrice(function(player, itemId, basePrice, context, modifiers)
		TestPriceHooks.modifyAppleBuyPrice(itemId, basePrice, modifiers)
	end)

	-- Register override buy price hook for Apple
	ShopPriceEvents.registerOnShopOverrideBuyPrice(function(player, itemId, price, context)
		return TestPriceHooks.overrideAppleBuyPrice(itemId, price)
	end)

	-- Register modify sell price hook for Apple
	ShopPriceEvents.registerOnShopModifySellPrice(function(player, item, basePrice, context, modifiers)
		TestPriceHooks.modifyAppleSellPrice(item, basePrice, modifiers)
	end)

	-- Register modify sell price hook for Baseball Bat
	ShopPriceEvents.registerOnShopModifySellPrice(function(player, item, basePrice, context, modifiers)
		TestPriceHooks.modifyBatSellPrice(item, basePrice, modifiers)
	end)

	-- Register override sell price hook for Baseball Bat
	ShopPriceEvents.registerOnShopOverrideSellPrice(function(player, item, price, context)
		return TestPriceHooks.overrideBatSellPrice(item, price)
	end)

	SharedLogger.log("Shops", "[TestPriceHooks] Test hooks registered (modify + override for apple and bat)")
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

-- Override Base.Apple buy price
function TestPriceHooks.overrideAppleBuyPrice(itemId, price)
	if not TestPriceHooks.enabled then
		return nil
	end

	if itemId ~= "Base.Apple" then
		return nil
	end

	if TestPriceHooks.appleOverrideBuyPrice == nil then
		return nil
	end

	SharedLogger.log(
		"Shops",
		"[TestPriceHooks] Overriding buy price for Base.Apple: " .. price .. " -> " .. TestPriceHooks.appleOverrideBuyPrice
	)
	return TestPriceHooks.appleOverrideBuyPrice
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

-- Modify Base.BaseballBat sell price
function TestPriceHooks.modifyBatSellPrice(item, basePrice, modifiers)
	if not TestPriceHooks.enabled then
		return
	end

	if not item or item:getFullType() ~= "Base.BaseballBat" then
		return
	end

	if not modifiers then
		return
	end

	table.insert(modifiers, { multiplier = TestPriceHooks.batSellMultiplier })
	SharedLogger.log(
		"Shops",
		"[TestPriceHooks] Applied sell price modifier to Base.BaseballBat: multiplier=" .. TestPriceHooks.batSellMultiplier
	)
end

-- Override Base.BaseballBat sell price
function TestPriceHooks.overrideBatSellPrice(item, price)
	if not TestPriceHooks.enabled then
		return nil
	end

	if not item or item:getFullType() ~= "Base.BaseballBat" then
		return nil
	end

	if TestPriceHooks.batOverrideSellPrice == nil then
		return nil
	end

	SharedLogger.log(
		"Shops",
		"[TestPriceHooks] Overriding sell price for Base.BaseballBat: " .. price .. " -> " .. TestPriceHooks.batOverrideSellPrice
	)
	return TestPriceHooks.batOverrideSellPrice
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

-- Set apple override buy price and trigger resync
function TestPriceHooks.setAppleOverrideBuyPrice(price)
	SharedLogger.log("Shops", "[TestPriceHooks.setAppleOverrideBuyPrice] ENTRY: price=" .. tostring(price))

	if not Utilities.IsServerOrSinglePlayer() then
		SharedLogger.log("Shops", "[TestPriceHooks.setAppleOverrideBuyPrice] Not server, aborting")
		return
	end

	TestPriceHooks.enabled = true
	TestPriceHooks.appleOverrideBuyPrice = price

	SharedLogger.log("Shops", "[TestPriceHooks] Apple override BUY price set to: " .. price)
	SharedLogger.log("Shops", "[TestPriceHooks] TestPriceHooks.enabled=" .. tostring(TestPriceHooks.enabled))
	SharedLogger.log(
		"Shops",
		"[TestPriceHooks] TestPriceHooks.appleOverrideBuyPrice=" .. tostring(TestPriceHooks.appleOverrideBuyPrice)
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

-- Set baseball bat sell price multiplier and trigger resync
function TestPriceHooks.setBatSellMultiplier(multiplier)
	SharedLogger.log("Shops", "[TestPriceHooks.setBatSellMultiplier] ENTRY: multiplier=" .. tostring(multiplier))

	if not Utilities.IsServerOrSinglePlayer() then
		SharedLogger.log("Shops", "[TestPriceHooks.setBatSellMultiplier] Not server, aborting")
		return
	end

	TestPriceHooks.enabled = true
	TestPriceHooks.batSellMultiplier = multiplier

	SharedLogger.log("Shops", "[TestPriceHooks] Baseball Bat SELL price multiplier set to: " .. multiplier)
	SharedLogger.log("Shops", "[TestPriceHooks] TestPriceHooks.enabled=" .. tostring(TestPriceHooks.enabled))
	SharedLogger.log(
		"Shops",
		"[TestPriceHooks] TestPriceHooks.batSellMultiplier=" .. tostring(TestPriceHooks.batSellMultiplier)
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

-- Set baseball bat override sell price and trigger resync
function TestPriceHooks.setBatOverrideSellPrice(price)
	SharedLogger.log("Shops", "[TestPriceHooks.setBatOverrideSellPrice] ENTRY: price=" .. tostring(price))

	if not Utilities.IsServerOrSinglePlayer() then
		SharedLogger.log("Shops", "[TestPriceHooks.setBatOverrideSellPrice] Not server, aborting")
		return
	end

	TestPriceHooks.enabled = true
	TestPriceHooks.batOverrideSellPrice = price

	SharedLogger.log("Shops", "[TestPriceHooks] Baseball Bat override SELL price set to: " .. price)
	SharedLogger.log("Shops", "[TestPriceHooks] TestPriceHooks.enabled=" .. tostring(TestPriceHooks.enabled))
	SharedLogger.log(
		"Shops",
		"[TestPriceHooks] TestPriceHooks.batOverrideSellPrice=" .. tostring(TestPriceHooks.batOverrideSellPrice)
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
	SharedLogger.log("Shops", "[TestPriceHooks.setAppleSellMultiplier] ENTRY: multiplier=" .. tostring(multiplier))

	if not Utilities.IsServerOrSinglePlayer() then
		SharedLogger.log("Shops", "[TestPriceHooks.setAppleSellMultiplier] Not server, aborting")
		return
	end

	TestPriceHooks.enabled = true
	TestPriceHooks.appleSellMultiplier = multiplier

	SharedLogger.log("Shops", "[TestPriceHooks] Apple SELL price multiplier set to: " .. multiplier)
	SharedLogger.log("Shops", "[TestPriceHooks] TestPriceHooks.enabled=" .. tostring(TestPriceHooks.enabled))
	SharedLogger.log(
		"Shops",
		"[TestPriceHooks] TestPriceHooks.appleSellMultiplier=" .. tostring(TestPriceHooks.appleSellMultiplier)
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

-- Disable test hook
function TestPriceHooks.disable()
	TestPriceHooks.enabled = false
	TestPriceHooks.appleMultiplier = 1.0
	TestPriceHooks.appleSellMultiplier = 1.0
	TestPriceHooks.batSellMultiplier = 1.0
	TestPriceHooks.appleOverrideBuyPrice = nil
	TestPriceHooks.batOverrideSellPrice = nil

	SharedLogger.log("Shops", "[TestPriceHooks] Test hooks disabled (all modifiers and overrides reset)")

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
