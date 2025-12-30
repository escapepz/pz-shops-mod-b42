local Utilities = require("nshopsb42/HelperFunction/Utilities")
local SharedLogger = require("nshopsb42/utils/SharedLogger")
local Shop = SHOPSB42.Shop
local UIText = SHOPSB42.UIText
local ShopSpriteCursor = SHOPSB42.ShopSpriteCursor
local ShopUI = SHOPSB42.ShopUI
local isDebug = getCore():getDebug() -- Used for UI visibility control only

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
	getCell():setDrag(ShopSpriteCursor:new(player, sprites), playerNum)
end

function Shop.removeShop(worldobject)
	worldobject:getSquare():transmitRemoveItemFromSquare(worldobject)
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
		context:addOption(UIText.RemoveShop, wo, Shop.removeShop)
	end
end

function Shop.shopUI(worldobjects, playerNum, viewMode, clickedSquare)
	local player = getSpecificPlayer(playerNum)
	if not viewMode then
		clickedSquare = luautils.getCorrectSquareForWall(player, clickedSquare)
		local adjacent = AdjacentFreeTileFinder.Find(clickedSquare, player)
		if adjacent then
			local action = ISWalkToTimedAction:new(player, adjacent)
			local shop = worldobjects[1]
			action:setOnComplete(function()
				ShopUI:show(player, viewMode, shop)
			end)
			ISTimedActionQueue.add(action)
		end
	else
		ShopUI:show(player, viewMode)
	end
end

function Shop.ShopUIContextMenu(playerNum, context, worldobjects)
	if not (isClient() or isServer() or isDebug) then
		return
	end
	local wo, found = seekShopTiles(worldobjects[1], Shop.spritePrefix)
	if not found then
		return
	end
	local clickedSquare = wo:getSquare()
	context:addOption(UIText.Shop, worldobjects, Shop.shopUI, playerNum, false, clickedSquare)
end

function Shop.ShopViewContextMenu(playerNum, context, worldobjects)
	if not (isClient() or isServer() or isDebug) then
		return
	end
	local _, found = seekShopTiles(worldobjects[1], Shop.spritePrefix)
	if found then
		return
	end
	context:addOption(UIText.ShopViewItems, worldobjects, Shop.shopUI, playerNum, true)
end

Events.OnFillWorldObjectContextMenu.Add(Shop.ShopViewContextMenu)
Events.OnPreFillWorldObjectContextMenu.Add(Shop.ShopContextMenu)
Events.OnPreFillWorldObjectContextMenu.Add(Shop.ShopUIContextMenu)
