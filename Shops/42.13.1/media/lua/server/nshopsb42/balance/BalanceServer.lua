local BServer = {}
local BalanceAudit = require("nshopsb42/balance/BalanceAudit")
local SharedLogger = require("nshopsb42/utils/SharedLogger")

local logfile = "timestamp_economy.log"
local msg = ""

-- Rate limiting configuration
local RATE_LIMIT = {
	windowMs = 10000, -- 10 second window
	maxRequests = 3, -- max 3 transfers per window
	minIntervalMs = 1500, -- hard minimum 1.5s between requests
}

-- Server-side rate limiter state (per sender)
BServer.rate = BServer.rate or {}

-- Per-recipient throttle (prevent griefing via notification floods)
BServer.recipientRate = BServer.recipientRate or {}

function BServer.OnInitGlobalModData()
	ModData.getOrCreate("CoinBalance")
	ModData.getOrCreate("BalanceMailbox")
end

Events.OnInitGlobalModData.Add(BServer.OnInitGlobalModData)

function BServer.writeLog(_msg)
	-- if Valhalla and Valhalla.Commands then
	-- 	local args = { file = logfile, line = msg }
	-- 	Valhalla.Commands.writeToLog(nil, args)
	-- 	return
	-- end
	SharedLogger.log("Shops", _msg)
end

function BServer.CreateAccount(player, args)
	if not player or not args then
		return
	end

	local username = player:getUsername()
	local linkedTo = args.linkedTo
	local walletID = args.walletID
	local account = ModData.get("CoinBalance")[username]

	if account then
		account.linkedTo = linkedTo

		msg = "Link: %s linked new wallet: %s"
		msg = string.format(msg, username, linkedTo)
		BServer.writeLog(msg)
	else
		ModData.get("CoinBalance")[username] = { coin = 0, specialCoin = 0, linkedTo = linkedTo }

		msg = "NewAccount: %s, Coin: 0 SpecialCoin: 0"
		msg = string.format(msg, username, linkedTo)
		BServer.writeLog(msg)
	end

	-- Sync wallet modData to all clients if wallet ID is provided
	if walletID then
		local wallet = player:getInventory():getItemById(walletID)
		if wallet then
			-- Validate wallet ownership: confirm wallet is in player's inventory
			if wallet:getContainer() ~= player:getInventory() then
				SharedLogger.log(
					"Shops",
					"CreateAccount: REJECTED - wallet not in player inventory - walletID=" .. tostring(walletID)
				)
				return
			end

			-- Set wallet modData on server to match client state
			local walletModData = wallet:getModData()
			walletModData.belongsTo = username
			walletModData.linkedTo = linkedTo
			SharedLogger.log(
				"Shops",
				"CreateAccount: Syncing wallet modData - walletID="
					.. tostring(walletID)
					.. ", belongsTo="
					.. tostring(walletModData.belongsTo)
					.. ", linkedTo="
					.. tostring(walletModData.linkedTo)
			)
			syncItemModData(player, wallet)
		else
			SharedLogger.log("Shops", "CreateAccount: Wallet not found - walletID=" .. tostring(walletID))
		end
	end

	ModData.transmit("CoinBalance")
end

function BServer.VirtualDeposit(player, args)
	if not player or not args then
		return
	end
	if not args.username then
		return
	end

	local username = args.username
	local coin = tonumber(args.coin) or 0
	local specialCoin = tonumber(args.specialCoin) or 0
	local source = args.source or "Unknown"

	local account = ModData.get("CoinBalance")[username]
	if not account then
		return
	end

	-- Validate amounts are non-negative
	if coin < 0 or specialCoin < 0 then
		return
	end

	-- Reject zero-value deposits
	if coin == 0 and specialCoin == 0 then
		return
	end

	-- Store old balance for logging
	local oldCoin = account.coin
	local oldSpecialCoin = account.specialCoin

	-- Perform atomic mutation (no inventory changes)
	account.coin = account.coin + coin
	account.specialCoin = account.specialCoin + specialCoin

	msg = "VirtualDeposit: %s (%s) oldBalance: Coin: %s SpecialCoin %s newBalance: Coin: %s SpecialCoin %s"
	msg = string.format(msg, username, source, oldCoin, oldSpecialCoin, account.coin, account.specialCoin)
	BServer.writeLog(msg)

	ModData.transmit("CoinBalance")
end

function BServer.Deposit(player, args)
	if not player or not args then
		return
	end

	local username = player:getUsername()
	local coin = tonumber(args.coin) or 0
	local specialCoin = tonumber(args.specialCoin) or 0
	local itemIDs = args.itemIDs

	local account = ModData.get("CoinBalance")[username]
	if not account then
		return
	end

	-- Validate amounts are non-negative
	if coin < 0 or specialCoin < 0 then
		return
	end

	-- CRITICAL: itemIDs must be provided to prevent infinite balance exploit
	if not itemIDs or type(itemIDs) ~= "table" or #itemIDs == 0 then
		SharedLogger.log("Shops", "Deposit REJECTED: no itemIDs provided - " .. username)
		return
	end

	-- Verify all items exist in inventory before deducting balance
	local itemsToRemove = {}
	for i, itemID in ipairs(itemIDs) do
		local item = player:getInventory():getItemById(itemID)
		if not item then
			SharedLogger.log(
				"Shops",
				"Deposit REJECTED: item " .. tostring(itemID) .. " not found in inventory - " .. username
			)
			return
		end
		table.insert(itemsToRemove, item)
	end

	-- Store old balance for logging
	local oldCoin = account.coin
	local oldSpecialCoin = account.specialCoin

	-- Perform atomic mutation
	account.coin = account.coin + coin
	account.specialCoin = account.specialCoin + specialCoin

	msg = "Deposit: %s oldBalance: Coin: %s SpecialCoin %s newBalance: Coin: %s SpecialCoin %s"
	msg = string.format(msg, username, oldCoin, oldSpecialCoin, account.coin, account.specialCoin)
	BServer.writeLog(msg)

	-- Remove coin items from player inventory
	for i, item in ipairs(itemsToRemove) do
		local container = item:getContainer()
		container:Remove(item)
		sendRemoveItemFromContainer(container, item)
	end

	ModData.transmit("CoinBalance")
end

function BServer.Transfer(player, args)
	-- Validate arguments
	if not player or not args then
		SharedLogger.log("Shops", "Transfer ERROR: player or args is nil")
		return
	end

	local sender = player:getUsername()
	local coin = tonumber(args.coin)
	local specialCoin = tonumber(args.specialCoin)
	local recipient = args.recipient
	local now = getTimestampMs()

	SharedLogger.log(
		"Shops",
		string.format(
			"Transfer START: sender=%s, recipient=%s, coin=%s, specialCoin=%s",
			sender,
			recipient,
			coin,
			specialCoin
		)
	)

	-- Rate limit enforcement (top priority)
	local r = BServer.rate[sender]
	if not r then
		r = { lastTs = 0, count = 0, windowStart = now }
		BServer.rate[sender] = r
	end

	-- Hard minimum interval between requests
	if now - r.lastTs < RATE_LIMIT.minIntervalMs then
		SharedLogger.log(
			"Shops",
			string.format("Transfer REJECTED: rate limit interval %d < %d", now - r.lastTs, RATE_LIMIT.minIntervalMs)
		)
		return
	end

	-- Sliding window counter
	if now - r.windowStart > RATE_LIMIT.windowMs then
		r.windowStart = now
		r.count = 0
	end

	r.count = r.count + 1
	r.lastTs = now

	-- Reject if over limit (silent rejection)
	if r.count > RATE_LIMIT.maxRequests then
		SharedLogger.log(
			"Shops",
			string.format("Transfer REJECTED: rate limit exceeded %d > %d", r.count, RATE_LIMIT.maxRequests)
		)
		return
	end

	-- Reject invalid arguments
	if not recipient or recipient == sender then
		SharedLogger.log(
			"Shops",
			string.format("Transfer REJECTED: invalid recipient (nil=%s, same=%s)", not recipient, recipient == sender)
		)
		return
	end
	if not coin or not specialCoin then
		SharedLogger.log(
			"Shops",
			string.format("Transfer REJECTED: coin or specialCoin is nil (coin=%s, sc=%s)", coin, specialCoin)
		)
		return
	end
	if coin < 0 or specialCoin < 0 then
		SharedLogger.log(
			"Shops",
			string.format("Transfer REJECTED: negative amounts (coin=%s, sc=%s)", coin, specialCoin)
		)
		return
	end

	-- Guard: reject zero-value transfers
	if coin == 0 and specialCoin == 0 then
		SharedLogger.log("Shops", "Transfer REJECTED: zero-value transfer")
		return
	end

	-- Resolve authoritative accounts (server-side truth)
	local coinBalance = ModData.get("CoinBalance")
	if not coinBalance then
		SharedLogger.log("Shops", "Transfer ERROR: CoinBalance ModData not found")
		return
	end

	local account = coinBalance[sender]
	local recipientAccount = coinBalance[recipient]

	if not account or not recipientAccount then
		SharedLogger.log(
			"Shops",
			string.format(
				"Transfer REJECTED: account not found (sender=%s, recipient=%s)",
				account == nil,
				recipientAccount == nil
			)
		)
		return
	end

	-- Validate balances (server-side authority)
	if account.coin < coin then
		writeLog("Shops", string.format("[SERVER] Transfer REJECTED: insufficient coin (%d < %d)", account.coin, coin))
		return
	end
	if account.specialCoin < specialCoin then
		writeLog(
			"Shops",
			string.format(
				"[SERVER] Transfer REJECTED: insufficient specialCoin (%d < %d)",
				account.specialCoin,
				specialCoin
			)
		)
		return
	end

	writeLog(
		"Shops",
		string.format(
			"[SERVER] Transfer VALIDATION PASSED: sender has coin=%d (need %d), specialCoin=%d (need %d)",
			account.coin,
			coin,
			account.specialCoin,
			specialCoin
		)
	)

	-- Per-recipient throttle (prevent griefing via notification floods)
	local rr = BServer.recipientRate[recipient] or { lastTs = 0 }
	if now - rr.lastTs < 500 then
		writeLog("Shops", string.format("[SERVER] Transfer REJECTED: recipient throttle %d < 500", now - rr.lastTs))
		return
	end
	rr.lastTs = now
	BServer.recipientRate[recipient] = rr

	-- Deduct funds from sender immediately
	local oldSenderCoin = account.coin
	local oldSenderSpecialCoin = account.specialCoin

	account.coin = account.coin - coin
	account.specialCoin = account.specialCoin - specialCoin

	writeLog(
		"Shops",
		string.format(
			"[SERVER] Transfer DEDUCTED: sender balance coin %d->%d, specialCoin %d->%d",
			oldSenderCoin,
			account.coin,
			oldSenderSpecialCoin,
			account.specialCoin
		)
	)

	-- Check if recipient is online
	local recipientPlayer = nil
	local players = getOnlinePlayers()
	local playersSize = players:size()
	if playersSize then
		for i = 0, playersSize - 1, 1 do
			local p = players:get(i)
			if p:getUsername() == recipient then
				recipientPlayer = p
				break
			end
		end
	end

	local isOnline = recipientPlayer ~= nil
	local actionId = BalanceAudit.logTransfer(sender, recipient, coin, specialCoin)

	if isOnline then
		-- Online path: credit immediately
		local oldRecipientCoin = recipientAccount.coin
		local oldRecipientSpecialCoin = recipientAccount.specialCoin

		recipientAccount.coin = recipientAccount.coin + coin
		recipientAccount.specialCoin = recipientAccount.specialCoin + specialCoin

		msg =
			"Transfer: Sender %s oldBalance: Coin: %s SpecialCoin %s newBalance: Coin: %s SpecialCoin %s Recipient: %s oldBalance: Coin: %s SpecialCoin %s newBalance: Coin: %s SpecialCoin %s [ONLINE]"
		msg = string.format(
			msg,
			sender,
			oldSenderCoin,
			oldSenderSpecialCoin,
			account.coin,
			account.specialCoin,
			recipient,
			oldRecipientCoin,
			oldRecipientSpecialCoin,
			recipientAccount.coin,
			recipientAccount.specialCoin
		)
		BServer.writeLog(msg)
		writeLog(
			"Shops",
			string.format(
				"[SERVER] Transfer actionId: %s | %s -> %s | %d / %d [ONLINE]",
				actionId,
				sender,
				recipient,
				coin,
				specialCoin
			)
		)

		-- Notify recipient
		local noti = {
			sender = sender,
			coin = coin,
			specialCoin = specialCoin,
		}
		sendServerCommand(recipientPlayer, "BS", "TransferReceived", noti)
	else
		-- Offline path: enqueue mailbox entry
		local mailbox = ModData.getOrCreate("BalanceMailbox")

		mailbox[recipient] = mailbox[recipient] or {}
		table.insert(mailbox[recipient], {
			ts = getTimestampMs(),
			from = sender,
			coin = coin,
			specialCoin = specialCoin,
			actionId = actionId,
		})

		-- Mark recipient account as having pending mailbox
		recipientAccount.hasMailbox = true

		msg =
			"Transfer: Sender %s oldBalance: Coin: %s SpecialCoin %s newBalance: Coin: %s SpecialCoin %s Recipient: %s [OFFLINE MAILBOX]"
		msg = string.format(
			msg,
			sender,
			oldSenderCoin,
			oldSenderSpecialCoin,
			account.coin,
			account.specialCoin,
			recipient
		)
		BServer.writeLog(msg)
		SharedLogger.log(
			"Shops",
			string.format(
				"Transfer actionId: %s | %s -> %s | %d / %d [OFFLINE MAILBOX]",
				actionId,
				sender,
				recipient,
				coin,
				specialCoin
			)
		)

		ModData.transmit("BalanceMailbox")
	end

	-- Persist and sync
	ModData.transmit("CoinBalance")
end

function BServer.Withdraw(player, args)
	if not player or not args then
		return
	end

	local username = player:getUsername()
	local coin = tonumber(args.coin) or 0
	local specialCoin = tonumber(args.specialCoin) or 0

	local account = ModData.get("CoinBalance")[username]
	if not account then
		return
	end

	-- Validate amounts are non-negative
	if coin < 0 or specialCoin < 0 then
		return
	end

	-- Validate sufficient balance (server authority)
	if account.coin < coin then
		return
	end
	if account.specialCoin < specialCoin then
		return
	end

	-- Store old balance for logging
	local oldCoin = account.coin
	local oldSpecialCoin = account.specialCoin

	-- Perform atomic mutation
	account.coin = account.coin - coin
	account.specialCoin = account.specialCoin - specialCoin

	msg = "Withdraw: %s oldBalance: Coin: %s SpecialCoin %s newBalance: Coin: %s SpecialCoin %s"
	msg = string.format(msg, username, oldCoin, oldSpecialCoin, account.coin, account.specialCoin)
	BServer.writeLog(msg)

	ModData.transmit("CoinBalance")
end

function BServer.UnlinkWallet(player, args)
	if not player or not args then
		return
	end

	local username = player:getUsername()
	local walletID = args.walletID
	local account = ModData.get("CoinBalance")[username]
	if not account then
		return
	end
	account.linkedTo = nil

	msg = "Unlink: %s unlinked wallet"
	msg = string.format(msg, username)
	BServer.writeLog(msg)

	-- Sync wallet modData to all clients if wallet ID is provided
	if walletID then
		local wallet = player:getInventory():getItemById(walletID)
		if wallet then
			-- Clear wallet modData on server to match client state
			local walletModData = wallet:getModData()
			walletModData.belongsTo = nil
			walletModData.linkedTo = nil
			SharedLogger.log(
				"Shops",
				"UnlinkWallet: Syncing wallet modData - walletID="
					.. tostring(walletID)
					.. ", belongsTo="
					.. tostring(walletModData.belongsTo)
					.. ", linkedTo="
					.. tostring(walletModData.linkedTo)
			)
			syncItemModData(player, wallet)
		else
			SharedLogger.log("Shops", "UnlinkWallet: Wallet not found - walletID=" .. tostring(walletID))
		end
	end

	ModData.transmit("CoinBalance")
end

-- Deliver queued mailbox entries on player login
function BServer.deliverMailbox(player)
	local username = player:getUsername()
	local mailbox = ModData.get("BalanceMailbox")
	if not mailbox or not mailbox[username] then
		return
	end

	local account = ModData.get("CoinBalance")[username]
	if not account then
		return
	end

	local totalCoin = 0
	local totalSpecialCoin = 0
	local entryCount = #mailbox[username]
	for _, entry in ipairs(mailbox[username]) do
		account.coin = account.coin + entry.coin
		account.specialCoin = account.specialCoin + entry.specialCoin
		totalCoin = totalCoin + entry.coin
		totalSpecialCoin = totalSpecialCoin + entry.specialCoin
	end

	mailbox[username] = nil -- clear mailbox
	account.hasMailbox = nil -- clear mailbox flag
	ModData.transmit("BalanceMailbox")
	ModData.transmit("CoinBalance")

	msg = string.format(
		"MailboxClaimed: %s received coin=%d specialCoin=%d from %d entries",
		username,
		totalCoin,
		totalSpecialCoin,
		entryCount
	)
	BServer.writeLog(msg)
	writeLog(
		"Shops",
		string.format(
			"[SERVER] Mailbox Delivered to %s: coin=%d specialCoin=%d from %d entries",
			username,
			totalCoin,
			totalSpecialCoin,
			entryCount
		)
	)
end

-- Handle explicit mailbox claim via context menu
function BServer.ClaimMailbox(player, args)
	if not player or not args then
		return
	end

	local username = player:getUsername()
	SharedLogger.log("Shops", string.format("ClaimMailbox Requested by %s", username))

	-- Get mailbox entries before delivery
	local mailbox = ModData.get("BalanceMailbox")
	local totalCoin = 0
	local totalSpecialCoin = 0
	local entryCount = 0

	if mailbox and mailbox[username] then
		entryCount = #mailbox[username]
		for _, entry in ipairs(mailbox[username]) do
			totalCoin = totalCoin + entry.coin
			totalSpecialCoin = totalSpecialCoin + entry.specialCoin
		end
	end

	-- Deliver any pending mailbox entries
	BServer.deliverMailbox(player)

	-- Send notification to player
	if entryCount > 0 then
		local noti = {
			coin = totalCoin,
			specialCoin = totalSpecialCoin,
			fromMailbox = true,
			entryCount = entryCount,
		}
		sendServerCommand(player, "BS", "MailboxReceived", noti)
	end
end

-- Admin-only rollback for a specific transfer by actionId
function BServer.Rollback(player, args)
	if not player or not args then
		return
	end

	-- Verify admin privilege
	if not player:isAdmin() then
		SharedLogger.log("Shops", "Rollback Non-admin attempt: " .. player:getUsername())
		return
	end

	local actionId = args.actionId
	if not actionId then
		return
	end

	-- Find the audit entry
	local entry = BalanceAudit.findEntry(actionId)
	if not entry then
		SharedLogger.log("Shops", "Rollback Entry not found: " .. actionId)
		return
	end

	-- Resolve accounts
	local coinBalance = ModData.get("CoinBalance")
	if not coinBalance then
		return
	end

	local senderAcc = coinBalance[entry.sender]
	local recAcc = coinBalance[entry.recipient]

	if not senderAcc or not recAcc then
		SharedLogger.log("Shops", "Rollback Account not found for actionId: " .. actionId)
		return
	end

	-- Check if this transfer was delivered online or is in mailbox (offline)
	local mailbox = ModData.getOrCreate("BalanceMailbox")
	local isInMailbox = false
	if mailbox[entry.recipient] then
		for i, mentry in ipairs(mailbox[entry.recipient]) do
			if mentry.actionId == actionId then
				isInMailbox = true
				-- Remove from mailbox instead of reversing account balances
				table.remove(mailbox[entry.recipient], i)
				if #mailbox[entry.recipient] == 0 then
					mailbox[entry.recipient] = nil
				end
				break
			end
		end
	end

	if isInMailbox then
		-- Mailbox case: just remove entry, refund sender
		senderAcc.coin = senderAcc.coin + entry.coin
		senderAcc.specialCoin = senderAcc.specialCoin + entry.specialCoin
	else
		-- Online delivery: verify balances are sufficient for rollback
		if recAcc.coin < entry.coin or recAcc.specialCoin < entry.specialCoin then
			SharedLogger.log("Shops", "Rollback Insufficient balance in recipient account: " .. actionId)
			return
		end

		-- Reverse the mutation (return to sender, deduct from recipient)
		senderAcc.coin = senderAcc.coin + entry.coin
		senderAcc.specialCoin = senderAcc.specialCoin + entry.specialCoin
		recAcc.coin = recAcc.coin - entry.coin
		recAcc.specialCoin = recAcc.specialCoin - entry.specialCoin
	end

	-- Log the rollback
	local status = isInMailbox and "[MAILBOX]" or "[ONLINE]"
	local msg = string.format(
		"Rollback actionId: %s | reversed %s -> %s | %d / %d | %s | by admin: %s",
		actionId,
		entry.sender,
		entry.recipient,
		entry.coin,
		entry.specialCoin,
		status,
		player:getUsername()
	)
	BServer.writeLog(msg)
	SharedLogger.log("Shops", msg)

	-- Sync updated balances
	ModData.transmit("CoinBalance")
	if isInMailbox then
		ModData.transmit("BalanceMailbox")
	end
end

local function BS_OnClientCommand(module, command, player, args)
	if module == "BS" and BServer[command] then
		BServer[command](player, args)
	elseif module == "shops" and BServer[command] then
		BServer[command](player, args)
	end
end

Events.OnClientCommand.Add(BS_OnClientCommand)
