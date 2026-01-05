-- ISAddShopAction.lua
-- B42-compliant timed action for Admin Shop placement
-- Enforces proper authority split: cursor (preview) -> action (permission) -> complete (server mutation)

require("TimedActions/ISBaseTimedAction")

local Shop = SHOPSB42.Shop
local SharedLogger = require("nshopsb42/utils/SharedLogger")
local Utilities = require("nshopsb42/utils/Utilities")

ISAddShopAction = ISBaseTimedAction:derive("ISAddShopAction")
SHOPSB42.ISAddShopAction = ISAddShopAction

function ISAddShopAction:isValid()
	-- Double-check square is still free (client preview may be stale)
	local square = self.square
	if not square then
		return false
	end
	if not square:isFree(false) then
		SharedLogger.log(
			"Shops",
			"[ISAddShopAction:isValid] Square not free at " .. square:getX() .. "," .. square:getY()
		)
		return false
	end
	return true
end

function ISAddShopAction:shouldBeTurning()
	return true
end

function ISAddShopAction:getDuration()
	-- Must return > 0
	return 1
end

function ISAddShopAction:perform()
	SharedLogger.logAction("ISAddShopAction", "perform", "Action performing, time remaining=" .. tostring(self.timer))
	ISBaseTimedAction.perform(self)
	-- Client-side animation, sounds, progress bar
end

function ISAddShopAction:complete()
	SharedLogger.logAction("ISAddShopAction", "complete", "ENTRY - sprite=" .. tostring(self.sprite))

	-- Server-only execution
	if not Utilities.IsServerOrSinglePlayer() then
		SharedLogger.logAction("ISAddShopAction", "complete", "MP - exiting early, returning true")
		return true
	end

	local square = self.square
	local sprite = self.sprite
	local north = self.north or false
	local player = self.character

	if not square then
		SharedLogger.log("Shops", "[ISAddShopAction:complete] ERROR: square is nil")
		return false
	end

	if not player then
		SharedLogger.log("Shops", "[ISAddShopAction:complete] ERROR: player is nil")
		return false
	end

	SharedLogger.log(
		"Shops",
		"[ISAddShopAction:complete] Placing admin shop at "
			.. square:getX()
			.. ","
			.. square:getY()
			.. " sprite="
			.. sprite
	)

	-- Admin validation (anti-cheat)
	if not Utilities.IsPlayerAdmin(player) then
		SharedLogger.log("Shops", "[ISAddShopAction:complete] Non-admin attempted shop placement, rejecting")
		return false
	end

	-- Re-validate server-side
	if not self:isValid() then
		SharedLogger.log("Shops", "[ISAddShopAction:complete] Validation failed, rejecting")
		player:setHaloNote("Cannot place shop here", 255, 0, 0, 400)
		return false
	end

	-- Create object (SERVER AUTHORITY - first and only place this happens)
	SharedLogger.log(
		"Shops",
		"[ISAddShopAction:complete] Creating IsoThumpable with sprite=" .. sprite .. " north=" .. tostring(north)
	)

	local cell = getWorld():getCell()
	local shop = IsoThumpable.new(cell, square, sprite, north, self)

	if not shop then
		SharedLogger.log("Shops", "[ISAddShopAction:complete] ERROR: IsoThumpable.new returned nil")
		return false
	end

	SharedLogger.log("Shops", "[ISAddShopAction:complete] IsoThumpable created successfully")

	-- Configure as static shop (not a container like player shop)
	shop:setSprite(sprite)
	shop:setIsThumpable(false)
	-- Admin shops are NOT containers - they're world objects only

	-- Add to world using AddTileObject (not AddSpecialObject)
	square:AddTileObject(shop)
	SharedLogger.log("Shops", "[ISAddShopAction:complete] Shop added to tile")

	-- CRITICAL: Transmit to all clients (mandatory in B42 MP)
	shop:transmitCompleteItemToClients()
	SharedLogger.log("Shops", "[ISAddShopAction:complete] Transmitted to clients")

	-- NOTE: No inventory removal for admin shops
	-- Admin placement does not consume items

	SharedLogger.logAction("ISAddShopAction", "complete", "SUCCESS - admin shop placed")
	return true
end

function ISAddShopAction:new(character, square, sprite, north)
	-- Validate inputs
	if not character then
		SharedLogger.log("Shops", "[ISAddShopAction:new] ERROR: character is nil")
		return nil
	end
	if not square then
		SharedLogger.log("Shops", "[ISAddShopAction:new] ERROR: square is nil")
		return nil
	end
	if not sprite then
		SharedLogger.log("Shops", "[ISAddShopAction:new] ERROR: sprite is nil")
		return nil
	end

	-- Create with ISBaseTimedAction base
	SharedLogger.log(
		"Shops",
		"[ISAddShopAction:new] Initializing with character="
			.. (character and character:getUsername() or "nil")
			.. " sprite="
			.. sprite
	)

	local o = ISBaseTimedAction.new(ISAddShopAction, character)

	if not o then
		SharedLogger.log("Shops", "[ISAddShopAction:new] ERROR: ISBaseTimedAction.new returned nil")
		return nil
	end

	-- Assign all arguments to fields (required for serialization)
	o.character = character
	o.square = square
	o.sprite = sprite
	o.north = north or false

	-- Set duration (must be done in constructor for B42 serialization)
	o.maxTime = o:getDuration()

	SharedLogger.log(
		"Shops",
		"[ISAddShopAction:new] Created admin action with sprite=" .. sprite .. " maxTime=" .. tostring(o.maxTime)
	)

	return o
end
