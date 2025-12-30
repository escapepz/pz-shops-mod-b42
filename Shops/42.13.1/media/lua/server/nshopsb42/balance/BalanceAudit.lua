if not isServer() then
	return
end

local BalanceAudit = {}

-- Maximum number of audit entries before oldest is pruned
local MAX_ENTRIES = 10000

-- Maximum age of audit entries in seconds (30 days)
local MAX_AGE_SECONDS = 30 * 24 * 60 * 60

-- Audit record schema (immutable, append-only)
-- {
--     ts = number,             -- timestamp ms
--     sender = string,
--     recipient = string,
--     coin = number,
--     specialCoin = number,
--     serverId = string,       -- server name or UUID
--     actionId = string        -- unique transfer id for rollback reference
-- }

-- Generate unique action ID for each transfer
local function makeActionId(sender, recipient)
	return string.format("%s:%s:%d:%d", sender, recipient, getTimestampMs(), ZombRand(1000000))
end

-- Prune old entries and enforce max count
function BalanceAudit.prune()
	local data = ModData.get("BalanceAudit")
	if not data then
		return
	end

	local now = os.time()
	local i = 1

	-- Remove entries older than MAX_AGE_SECONDS
	while i <= #data do
		local entry = data[i]
		if entry.ts and (now - (entry.ts / 1000)) > MAX_AGE_SECONDS then
			table.remove(data, i)
		else
			i = i + 1
		end
	end

	-- Enforce max entry count (FIFO pruning if still over limit)
	while #data > MAX_ENTRIES do
		table.remove(data, 1)
	end
end

-- Append audit entry to immutable log
function BalanceAudit.append(entry)
	if not entry then
		return
	end

	local data = ModData.getOrCreate("BalanceAudit")
	if not data then
		return
	end

	-- Ensure entry is timestamped
	if not entry.ts then
		entry.ts = getTimestampMs()
	end

	-- Add server identifier
	if not entry.serverId then
		entry.serverId = getServerName() or "default"
	end

	-- Add to log (append-only)
	table.insert(data, entry)

	-- Prune old entries and enforce max count
	BalanceAudit.prune()

	-- Transmit to all clients (read-only for admins)
	ModData.transmit("BalanceAudit")
end

-- Create and log a transfer entry
function BalanceAudit.logTransfer(sender, recipient, coin, specialCoin)
	local entry = {
		ts = getTimestampMs(),
		sender = sender,
		recipient = recipient,
		coin = coin,
		specialCoin = specialCoin,
		serverId = getServerName() or "default",
		actionId = makeActionId(sender, recipient),
	}

	BalanceAudit.append(entry)
	return entry.actionId
end

-- Find audit entry by actionId
function BalanceAudit.findEntry(actionId)
	local data = ModData.get("BalanceAudit")
	if not data then
		return nil
	end

	for _, entry in ipairs(data) do
		if entry.actionId == actionId then
			return entry
		end
	end

	return nil
end

-- Get audit entries for a specific account
function BalanceAudit.getAccountHistory(username)
	local data = ModData.get("BalanceAudit")
	if not data then
		return {}
	end

	local history = {}
	for _, entry in ipairs(data) do
		if entry.sender == username or entry.recipient == username then
			table.insert(history, entry)
		end
	end

	return history
end

-- Get total transfers for a user (sum incoming and outgoing)
function BalanceAudit.getAccountStats(username)
	local history = BalanceAudit.getAccountHistory(username)
	local sent = { coin = 0, specialCoin = 0, count = 0 }
	local received = { coin = 0, specialCoin = 0, count = 0 }

	for _, entry in ipairs(history) do
		if entry.sender == username then
			sent.coin = sent.coin + entry.coin
			sent.specialCoin = sent.specialCoin + entry.specialCoin
			sent.count = sent.count + 1
		elseif entry.recipient == username then
			received.coin = received.coin + entry.coin
			received.specialCoin = received.specialCoin + entry.specialCoin
			received.count = received.count + 1
		end
	end

	return { sent = sent, received = received }
end

return BalanceAudit
