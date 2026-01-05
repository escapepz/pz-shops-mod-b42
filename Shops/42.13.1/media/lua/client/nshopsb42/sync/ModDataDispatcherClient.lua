-- ModDataDispatcherClient.lua
-- Unified client-side dispatcher for global ModData events
-- Consolidates handlers from: TransferUI, BalanceClient, TransactionValidationClient
-- Follows EVENTS_RULE.md: Single listener per event, dispatch to handler table

if not isClient() then
	return
end

local SharedLogger = require("nshopsb42/utils/SharedLogger")
local TransactionValidationClient = require("nshopsb42/transactions/TransactionValidationClient")

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
	---@diagnostic disable-next-line: unnecessary-if
	if BClient.OnReceiveGlobalModData then
		BClient.OnReceiveGlobalModData(key, data)
	end

	-- Phase 2.3: Transaction validation (for CoinBalance updates)
	if key == "CoinBalance" then
		-- Validate transaction price mismatch when balance updates
		if data and TransactionValidationClient then
			-- Get the last recorded transaction
			local lastTxn = TransactionValidationClient.getLastTransaction()
			---@diagnostic disable-next-line: unnecessary-if
			if lastTxn and lastTxn.txnId then
				-- Transaction was recorded, validate it after server response
				SharedLogger.log(
					"Shops",
					"[ModDataDispatcher:onReceiveGlobalModData] Transaction recorded, clearing after balance update - txnId="
						.. tostring(lastTxn.txnId)
				)
				-- Clear transaction after balance is updated
				-- (Actual validation delta comparison can be added here later)
				TransactionValidationClient.clearTransaction()
			end
		end
	end

	-- TransferUI handler (only for CoinBalance updates)
	if key == "CoinBalance" then
		local TransferUI = SHOPSB42.TransferUI
		---@diagnostic disable-next-line: unnecessary-if
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
	---@diagnostic disable-next-line: unnecessary-if
	if BClient and BClient.OnConnected then
		BClient.OnConnected()
	end
end

-- =============================================================================
-- IDEMPOTENT REGISTRATION
-- =============================================================================

---@diagnostic disable-next-line: unnecessary-if
if not Dispatcher._registered then
	Dispatcher._registered = true
	Events.OnReceiveGlobalModData.Add(Dispatcher.onReceiveGlobalModData)
	Events.OnConnected.Add(Dispatcher.onConnected)
	SharedLogger.log("Shops", "[ModDataDispatcher] Registered single listeners for ModData sync events")
end

return Dispatcher
