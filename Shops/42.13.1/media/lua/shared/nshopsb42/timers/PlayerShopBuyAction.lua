require("TimedActions/ISBaseTimedAction")
local Nfunction = require("nshopsb42/utils/Nfunction")
local Balance = SHOPSB42.Balance

SHOPSB42.PlayerShopBuyAction = ISBaseTimedAction:derive("nshopsb42_PlayerShopBuyAction")
local PlayerShopBuyAction = SHOPSB42.PlayerShopBuyAction

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
	local context = isClient() and "CLIENT" or (isServer() and "SERVER" or "SP")
	writeLog("Shops", "[PlayerShopBuyAction:perform] [" .. context .. "] time remaining=" .. tostring(self.timer))
	self.character:playSound("CashRegister")
	ISBaseTimedAction.perform(self)
end

function PlayerShopBuyAction:complete()
	local context = isClient() and "CLIENT" or (isServer() and "SERVER" or "SP")
	writeLog("Shops", "[PlayerShopBuyAction:complete] [" .. context .. "] ENTRY")
	-- Server-only: execute authoritative transaction
	if isMultiplayer() and not isServer() then
		writeLog("Shops", "[PlayerShopBuyAction:complete] [CLIENT] MP - exiting early")
		return true
	end

	local username = self.character:getUsername()
	local ticket = self.ticket

	-- Retrieve shop from registry using serialized shop name
	local shop = SHOPSB42.ShopRegistry:getShop(self.shopName)
	if not shop then
		writeLog("Shops", "[PlayerShopBuyAction:complete] [SERVER] ERROR: Shop not found: " .. tostring(self.shopName))
		return false
	end

	-- Step 1: Server-side proximity validation (enforce purchase-at-shop rule)
	local shopSquare = shop:getSquare()
	local distance = self.character:DistTo(shopSquare:getX(), shopSquare:getY())
	if distance > 2 then
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
	if isClient() then
		Nfunction.logShop({
			x = shopSquare:getX(),
			y = shopSquare:getY(),
			z = shopSquare:getZ(),
		}, "Purchase")
	end

	writeLog("Shops", "[PlayerShopBuyAction:complete] [SERVER] SUCCESS - transaction complete, items transferred")
	return true
end

function PlayerShopBuyAction:new(character, shopName, ticket)
	local o = ISBaseTimedAction.new(PlayerShopBuyAction, character)
	o.shopName = shopName -- String - serializable
	o.ticket = ticket -- Lua table - serializable
	o.stopOnWalk = true
	o.stopOnRun = true
	o.maxTime = o:getDuration()
	return o
end
