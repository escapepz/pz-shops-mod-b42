require("TimedActions/ISBaseTimedAction")
local Nfunction = require("nshopsb42/utils/Nfunction")
local Balance = SHOPSB42.Balance
local Utilities = require("nshopsb42/utils/Utilities")
local PlayerShop = require("nshopsb42/core/PlayerShop")
local SharedLogger = SHOPSB42.SharedLogger

PlayerShopBuyAction = ISBaseTimedAction:derive("PlayerShopBuyAction")
SHOPSB42.PlayerShopBuyAction = PlayerShopBuyAction

function PlayerShopBuyAction:isValid()
	local username = self.character:getUsername()
	local coin, specialCoin = Balance.getUserBalance(username)
	local ticket = self.ticket
	if not ticket then
		return false
	end
	return coin >= ticket.coin and specialCoin >= ticket.specialCoin
end

function PlayerShopBuyAction:waitToStart()
	return self.character:shouldBeTurning()
end

function PlayerShopBuyAction:update()
	-- no-op for MP safety
end

function PlayerShopBuyAction:start() end

function PlayerShopBuyAction:stop()
	ISBaseTimedAction.stop(self)
end

function PlayerShopBuyAction:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 50
end

function PlayerShopBuyAction:perform()
	SharedLogger.logAction("PlayerShopBuyAction", "perform", "time remaining=" .. tostring(self.timer))
	self.character:playSound("CashRegister")
	ISBaseTimedAction.perform(self)
end

function PlayerShopBuyAction:complete()
	SharedLogger.logAction("PlayerShopBuyAction", "complete", "ENTRY")
	-- Server-only: execute authoritative transaction
	if not Utilities.IsServerOrSinglePlayer() then
		SharedLogger.logAction("PlayerShopBuyAction", "complete", "MP - exiting early")
		return true
	end

	local username = self.character:getUsername()
	local ticket = self.ticket

	-- Retrieve shop from world using stored coordinates
	SharedLogger.logAction(
		"PlayerShopBuyAction",
		"complete",
		"Looking for shop at coords: "
			.. tostring(self.shopCoords.x)
			.. ","
			.. tostring(self.shopCoords.y)
			.. ","
			.. tostring(self.shopCoords.z)
	)
	local square = getCell():getGridSquare(self.shopCoords.x, self.shopCoords.y, self.shopCoords.z)
	if not square then
		SharedLogger.logAction("PlayerShopBuyAction", "complete", "ERROR: Grid square not found at coordinates")
		return false
	end

	-- Retrieve player shop from world using stored coordinates
	self.shop =
		Utilities.FindShopAtCoords(self.shopCoords.x, self.shopCoords.y, self.shopCoords.z, PlayerShop.spritePrefix)
	if not self.shop then
		SharedLogger.logAction(
			"PlayerShopBuyAction",
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

	-- Step 1: Server-side proximity validation (enforce purchase-at-shop rule)
	local shopSquare = self.shop:getSquare()
	local distance = self.character:DistTo(shopSquare:getX(), shopSquare:getY())
	if distance > 2 then
		return false
	end

	-- Retrieve shop modData
	local shopModData = self.shop:getModData()
	if not shopModData then
		return false
	end

	-- Step 2: Re-validate balance (defensive check)
	local coin, specialCoin = Balance.getUserBalance(username)
	if not ticket or coin < ticket.coin or specialCoin < ticket.specialCoin then
		return false
	end

	-- Step 3: Re-locate shop from world (do not trust cached references)
	local shopContainer = self.shop:getContainer()
	if not shopContainer then
		return false
	end

	-- Step 4a: PHASE 1 - Validate all items and calculate totals BEFORE any transfers
	local playerInv = self.character:getInventory()
	shopModData = self.shop:getModData()
	local income = shopModData.income or {}
	local totalCoin = 0
	local totalSpecial = 0
	local itemsToTransfer = {}

	-- Pre-validate: Check all items exist and prices are valid
	for _, cartEntry in ipairs(ticket.items or {}) do
		local itemID = cartEntry.itemID
		local invItem = shopContainer:getItemById(itemID)

		if invItem then
			-- Calculate correct currency totals
			if cartEntry.specialCoin then
				totalSpecial = totalSpecial + cartEntry.price
			else
				totalCoin = totalCoin + cartEntry.price
			end

			-- Store item for later transfer (after balance deduction)
			table.insert(itemsToTransfer, { item = invItem, entry = cartEntry })
		end
	end

	-- Step 4b: PHASE 2 - Deduct balance BEFORE transferring items (atomic server-side operation)
	if totalCoin > 0 or totalSpecial > 0 then
		-- Server-side balance check and deduction (atomic)
		local account = ModData.get("CoinBalance")[username]
		if not account then
			SharedLogger.logAction("PlayerShopBuyAction", "complete", "ERROR: Account not found for " .. username)
			return false
		end

		-- Verify balance exists
		if account.coin < totalCoin or account.specialCoin < totalSpecial then
			SharedLogger.logAction(
				"PlayerShopBuyAction",
				"complete",
				"REJECTED - insufficient balance. Have: "
					.. account.coin
					.. "/"
					.. account.specialCoin
					.. " Need: "
					.. totalCoin
					.. "/"
					.. totalSpecial
			)
			return false
		end

		-- DEDUCT BALANCE FIRST (atomic, server-side)
		account.coin = account.coin - totalCoin
		account.specialCoin = account.specialCoin - totalSpecial
		ModData.transmit("CoinBalance")

		SharedLogger.logAction(
			"PlayerShopBuyAction",
			"complete",
			"Balance deducted: -"
				.. totalCoin
				.. "/"
				.. totalSpecial
				.. " (new: "
				.. account.coin
				.. "/"
				.. account.specialCoin
				.. ")"
		)

		-- Record income in shop (after balance deduction confirmed)
		local data = {
			b = username,
			t = { tl = totalCoin, tls = totalSpecial },
		}
		table.insert(income, data)
		shopModData.income = income
	end

	-- Step 4c: PHASE 3 - Transfer items ONLY after balance deducted successfully
	for _, transferData in ipairs(itemsToTransfer) do
		local invItem = transferData.item
		local cartEntry = transferData.entry

		-- Remove from shop container
		shopContainer:Remove(invItem)
		sendRemoveItemFromContainer(shopContainer, invItem)

		-- Add to player inventory
		playerInv:AddItem(invItem)
		sendAddItemToContainer(playerInv, invItem)

		-- Clear shop-specific ModData
		local modData = invItem:getModData()
		modData.price = nil
		modData.specialCoin = nil
		syncItemModData(self.character, invItem)

		-- Log item
		Nfunction.buildLogShop(invItem:getFullType())
	end

	-- Step 5: (deprecated - balance now deducted at PHASE 2)
	-- Keeping note: Old code used speculative sendClientCommand - now atomic server-side

	-- Step 6: Sync shop state
	self.shop:transmitModData()

	-- Step 7: Log transaction (client-side only: Nfunction.logShop uses getPlayer())
	-- dead code
	-- if isClient() then
	-- 	Nfunction.logShop({
	-- 		x = shopSquare:getX(),
	-- 		y = shopSquare:getY(),
	-- 		z = shopSquare:getZ(),
	-- 	}, "Purchase")
	-- end

	SharedLogger.logAction("PlayerShopBuyAction", "complete", "SUCCESS - transaction complete, items transferred")
	return true
end

function PlayerShopBuyAction:new(character, shopCoords, ticket)
	local o = ISBaseTimedAction.new(PlayerShopBuyAction, character)
	-- Store shop coordinates for server-side lookup (always passed as table {x, y, z})
	o.shopCoords = shopCoords or { x = 0, y = 0, z = 0 }
	o.ticket = ticket -- Lua table - serializable
	o._shopActionType = "playerBuy" -- Marker field for UI type checking (avoids class identity issues)
	o.stopOnWalk = true
	o.stopOnRun = true
	o.maxTime = o:getDuration()
	return o
end
