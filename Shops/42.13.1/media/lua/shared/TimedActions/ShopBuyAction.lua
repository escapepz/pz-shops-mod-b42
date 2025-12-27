require "TimedActions/ISBaseTimedAction"

ShopBuyAction = ISBaseTimedAction:derive("ShopBuyAction")
local Nfunction = require "Nfunction"

-- Lazy-load server modules to avoid initialization order issues
local TransactionRegistry
local ShopAudit

local function getTransactionRegistry()
	if not TransactionRegistry then
		TransactionRegistry = require "TransactionRegistry"
	end
	return TransactionRegistry
end

local function getShopAudit()
	if not ShopAudit then
		ShopAudit = require "ShopAudit"
	end
	return ShopAudit
end

function ShopBuyAction:isValid()
	local username = self.character:getUsername()
	local coin, specialCoin = Balance.getUserBalance(username)
	local ticket = self.ticket
	return coin >= ticket.coin and specialCoin >= ticket.specialCoin
end

function ShopBuyAction:waitToStart()
	return self.character:shouldBeTurning()
end

function ShopBuyAction:update()
end

function ShopBuyAction:start()
end

function ShopBuyAction:stop()
	ISBaseTimedAction.stop(self)
end

function ShopBuyAction:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 50
end

function ShopBuyAction:perform()
	self.character:playSound("CashRegister")
	ISBaseTimedAction.perform(self)
end

function ShopBuyAction:complete()
	-- Server-only execution
	if not isServer() then return true end

	local username = self.character:getUsername()
	local txnId = self.ticket.txnId

	-- Anti-dupe check: reject if already processed
	local TxnRegistry = getTransactionRegistry()
	if TxnRegistry and TxnRegistry.isProcessed(username, txnId) then
		return false
	end

	-- Server-side proximity validation (enforce purchase-at-kiosk rule)
	local shopSquare = self.shop:getSquare()
	local distance = self.character:DistTo(shopSquare:getX(), shopSquare:getY())
	if distance > 2 then
		return false
	end

	-- Recompute prices authoritatively on server
	local totalCoin = 0
	local totalSpecialCoin = 0
	local ticket = self.ticket
	
	-- First pass: validate and compute final prices
	for _, entry in ipairs(ticket.items) do
		local itemType = entry.type
		local quantity = entry.quantity or 1
		if itemType and Shop.Items[itemType] then
			local context = {
				shopId = self.shop:getName(),
				quantity = quantity,
				isSpecialCoin = Shop.Items[itemType].specialCoin or false,
				isBroken = false,
			}
			local finalPrice = Shop.resolvePlayerBuyPrice(self.character, itemType, context)
			if not finalPrice then finalPrice = Shop.Items[itemType].price end
			
			if Shop.Items[itemType].specialCoin then
				totalSpecialCoin = totalSpecialCoin + (finalPrice * quantity)
			else
				totalCoin = totalCoin + (finalPrice * quantity)
			end
		end
	end

	-- Re-validate balance with authoritative server-computed prices
	local coin, specialCoin = Balance.getUserBalance(username)
	if coin < totalCoin or specialCoin < totalSpecialCoin then
		return false
	end

	-- Withdraw balance from virtual wallet
	-- Direct ModData manipulation since we're on server
	local account = ModData.get("CoinBalance")[username]
	if not account then return false end
	if account.coin < totalCoin or account.specialCoin < totalSpecialCoin then return false end

	account.coin = account.coin - totalCoin
	account.specialCoin = account.specialCoin - totalSpecialCoin
	ModData.transmit("CoinBalance")

	-- Spawn purchased items
	local playerInv = self.character:getInventory()
	local shopSquare = self.shop:getSquare()

	for _, entry in ipairs(ticket.items) do
		local packItems = entry.items
		if packItems then
			-- Handle compound items (packs)
			local drop = entry.drop
			local square = drop and shopSquare or nil
			local container = drop and nil or playerInv

			for _, packEntry in ipairs(packItems) do
				local quantity = packEntry.quantity or 1
				for i = 1, quantity do
					local newItem = instanceItem(packEntry.item)
					if drop then
						square:AddTileObject(newItem)
						newItem:transmitCompleteItemToClients()
					else
						container:AddItem(newItem)
						sendAddItemToContainer(container, newItem)
					end
					Nfunction.buildLogShop(packEntry.item)
				end
			end
		else
			-- Handle simple items
			local quantity = entry.quantity or 1
			for i = 1, quantity do
				local newItem = instanceItem(entry.type)
				playerInv:AddItem(newItem)
				sendAddItemToContainer(playerInv, newItem)
			end
			Nfunction.buildLogShop(entry.type, quantity)
		end
	end

	-- Note: Nfunction.logShop() is client-side only, skipping on server
	-- Audit logging is handled by ShopAudit.append() below

	-- Mark transaction as processed
	local TxnRegistry = getTransactionRegistry()
	if TxnRegistry then
		TxnRegistry.markProcessed(username, txnId)
	end

	-- Audit log entry (after successful transaction)
	local coin, specialCoin = Balance.getUserBalance(username)
	local Audit = getShopAudit()
	if not Audit then return true end

	Audit.append({
		time = os.time(),
		worldHours = getGameTime():getWorldAgeHours(),
		txnId = txnId,
		type = "BUY",

		player = {
			username = username,
			steamID = self.character:getSteamID()
		},

		shop = {
			x = shopSquare:getX(),
			y = shopSquare:getY(),
			z = shopSquare:getZ()
		},

		balance = {
			coin = coin,
			specialCoin = specialCoin
		},

		delta = {
			coin = -ticket.coin,
			specialCoin = -ticket.specialCoin
		},

		items = ticket.items
	})

	return true
end

function ShopBuyAction:new(character, shop, ticket)
	local o = ISBaseTimedAction.new(self, character)
	o.shop = shop
	o.ticket = ticket
	o.stopOnWalk = true
	o.stopOnRun = true
	o.maxTime = o:getDuration()
	return o
end
