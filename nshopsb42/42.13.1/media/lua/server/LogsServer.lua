if not isServer() then return end

local isDebug = getCore():getDebug()  -- Enable debug logs when running with -debug flag
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
			if isDebug then writeLog("Shops", "[SERVER] Log written to file: " .. logfile) end
		else
			if isDebug then writeLog("Shops", "[SERVER] Failed to open log file: " .. logfile) end
		end
	end)
	if not success and isDebug then
		writeLog("Shops", "[SERVER] Error writing log file: " .. tostring(err))
	end
end

function LServer.TransactionShopLog(player, args)
	msg = args[1]
	if isDebug then writeLog("Shops", "[SERVER] TransactionShopLog received: " .. msg) end
	if Valhalla and Valhalla.Commands then
		local args = { file = logfile, line = msg }
		Valhalla.Commands.writeToLog(nil, args)
		if isDebug then writeLog("Shops", "[SERVER] Log written via Valhalla") end
	else
		writeLogToFile(msg)
	end
end

local function LS_OnClientCommand(module, command, player, args)
    if module == "LS" and LServer[command] then
        LServer[command](player, args)
    end
end

Events.OnClientCommand.Add(LS_OnClientCommand)
