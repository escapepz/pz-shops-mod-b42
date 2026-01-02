local BClient = {}

function BClient.OnReceiveGlobalModData(key, modData)
	if not modData then
		return
	end
	ModData.remove(key)
	ModData.add(key, modData)
end

-- OnReceiveGlobalModData listener consolidated into ModDataDispatcherClient (Phase 5)

function BClient.OnConnected()
	-- Only request ModData in multiplayer - in SP the ModData is already available
	if isMultiplayer() then
		ModData.request("CoinBalance")
	end
end

function BClient.TransferReceived(noti)
	local player = getPlayer()
	if not player then
		return
	end

	local sender = noti.sender
	local coin = SHOPSB42.Currency.format(noti.coin)
	local specialCoin = SHOPSB42.Currency.format(noti.specialCoin)
	local msg = getText("IGUI_Balance_TransferReceivedSpecial", sender, coin, specialCoin)
	if not SHOPSB42.Currency.UseSpecialCoin then
		msg = getText("IGUI_Balance_TransferReceived", sender, coin)
	end
	player:playSound("Notification")
	player:setHaloNote(msg, 255, 255, 255, 400)
end

function BClient.MailboxReceived(noti)
	local player = getPlayer()
	if not player then
		return
	end

	local coin = SHOPSB42.Currency.format(noti.coin)
	local specialCoin = SHOPSB42.Currency.format(noti.specialCoin)
	local entryCount = noti.entryCount or 0

	local msg = getText("IGUI_Balance_MailboxReceivedSpecial", coin, specialCoin, entryCount)
	if not SHOPSB42.Currency.UseSpecialCoin then
		msg = getText("IGUI_Balance_MailboxReceived", coin, entryCount)
	end
	player:playSound("Notification")
	player:setHaloNote(msg, 255, 255, 255, 400)
end

-- OnServerCommand listener consolidated into ShopCommandDispatcherClient
-- OnReceiveGlobalModData listener consolidated into ModDataDispatcherClient (Phase 5)
-- OnConnected listener consolidated into ModDataDispatcherClient (Phase 5)
