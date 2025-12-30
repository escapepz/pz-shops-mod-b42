-- TransactionRegistry.lua
-- Transaction processing state tracking
-- Extends SHOPSB42 namespace (no new globals)

SHOPSB42.TransactionRegistry = SHOPSB42.TransactionRegistry or {}
local TransactionRegistry = SHOPSB42.TransactionRegistry

-- Retrieve or create the ModData storage for shop transactions
function TransactionRegistry.get()
	return ModData.getOrCreate("ShopTransactions")
end

-- Check if a transaction has already been processed
-- Only the server should call this, but it's safe to call from client
function TransactionRegistry.isProcessed(username, txnId)
	if not isServer() then
		return false
	end

	local data = TransactionRegistry.get()
	if not data[username] then
		return false
	end

	local status = data[username][txnId]
	return status == "processed" or status == "rolled_back"
end

-- Mark a transaction as processed on the server
-- Must only be called on the server after a successful transaction
function TransactionRegistry.markProcessed(username, txnId)
	if not isServer() then
		return
	end

	local data = TransactionRegistry.get()
	if not data[username] then
		data[username] = {}
	end

	data[username][txnId] = "processed"
	ModData.transmit("ShopTransactions")
end

-- Mark a transaction as rolled back (prevented duplicate rollback processing)
-- Must only be called on the server during rollback procedures
function TransactionRegistry.markRolledBack(username, txnId)
	if not isServer() then
		return
	end

	local data = TransactionRegistry.get()
	if not data[username] then
		data[username] = {}
	end

	-- Prevent re-rollback: mark status only if not already marked
	if not data[username][txnId] then
		data[username][txnId] = "rolled_back"
		ModData.transmit("ShopTransactions")
	end
end

return TransactionRegistry
