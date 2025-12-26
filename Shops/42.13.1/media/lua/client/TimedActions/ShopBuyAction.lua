require "TimedActions/ISBaseTimedAction"

ShopBuyAction = ISBaseTimedAction:derive("ShopBuyAction")
local Nfunction = require "Nfunction"
local TransactionRegistry = require "TransactionRegistry"
local ShopAudit = require "ShopAudit"

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
	if TransactionRegistry.isProcessed(username, txnId) then
		return false
	end

	-- Re-validate balance (authoritative server-side check)
	local coin, specialCoin = Balance.getUserBalance(username)
	local ticket = self.ticket
	if coin < ticket.coin or specialCoin < ticket.specialCoin then
		return false
	end

	-- Withdraw balance from virtual wallet
	if not Balance.withdraw(username, ticket.coin, ticket.specialCoin) then
		return false
	end

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
						if isClient() then
						Nfunction.buildLogShop(packEntry.item)
						end
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
			if isClient() then
				Nfunction.buildLogShop(entry.type, quantity)
			end
		end
	end

	-- Log transaction (client-side only: Nfunction.logShop uses getPlayer())
	local coords = {
		x = shopSquare:getX(),
		y = shopSquare:getY(),
		z = shopSquare:getZ(),
	}
	if isClient() then
		Nfunction.logShop(coords)
	end

	-- Mark transaction as processed
	TransactionRegistry.markProcessed(username, txnId)

	-- Audit log entry (after successful transaction)
	local coin, specialCoin = Balance.getUserBalance(username)
	ShopAudit.append({
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
