ShopAudit = ShopAudit or {}

-- Maximum number of log entries before oldest is pruned
local MAX_LOGS = 5000

-- Retrieve or create the audit log ModData
function ShopAudit.getLog()
	return ModData.getOrCreate("ShopAuditLog")
end

-- Append a transaction entry to the audit log
-- Safe to call from server-side TimedAction.complete()
function ShopAudit.append(entry)
	if not isServer() then return end

	-- Wrap in pcall to ensure logging errors never break gameplay
	local success, err = pcall(function()
		local log = ShopAudit.getLog()
		log.entries = log.entries or {}

		-- Add timestamp and entry to log
		table.insert(log.entries, entry)

		-- Enforce max log size (FIFO pruning)
		while #log.entries > MAX_LOGS do
			table.remove(log.entries, 1)
		end

		-- Sync to all clients
		ModData.transmit("ShopAuditLog")
	end)

	if not success then
		print("ShopAudit.append error: " .. tostring(err))
	end
end

-- Query log entries by transaction ID
function ShopAudit.queryByTxnId(txnId)
	if not isServer() then return nil end

	local log = ShopAudit.getLog()
	if not log.entries then return nil end

	for _, entry in ipairs(log.entries) do
		if entry.txnId == txnId then
			return entry
		end
	end

	return nil
end

-- Query log entries by player username
function ShopAudit.queryByPlayer(username)
	if not isServer() then return {} end

	local log = ShopAudit.getLog()
	if not log.entries then return {} end

	local results = {}
	for _, entry in ipairs(log.entries) do
		if entry.player and entry.player.username == username then
			table.insert(results, entry)
		end
	end

	return results
end
