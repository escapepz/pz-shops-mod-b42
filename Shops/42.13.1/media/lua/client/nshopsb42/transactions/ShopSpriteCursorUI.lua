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
	ShopSpriteCursorUI = ISBuildingObject:derive("nshopsb42_ShopSpriteCursorUI")

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
		local spriteIndex = ShopSpriteCursorUI.instance.spriteIndex
		if spriteIndex == 2 then
			spriteIndex = 1
		else
			spriteIndex = 2
		end
		local nextSprite = ShopSpriteCursorUI.instance.sprites[spriteIndex]
		ShopSpriteCursorUI.instance.spriteIndex = spriteIndex
		ShopSpriteCursorUI.instance:setSprite(nextSprite)
		ShopSpriteCursorUI.instance:setNorthSprite(nextSprite)
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
	return ShopSpriteCursorUI:new(character, sprites)
end

function module:derive(name)
	ensureInitialized()
	return ShopSpriteCursorUI:derive(name)
end

-- Expose initialization function for explicit control
function module.ensureInitialized()
	ensureInitialized()

	-- only work in MP
	Events.OnServerCommand.Add(function(module_name, command, args)
		if module_name ~= "nshopsb42" then
			return
		end
		if command ~= "ClearShopSpriteDrag" then
			return
		end

		SharedLogger.log("Shops", "[ShopSpriteCursorUI] Received ClearShopSpriteDrag command")

		if getWorld() and getWorld():getCell() then
			getWorld():getCell():setDrag(nil, 0)
			SharedLogger.log("Shops", "[ShopSpriteCursorUI] Sprite drag cleared")
		end
	end)

	SharedLogger.log("Shops", "[ShopCommandHandlerClient] Initialized.")
end

return module
