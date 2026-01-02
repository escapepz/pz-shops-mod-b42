-- ShopSpriteCursorUI.lua
-- Client-side building cursor for placing player shops
-- B42 MP compliant: cursor is UI-only, does NOT perform world mutations
-- All mutations happen in ISAddPlayerShopAction:complete()

local SharedLogger = require("nshopsb42/utils/SharedLogger")

local ShopSpriteCursorUI = nil -- Lazy-loaded class
local initialized = false

-- Lazy initialization: derive class only when needed
local function ensureInitialized()
	if initialized then
		return
	end

	-- ISBuildingObject is a PZ engine global - verify it's loaded
	if not ISBuildingObject then
		error("[ShopSpriteCursorUI] ISBuildingObject not available - PZ engine class missing")
	end

	-- Create base class (this is the expensive operation we defer)
	ShopSpriteCursorUI = ISBuildingObject:derive("ShopSpriteCursorUI")

	-- Define methods
	function ShopSpriteCursorUI:new(character, sprites)
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
		o.spriteIndex = 1
		o.north = false -- Start with west (index 1), north=false; when toggled, index 2 = north=true
		return o
	end

	function ShopSpriteCursorUI:isValid(square)
		-- Pass self (the building object) and square to buildUtil
		return buildUtil.canBePlace(self, square)
	end

	function ShopSpriteCursorUI:walkTo(x, y, z)
		return true
	end

	-- B42 COMPLIANCE: tryBuild is client-side only
	-- It queues a timed action; the server processes it in the action's complete()
	-- DO NOT create world objects here
	function ShopSpriteCursorUI:tryBuild(x, y, z)
		-- Determine which action class to use (default: ISAddPlayerShopAction)
		local ActionClass = self.actionClass or ISAddPlayerShopAction

		if not ActionClass then
			SharedLogger.log("Shops", "[ShopSpriteCursorUI:tryBuild] ERROR: Action class not loaded")
			return
		end

		local square = getWorld():getCell():getGridSquare(x, y, z)
		if not square then
			SharedLogger.log("Shops", "[ShopSpriteCursorUI:tryBuild] ERROR: no square at " .. x .. "," .. y .. "," .. z)
			return
		end

		SharedLogger.log(
			"Shops",
			"[ShopSpriteCursorUI:tryBuild] Queuing action for sprite=" .. self:getSprite() .. " at " .. x .. "," .. y
		)

		-- Queue the timed action (server will handle the actual placement)
		local action = ActionClass:new(self.character, square, self:getSprite(), self.north)
		if not action then
			SharedLogger.log("Shops", "[ShopSpriteCursorUI:tryBuild] ERROR: Action creation returned nil")
			return
		end
		ISTimedActionQueue.add(action)
	end

	-- Client-side code (render, key events)
	-- Toggle between shop types
	function ShopSpriteCursorUI.toggleSprites(key)
		if not ShopSpriteCursorUI.instance then
			return
		end
		if key ~= getCore():getKey("Rotate building") then
			return
		end

		local instance = ShopSpriteCursorUI.instance
		if not instance.sprites or #instance.sprites ~= 2 then
			SharedLogger.log(
				"Shops",
				"[ShopSpriteCursorUI:toggleSprites] KEY PRESSED but ERROR - sprites not set correctly (count="
					.. (instance.sprites and #instance.sprites or "nil")
					.. ")"
			)
			return
		end

		-- Toggle between the two sprite variants (even/odd for rotation)
		local spriteIndex = instance.spriteIndex
		if spriteIndex == 2 then
			spriteIndex = 1
		else
			spriteIndex = 2
		end

		local nextSprite = instance.sprites[spriteIndex]
		instance.spriteIndex = spriteIndex
		instance.north = (spriteIndex == 2) -- Index 1 = west (false), Index 2 = north (true)

		SharedLogger.log(
			"Shops",
			"[ShopSpriteCursorUI:toggleSprites] ROTATION OK - sprite="
				.. nextSprite
				.. " north="
				.. tostring(instance.north)
		)

		instance:setSprite(nextSprite)
		instance:setNorthSprite(nextSprite)
	end

	-- Register key listener (always safe in client/ context)
	Events.OnKeyPressed.Add(ShopSpriteCursorUI.toggleSprites)

	-- Store in global namespace so other modules can access it
	SHOPSB42.ShopSpriteCursorUI = ShopSpriteCursorUI

	initialized = true
	SharedLogger.log("Shops", "[ShopSpriteCursorUI] Lazy initialization complete - ISBuildingObject:derive() called")
end

-- Create a wrapper that triggers ensureInitialized on first method call
local module = {}

-- Metamethod to trigger lazy-load on any method call
setmetatable(module, {
	__index = function(self, key)
		ensureInitialized()
		if not ShopSpriteCursorUI then
			error("[ShopSpriteCursorUI] Initialization failed - ShopSpriteCursorUI is nil")
		end
		return ShopSpriteCursorUI[key]
	end,
	__call = function(self, ...)
		ensureInitialized()
		if not ShopSpriteCursorUI then
			error("[ShopSpriteCursorUI] Initialization failed - ShopSpriteCursorUI is nil")
		end
		return ShopSpriteCursorUI(...)
	end,
})

-- Also provide explicit methods for clarity
function module:new(character, sprites)
	ensureInitialized()
	if ShopSpriteCursorUI then
		return ShopSpriteCursorUI:new(character, sprites)
	end
	return nil
end

function module:derive(name)
	ensureInitialized()
	if ShopSpriteCursorUI then
		return ShopSpriteCursorUI:derive(name)
	end
	return nil
end

-- Expose initialization function for explicit control
function module.ensureInitialized()
	ensureInitialized()

	-- Event listener consolidated into ShopCommandDispatcherClient
	SharedLogger.log("Shops", "[ShopSpriteCursorUI] Initialized (dispatcher registered separately)")
end

return module
