require("TimedActions/ISBaseTimedAction")

SHOPSB42.ShopBuyAction = ISBaseTimedAction:derive("nshopsb42_ShopBuyAction")
local ShopBuyAction = SHOPSB42.ShopBuyAction
local Nfunction = require("nshopsb42/utils/Nfunction")
local Shop = SHOPSB42.Shop
local Balance = SHOPSB42.Balance
local Utilities = require("nshopsb42/utils/Utilities")
local SharedLogger = SHOPSB42.SharedLogger

-- Lazy-load server modules to avoid initialization order issues
local TransactionRegistry
local ShopAudit

local function getTransactionRegistry()
	if not TransactionRegistry then
		TransactionRegistry = require("nshopsb42/core/TransactionRegistry")
	end
	return TransactionRegistry
end

local function getShopAudit()
	if not ShopAudit then
		ShopAudit = require("nshopsb42/audit/ShopAudit")
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

function ShopBuyAction:update() end

function ShopBuyAction:start() end

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
	SharedLogger.logAction("ShopBuyAction", "perform", "time remaining=" .. tostring(self.timer))
	self.character:playSound("CashRegister")
	ISBaseTimedAction.perform(self)
end

function ShopBuyAction:complete()
	SharedLogger.logAction("ShopBuyAction", "complete", "ENTRY - txnId=" .. tostring(self.ticket.txnId))
	-- Server-only execution
	if isMultiplayer() and not isServer() then
		SharedLogger.logAction("ShopBuyAction", "complete", "MP - exiting early")
		return true
	end

	local username = self.character:getUsername()
	local txnId = self.ticket.txnId

	-- Anti-dupe check: reject if already processed
	local TxnRegistry = getTransactionRegistry()
	if TxnRegistry and TxnRegistry.isProcessed(username, txnId) then
		return false
	end

	-- Retrieve shop from world using stored coordinates
	local shop = Utilities.FindShopAtCoords(self.shopCoords.x, self.shopCoords.y, self.shopCoords.z, Shop.spritePrefix)
	if not shop then
		SharedLogger.logAction(
			"ShopBuyAction",
			"complete",
			"ERROR: Shop not found at "
				.. tostring(self.shopCoords.x)
				.. ","
				.. tostring(self.shopCoords.y)
				.. ","
				.. tostring(self.shopCoords.z)
		)
		return false
	end

	-- Server-side proximity validation (enforce purchase-at-kiosk rule)
	local shopSquare = shop:getSquare()
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
				shopId = self.shopName,
				quantity = quantity,
				isSpecialCoin = Shop.Items[itemType].specialCoin or false,
				isBroken = false,
			}
			local finalPrice = Shop.resolvePlayerBuyPrice(self.character, itemType, context)
			if not finalPrice then
				finalPrice = Shop.Items[itemType].price
			end

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
	local account = ModData.get("nshopsb42_CoinBalance")[username]
	if not account then
		return false
	end
	if account.coin < totalCoin or account.specialCoin < totalSpecialCoin then
		return false
	end

	account.coin = account.coin - totalCoin
	account.specialCoin = account.specialCoin - totalSpecialCoin
	ModData.transmit("nshopsb42_CoinBalance")

	-- Spawn purchased items
	local playerInv = self.character:getInventory()

	for _, entry in ipairs(ticket.items) do
		local packItems = entry.items
		if packItems then
			if entry.isVirtualBundle then
				-- Handle virtual bundles - add items directly to inventory without container
				for _, packEntry in ipairs(packItems) do
					local packQuantity = packEntry.quantity or 1
					for i = 1, packQuantity do
						local newItem = instanceItem(packEntry.item)
						if newItem then
							playerInv:AddItem(newItem)
							sendAddItemToContainer(playerInv, newItem)
							Nfunction.buildLogShop(packEntry.item)
						else
							SharedLogger.logAction("ShopBuyAction", "complete", "ERROR: Failed to instantiate item " .. tostring(packEntry.item))
						end
					end
				end
				-- Log bundle purchase
				Nfunction.buildLogShop(entry.type, 1)
			else
				-- Handle compound items (packs) - create container with items inside
				-- Only for items with actual InventorySlots defined
				local quantity = entry.quantity or 1
				for q = 1, quantity do
					-- Create the container item
					local containerItem = instanceItem(entry.type)
					if not containerItem then
						SharedLogger.logAction("ShopBuyAction", "complete", 
							"ERROR: Failed to instantiate container item " .. tostring(entry.type))
						return false
					end
					
					local containerInv = containerItem:getInventory()
					if not containerInv then
						SharedLogger.logAction("ShopBuyAction", "complete", 
							"ERROR: Container item " .. tostring(entry.type) .. " has no inventory (InventorySlots not defined?)")
						return false
					end

					-- Add all pack items into the container
					for _, packEntry in ipairs(packItems) do
						local packQuantity = packEntry.quantity or 1
						for i = 1, packQuantity do
							local newItem = instanceItem(packEntry.item)
							if newItem then
								containerInv:AddItem(newItem)
								Nfunction.buildLogShop(packEntry.item)
							end
						end
					end

					-- Add the populated container to player inventory or drop on ground
					if entry.drop and shopSquare then
						shopSquare:AddTileObject(containerItem)
						containerItem:transmitCompleteItemToClients()
					else
						playerInv:AddItem(containerItem)
						sendAddItemToContainer(playerInv, containerItem)
					end
				end
				Nfunction.buildLogShop(entry.type, quantity)
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
	TxnRegistry = getTransactionRegistry()
	if TxnRegistry then
		TxnRegistry.markProcessed(username, txnId)
	end

	-- Audit log entry (after successful transaction)
	coin, specialCoin = Balance.getUserBalance(username)
	local Audit = getShopAudit()
	if not Audit then
		return true
	end

	Audit.append({
		time = os.time(),
		worldHours = getGameTime():getWorldAgeHours(),
		txnId = txnId,
		type = "BUY",

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
			coin = -ticket.coin,
			specialCoin = -ticket.specialCoin,
		},

		items = ticket.items,
	})

	SharedLogger.logAction("ShopBuyAction", "complete", "SUCCESS - purchase transaction processed")
	return true
end

function ShopBuyAction:new(character, shop, ticket)
	local o = ISBaseTimedAction.new(ShopBuyAction, character)
	-- Store shop coordinates for server-side lookup (avoid storing object references)
	local square = shop:getSquare()
	o.shopCoords = { x = square:getX(), y = square:getY(), z = square:getZ() }
	o.ticket = ticket -- Lua table - serializable
	o._shopActionType = "buy" -- Marker field for UI type checking (avoids class identity issues)
	o.stopOnWalk = true
	o.stopOnRun = true
	o.maxTime = o:getDuration()
	return o
end
