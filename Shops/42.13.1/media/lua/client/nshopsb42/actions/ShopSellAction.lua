require("TimedActions/ISBaseTimedAction")

ShopSellAction = ISBaseTimedAction:derive("ShopSellAction")
local Nfunction = require("nshopsb42/utils/Nfunction")
local TransactionRegistry = require("nshopsb42/core/TransactionRegistry")
local ShopAudit = require("nshopsb42/audit/ShopAudit")

function ShopSellAction:isValid()
	return self.sellList and self.sellList.items and #self.sellList.items > 0
end

function ShopSellAction:waitToStart()
	return self.character:shouldBeTurning()
end

function ShopSellAction:update() end

function ShopSellAction:start() end

function ShopSellAction:stop()
	ISBaseTimedAction.stop(self)
end

function ShopSellAction:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 50
end

function ShopSellAction:perform()
	if self.total and (self.total > 0 or self.totalSpecial > 0) then
		self.character:playSound("CashRegister")
	end
	ISBaseTimedAction.perform(self)
end

function ShopSellAction:complete()
	-- Server-only execution
	if not isServer() then
		return true
	end

	local username = self.character:getUsername()
	local txnId = self.sellList.txnId

	-- Anti-dupe check: reject if already processed
	if TransactionRegistry.isProcessed(username, txnId) then
		return false
	end

	local inv = self.character:getInventory()
	local total = 0
	local totalSpecial = 0

	-- Process each item in the sell list
	for _, entry in ipairs(self.sellList.items) do
		local item = inv:getItemById(entry.itemID)
		if item then
			-- Remove item from inventory
			inv:Remove(item)
			sendRemoveItemFromContainer(inv, item)

			-- Accumulate payment
			if entry.specialCoin then
				totalSpecial = totalSpecial + entry.price
			else
				total = total + entry.price
			end

			-- Log sale (client-side only: Nfunction.buildLogShop populates shopItems table)
			if isClient() then
				Nfunction.buildLogShop(item:getFullType())
			end
		end
	end

	-- Log transaction (client-side only: Nfunction.logShop uses getPlayer())
	if total > 0 or totalSpecial > 0 then
		local shopSquare = self.shop:getSquare()
		local coords = {
			x = shopSquare:getX(),
			y = shopSquare:getY(),
			z = shopSquare:getZ(),
		}
		if isClient() then
			Nfunction.logShop(coords, "Sell")
		end
	end

	-- Deposit virtual balance (no coin items created)
	if total > 0 or totalSpecial > 0 then
		SHOPSB42.Balance.deposit(username, total, totalSpecial)
	end

	-- Mark transaction as processed
	TransactionRegistry.markProcessed(username, txnId)

	-- Audit log entry (after successful transaction)
	local coin, specialCoin = SHOPSB42.Balance.getUserBalance(username)
	local shopSquare = self.shop:getSquare()

	ShopAudit.append({
		time = os.time(),
		worldHours = getGameTime():getWorldAgeHours(),
		txnId = txnId,
		type = "SELL",

		player = {
			username = username,
			steamID = self.character:getSteamID(),
		},

		shop = {
			x = shopSquare:getX(),
			y = shopSquare:getY(),
			z = shopSquare:getZ(),
		},

		balance = {
			coin = coin,
			specialCoin = specialCoin,
		},

		delta = {
			coin = total,
			specialCoin = totalSpecial,
		},

		items = self.sellList.items,
	})

	return true
end

function ShopSellAction:new(character, shop, sellList)
	local o = ISBaseTimedAction.new(self, character)
	o.shop = shop
	o.sellList = sellList
	o.stopOnWalk = true
	o.stopOnRun = true
	o.maxTime = o:getDuration()
	return o
end
