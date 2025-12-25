TransactionRegistry = TransactionRegistry or {}

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

	return data[username][txnId] == true
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

	data[username][txnId] = true
	ModData.transmit("ShopTransactions")
end
