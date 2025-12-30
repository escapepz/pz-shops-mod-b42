-- SharedLogger.lua
-- Centralized logging utility with debug toggle and server/client identification
-- Extends SHOPSB42 namespace (no new globals)

SHOPSB42.SharedLogger = SHOPSB42.SharedLogger or {}
local SharedLogger = SHOPSB42.SharedLogger

-- Global debug toggle - set to false to disable all logging
SharedLogger.DEBUG = true

-- Log a message with side identification
-- @param modName: Name of the mod (e.g., "Shops", "ShopsHooksExample")
-- @param message: Message to log
function SharedLogger.log(modName, message)
	if not SharedLogger.DEBUG then
		return
	end

	-- Determine side: In multiplayer, check who's running this code
	-- isClient() = true on both client (in MP) and in single-player
	-- isServer() = true on server (in MP) and in single-player
	-- Therefore: true client-only code = isClient() and not isServer()
	local side
	if isClient() and isServer() then
		-- Single-player mode: both return true, default to SERVER for backward compat
		side = "[SERVER]"
	elseif isClient() then
		-- Multiplayer client-only
		side = "[CLIENT]"
	else
		-- Multiplayer server-only
		side = "[SERVER]"
	end
	-- local timestamp = os.date("%H:%M:%S")
	writeLog(modName, string.format("%s %s", side, message))
end

return SharedLogger
