ShopAudit = ShopAudit or {}

-- Maximum number of log entries before oldest is pruned
local MAX_LOGS = 5000

-- Maximum age of log entries in seconds (7 days)
local MAX_AGE_SECONDS = 7 * 24 * 60 * 60

-- Retrieve or create the audit log ModData
function ShopAudit.getLog()
	return ModData.getOrCreate("ShopAuditLog")
end

-- Prune old entries and enforce max count
function ShopAudit.prune()
	local log = ShopAudit.getLog()
	if not log.entries then return end

	local now = os.time()
	local i = 1
	
	-- Remove entries older than MAX_AGE_SECONDS
	while i <= #log.entries do
		local entry = log.entries[i]
		if entry.time and (now - entry.time) > MAX_AGE_SECONDS then
			table.remove(log.entries, i)
		else
			i = i + 1
		end
	end

	-- Enforce max log size (FIFO pruning if still over limit)
	while #log.entries > MAX_LOGS do
		table.remove(log.entries, 1)
	end
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

		-- Prune old entries and enforce max count
		ShopAudit.prune()

		-- Sync to all clients
		ModData.transmit("ShopAuditLog")
	end)

	if not success then
		writeLog("Shops", "[ShopAudit] append error: " .. tostring(err))
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
