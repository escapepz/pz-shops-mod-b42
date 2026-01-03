-- TransactionRegistry.lua
-- Transaction processing state tracking
-- Extends SHOPSB42 namespace (no new globals)

local Utilities = require("nshopsb42/utils/Utilities")
local SharedLogger = require("nshopsb42/utils/SharedLogger")

SHOPSB42.TransactionRegistry = SHOPSB42.TransactionRegistry or {}
local TransactionRegistry = SHOPSB42.TransactionRegistry

-- Constants for transaction lifecycle
local TRANSACTION_TTL_SECONDS = 86400 -- 24 hours in seconds
local MAX_RECORDS_PER_PLAYER = 1000 -- Keep last 1000 transactions per player
local CLEANUP_INTERVAL_SECONDS = 3600 -- Clean up at most once per hour

-- Track when we last cleaned up to avoid excessive ModData operations
TransactionRegistry._lastCleanupTime = TransactionRegistry._lastCleanupTime or 0

-- Retrieve or create the ModData storage for shop transactions
function TransactionRegistry.get()
	return ModData.getOrCreate("ShopTransactions")
end

-- Clean up transaction entries per player (rate-limited)
-- Strategy: Keep last 1000 records per player, delete by TTL (24h) when over limit
function TransactionRegistry.cleanupExpired()
	if not Utilities.IsServerOrSinglePlayer() then
		return
	end

	local now = os.time()
	-- Rate limit cleanup to avoid excessive ModData operations
	if (now - TransactionRegistry._lastCleanupTime) < CLEANUP_INTERVAL_SECONDS then
		return
	end

	TransactionRegistry._lastCleanupTime = now
	local data = TransactionRegistry.get()
	local totalCleaned = 0
	local usersToRemove = {} -- Collect users to delete after iteration

	-- Process each player's transaction history
	for username, transactions in pairs(data) do
		if type(transactions) == "table" then
			-- Collect all txnIds with their server timestamps
			local txnList = {}
			for txnId, txnData in pairs(transactions) do
				if type(txnData) == "table" and txnData.serverTimestamp then
					table.insert(txnList, {
						txnId = txnId,
						serverTimestamp = txnData.serverTimestamp,
					})
				end
			end

			-- Sort by timestamp (oldest first)
			table.sort(txnList, function(a, b)
				return a.serverTimestamp < b.serverTimestamp
			end)

			-- Delete if over limit OR if older than TTL
			local recordCount = #txnList
			local userCleaned = 0

			if recordCount > MAX_RECORDS_PER_PLAYER then
				-- Delete oldest records until we're at 1000
				for i = 1, recordCount - MAX_RECORDS_PER_PLAYER do
					local entry = txnList[i]
					data[username][entry.txnId] = nil
					userCleaned = userCleaned + 1
				end
			end

			-- Also delete anything older than 24 hours (secondary check for edge cases)
			for _, entry in ipairs(txnList) do
				local age = now - entry.serverTimestamp
				if age > TRANSACTION_TTL_SECONDS then
					data[username][entry.txnId] = nil
					userCleaned = userCleaned + 1
				end
			end

			-- Log cleanup for this player
			if userCleaned > 0 then
				SharedLogger.log(
					"Shops",
					"[TransactionRegistry] Cleanup for "
						.. username
						.. ": removed "
						.. userCleaned
						.. " records (kept last "
						.. MAX_RECORDS_PER_PLAYER
						.. ")"
				)
				totalCleaned = totalCleaned + userCleaned
			end

			-- Mark user for deletion if all their transactions were cleaned
			-- Must not modify data while iterating with pairs() - collect for post-iteration cleanup
			-- Check if table is empty by counting entries (safer than next() in Kahlua)
			local isEmpty = true
			if data[username] then
				for _ in pairs(data[username]) do
					isEmpty = false
					break
				end
			end
			if isEmpty then
				table.insert(usersToRemove, username)
			end
		end
	end

	-- Remove empty user entries after iteration is complete
	for _, username in ipairs(usersToRemove) do
		data[username] = nil
	end

	if totalCleaned > 0 then
		ModData.transmit("ShopTransactions")
	end
end

-- Check if a transaction has already been processed
-- Only the server should call this, but it's safe to call from client
function TransactionRegistry.isProcessed(username, txnId)
	if not Utilities.IsServerOrSinglePlayer() then
		return false
	end

	-- Periodically clean up entries (runs at most once per CLEANUP_INTERVAL_SECONDS)
	TransactionRegistry.cleanupExpired()

	local data = TransactionRegistry.get()
	if not data[username] then
		return false
	end

	local txnData = data[username][txnId]
	if not txnData then
		return false
	end

	-- Check if marked as processed or rolled back
	local status = txnData.status or txnData -- backward compat for old format
	return status == "processed" or status == "rolled_back"
end

-- Mark a transaction as processed on the server
-- Must only be called on the server after a successful transaction
-- Stores both status and server-authoritative timestamp
function TransactionRegistry.markProcessed(username, txnId)
	if not Utilities.IsServerOrSinglePlayer() then
		return
	end

	local data = TransactionRegistry.get()
	if not data[username] then
		data[username] = {}
	end

	-- Store as table with status and server timestamp (server-authoritative)
	data[username][txnId] = {
		status = "processed",
		serverTimestamp = os.time(), -- Server's own time, not client's
	}
	ModData.transmit("ShopTransactions")
end

-- Mark a transaction as rolled back (prevented duplicate rollback processing)
-- Must only be called on the server during rollback procedures
function TransactionRegistry.markRolledBack(username, txnId)
	if not Utilities.IsServerOrSinglePlayer() then
		return
	end

	local data = TransactionRegistry.get()
	if not data[username] then
		data[username] = {}
	end

	-- Prevent re-rollback: mark status only if not already marked
	if not data[username][txnId] then
		data[username][txnId] = {
			status = "rolled_back",
			serverTimestamp = os.time(), -- Server's own time
		}
		ModData.transmit("ShopTransactions")
	end
end

return TransactionRegistry
