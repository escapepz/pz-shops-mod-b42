ShopSpriteCursor = ISBuildingObject:derive("ShopSpriteCursor")
ShopSpriteCursor.instance = nil
ShopSpriteCursor.spriteIndex = 1

local function isFreezer(sprite)
	for k,v in pairs(PlayerShop.sprites.Freezer) do
		if v == sprite then return true end
	end
	return false
end

function ShopSpriteCursor:create(x, y, z, north, sprite)
	print("[Shop Debug] ShopSpriteCursor:create() called with sprite=" .. sprite .. ", pos=" .. x .. "," .. y .. "," .. z)
	local cell = getWorld():getCell()
	local square = cell:getGridSquare(x, y, z)
	if not square then
		print("[Shop Error] ShopSpriteCursor:create() - Failed to get square at " .. x .. "," .. y .. "," .. z)
		return
	end
	local shop = IsoThumpable.new(cell, square, sprite, north, self)
	if not shop then
		print("[Shop Error] ShopSpriteCursor:create() - Failed to create IsoThumpable")
		return
	end
	print("[Shop Debug] ShopSpriteCursor:create() - IsoThumpable created, sprite=" .. sprite)
	local isPlayerShop = string.find(sprite,PlayerShop.spritePrefix)
	local itemTag = nil
	if isPlayerShop then
		print("[Shop Debug] ShopSpriteCursor:create() - Detected PlayerShop")
		shop:setIsContainer(true);
		shop:setCanBeLockByPadlock(true)
		if isFreezer(sprite) then
			shop:getContainer():setType("freezer");
			itemTag = ItemTag.get(ResourceLocation.of("shops:PlayerShopFreezer"))
		else
			itemTag = ItemTag.get(ResourceLocation.of("shops:PlayerShop"))
		end
	end
	shop:setSprite(sprite)
	shop:setIsThumpable(false);
	print("[Shop Debug] ShopSpriteCursor:create() - About to add special object, sprite confirmed as " .. tostring(shop:getSprite():getName()))
	square:AddSpecialObject(shop)
	print("[Shop Debug] ShopSpriteCursor:create() - Shop added to special objects")
	if shop.transmitCompleteItemToServer then
		shop:transmitCompleteItemToServer()
	end
	print("[Shop Debug] ShopSpriteCursor:create() - Synced to clients")
	if isPlayerShop then
		shop:getModData().owner = self.character:getUsername()
		shop:getModData().income = {}
		shop:transmitModData()
		print("[Shop Debug] ShopSpriteCursor:create() - ModData set and transmitted")
	end
	getWorld():getCell():setDrag(nil, 0);
	if itemTag then
		local playerShop = self.character:getInventory():getFirstTag(itemTag)
		if playerShop then
			self.character:getInventory():Remove(playerShop)
			print("[Shop Debug] ShopSpriteCursor:create() - Item removed from inventory")
		end
	end
	print("[Shop Debug] ShopSpriteCursor:create() - Complete")
end

function ShopSpriteCursor:render(x, y, z, square)
	ISBuildingObject.render(self, x, y, z, square)
end

function ShopSpriteCursor:isValid(square)
	return true
end

ShopSpriteCursor.toggleSprites = function (key)
	if ShopSpriteCursor.instance == nil then return end
	if not(key == getCore():getKey("Rotate building")) then return end
	local spriteIndex = ShopSpriteCursor.instance.spriteIndex
	if spriteIndex == 2 then
		spriteIndex = 1 
	else
		spriteIndex = 2
	end
	local nextSprite = ShopSpriteCursor.instance.sprites[spriteIndex]
	ShopSpriteCursor.instance.spriteIndex = spriteIndex
	ShopSpriteCursor.instance:setSprite(nextSprite)
	ShopSpriteCursor.instance:setNorthSprite(nextSprite)
end

function ShopSpriteCursor:new(character,sprites)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o:init()
	o.sprites = sprites
	o:setSprite(sprites[1])
	o:setNorthSprite(sprites[1])
	o.character = character
	o.player = character:getPlayerNum()
	o.noNeedHammer = true
	o.skipBuildAction = true
	ShopSpriteCursor.instance = o
	return o
end

Events.OnKeyPressed.Add(ShopSpriteCursor.toggleSprites)
