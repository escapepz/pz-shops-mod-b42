local Utilities = require("nshopsb42/utils/Utilities")
local SharedLogger = require("nshopsb42/utils/SharedLogger")
local Shop = SHOPSB42.Shop
local UIText = SHOPSB42.UIText

-- Lazy-load ShopUI to avoid initialization order issues
local function getShopUI()
	return SHOPSB42.ShopUI
end

local function seekShopTiles(worldobject, spritePrefix)
	local wo = worldobject
	local found = false
	if not wo then
		return wo, found
	end
	local sprite = wo:getSprite()
	local spriteName = sprite:getName()
	if spriteName then
		if string.find(spriteName, spritePrefix) then
			found = true
			SharedLogger.log("Shops", "seekShopTiles: Found shop tile - " .. spriteName)
		end
	end
	return wo, found
end

function Shop.addShop(worldobjects, playerNum, sprites)
	local player = getSpecificPlayer(playerNum)
	-- Get the UI class (loaded by Init.lua on OnGameStart, lazy derives on first use)
	if not SHOPSB42.ShopSpriteCursorUI then
		SharedLogger.log("Shops", "addShop: ERROR - ShopSpriteCursorUI not available")
		return
	end
	-- Create cursor instance (lazy-loads class if not already derived)
	-- Set actionClass to ISAddShopAction for admin shops
	local cursorUI = SHOPSB42.ShopSpriteCursorUI:new(player, sprites)
	cursorUI.actionClass = SHOPSB42.ISAddShopAction
	-- Store as instance so toggleSprites() can access it
	SHOPSB42.ShopSpriteCursorUI.instance = cursorUI
	getCell():setDrag(cursorUI, playerNum)
end

--- Client-side: Request shop removal (sends to server for validation)
function Shop.requestRemoveShop(worldobjects, worldobject)
	if not worldobject then
		return
	end

	SharedLogger.log(
		"Shops",
		"requestRemoveShop: Sending removal request to server for " .. worldobject:getObjectIndex()
	)

	local sq = worldobject:getSquare()
	sendClientCommand(getPlayer(), "nshopsb42", "RemoveShop", {
		x = sq:getX(),
		y = sq:getY(),
		z = sq:getZ(),
		index = worldobject:getObjectIndex(),
	})
end

function Shop.ShopContextMenu(playerNum, context, worldobjects)
	-- Allow access if client is admin or in single-player debug mode
	if not Utilities.IsClientAdmin() then
		return
	end

	SharedLogger.log("Shops", "ShopContextMenu: Admin access granted")

	local wo, found = seekShopTiles(worldobjects[1], Shop.spritePrefix)
	local player = getSpecificPlayer(playerNum)
	SharedLogger.log("Shops", "ShopContextMenu: wo found=" .. tostring(found))

	local shop = context:addOption(UIText.AddShop, worldobjects, nil)
	local subShop = context:getNew(context)
	context:addSubMenu(shop, subShop)
	for k, v in pairs(Shop.sprites) do
		subShop:addOption(k, worldobjects, Shop.addShop, playerNum, v)
	end
	if found then
		context:addOption(UIText.RemoveShop, worldobjects, Shop.requestRemoveShop, wo)
	end
end

function Shop.shopUI(worldobjects, playerNum, viewMode, clickedSquare)
	local player = getSpecificPlayer(playerNum)
	local shop = worldobjects[1]
	local ShopUI = getShopUI()
	if not ShopUI then
		return
	end
	if not viewMode then
		clickedSquare = luautils.getCorrectSquareForWall(player, clickedSquare)
		local adjacent = AdjacentFreeTileFinder.Find(clickedSquare, player)
		if adjacent then
			local action = ISWalkToTimedAction:new(player, adjacent)
			action:setOnComplete(function()
				ShopUI:show(player, viewMode, shop)
			end)
			ISTimedActionQueue.add(action)
		end
	else
		ShopUI:show(player, viewMode, shop)
	end
end

function Shop.ShopUIContextMenu(playerNum, context, worldobjects)
	local wo, found = seekShopTiles(worldobjects[1], Shop.spritePrefix)
	if not found then
		return
	end
	local clickedSquare = wo:getSquare()
	context:addOption(UIText.Shop, worldobjects, Shop.shopUI, playerNum, false, clickedSquare)
end

function Shop.ShopViewContextMenu(playerNum, context, worldobjects)
	local _, found = seekShopTiles(worldobjects[1], Shop.spritePrefix)
	if found then
		return
	end
	context:addOption(UIText.ShopViewItems, worldobjects, Shop.shopUI, playerNum, true)
end

-- Event listeners consolidated into WorldObjectContextMenuDispatcher
