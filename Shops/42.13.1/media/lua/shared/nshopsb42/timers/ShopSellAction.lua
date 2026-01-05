require("TimedActions/ISBaseTimedAction")

-- SECURITY INVARIANT:
-- Server must never consume client-provided prices under any circumstance.
-- All pricing calculations are recomputed server-side; client price values are ignored.

ShopSellAction = ISBaseTimedAction:derive("ShopSellAction")
SHOPSB42.ShopSellAction = ShopSellAction
local Nfunction = require("nshopsb42/utils/Nfunction")
local Shop = SHOPSB42.Shop
local Balance = SHOPSB42.Balance
local Utilities = require("nshopsb42/utils/Utilities")
local SharedLogger = SHOPSB42.SharedLogger
local LazyMigration

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

local function getLazyMigration()
	if not LazyMigration then
		LazyMigration = require("nshopsb42/schema/LazyMigration")
	end
	return LazyMigration
end

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
	SharedLogger.logAction("ShopSellAction", "perform", "time remaining=" .. tostring(self.timer))
	---@diagnostic disable-next-line: unnecessary-if
	if self.total and (self.total > 0 or self.totalSpecial > 0) then
		self.character:playSound("CashRegister")
	end
	ISBaseTimedAction.perform(self)
end

function ShopSellAction:complete()
	SharedLogger.logAction("ShopSellAction", "complete", "ENTRY - txnId=" .. tostring(self.sellList.txnId))
	-- Server-only execution
	if not Utilities.IsServerOrSinglePlayer() then
		SharedLogger.logAction("ShopSellAction", "complete", "MP - exiting early")
		return true
	end

	local username = self.character:getUsername()
	local txnId = self.sellList.txnId

	-- Anti-dupe check: reject if already processed
	local TxnRegistry = getTransactionRegistry()
	if TxnRegistry and TxnRegistry.isProcessed(username, txnId) then
		return false
	end

	-- Retrieve shop from world using stored coordinates
	self.shop = Utilities.FindShopAtCoords(self.shopCoords.x, self.shopCoords.y, self.shopCoords.z, Shop.spritePrefix)
	if not self.shop then
		SharedLogger.logAction(
			"ShopSellAction",
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

	-- Server-side proximity validation (enforce sale-at-kiosk rule)
	local shopSquare = self.shop:getSquare()
	local distance = self.character:DistTo(shopSquare:getX(), shopSquare:getY())
	if distance > 2 then
		return false
	end

	local inv = self.character:getInventory()
	local total = 0
	local totalSpecial = 0

	-- Validate account exists before processing items (fail early to prevent item loss)
	local coinBalance = ModData.get("CoinBalance")
	local account = coinBalance[username]
	if not account then
		SharedLogger.logAction("ShopSellAction", "complete", "REJECTED - no account found for user: " .. username)
		return false
	end

	-- Process each item in the sell list
	for _, entry in ipairs(self.sellList.items) do
		local item = inv:getItemById(entry.itemID)
		if item then
			-- Migrate item from old schema if needed (removes deprecated fields)
			getLazyMigration().migrateItemIfNeeded(item)

			-- Recompute sell price authoritatively on server
			local itemType = item:getFullType()
			local isSpecialCoin = (
				Shop.PlayerSell
				and Shop.PlayerSell[itemType]
				and Shop.PlayerSell[itemType].specialCoin
			) or false

			local context = {
				shopId = self.shopName,
				quantity = 1,
				isSpecialCoin = isSpecialCoin,
				isBroken = false,
			}
			local finalPrice = Shop.resolvePlayerSellPrice(self.character, item, context)

			-- SECURITY INVARIANT: Server must never consume client-provided prices under any circumstance
			local itemPrice = nil
			if finalPrice ~= nil then
				-- Server successfully calculated price - use it
				itemPrice = finalPrice
			else
				-- Server calculation failed - fallback to base price ONLY (server-authoritative)
				local itemDef = Shop.PlayerSell and Shop.PlayerSell[itemType]
				---@diagnostic disable-next-line: unnecessary-if
				if itemDef and itemDef.basePrice then
					itemPrice = itemDef.basePrice
					SharedLogger.logAction(
						"ShopSellAction",
						"complete",
						"[SECURITY] Price fallback to base for " .. itemType
					)
				else
					-- Unpriceable item - reject this entry
					SharedLogger.logAction(
						"ShopSellAction",
						"complete",
						"[SECURITY] Reject sell: unpriceable item " .. itemType
					)
					-- Skip this item without payment
				end
			end

			if itemPrice ~= nil then
				-- Remove item from inventory
				inv:Remove(item)
				sendRemoveItemFromContainer(inv, item)

				---@diagnostic disable-next-line: unnecessary-if
				-- Accumulate payment with server-authoritative price
				if isSpecialCoin then
					totalSpecial = totalSpecial + itemPrice
				else
					total = total + itemPrice
				end

				-- Log sale
				Nfunction.buildLogShop(item:getFullType())
			end
			-- If itemPrice is nil (unpriceable or blacklisted), item is skipped without payment
		end
	end

	-- Note: Server-side logging is handled by buildLogShop() above for each item sold

	-- Deposit virtual balance (no coin items created)
	if total > 0 or totalSpecial > 0 then
		-- Direct ModData manipulation since we're on server
		-- Account existence already validated above, safe to access
		SharedLogger.logAction(
			"ShopSellAction",
			"complete",
			"Adding balance - total=" .. total .. ", totalSpecial=" .. totalSpecial
		)
		account.coin = account.coin + total
		account.specialCoin = account.specialCoin + totalSpecial
		SharedLogger.logAction(
			"ShopSellAction",
			"complete",
			"Transmitting balance update - coin=" .. account.coin .. ", specialCoin=" .. account.specialCoin
		)
		ModData.transmit("CoinBalance")
		SharedLogger.logAction("ShopSellAction", "complete", "Balance transmitted successfully")
	else
		SharedLogger.logAction("ShopSellAction", "complete", "No balance to add (total=0, totalSpecial=0)")
	end

	-- Phase 3c: Send targeted transaction result to player (not broadcast)
	-- Find the player object from username
	local onlinePlayer = nil
	for i = 0, getOnlinePlayers():size() - 1 do
		local p = getOnlinePlayers():get(i)
		if p and p:getUsername() == username then
			onlinePlayer = p
			break
		end
	end

	---@diagnostic disable-next-line: unnecessary-if
	if onlinePlayer then
		local itemCount = self.sellList.items and #self.sellList.items or 0
		Utilities.SendServerCommandTo(onlinePlayer, "nshopsb42", "TransactionResult", {
			txnId = txnId,
			type = "SELL",
			success = true,
			finalRevenue = total,
			finalRevenueSpecial = totalSpecial,
			newBalance = account.coin,
			newBalanceSpecial = account.specialCoin,
			itemCount = itemCount,
		})
		SharedLogger.logAction("ShopSellAction", "complete", "Transaction result sent to player")
	end

	-- Mark transaction as processed
	local TxnRegistry = getTransactionRegistry()
	---@diagnostic disable-next-line: unnecessary-if
	if TxnRegistry then
		TxnRegistry.markProcessed(username, txnId)
	end

	-- Audit log entry (after successful transaction)
	local coin, specialCoin = Balance.getUserBalance(username)
	local shopSquare = self.shop:getSquare()

	local Audit = getShopAudit()
	if not Audit then
		return true
	end

	Audit.append({
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

	SharedLogger.logAction("ShopSellAction", "complete", "SUCCESS - sell transaction processed")
	return true
end

function ShopSellAction:new(character, shopCoords, sellList)
	local o = ISBaseTimedAction.new(ShopSellAction, character)
	-- Store shop coordinates for server-side lookup (always passed as table {x, y, z})
	o.shopCoords = shopCoords or { x = 0, y = 0, z = 0 }
	o.sellList = sellList -- Lua table - serializable
	o._shopActionType = "sell" -- Marker field for UI type checking (avoids class identity issues)
	o.stopOnWalk = true
	o.stopOnRun = true
	o.maxTime = o:getDuration()
	return o
end
