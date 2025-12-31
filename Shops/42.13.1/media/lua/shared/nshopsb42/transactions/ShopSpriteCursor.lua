-- Server/SP-only creation logic
if isClient() and not isServer() then
	return
end

local PlayerShop = SHOPSB42.PlayerShop
local ShopSpriteCursorUI = require("nshopsb42/transactions/ShopSpriteCursorUI")

-- Extend the shared UI cursor with server-side creation logic
ShopSpriteCursor = ShopSpriteCursorUI:derive("ShopSpriteCursor")
SHOPSB42.ShopSpriteCursor = ShopSpriteCursor

local function isFreezer(sprite)
	for k, v in pairs(PlayerShop.sprites.Freezer) do
		if v == sprite then
			return true
		end
	end
	return false
end

function ShopSpriteCursor:create(x, y, z, north, sprite)
	writeLog(
		"Shops",
		"[SERVER] ShopSpriteCursor:create() called with sprite=" .. sprite .. ", pos=" .. x .. "," .. y .. "," .. z
	)
	local cell = getWorld():getCell()
	local square = cell:getGridSquare(x, y, z)
	if not square then
		writeLog("Shops", "[SERVER] ShopSpriteCursor:create() - Failed to get square at " .. x .. "," .. y .. "," .. z)
		return
	end
	local shop = IsoThumpable.new(cell, square, sprite, north, self)
	if not shop then
		writeLog("Shops", "[SERVER] ShopSpriteCursor:create() - Failed to create IsoThumpable")
		return
	end
	writeLog("Shops", "[SERVER] ShopSpriteCursor:create() - IsoThumpable created, sprite=" .. sprite)
	local isPlayerShop = string.find(sprite, PlayerShop.spritePrefix)
	local itemTag = nil
	if isPlayerShop then
		writeLog("Shops", "[SERVER] ShopSpriteCursor:create() - Detected PlayerShop")
		shop:setIsContainer(true)
		shop:setCanBeLockByPadlock(true)
		if isFreezer(sprite) then
			shop:getContainer():setType("freezer")
			itemTag = ItemTag.get(ResourceLocation.of("shops:PlayerShopFreezer"))
		else
			itemTag = ItemTag.get(ResourceLocation.of("shops:PlayerShop"))
		end
	end
	shop:setSprite(sprite)
	shop:setIsThumpable(false)
	writeLog(
		"Shops",
		"[SERVER] ShopSpriteCursor:create() - About to add special object, sprite confirmed as "
			.. tostring(shop:getSprite():getName())
	)
	square:AddSpecialObject(shop)
	writeLog("Shops", "[SERVER] ShopSpriteCursor:create() - Shop added to special objects")

	writeLog("Shops", "[SERVER] ShopSpriteCursor:create() - Synced to clients")
	if isPlayerShop then
		shop:getModData().owner = self.character:getUsername()
		shop:getModData().income = {}
		shop:transmitModData()
		writeLog("Shops", "[SERVER] ShopSpriteCursor:create() - ModData set and transmitted")
	end
	getWorld():getCell():setDrag(nil, 0)
	if itemTag then
		local playerShop = self.character:getInventory():getFirstTag(itemTag)
		if playerShop then
			-- Send server command to remove the shop item from inventory
			sendClientCommand(self.character, "PS", "RemoveItemFromInventory", { itemID = playerShop:getID() })
			writeLog(
				"Shops",
				"[SERVER] ShopSpriteCursor:create() - Item removal command sent for ID: "
					.. tostring(playerShop:getID())
			)
		end
	end
	writeLog("Shops", "[SERVER] ShopSpriteCursor:create() - Complete")
end

-- Visual/UI functions are inherited from ShopSpriteCursorUI
