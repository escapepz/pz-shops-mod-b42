-- ModDataDispatcherClient.lua
-- Unified client-side dispatcher for global ModData events
-- Consolidates handlers from: TransferUI, BalanceClient
-- Follows EVENTS_RULE.md: Single listener per event, dispatch to handler table

if not isClient() then
	return
end

local SharedLogger = require("nshopsb42/utils/SharedLogger")

local Dispatcher = {}

-- =============================================================================
-- ONRECEIVEGLOBALMODDATA HANDLER
-- =============================================================================

function Dispatcher.onReceiveGlobalModData(key, data)
	if not key then
		return
	end

	SharedLogger.log("Shops", "[ModDataDispatcher:onReceiveGlobalModData] key=" .. key)

	-- BalanceClient handler
	local BClient = SHOPSB42.BalanceClient
	if BClient.OnReceiveGlobalModData then
		BClient.OnReceiveGlobalModData(key, data)
	end

	-- TransferUI handler (only for CoinBalance updates)
	if key == "CoinBalance" then
		local TransferUI = SHOPSB42.TransferUI
		if TransferUI.instance then
			local function onReceiveTransferUpdate()
				if TransferUI.instance and TransferUI.instance.onBalanceUpdate then
					TransferUI.instance:onBalanceUpdate(data)
				end
			end
			onReceiveTransferUpdate()
		end
	end
end

-- =============================================================================
-- ONCONNECTED HANDLER
-- =============================================================================

function Dispatcher.onConnected()
	SharedLogger.log("Shops", "[ModDataDispatcher:onConnected] Connection established")

	-- BalanceClient handler
	local BClient = SHOPSB42.BalanceClient
	if BClient and BClient.OnConnected then
		BClient.OnConnected()
	end
end

-- =============================================================================
-- IDEMPOTENT REGISTRATION
-- =============================================================================

if not Dispatcher._registered then
	Dispatcher._registered = true
	Events.OnReceiveGlobalModData.Add(Dispatcher.onReceiveGlobalModData)
	Events.OnConnected.Add(Dispatcher.onConnected)
	SharedLogger.log("Shops", "[ModDataDispatcher] Registered single listeners for ModData sync events")
end

return Dispatcher
