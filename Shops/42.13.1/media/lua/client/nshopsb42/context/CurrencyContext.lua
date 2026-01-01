---@diagnostic disable: undefined-global

local Utilities = require("nshopsb42/utils/Utilities")
local Currency = SHOPSB42.Currency
local UIText = SHOPSB42.UIText
local Balance = SHOPSB42.Balance

-- Lazy reference to TransferUI to avoid module-load-time dependency
local function getTransferUI()
	return SHOPSB42.TransferUI
end

function Currency.lootCoins(worldobjects, playerNum, player)
	local containers = getPlayerLoot(playerNum).inventoryPane.inventoryPage.backpacks
	local coinsList = ArrayList.new()
	for k, v in pairs(containers) do
		local container = v.inventory
		if container then
			for coinType, coinData in pairs(Currency.Coins) do
				local coins = container:getItemsFromFullType(coinType)
				if coins:size() > 0 then
					coinsList:addAll(coins)
				end
			end
		end
	end
	if coinsList:size() > 0 then
		local playerInv = getPlayerInventory(playerNum).inventory
		for i = 0, coinsList:size() - 1 do
			local coin = coinsList:get(i)
			ISTimedActionQueue.add(ISInventoryTransferAction:new(player, coin, coin:getContainer(), playerInv))
		end
	end
end

function Currency.LootCoinsObjectContextMenu(playerNum, context, items)
	local player = getSpecificPlayer(playerNum)
	if player:getVehicle() ~= nil then
		return
	end
	items = ISInventoryPane.getActualItems(items)
	if not items then
		return
	end
	if #items < 1 then
		return
	end
	if items[1]:isInPlayerInventory() then
		return
	end
	local coin = Currency.Coins[items[1]:getFullType()]
	if not coin then
		return
	end
	context:addOption(UIText.LootAllCoins, worldobjects, Currency.lootCoins, playerNum, player)
end

function Currency.coinsToAccount(worldobjects, items, coinQuantity)
	local player = getPlayer()
	local itemIDs = {}
	for k, v in pairs(items) do
		table.insert(itemIDs, v:getID())
	end
	-- Server will remove items from inventory after validation
	sendClientCommand(player, "BS", "Deposit", {
		coin = coinQuantity.coin,
		specialCoin = coinQuantity.specialCoin,
		itemIDs = itemIDs,
	})
end

function Currency.CoinsToAccountObjectContextMenu(playerNum, context, items)
	items = ISInventoryPane.getActualItems(items)
	if not items or #items < 1 then
		return
	end
	local playerInv = getPlayerInventory(playerNum).backpacks[1].inventory
	local wallet = nil
	local player = getSpecificPlayer(playerNum)
	local username = player:getUsername()
	local account = Balance.getUserAccount(username)

	-- Find any valid wallet (not stale) across all wallet types
	for k, v in pairs(Currency.Wallets) do
		local walletItems = playerInv:getItemsFromFullType(k)
		for i = 0, walletItems:size() - 1 do
			local w = walletItems:get(i)
			if w:getModData().nshopsb42_belongsTo == username and w:getModData().nshopsb42_linkedTo then
				-- Check if wallet is valid (not stale)
				if account and account.linkedTo == w:getModData().nshopsb42_linkedTo then
					wallet = w
					break
				end
			end
		end
		if wallet then
			break
		end
	end
	if not wallet then
		return
	end

	local coinQuantity = {}
	coinQuantity.coin = 0
	coinQuantity.specialCoin = 0
	for k, v in pairs(items) do
		if not v:isInPlayerInventory() then
			return
		end
		local coin = Currency.Coins[v:getFullType()]
		if not coin then
			return
		end
		if not coin.specialCoin then
			coinQuantity.coin = coinQuantity.coin + coin.value
		else
			coinQuantity.specialCoin = coinQuantity.specialCoin + 1
		end
	end
	local isSinglePlayer = Utilities.IsClientOrSinglePlayer()
	if isSinglePlayer or account then
		if coinQuantity.coin > 0 or coinQuantity.specialCoin > 0 then
			context:addOption(UIText.CoinsToAccount, worldobjects, Currency.coinsToAccount, items, coinQuantity)
		end
	end
end

function Currency.linkWallet(worldobjects, wallet, player)
	local username = player:getUsername()
	local linkedTo = username .. getTimestampMs()
	wallet:getModData().nshopsb42_belongsTo = username
	wallet:getModData().nshopsb42_linkedTo = linkedTo
	writeLog(
		"Shops",
		"[CLIENT] Link: Set wallet modData - belongsTo="
			.. tostring(wallet:getModData().nshopsb42_belongsTo)
			.. ", linkedTo="
			.. tostring(wallet:getModData().nshopsb42_linkedTo)
	)
	sendClientCommand(player, "BS", "CreateAccount", {
		linkedTo = linkedTo,
		walletID = wallet:getID(),
	})
	-- Only request ModData in multiplayer - in SP the ModData is already available
	if isMultiplayer() then
		ModData.request("CoinBalance")
	end
end

function Currency.LinkWalletObjectContextMenu(playerNum, context, items)
	items = ISInventoryPane.getActualItems(items)
	if not items or #items > 1 then
		return
	end
	local item = items[1]
	if not item then
		return
	end
	local itemType = item:getFullType()
	if not Currency.Wallets[itemType] then
		return
	end
	if not item:isInPlayerInventory() then
		return
	end
	local player = getSpecificPlayer(playerNum)
	local username = player:getUsername()
	local modData = item:getModData()

	-- Allow linking unlinked wallets or stale wallets (where linkedTo doesn't match server)
	local account = Balance.getUserAccount(username)
	local isStaleWallet = modData.nshopsb42_linkedTo and (not account or account.linkedTo ~= modData.nshopsb42_linkedTo)
	if modData.nshopsb42_linkedTo and not isStaleWallet then
		return -- Wallet is already linked and not stale
	end

	-- Check if player already has a valid linked wallet in main inventory
	local playerInv = getPlayerInventory(playerNum).backpacks[1].inventory
	for k, v in pairs(Currency.Wallets) do
		local walletItems = playerInv:getItemsFromFullType(k)
		for i = 0, walletItems:size() - 1 do
			local w = walletItems:get(i)
			if w:getModData().nshopsb42_belongsTo == username and w:getModData().nshopsb42_linkedTo then
				-- Check if this wallet is valid (not stale)
				local wAccount = Balance.getUserAccount(username)
				if wAccount and wAccount.linkedTo == w:getModData().nshopsb42_linkedTo then
					return -- Player has a valid linked wallet, don't show Link option
				end
			end
		end
	end

	context:addOption(UIText.Link, worldobjects, Currency.linkWallet, item, player)
end

function Currency.unlinkWallet(worldobjects, wallet)
	local player = getPlayer()
	wallet:getModData().nshopsb42_belongsTo = nil
	wallet:getModData().nshopsb42_linkedTo = nil
	writeLog(
		"Shops",
		"[CLIENT] Unlink: Cleared wallet modData - belongsTo="
			.. tostring(wallet:getModData().nshopsb42_belongsTo)
			.. ", linkedTo="
			.. tostring(wallet:getModData().nshopsb42_linkedTo)
	)
	sendClientCommand(player, "BS", "UnlinkWallet", {
		walletID = wallet:getID(),
	})
	-- Only request ModData in multiplayer - in SP the ModData is already available
	if isMultiplayer() then
		ModData.request("CoinBalance")
	end
end

function Currency.UnlinkWalletObjectContextMenu(playerNum, context, items)
	items = ISInventoryPane.getActualItems(items)
	if not items or #items > 1 then
		return
	end
	local item = items[1]
	if not item then
		return
	end
	local itemType = item:getFullType()
	if not Currency.Wallets[itemType] then
		return
	end
	if not item:isInPlayerInventory() then
		return
	end
	local player = getSpecificPlayer(playerNum)
	local username = player:getUsername()
	local modData = item:getModData()
	if not (modData.nshopsb42_belongsTo == username and modData.nshopsb42_linkedTo) then
		return
	end

	-- Validate wallet modData matches server account to prevent stale wallet operations
	local account = Balance.getUserAccount(username)
	if not account or account.linkedTo ~= modData.nshopsb42_linkedTo then
		return
	end

	context:addOption(UIText.Transfer, worldobjects, Currency.transfer, item, player)

	-- Show "Claim Offline Mailbox" only if player has pending mailbox funds
	if account and account.hasMailbox then
		context:addOption(UIText.ClaimOfflineMailbox, worldobjects, Currency.claimOfflineMailbox, item, player)
	end

	context:addOption(UIText.Unlink, worldobjects, Currency.unlinkWallet, item)
end

function Currency.transfer(worldobjects, wallet, player)
	getTransferUI():show(player)
end

function Currency.claimOfflineMailbox(worldobjects, wallet, player)
	local username = player:getUsername()
	sendClientCommand(player, "BS", "ClaimMailbox", {
		walletID = wallet:getID(),
	})
	writeLog("Shops", string.format("[CLIENT] Claim Offline Mailbox: Requested for %s", username))
	-- Only request ModData in multiplayer - in SP the ModData is already available
	if isMultiplayer() then
		ModData.request("CoinBalance")
	end
end

Events.OnPreFillInventoryObjectContextMenu.Add(Currency.LootCoinsObjectContextMenu)
Events.OnPreFillInventoryObjectContextMenu.Add(Currency.LinkWalletObjectContextMenu)
Events.OnPreFillInventoryObjectContextMenu.Add(Currency.UnlinkWalletObjectContextMenu)
Events.OnPreFillInventoryObjectContextMenu.Add(Currency.CoinsToAccountObjectContextMenu)
