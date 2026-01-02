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

-- Handle the bat sell command (called from direct Lua or server admin interface)
local function handleTestBatSellCommand(args)
	if not args or #args == 0 then
		SharedLogger.log("TestPriceHooks", "Usage: testBatSell [multiplier]")
		SharedLogger.log("TestPriceHooks", "  testBatSell(2.0)    - Double baseball bat sell price")
		SharedLogger.log("TestPriceHooks", "  testBatSell(0.5)    - Half baseball bat sell price")
		SharedLogger.log("TestPriceHooks", "  testBatSell(3.0)    - Triple baseball bat sell price")
		SharedLogger.log("TestPriceHooks", "  testBatSell('reset') - Disable test hook")
		return
	end

	local arg = args[1]

	if arg == "reset" or arg == "disable" or arg == "off" then
		TestPriceHooks.disable()
		SharedLogger.log("TestPriceHooks", "Test hook disabled, baseball bat price reset to normal")
		return
	end

	local multiplier = tonumber(arg)
	if not multiplier or multiplier <= 0 then
		SharedLogger.log("TestPriceHooks", "Invalid multiplier: " .. tostring(arg))
		SharedLogger.log("TestPriceHooks", "  Use a positive number (e.g., 2.0, 0.5, 1.5)")
		return
	end

	TestPriceHooks.setBatSellMultiplier(multiplier)
	SharedLogger.log("TestPriceHooks", "Baseball Bat SELL price multiplier set to: " .. multiplier)
	SharedLogger.log("TestPriceHooks", "  Resync triggered. Check Shop UI Sell tab for live price update.")
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

-- Bat sell price function wrapper
function TestPriceHooksCommand.testBatSell(multiplier)
	if multiplier == nil then
		handleTestBatSellCommand({})
		return
	end
	if type(multiplier) == "number" then
		handleTestBatSellCommand({ multiplier })
	elseif type(multiplier) == "string" then
		handleTestBatSellCommand({ multiplier })
	end
end

-- Handle the apple override buy command
local function handleTestAppleOverrideBuyCommand(args)
	if not args or #args == 0 then
		SharedLogger.log("TestPriceHooks", "Usage: testAppleOverrideBuy [price]")
		SharedLogger.log("TestPriceHooks", "  testAppleOverrideBuy(5)  - Force apple buy price to 5")
		SharedLogger.log("TestPriceHooks", "  testAppleOverrideBuy(25) - Force apple buy price to 25")
		SharedLogger.log("TestPriceHooks", "  testAppleOverrideBuy('reset') - Disable override")
		return
	end

	local arg = args[1]

	if arg == "reset" or arg == "disable" or arg == "off" then
		TestPriceHooks.setAppleOverrideBuyPrice(nil)
		SharedLogger.log("TestPriceHooks", "Apple override buy price disabled")
		return
	end

	local price = tonumber(arg)
	if not price or price < 0 then
		SharedLogger.log("TestPriceHooks", "Invalid price: " .. tostring(arg))
		SharedLogger.log("TestPriceHooks", "  Use a non-negative number (e.g., 5, 25, 100)")
		return
	end

	TestPriceHooks.setAppleOverrideBuyPrice(price)
	SharedLogger.log("TestPriceHooks", "Apple override buy price set to: " .. price)
	SharedLogger.log("TestPriceHooks", "  Resync triggered. Check Shop UI Buy tab for live price update.")
end

-- Handle the bat override sell command
local function handleTestBatOverrideSellCommand(args)
	if not args or #args == 0 then
		SharedLogger.log("TestPriceHooks", "Usage: testBatOverrideSell [price]")
		SharedLogger.log("TestPriceHooks", "  testBatOverrideSell(50) - Force baseball bat sell price to 50")
		SharedLogger.log("TestPriceHooks", "  testBatOverrideSell(1)  - Force baseball bat sell price to 1")
		SharedLogger.log("TestPriceHooks", "  testBatOverrideSell('reset') - Disable override")
		return
	end

	local arg = args[1]

	if arg == "reset" or arg == "disable" or arg == "off" then
		TestPriceHooks.setBatOverrideSellPrice(nil)
		SharedLogger.log("TestPriceHooks", "Baseball bat override sell price disabled")
		return
	end

	local price = tonumber(arg)
	if not price or price < 0 then
		SharedLogger.log("TestPriceHooks", "Invalid price: " .. tostring(arg))
		SharedLogger.log("TestPriceHooks", "  Use a non-negative number (e.g., 1, 50, 100)")
		return
	end

	TestPriceHooks.setBatOverrideSellPrice(price)
	SharedLogger.log("TestPriceHooks", "Baseball bat override sell price set to: " .. price)
	SharedLogger.log("TestPriceHooks", "  Resync triggered. Check Shop UI Sell tab for live price update.")
end

-- Apple override buy wrapper
function TestPriceHooksCommand.testAppleOverrideBuy(price)
	if price == nil then
		handleTestAppleOverrideBuyCommand({})
		return
	end
	if type(price) == "number" then
		handleTestAppleOverrideBuyCommand({ price })
	elseif type(price) == "string" then
		handleTestAppleOverrideBuyCommand({ price })
	end
end

-- Baseball bat override sell wrapper
function TestPriceHooksCommand.testBatOverrideSell(price)
	if price == nil then
		handleTestBatOverrideSellCommand({})
		return
	end
	if type(price) == "number" then
		handleTestBatOverrideSellCommand({ price })
	elseif type(price) == "string" then
		handleTestBatOverrideSellCommand({ price })
	end
end

function TestPriceHooksCommand.testappleReset()
	TestPriceHooks.disable()
	SharedLogger.log("TestPriceHooks", "All test hooks disabled - prices reset to normal")
end

-- No-op register for compatibility (command is called directly)
function TestPriceHooksCommand.register()
	SharedLogger.log(
		"Shops",
		"[TestPriceHooksCommand] Test apple command helper loaded (call SHOPSB42.TestPriceHooksCommand.testapple(multiplier) or use Lua directly)"
	)
end

return TestPriceHooksCommand
