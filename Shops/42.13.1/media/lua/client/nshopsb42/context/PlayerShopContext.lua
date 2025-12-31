local minutes = 10
local shopLockTime = minutes * 60 * 1000

local SharedLogger = require("nshopsb42/utils/SharedLogger")
local PlayerShop = SHOPSB42.PlayerShop
local UIText = SHOPSB42.UIText

-- Lazy-load UI components to avoid initialization order issues
local function getPlayerShopUI()
	return SHOPSB42.PlayerShopUI
end

local function getIncomeUI()
	return SHOPSB42.IncomeUI
end

local function getSetPriceUI()
	return SHOPSB42.SetPriceUI
end

local function seekShopTiles(worldobject, spritePrefix)
	local wo = worldobject
	local found = false
	if not wo then
		SharedLogger.log("Shops", "seekShopTiles: worldobject is nil")
		return wo, found
	end
	local sprite = wo:getSprite()
	if not sprite then
		SharedLogger.log("Shops", "seekShopTiles: sprite is nil")
		return wo, found
	end
	local spriteName = sprite:getName()
	if spriteName then
		if string.find(spriteName, spritePrefix) then
			found = true
			SharedLogger.log("Shops", "seekShopTiles: Found shop tile - " .. spriteName)
		else
			SharedLogger.log(
				"Shops",
				"seekShopTiles: sprite '" .. spriteName .. "' does not match prefix '" .. spritePrefix .. "'"
			)
		end
	else
		SharedLogger.log("Shops", "seekShopTiles: spriteName is nil")
	end
	return wo, found
end

function PlayerShop.playerShopUI(worldobjects, playerNum, clickedSquare, shop)
	local player = getSpecificPlayer(playerNum)
	clickedSquare = luautils.getCorrectSquareForWall(player, clickedSquare)
	local adjacent = AdjacentFreeTileFinder.Find(clickedSquare, player)
	if adjacent then
		local action = ISWalkToTimedAction:new(player, adjacent)
		-- Get PlayerShopUI (lazy-loaded)
		local PlayerShopUI = getPlayerShopUI()
		if not PlayerShopUI then
			SharedLogger.log("Shops", "playerShopUI: ERROR - PlayerShopUI not available")
			return
		end
		if PlayerShopUI.instance then
			PlayerShopUI.instance:close()
		end
		action:setOnComplete(function()
			if PlayerShop.isBusy(shop) then
				return
			end
			PlayerShopUI:show(player, shop)
		end)
		ISTimedActionQueue.add(action)
	end
end

function PlayerShop.addPlayerShop(worldobjects, playerNum, sprites)
	local player = getSpecificPlayer(playerNum)
	-- Get the UI class (loaded by Init.lua on OnGameStart, lazy derives on first use)
	if not SHOPSB42.ShopSpriteCursorUI then
		SharedLogger.log("Shops", "addPlayerShop: ERROR - ShopSpriteCursorUI not available")
		return
	end
	-- Create cursor instance (lazy-loads class if not already derived)
	local cursorUI = SHOPSB42.ShopSpriteCursorUI:new(player, sprites)
	-- Explicitly set actionClass to ISAddPlayerShopAction (default, but be explicit)
	cursorUI.actionClass = SHOPSB42.ISAddPlayerShopAction
	getCell():setDrag(cursorUI, playerNum)
end

function PlayerShop.LockUnlockPlayerShop(worldobjects, shop, lock)
	shop:setLockedByPadlock(lock)
end

function PlayerShop.ViewIncome(worldobjects, player, shop)
	local IncomeUI = getIncomeUI()
	if not IncomeUI then
		SharedLogger.log("Shops", "ViewIncome: ERROR - IncomeUI not available")
		return
	end
	IncomeUI:show(player, shop)
end

function PlayerShop.PickupShop(worldobjects, player, shop)
	local items = shop:getContainer():getItems()
	if items and items:size() > 0 then
		player:setHaloNote(UIText.RemoveItemsPlayerShop, 255, 255, 255, 400)
		return
	end
	local income = shop:getModData().nshopsb42_income
	if #income and #income > 0 then
		player:setHaloNote(UIText.RemoveIncomePlayerShop, 255, 255, 255, 400)
		return
	end
	-- Send command to server to handle pickup
	local coords = {
		x = shop:getX(),
		y = shop:getY(),
		z = shop:getZ(),
	}
	sendClientCommand("PS", "PickupShop", { coords })
	PlayerShop.toggleBusy(shop, player:getUsername(), false)
end

function PlayerShop.getShopID(shop)
	return shop:getX() .. "-" .. shop:getY()
end

function PlayerShop.isBlockByUser(shop, username)
	local id = PlayerShop.getShopID(shop)
	local shopStatus = PlayerShop.status[id]
	if not shopStatus then
		return false
	end
	return shopStatus.buyer == username
end

function PlayerShop.isBusy(shop)
	local id = PlayerShop.getShopID(shop)
	local shopStatus = PlayerShop.status[id]
	if shopStatus then
		if not shopStatus.time then
			shopStatus.time = getTimestampMs() + shopLockTime
		end
		if getTimestampMs() > shopStatus.time then
			return false
		else
			return shopStatus.busy
		end
	else
		return false
	end
end

function PlayerShop.toggleBusy(shop, username, busy)
	local shopId = PlayerShop.getShopID(shop)
	local data = {
		busy = busy,
		buyer = username,
		time = getTimestampMs() + shopLockTime,
	}
	sendClientCommand("PS", "ToggleBusy", { shopId, data })
end

function PlayerShop.ChangeSprite(worldobjects, playerNum, sprites, shop)
	if not shop or not sprites then
		return
	end

	local currentSprite = shop:getSprite():getName()
	local coords = { x = shop:getX(), y = shop:getY(), z = shop:getZ() }
	local newSprite = nil

	-- Keep the same orientation (odd/even) when changing signs
	-- Check if current sprite ends with odd or even number
	local lastChar = string.sub(currentSprite, -1)
	local spriteNum = lastChar and tonumber(lastChar) or 0

	if spriteNum and (spriteNum % 2 == 0) then
		newSprite = sprites[1]
	else
		newSprite = sprites[2]
	end

	if newSprite then
		SharedLogger.log("Shops", "ChangeSprite: Sending command with sprite=" .. newSprite)
		sendClientCommand("PS", "ChangeSprite", { newSprite, coords })
		shop:setSprite(newSprite)
	end
end

function PlayerShop.PlayerShopContextMenu(playerNum, context, worldobjects)
	local player = getSpecificPlayer(playerNum)
	SharedLogger.log("Shops", "PlayerShopContextMenu: worldobjects=" .. (worldobjects and "table" or "nil"))
	local wo, found = seekShopTiles(worldobjects[1], PlayerShop.spritePrefix)
	SharedLogger.log("Shops", "PlayerShopContextMenu: wo found=" .. tostring(found))
	local owner = ""
	if found then
		owner = wo:getModData().nshopsb42_owner
		local optionView = getText("IGUI_ViewPlayerShop", owner)
		local clickedSquare = wo:getSquare()
		local viewPS =
			context:addOption(optionView, worldobjects, PlayerShop.playerShopUI, playerNum, clickedSquare, wo)
		local isBusy = PlayerShop.isBusy(wo)
		if isBusy then
			viewPS.notAvailable = isBusy
		end
		if player:getUsername() == owner then
			local shop = context:addOption(UIText.ManagePlayerShop, worldobjects, nil)
			local subShop = context:getNew(context)
			context:addSubMenu(shop, subShop)
			if not (wo:getContainer():getType() == "freezer") then
				if wo:isLockedByPadlock() then
					local unlockOption = subShop:addOption(
						UIText.UnlockContainerPlayerShop,
						worldobjects,
						PlayerShop.LockUnlockPlayerShop,
						wo,
						false
					)
					if isBusy then
						unlockOption.notAvailable = isBusy
					end
				else
					local lockOption = subShop:addOption(
						UIText.LockContainerPlayerShop,
						worldobjects,
						PlayerShop.LockUnlockPlayerShop,
						wo,
						true
					)
					if isBusy then
						lockOption.notAvailable = isBusy
					end
				end
				local sign = subShop:addOption(UIText.ChangeSign, worldobjects, nil)
				local subSign = context:getNew(context)
				context:addSubMenu(sign, subSign)
				for k, v in pairs(PlayerShop.sprites) do
					if not (k == "Freezer") then
						subSign:addOption(k, worldobjects, PlayerShop.ChangeSprite, playerNum, v, wo)
					end
				end
			end
			subShop:addOption(UIText.ViewIncomePlayerShop, worldobjects, PlayerShop.ViewIncome, player, wo)
			subShop:addOption(UIText.PickupPlayerShop, worldobjects, PlayerShop.PickupShop, player, wo)
		end
	end

	local inv = player:getInventory()

	if inv:containsTag(ItemTag.get(ResourceLocation.of("shops:PlayerShop"))) then
		context:addOption(
			UIText.AddPlayerShop,
			worldobjects,
			PlayerShop.addPlayerShop,
			playerNum,
			PlayerShop.sprites.NoSign
		)
	end

	if inv:containsTag(ItemTag.get(ResourceLocation.of("shops:PlayerShopFreezer"))) then
		context:addOption(
			UIText.AddPlayerShopFreezer,
			worldobjects,
			PlayerShop.addPlayerShop,
			playerNum,
			PlayerShop.sprites.Freezer
		)
	end
end

function PlayerShop.PlayerShopSetPrice(worldobjects, playerNum, items, container)
	local player = getSpecificPlayer(playerNum)
	local SetPriceUI = getSetPriceUI()
	if not SetPriceUI then
		SharedLogger.log("Shops", "PlayerShopSetPrice: ERROR - SetPriceUI not available")
		return
	end
	SetPriceUI:show(player, items)
end

function PlayerShop.ItemsSellPrice(playerNum, context, items, worldobjects)
	items = ISInventoryPane.getActualItems(items)
	if not items then
		return
	end
	if #items < 1 then
		return
	end
	local container = items[1]:getContainer()
	local player = getSpecificPlayer(playerNum)
	if container and container:isInCharacterInventory(player) then
		local inv = player:getInventory()

		-- Debug: Log all tags in inventory
		-- writeLog("Shops", "[DEBUG] ItemsSellPrice: Checking inventory tags for player " .. player:getUsername())
		-- local allItems = inv:getItems()
		-- if allItems then
		--     for i = 0, allItems:size() - 1 do
		--         local item = allItems:get(i)
		--         local itemTags = item:getTags()
		--         writeLog("Shops", tostring(ItemTag.Write))
		--         writeLog("Shops", "[DEBUG] Item: " .. item:getType() .. " Tags: " .. tostring(itemTags))
		--     end
		-- end

		-- Check if player has Write tag OR is in debug mode
		local hasWriteTag = inv:containsTag(ItemTag.get(ResourceLocation.of("base:write")))
		local isDebugMode = getCore():getDebug()
		SharedLogger.log(
			"Shops",
			"ItemsSellPrice: hasWriteTag=" .. tostring(hasWriteTag) .. " isDebugMode=" .. tostring(isDebugMode)
		)

		if hasWriteTag or isDebugMode then
			context:addOption(
				UIText.SetPricePlayerShop,
				worldobjects,
				PlayerShop.PlayerShopSetPrice,
				playerNum,
				items,
				container
			)
		end
	end
end

Events.OnFillInventoryObjectContextMenu.Add(PlayerShop.ItemsSellPrice)
Events.OnPreFillWorldObjectContextMenu.Add(PlayerShop.PlayerShopContextMenu)
