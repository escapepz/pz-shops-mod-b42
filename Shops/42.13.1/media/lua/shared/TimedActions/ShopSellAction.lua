require "TimedActions/ISBaseTimedAction"

ShopSellAction = ISBaseTimedAction:derive("ShopSellAction")
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

function ShopSellAction:isValid()
	return self.sellList and self.sellList.items and #self.sellList.items > 0
end

function ShopSellAction:waitToStart()
	return self.character:shouldBeTurning()
end

function ShopSellAction:update()
end

function ShopSellAction:start()
end

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
	if not isServer() then return true end

	local username = self.character:getUsername()
	local txnId = self.sellList.txnId

	-- Anti-dupe check: reject if already processed
	local TxnRegistry = getTransactionRegistry()
	if TxnRegistry and TxnRegistry.isProcessed(username, txnId) then
		return false
	end

	local inv = self.character:getInventory()
	local total = 0
	local totalSpecial = 0

	-- Process each item in the sell list
	for _, entry in ipairs(self.sellList.items) do
		local item = inv:getItemById(entry.itemID)
		if item then
			-- Recompute sell price authoritatively on server
			local context = {
				shopId = self.shop:getName(),
				quantity = 1,
				isSpecialCoin = entry.specialCoin or false,
				isBroken = false,
			}
			local finalPrice = Shop.resolvePlayerSellPrice(self.character, item, context)
			local itemPrice = finalPrice or entry.price
			if itemPrice ~= nil then
				-- Remove item from inventory
				inv:Remove(item)
				sendRemoveItemFromContainer(inv, item)

				-- Accumulate payment with recomputed price
				if entry.specialCoin then
					totalSpecial = totalSpecial + itemPrice
				else
					total = total + itemPrice
				end

				-- Log sale
				Nfunction.buildLogShop(item:getFullType())
			end
			-- If itemPrice is nil (blacklisted/invalid), simply skip this item
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
		-- Direct ModData manipulation since we're on server
		local account = ModData.get("CoinBalance")[username]
		if not account then return false end

		account.coin = account.coin + total
		account.specialCoin = account.specialCoin + totalSpecial
		ModData.transmit("CoinBalance")
	end

	-- Mark transaction as processed
	local TxnRegistry = getTransactionRegistry()
	if TxnRegistry then
		TxnRegistry.markProcessed(username, txnId)
	end

	-- Audit log entry (after successful transaction)
	local coin, specialCoin = Balance.getUserBalance(username)
	local shopSquare = self.shop:getSquare()

	local Audit = getShopAudit()
	if not Audit then return true end

	Audit.append({
		time = os.time(),
		worldHours = getGameTime():getWorldAgeHours(),
		txnId = txnId,
		type = "SELL",

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
			coin = total,
			specialCoin = totalSpecial
		},

		items = self.sellList.items
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
