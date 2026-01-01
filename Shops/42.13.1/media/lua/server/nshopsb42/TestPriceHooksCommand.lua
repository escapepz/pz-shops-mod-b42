-- TestPriceHooksCommand.lua
-- Debug console command for testing price hooks
-- Server-side only (call functions directly or through server admin commands)
-- Extends SHOPSB42 namespace (no new globals)

local SharedLogger = require("nshopsb42/utils/SharedLogger")
local Utilities = require("nshopsb42/utils/Utilities")
local TestPriceHooks = require("nshopsb42/TestPriceHooks")

SHOPSB42.TestPriceHooksCommand = SHOPSB42.TestPriceHooksCommand or {}
local TestPriceHooksCommand = SHOPSB42.TestPriceHooksCommand

-- Handle the command (called from direct Lua or server admin interface)
local function handleTestAppleCommand(args)
	if not args or #args == 0 then
		SharedLogger.log("TestPriceHooks", "Usage: testapple [multiplier]")
		SharedLogger.log("TestPriceHooks", "  testapple(2.0)    - Double apple price")
		SharedLogger.log("TestPriceHooks", "  testapple(0.5)    - Half apple price")
		SharedLogger.log("TestPriceHooks", "  testapple(3.0)    - Triple apple price")
		SharedLogger.log("TestPriceHooks", "  testapple('reset') - Disable test hook")
		return
	end

	local arg = args[1]

	if arg == "reset" or arg == "disable" or arg == "off" then
		TestPriceHooks.disable()
		SharedLogger.log("TestPriceHooks", "Test hook disabled, apple price reset to normal")
		return
	end

	local multiplier = tonumber(arg)
	if not multiplier or multiplier <= 0 then
		SharedLogger.log("TestPriceHooks", "Invalid multiplier: " .. tostring(arg))
		SharedLogger.log("TestPriceHooks", "  Use a positive number (e.g., 2.0, 0.5, 1.5)")
		return
	end

	TestPriceHooks.setAppleMultiplier(multiplier)
	SharedLogger.log("TestPriceHooks", "Apple price multiplier set to: " .. multiplier)
	SharedLogger.log("TestPriceHooks", "  Resync triggered. Check Shop UI for live price update.")
end

-- Buy price function wrapper
function TestPriceHooksCommand.testapple(multiplier)
	if multiplier == nil then
		handleTestAppleCommand({})
		return
	end
	if type(multiplier) == "number" then
		handleTestAppleCommand({ multiplier })
	elseif type(multiplier) == "string" then
		handleTestAppleCommand({ multiplier })
	end
end

-- Sell price function wrapper
function TestPriceHooksCommand.testappleSell(multiplier)
	if not Utilities.IsServerOrSinglePlayer() then
		SharedLogger.log("TestPriceHooks", "This command is server-only")
		return
	end

	if multiplier == nil then
		SharedLogger.log("TestPriceHooks", "Usage: testappleSell(multiplier)")
		SharedLogger.log("TestPriceHooks", "  testappleSell(2.0)  - Double apple sell price")
		SharedLogger.log("TestPriceHooks", "  testappleSell(0.5)  - Half apple sell price")
		SharedLogger.log("TestPriceHooks", "  testappleSell(3.0)  - Triple apple sell price")
		return
	end

	if type(multiplier) == "string" and (multiplier == "reset" or multiplier == "disable") then
		TestPriceHooks.disable()
		SharedLogger.log("TestPriceHooks", "Test hook disabled, apple prices reset to normal")
		return
	end

	local mult = tonumber(multiplier)
	if not mult or mult <= 0 then
		SharedLogger.log("TestPriceHooks", "Invalid multiplier: " .. tostring(multiplier))
		SharedLogger.log("TestPriceHooks", "  Use a positive number (e.g., 2.0, 0.5, 1.5)")
		return
	end

	TestPriceHooks.setAppleSellMultiplier(mult)
	SharedLogger.log("TestPriceHooks", "Apple SELL price multiplier set to: " .. mult)
	SharedLogger.log("TestPriceHooks", "  Resync triggered. Check Shop UI Sell tab for live price update.")
end

function TestPriceHooksCommand.testappleReset()
	TestPriceHooks.disable()
	SharedLogger.log("TestPriceHooks", "Test hook disabled, apple prices reset to normal (buy and sell)")
end

-- No-op register for compatibility (command is called directly)
function TestPriceHooksCommand.register()
	SharedLogger.log(
		"Shops",
		"[TestPriceHooksCommand] Test apple command helper loaded (call SHOPSB42.TestPriceHooksCommand.testapple(multiplier) or use Lua directly)"
	)
end

return TestPriceHooksCommand
