-- TestPriceHooksCommand.lua (Client)
-- Debug console commands for testing price hooks
-- Client-side only - sends commands to server for execution
-- Available in in-game Lua debug console without RCON
-- Extends SHOPSB42 namespace (no new globals)

local SharedLogger = SHOPSB42.SharedLogger

SHOPSB42.TestPriceHooksCommand = SHOPSB42.TestPriceHooksCommand or {}
local TestPriceHooksCommand = SHOPSB42.TestPriceHooksCommand

-- Send command to server
local function sendCommandToServer(commandName, value)
	local success, err = pcall(function()
		sendClientCommand("nshopsb42", "TestPriceHooksCommand", { command = commandName, value = value })
	end)

	if not success then
		SharedLogger.log("TestPriceHooks", "ERROR sending command to server: " .. tostring(err))
	end
end

-- Handle the apple buy price command
function TestPriceHooksCommand.testapple(multiplier)
	if multiplier == nil then
		SharedLogger.log("TestPriceHooks", "Usage: testapple [multiplier]")
		SharedLogger.log("TestPriceHooks", "  testapple(2.0)    - Double apple price")
		SharedLogger.log("TestPriceHooks", "  testapple(0.5)    - Half apple price")
		SharedLogger.log("TestPriceHooks", "  testapple(3.0)    - Triple apple price")
		SharedLogger.log("TestPriceHooks", "  testapple('reset') - Disable test hook")
		return
	end

	local arg = multiplier
	if arg == "reset" or arg == "disable" or arg == "off" then
		sendCommandToServer("setAppleMultiplier", nil)
		SharedLogger.log("TestPriceHooks", "Sending reset command to server...")
		return
	end

	local mult = tonumber(arg)
	if not mult or mult <= 0 then
		SharedLogger.log("TestPriceHooks", "Invalid multiplier: " .. tostring(arg))
		SharedLogger.log("TestPriceHooks", "  Use a positive number (e.g., 2.0, 0.5, 1.5)")
		return
	end

	sendCommandToServer("setAppleMultiplier", mult)
	SharedLogger.log("TestPriceHooks", "Sending apple multiplier to server: " .. mult)
end

-- Handle the bat sell price command
function TestPriceHooksCommand.testBatSell(multiplier)
	if multiplier == nil then
		SharedLogger.log("TestPriceHooks", "Usage: testBatSell [multiplier]")
		SharedLogger.log("TestPriceHooks", "  testBatSell(2.0)    - Double baseball bat sell price")
		SharedLogger.log("TestPriceHooks", "  testBatSell(0.5)    - Half baseball bat sell price")
		SharedLogger.log("TestPriceHooks", "  testBatSell(3.0)    - Triple baseball bat sell price")
		SharedLogger.log("TestPriceHooks", "  testBatSell('reset') - Disable test hook")
		return
	end

	local arg = multiplier
	if arg == "reset" or arg == "disable" or arg == "off" then
		sendCommandToServer("setBatSellMultiplier", nil)
		SharedLogger.log("TestPriceHooks", "Sending reset command to server...")
		return
	end

	local mult = tonumber(arg)
	if not mult or mult <= 0 then
		SharedLogger.log("TestPriceHooks", "Invalid multiplier: " .. tostring(arg))
		SharedLogger.log("TestPriceHooks", "  Use a positive number (e.g., 2.0, 0.5, 1.5)")
		return
	end

	sendCommandToServer("setBatSellMultiplier", mult)
	SharedLogger.log("TestPriceHooks", "Sending bat sell multiplier to server: " .. mult)
end

-- Handle the apple override buy command
function TestPriceHooksCommand.testAppleOverrideBuy(price)
	if price == nil then
		SharedLogger.log("TestPriceHooks", "Usage: testAppleOverrideBuy [price]")
		SharedLogger.log("TestPriceHooks", "  testAppleOverrideBuy(5)  - Force apple buy price to 5")
		SharedLogger.log("TestPriceHooks", "  testAppleOverrideBuy(25) - Force apple buy price to 25")
		SharedLogger.log("TestPriceHooks", "  testAppleOverrideBuy('reset') - Disable override")
		return
	end

	local arg = price
	if arg == "reset" or arg == "disable" or arg == "off" then
		sendCommandToServer("setAppleOverrideBuyPrice", nil)
		SharedLogger.log("TestPriceHooks", "Sending reset command to server...")
		return
	end

	local p = tonumber(arg)
	if not p or p < 0 then
		SharedLogger.log("TestPriceHooks", "Invalid price: " .. tostring(arg))
		SharedLogger.log("TestPriceHooks", "  Use a non-negative number (e.g., 5, 25, 100)")
		return
	end

	sendCommandToServer("setAppleOverrideBuyPrice", p)
	SharedLogger.log("TestPriceHooks", "Sending apple override buy price to server: " .. p)
end

-- Handle the bat override sell command
function TestPriceHooksCommand.testBatOverrideSell(price)
	if price == nil then
		SharedLogger.log("TestPriceHooks", "Usage: testBatOverrideSell [price]")
		SharedLogger.log("TestPriceHooks", "  testBatOverrideSell(50) - Force baseball bat sell price to 50")
		SharedLogger.log("TestPriceHooks", "  testBatOverrideSell(1)  - Force baseball bat sell price to 1")
		SharedLogger.log("TestPriceHooks", "  testBatOverrideSell('reset') - Disable override")
		return
	end

	local arg = price
	if arg == "reset" or arg == "disable" or arg == "off" then
		sendCommandToServer("setBatOverrideSellPrice", nil)
		SharedLogger.log("TestPriceHooks", "Sending reset command to server...")
		return
	end

	local p = tonumber(arg)
	if not p or p < 0 then
		SharedLogger.log("TestPriceHooks", "Invalid price: " .. tostring(arg))
		SharedLogger.log("TestPriceHooks", "  Use a non-negative number (e.g., 1, 50, 100)")
		return
	end

	sendCommandToServer("setBatOverrideSellPrice", p)
	SharedLogger.log("TestPriceHooks", "Sending bat override sell price to server: " .. p)
end

-- Reset all test hooks
function TestPriceHooksCommand.testappleReset()
	sendCommandToServer("disableAll", nil)
	SharedLogger.log("TestPriceHooks", "Sending disable command to server...")
end

return TestPriceHooksCommand
