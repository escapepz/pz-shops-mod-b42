-- SharedLogger.lua
-- Centralized logging utility with debug toggle and server/client identification
-- Extends SHOPSB42 namespace (no new globals)

SHOPSB42.SharedLogger = SHOPSB42.SharedLogger or {}
local SharedLogger = SHOPSB42.SharedLogger

-- Global debug toggle - set to false to disable all logging
SharedLogger.DEBUG = true

-- Get the current execution side
-- @return string: "[SERVER]", "[CLIENT]", or nil
local function getSide()
	-- Determine side: In multiplayer, check who's running this code
	-- isClient() = true on both client (in MP) and in single-player
	-- isServer() = true on server (in MP) and in single-player
	-- Therefore: true client-only code = isClient() and not isServer()
	if isClient() and isServer() then
		-- Single-player mode: both return true, default to SERVER for backward compat
		return "[SERVER]"
	elseif isClient() then
		-- Multiplayer client-only
		return "[CLIENT]"
	else
		-- Multiplayer server-only
		return "[SERVER]"
	end
end

-- Log a message with side identification
-- Supports multiple signatures:
--   log(modName, message)
--   log(modName, message, context)
--   log(modName, action, phase, details)
-- @param modName: Name of the mod (e.g., "Shops", "ShopsHooksExample")
-- @param message: Message to log (or action name if 4 params)
-- @param context: Additional context string, or phase name if table follows
-- @param details: Optional table or string with details (txnId, status, etc.)
function SharedLogger.log(modName, message, context, details)
	if not SharedLogger.DEBUG then
		return
	end

	local side = getSide()
	local fullMessage

	-- Handle 4-param signature: action, phase, details
	if details then
		local action = message
		local phase = context
		fullMessage = string.format("%s [%s:%s] %s", side, action, phase, details)
	-- Handle 3-param signature: message with context
	elseif context then
		if type(context) == "table" then
			-- Details table provided
			local parts = {}
			for k, v in pairs(context) do
				table.insert(parts, string.format("%s=%s", k, tostring(v)))
			end
			fullMessage = string.format("%s %s - %s", side, message, table.concat(parts, ", "))
		else
			-- Context is a string
			fullMessage = string.format("%s %s %s", side, message, context)
		end
	-- Handle 2-param signature: simple message
	else
		fullMessage = string.format("%s %s", side, message)
	end

	writeLog(modName, fullMessage)
end

-- Convenience method for action logging
-- @param action: Action class name (e.g., "ShopSellAction")
-- @param phase: Phase name (e.g., "perform", "complete")
-- @param details: Optional table or string with details
function SharedLogger.logAction(action, phase, details)
	SharedLogger.log("Shops", string.format("[%s:%s]", action, phase), details)
end

return SharedLogger
