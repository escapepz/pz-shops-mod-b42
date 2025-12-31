-- ISAddPlayerShopAction.lua
-- B42-compliant timed action for Player Shop placement
-- Enforces proper authority split: cursor (preview) → action (permission) → complete (server mutation)

require("TimedActions/ISBaseTimedAction")

local PlayerShop = SHOPSB42.PlayerShop
local SharedLogger = require("nshopsb42/utils/SharedLogger")

ISAddPlayerShopAction = ISBaseTimedAction:derive("nshopsb42_ISAddPlayerShopAction")
SHOPSB42.ISAddPlayerShopAction = ISAddPlayerShopAction

function ISAddPlayerShopAction:isValid()
	-- Double-check square is still free (client preview may be stale)
	local square = self.square
	if not square then
		return false
	end
	if not square:isFree(false) then
		SharedLogger.log(
			"Shops",
			"[ISAddPlayerShopAction:isValid] Square not free at " .. square:getX() .. "," .. square:getY()
		)
		return false
	end
	return true
end

function ISAddPlayerShopAction:shouldBeTurning()
	return true
end

function ISAddPlayerShopAction:getDuration()
	-- Must return > 0
	return 1
end

function ISAddPlayerShopAction:perform()
	SharedLogger.logAction(
		"ISAddPlayerShopAction",
		"perform",
		"Action performing, time remaining=" .. tostring(self.timer)
	)
	ISBaseTimedAction.perform(self)
	-- Client-side animation, sounds, progress bar
end

function ISAddPlayerShopAction:complete()
	SharedLogger.logAction("ISAddPlayerShopAction", "complete", "ENTRY - sprite=" .. tostring(self.sprite))

	-- Server-only execution
	if isMultiplayer() and not isServer() then
		SharedLogger.logAction("ISAddPlayerShopAction", "complete", "MP - exiting early, returning true")
		return true
	end

	local square = self.square
	local sprite = self.sprite
	local north = self.north or false
	local player = self.character

	SharedLogger.log(
		"Shops",
		"[ISAddPlayerShopAction:complete] Placing player shop at "
			.. square:getX()
			.. ","
			.. square:getY()
			.. " sprite="
			.. sprite
	)

	-- Re-validate server-side (anti-cheat)
	if not self:isValid() then
		SharedLogger.log("Shops", "[ISAddPlayerShopAction:complete] Validation failed, rejecting")
		player:setHaloNote("Cannot place shop here", 255, 0, 0, 400)
		return false
	end

	-- Detect if freezer by checking sprite name
	local isFreezer = false
	if PlayerShop.sprites.Freezer then
		for k, v in pairs(PlayerShop.sprites.Freezer) do
			if v == sprite then
				isFreezer = true
				break
			end
		end
	end

	-- Determine item tag based on freezer detection
	local itemTag = nil
	if isFreezer then
		itemTag = ItemTag.get(ResourceLocation.of("shops:PlayerShopFreezer"))
	else
		itemTag = ItemTag.get(ResourceLocation.of("shops:PlayerShop"))
	end

	-- Verify player still has the item
	if not player:getInventory():containsTag(itemTag) then
		SharedLogger.log("Shops", "[ISAddPlayerShopAction:complete] Player missing item, rejecting")
		player:setHaloNote("Item missing from inventory", 255, 0, 0, 400)
		return false
	end

	-- Create object (SERVER AUTHORITY - first and only place this happens)
	SharedLogger.log(
		"Shops",
		"[ISAddPlayerShopAction:complete] Creating IsoThumpable with sprite=" .. sprite .. " north=" .. tostring(north)
	)

	local cell = getWorld():getCell()
	local shop = IsoThumpable.new(cell, square, sprite, north, self)

	if not shop then
		SharedLogger.log("Shops", "[ISAddPlayerShopAction:complete] ERROR: IsoThumpable.new returned nil")
		return false
	end

	SharedLogger.log("Shops", "[ISAddPlayerShopAction:complete] IsoThumpable created successfully")

	-- Configure as player shop
	shop:setSprite(sprite)
	shop:setIsThumpable(false)
	shop:setIsContainer(true)
	shop:setCanBeLockByPadlock(true)

	if isFreezer then
		shop:getContainer():setType("freezer")
		SharedLogger.log("Shops", "[ISAddPlayerShopAction:complete] Configured as freezer")
	end

	-- Set ownership and initialize income tracking
	shop:getModData().owner = player:getUsername()
	shop:getModData().income = {}

	-- Add to world using AddSpecialObject (matches old working pattern)
	square:AddSpecialObject(shop)
	SharedLogger.log("Shops", "[ISAddPlayerShopAction:complete] Shop added to special objects")

	-- Sync moddata to all clients
	shop:transmitModData()
	SharedLogger.log("Shops", "[ISAddPlayerShopAction:complete] Transmitted to clients")

	-- Remove item from inventory + sync (atomic with creation)
	local item = player:getInventory():getFirstTag(itemTag)
	if item then
		player:getInventory():Remove(item)
		sendRemoveItemFromContainer(player:getInventory(), item)
		SharedLogger.log("Shops", "[ISAddPlayerShopAction:complete] Item removed from inventory")
	else
		SharedLogger.log(
			"Shops",
			"[ISAddPlayerShopAction:complete] WARNING: Item tag found but getFirstTag returned nil"
		)
	end

	-- Check if player has any shop items left
	local item = player:getInventory():getFirstTag(itemTag)
	if not item then
		SharedLogger.log("Shops", "[ISAddPlayerShopAction:complete] No shop items left, clearing sprite drag on client")
		sendClientCommand(player, "nshopsb42", "ClearShopSpriteDrag", {})
	end

	SharedLogger.logAction("ISAddPlayerShopAction", "complete", "SUCCESS - shop placed, inventory consumed")
	return true
end

function ISAddPlayerShopAction:new(character, square, sprite, north)
	-- Validate inputs
	if not character then
		SharedLogger.log("Shops", "[ISAddPlayerShopAction:new] ERROR: character is nil")
		return nil
	end
	if not square then
		SharedLogger.log("Shops", "[ISAddPlayerShopAction:new] ERROR: square is nil")
		return nil
	end
	if not sprite then
		SharedLogger.log("Shops", "[ISAddPlayerShopAction:new] ERROR: sprite is nil")
		return nil
	end

	-- Create with ISBaseTimedAction base
	-- Note: only 4 essential parameters for proper serialization
	SharedLogger.log(
		"Shops",
		"[ISAddPlayerShopAction:new] Initializing with character="
			.. (character and character:getUsername() or "nil")
			.. " sprite="
			.. sprite
	)

	local o = ISBaseTimedAction.new(ISAddPlayerShopAction, character)

	if not o then
		SharedLogger.log("Shops", "[ISAddPlayerShopAction:new] ERROR: ISBaseTimedAction.new returned nil")
		return nil
	end

	-- Assign all arguments to fields (required for serialization)
	-- CRITICAL: Parameters must match exactly for B42 network reconstruction
	o.character = character
	o.square = square
	o.sprite = sprite
	o.north = north or false

	-- Set duration (must be done in constructor for B42 serialization)
	o.maxTime = o:getDuration()

	SharedLogger.log(
		"Shops",
		"[ISAddPlayerShopAction:new] Created action with sprite=" .. sprite .. " maxTime=" .. tostring(o.maxTime)
	)

	return o
end
