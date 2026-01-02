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
	local shop =
		Utilities.FindShopAtCoords(self.shopCoords.x, self.shopCoords.y, self.shopCoords.z, PlayerShop.spritePrefix)
	if not shop then
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
	local shopSquare = shop:getSquare()
	local distance = self.character:DistTo(shopSquare:getX(), shopSquare:getY())
	if distance > 2 then
		return false
	end

	-- Retrieve shop modData
	local shopModData = shop:getModData()
	if not shopModData then
		return false
	end

	-- Step 2: Re-validate balance (defensive check)
	local coin, specialCoin = Balance.getUserBalance(username)
	if coin < ticket.coin or specialCoin < ticket.specialCoin then
		return false
	end

	-- Step 3: Re-locate shop from world (do not trust cached references)
	local shopContainer = shop:getContainer()
	if not shopContainer then
		return false
	end

	-- Step 4: Iterate cart items and transfer
	local playerInv = self.character:getInventory()
	local shopModData = shop:getModData()
	local income = shopModData.income or {}
	local totalCoin = 0
	local totalSpecial = 0

	for _, cartEntry in ipairs(ticket.items or {}) do
		local itemID = cartEntry.itemID
		local invItem = shopContainer:getItemById(itemID)

		-- Validate item still exists in shop
		if invItem then
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

			-- Track totals
			if cartEntry.specialCoin then
				totalSpecial = totalSpecial + cartEntry.price
			else
				totalCoin = totalCoin + cartEntry.price
			end

			-- Log item
			Nfunction.buildLogShop(invItem:getFullType())
		end
	end

	-- Step 5: Withdraw currency (server-initiated)
	if totalCoin > 0 or totalSpecial > 0 then
		sendClientCommand(self.character, "BS", "Withdraw", {
			coin = totalCoin,
			specialCoin = totalSpecial,
		})

		-- Record income
		local data = {
			b = username,
			t = { tl = totalCoin, tls = totalSpecial },
		}
		table.insert(income, data)
		shopModData.income = income
	end

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

function PlayerShopBuyAction:new(character, shop, ticket)
	local o = ISBaseTimedAction.new(PlayerShopBuyAction, character)
	-- Store shop coordinates for server-side lookup (avoid storing object references)
	local square = shop:getSquare()
	o.shopCoords = { x = square:getX(), y = square:getY(), z = square:getZ() }
	o.ticket = ticket -- Lua table - serializable
	o._shopActionType = "playerBuy" -- Marker field for UI type checking (avoids class identity issues)
	o.stopOnWalk = true
	o.stopOnRun = true
	o.maxTime = o:getDuration()
	return o
end
