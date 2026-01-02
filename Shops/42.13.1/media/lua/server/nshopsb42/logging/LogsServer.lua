local SharedLogger = require("nshopsb42/utils/SharedLogger")
local LServer = {}

local logfile = "shops_transactions.log"
local msg = ""

--- Write log message to file (fallback when Valhalla unavailable)
local function writeLogToFile(message)
	local success, err = pcall(function()
		local file = io.open(logfile, "a")
		if file then
			file:write(os.date("%Y-%m-%d %H:%M:%S") .. " - " .. message .. "\n")
			file:close()
			SharedLogger.log("Shops", "Log written to file: " .. logfile)
		else
			SharedLogger.log("Shops", "Failed to open log file: " .. logfile)
		end
	end)
	if not success then
		SharedLogger.log("Shops", "Error writing log file: " .. tostring(err))
	end
end

function LServer.TransactionShopLog(player, args)
	msg = args[1]
	SharedLogger.log("Shops", "TransactionShopLog received: " .. msg)

	writeLogToFile(msg)
end

-- Event listeners consolidated into ShopCommandDispatcherServer
-- LS_OnClientCommand logic is now handled by unified dispatcher
