local Nfunction = require("nshopsb42/utils/Nfunction")
local PlayerShop = require("nshopsb42/core/PlayerShop")
local Utilities = require("nshopsb42/utils/Utilities")
local SharedLogger = SHOPSB42.SharedLogger
local PSServer = {}
local PlayerShopStatus = {}

function PSServer.ToggleBusy(player, args)
	PlayerShopStatus[args[1]] = args[2]
	-- Broadcast to all players
	Utilities.SendServerCommandToAll("nshopsb42", "PlayerShopToggleBusy", args)
end

function PSServer.SyncStatusData(player, args)
	-- Send to specific player
	Utilities.SendServerCommandTo(player, "nshopsb42", "PlayerShopSyncStatusData", { PlayerShopStatus })
end

local function getShopObject(coords)
	local square = getCell():getGridSquare(coords.x, coords.y, coords.z)
	if not square then
		return nil
	end
	for i = 0, square:getSpecialObjects():size() - 1 do
		local o = square:getSpecialObjects():get(i)
		local sprite = o:getSprite():getName()
		if string.find(sprite, PlayerShop.spritePrefix) then
			return o
		end
	end
	return nil
end

function PSServer.ChangeSprite(player, args)
	local sprite = args[1]
	local coords = args[2]
	local shop = getShopObject(coords)
	if shop then
		shop:setSprite(sprite)
		shop:sendObjectChange("sprite")
	end
end

function PSServer.SetItemPrice(player, args)
	local itemID = args.itemID
	local price = args.price
	local specialCoin = args.specialCoin

	if not itemID then
		return
	end

	-- Find item in player inventory by ID
	local item = player:getInventory():getItemById(itemID)
	if not item then
		return
	end

	-- Store price on the item itself (persists with item when moved)
	local modData = item:getModData()
	if price == nil then
		modData.price = nil
		modData.specialCoin = nil
	else
		modData.price = price
		modData.specialCoin = specialCoin
	end

	-- Sync item ModData to all clients
	syncItemModData(player, item)
end

function PSServer.RemoveItemFromInventory(player, args)
	local itemID = args.itemID
	if not itemID then
		return
	end

	local item = player:getInventory():getItemById(itemID)
	if item then
		local container = item:getContainer()
		container:Remove(item)
		sendRemoveItemFromContainer(container, item)
		SharedLogger.log("Shops", "[SERVER] PlayerShop inventory item removed - ID: " .. tostring(itemID))
	end
end

function PSServer.PickupShop(player, args)
	local coords = args[1]
	local shop = getShopObject(coords)

	if not shop then
		return
	end

	-- Check if shop is empty
	local items = shop:getContainer():getItems()
	if items and items:size() > 0 then
		return
	end

	local income = shop:getModData().income
	if income and #income > 0 then
		return
	end

	-- Get item type
	local itemType = "Shops.PlayerShop"
	if shop:getContainer():getType() == "freezer" then
		itemType = "Shops.PlayerShopFreezer"
	end

	-- Remove shop from world
	shop:getSquare():transmitRemoveItemFromSquare(shop)

	-- Add item to player inventory
	local newItem = instanceItem(itemType)
	player:getInventory():AddItem(newItem)
	sendAddItemToContainer(player:getInventory(), newItem)
end

-- Event listeners consolidated into ShopCommandDispatcherServer
-- Keep Initialize() for compatibility but it's now a no-op

function PSServer.Initialize()
	SharedLogger.log("Shops", "[PlayerShopServer] Initialize() called (listener registered in dispatcher)")
end

return PSServer
