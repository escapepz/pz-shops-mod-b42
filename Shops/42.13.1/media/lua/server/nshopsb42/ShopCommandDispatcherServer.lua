-- ShopCommandDispatcherServer.lua
-- Unified server-side command dispatcher for all OnClientCommand handlers
-- Consolidates commands from: ShopCommandHandlerServer, PlayerShopServer, BalanceServer, LogsServer
-- Follows EVENTS_RULE.md: Single listener per event, dispatch to command table

if not isServer() then
	return
end

local SharedLogger = require("nshopsb42/utils/SharedLogger")
local Utilities = require("nshopsb42/utils/Utilities")

local Dispatcher = {}
local Commands = {}

-- =============================================================================
-- SHOP COMMANDS (from ShopCommandHandlerServer)
-- =============================================================================

function Commands.RequestShopData(player, args)
	local username = player and player:getUsername() or "unknown"
	SharedLogger.log("Shops", "[ShopCommandDispatcher:RequestShopData] from " .. username)

	local ShopFinalizeHandler = require("nshopsb42/transactions/ShopFinalizeHandlerServer")
	local success, err = pcall(function()
		ShopFinalizeHandler.sendShopDataToPlayer(player)
	end)

	if not success then
		SharedLogger.log("Shops", "[ShopCommandDispatcher:RequestShopData] ERROR: " .. tostring(err))
	end
end

function Commands.ClearShopSpriteDrag(player, args)
	SharedLogger.log(
		"Shops",
		"[ShopCommandDispatcher:ClearShopSpriteDrag] Clearing sprite drag for " .. player:getUsername()
	)
	Utilities.SendServerCommandTo(player, "nshopsb42", "ClearShopSpriteDrag", {})
end

function Commands.RemoveShop(player, args)
	if not player then
		return
	end
	local username = player:getUsername()

	-- Admin permission check
	if not Utilities.IsPlayerAdmin(player) then
		SharedLogger.log("Shops", "[ShopCommandDispatcher:RemoveShop] DENIED - Non-admin " .. username)
		player:setHaloNote("Admin permission required", 255, 0, 0, 400)
		return
	end

	-- Resolve square safely
	local square = getWorld():getCell():getGridSquare(args.x, args.y, args.z)
	if not square then
		SharedLogger.log(
			"Shops",
			"[ShopCommandDispatcher:RemoveShop] ERROR: Square not found at " .. args.x .. "," .. args.y
		)
		return
	end

	-- Resolve object safely
	local obj = square:getObjects():get(args.index)
	if not obj then
		SharedLogger.log("Shops", "[ShopCommandDispatcher:RemoveShop] ERROR: Object not found at index " .. args.index)
		return
	end

	SharedLogger.log("Shops", "[ShopCommandDispatcher:RemoveShop] REMOVING shop at " .. args.x .. "," .. args.y)

	-- Remove object on server
	square:transmitRemoveItemFromSquare(obj)

	-- Notify player
	player:setHaloNote("Shop removed", 0, 255, 0, 300)
end

-- =============================================================================
-- PLAYERSHOP COMMANDS (from PlayerShopServer)
-- =============================================================================

function Commands.ToggleBusy(player, args)
	Utilities.SendServerCommandToAll("PS", "ToggleBusy", args)
end

function Commands.SyncStatusData(player, args)
	-- Retrieve shop status from PlayerShopServer
	local PlayerShopServer = require("nshopsb42/PlayerShopServer")
	if PlayerShopServer.PlayerShopStatus then
		Utilities.SendServerCommandTo(player, "PS", "SyncStatusData", { PlayerShopServer.PlayerShopStatus })
	end
end

function Commands.ChangeSprite(player, args)
	local sprite = args[1]
	local coords = args[2]

	local square = getCell():getGridSquare(coords.x, coords.y, coords.z)
	if not square then
		return
	end

	local PlayerShop = require("nshopsb42/core/PlayerShop")
	for i = 0, square:getSpecialObjects():size() - 1 do
		local o = square:getSpecialObjects():get(i)
		local spriteStr = o:getSprite():getName()
		if string.find(spriteStr, PlayerShop.spritePrefix) then
			o:setSprite(sprite)
			o:sendObjectChange("sprite")
			return
		end
	end
end

function Commands.SetItemPrice(player, args)
	local itemID = args.itemID
	local price = args.price
	local specialCoin = args.specialCoin

	if not itemID then
		return
	end

	-- Find item in player inventory by ID
	local item = player:getInventory():getItemById(itemID)
	if not item then
		return
	end

	-- Store price on the item itself
	local modData = item:getModData()
	if price == nil then
		modData.price = nil
		modData.specialCoin = nil
	else
		modData.price = price
		modData.specialCoin = specialCoin
	end

	-- Sync item ModData to all clients
	syncItemModData(player, item)
end

function Commands.RemoveItemFromInventory(player, args)
	local itemID = args.itemID
	if not itemID then
		return
	end

	local item = player:getInventory():getItemById(itemID)
	if item then
		local container = item:getContainer()
		container:Remove(item)
		sendRemoveItemFromContainer(container, item)
		SharedLogger.log(
			"Shops",
			"[ShopCommandDispatcher:RemoveItemFromInventory] Item removed - ID: " .. tostring(itemID)
		)
	end
end

function Commands.PickupShop(player, args)
	local coords = args[1]
	local square = getCell():getGridSquare(coords.x, coords.y, coords.z)
	if not square then
		return
	end

	local PlayerShop = require("nshopsb42/core/PlayerShop")
	local shop = nil
	for i = 0, square:getSpecialObjects():size() - 1 do
		local o = square:getSpecialObjects():get(i)
		local spriteStr = o:getSprite():getName()
		if string.find(spriteStr, PlayerShop.spritePrefix) then
			shop = o
			break
		end
	end

	if not shop then
		return
	end

	-- Check if shop is empty
	local items = shop:getContainer():getItems()
	if items and items:size() > 0 then
		return
	end

	local income = shop:getModData().income
	if income and #income > 0 then
		return
	end

	-- Get item type
	local itemType = "Shops.PlayerShop"
	if shop:getContainer():getType() == "freezer" then
		itemType = "Shops.PlayerShopFreezer"
	end

	-- Remove shop from world
	shop:getSquare():transmitRemoveItemFromSquare(shop)

	-- Add item to player inventory
	local newItem = instanceItem(itemType)
	player:getInventory():AddItem(newItem)
	sendAddItemToContainer(player:getInventory(), newItem)
end

-- =============================================================================
-- BALANCE COMMANDS (from BalanceServer)
-- =============================================================================

function Commands.CreateAccount(player, args)
	if not player or not args then
		return
	end

	local username = player:getUsername()
	local linkedTo = args.linkedTo
	local walletID = args.walletID
	local account = ModData.get("CoinBalance")[username]

	if account then
		account.linkedTo = linkedTo
		SharedLogger.log("Shops", "[ShopCommandDispatcher:CreateAccount] Linked wallet for " .. username)
	else
		ModData.get("CoinBalance")[username] = { coin = 0, specialCoin = 0, linkedTo = linkedTo }
		SharedLogger.log("Shops", "[ShopCommandDispatcher:CreateAccount] Created account for " .. username)
	end

	-- Sync wallet modData if ID provided
	if walletID then
		local wallet = player:getInventory():getItemById(walletID)
		if wallet then
			if wallet:getContainer() ~= player:getInventory() then
				SharedLogger.log("Shops", "[ShopCommandDispatcher:CreateAccount] REJECTED - wallet not in inventory")
				return
			end

			local walletModData = wallet:getModData()
			walletModData.belongsTo = username
			walletModData.linkedTo = linkedTo
			syncItemModData(player, wallet)
		end
	end

	ModData.transmit("CoinBalance")
end

function Commands.VirtualDeposit(player, args)
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
		SharedLogger.log("Shops", "[ShopCommandDispatcher:VirtualDeposit] No account for " .. username)
		return
	end

	-- Validate wallet is linked
	if not account.linkedTo then
		SharedLogger.log("Shops", "[ShopCommandDispatcher:VirtualDeposit] No wallet linked for " .. username)
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

	account.coin = account.coin + coin
	account.specialCoin = account.specialCoin + specialCoin

	SharedLogger.log(
		"Shops",
		"[ShopCommandDispatcher:VirtualDeposit] " .. username .. " +" .. coin .. "/" .. specialCoin
	)

	ModData.transmit("CoinBalance")
end

function Commands.Deposit(player, args)
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

	-- CRITICAL: itemIDs must be provided
	if not itemIDs or type(itemIDs) ~= "table" or #itemIDs == 0 then
		SharedLogger.log("Shops", "[ShopCommandDispatcher:Deposit] REJECTED - no itemIDs - " .. username)
		return
	end

	-- Verify all items exist in inventory before deducting balance
	local itemsToRemove = {}
	for i, itemID in ipairs(itemIDs) do
		local item = player:getInventory():getItemById(itemID)
		if not item then
			SharedLogger.log("Shops", "[ShopCommandDispatcher:Deposit] REJECTED - item not found - " .. username)
			return
		end
		table.insert(itemsToRemove, item)
	end

	-- Perform atomic mutation
	account.coin = account.coin + coin
	account.specialCoin = account.specialCoin + specialCoin

	SharedLogger.log("Shops", "[ShopCommandDispatcher:Deposit] " .. username .. " +" .. coin .. "/" .. specialCoin)

	-- Remove coin items from player inventory
	for i, item in ipairs(itemsToRemove) do
		local container = item:getContainer()
		container:Remove(item)
		sendRemoveItemFromContainer(container, item)
	end

	ModData.transmit("CoinBalance")
end

function Commands.Transfer(player, args)
	-- Delegate to BalanceServer for complex transfer logic
	local BalanceServer = require("nshopsb42/balance/BalanceServer")
	if BalanceServer.Transfer then
		BalanceServer.Transfer(player, args)
	end
end

function Commands.Withdraw(player, args)
	if not player or not args then
		return
	end

	local username = player:getUsername()
	local coin = tonumber(args.coin) or 0
	local specialCoin = tonumber(args.specialCoin) or 0
	local itemID = args.itemID

	local account = ModData.get("CoinBalance")[username]
	if not account then
		return
	end

	-- Validate amounts are non-negative
	if coin < 0 or specialCoin < 0 then
		return
	end

	-- Check sufficient balance
	if account.coin < coin or account.specialCoin < specialCoin then
		return
	end

	-- Perform atomic mutation
	account.coin = account.coin - coin
	account.specialCoin = account.specialCoin - specialCoin

	SharedLogger.log("Shops", "[ShopCommandDispatcher:Withdraw] " .. username .. " -" .. coin .. "/" .. specialCoin)

	ModData.transmit("CoinBalance")
end

function Commands.UnlinkWallet(player, args)
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

	SharedLogger.log("Shops", "[ShopCommandDispatcher:UnlinkWallet] Unlinked " .. username)

	-- Sync wallet modData if ID provided
	if walletID then
		local wallet = player:getInventory():getItemById(walletID)
		if wallet then
			local walletModData = wallet:getModData()
			walletModData.belongsTo = nil
			walletModData.linkedTo = nil
			syncItemModData(player, wallet)
		end
	end

	ModData.transmit("CoinBalance")
end

function Commands.ClaimMailbox(player, args)
	if not player or not args then
		return
	end

	local username = player:getUsername()
	SharedLogger.log("Shops", "[ShopCommandDispatcher:ClaimMailbox] Claimed by " .. username)

	-- Delegate to BalanceServer for mailbox delivery
	local BalanceServer = require("nshopsb42/balance/BalanceServer")
	if BalanceServer.ClaimMailbox then
		BalanceServer.ClaimMailbox(player, args)
	end
end

function Commands.Rollback(player, args)
	if not player or not args then
		return
	end

	-- Delegate to BalanceServer for rollback logic
	local BalanceServer = require("nshopsb42/balance/BalanceServer")
	if BalanceServer.Rollback then
		BalanceServer.Rollback(player, args)
	end
end

-- =============================================================================
-- LOGGING COMMANDS (from LogsServer)
-- =============================================================================

function Commands.TransactionShopLog(player, args)
	local msg = args[1]
	SharedLogger.log("Shops", "[ShopCommandDispatcher:TransactionShopLog] " .. msg)
end

-- =============================================================================
-- DISPATCHER FUNCTION
-- =============================================================================

function Dispatcher.onClientCommand(module, command, player, args)
	if module ~= "nshopsb42" and module ~= "PS" and module ~= "BS" and module ~= "LS" and module ~= "shops" then
		return
	end

	-- Normalize module names to match command table
	if module == "PS" then
		command = "PS_" .. command
	elseif module == "BS" then
		command = "BS_" .. command
	elseif module == "LS" then
		command = "LS_" .. command
	elseif module == "shops" then
		-- Legacy: shops module maps to BS commands
		command = "BS_" .. command
	end

	local SharedLogger = require("nshopsb42/utils/SharedLogger")
	SharedLogger.log(
		"Shops",
		"[ShopCommandDispatcher] OnClientCommand - module="
			.. module
			.. " command="
			.. command
			.. " player="
			.. (player:getUsername() or "unknown")
	)

	local handler = Commands[command]
	if handler then
		handler(player, args)
	else
		SharedLogger.log("Shops", "[ShopCommandDispatcher] UNKNOWN command: " .. command)
	end
end

-- =============================================================================
-- IDEMPOTENT REGISTRATION
-- =============================================================================

if not Dispatcher._registered then
	Dispatcher._registered = true
	Events.OnClientCommand.Add(Dispatcher.onClientCommand)
	SharedLogger.log("Shops", "[ShopCommandDispatcher] Registered single OnClientCommand listener")
end

return Dispatcher
