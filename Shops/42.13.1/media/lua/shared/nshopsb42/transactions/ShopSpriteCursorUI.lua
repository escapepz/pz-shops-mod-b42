-- ShopSpriteCursorUI.lua
-- Shared visual placement cursor for shop sprites (client-side UI functions)
-- Extends ISBuildingObject for visual preview of shop placement

local SharedLogger = require("nshopsb42/utils/SharedLogger")
SharedLogger.log("Shops", "[ShopSpriteCursorUI] Module loading, ISBuildingObject=" .. tostring(ISBuildingObject))

-- Create a lazy-loading wrapper that defers to ISBuildingObject when available
local ShopSpriteCursorUIBase = {}
ShopSpriteCursorUIBase.__index = ShopSpriteCursorUIBase
ShopSpriteCursorUIBase._isInitialized = false

function ShopSpriteCursorUIBase:derive(name)
	local derived = {}
	derived.__index = derived
	setmetatable(derived, { __index = self })
	return derived
end

function ShopSpriteCursorUIBase:_ensureInitialized()
	-- Lazy upgrade to ISBuildingObject if available and not yet done
	if not self._isInitialized and (isClient() or (not isServer() and not isClient())) and ISBuildingObject then
		SharedLogger.log("Shops", "[ShopSpriteCursorUI] Lazily upgrading to ISBuildingObject-based class on first use")
		local RealUI = ISBuildingObject:derive("ShopSpriteCursorUI")
		RealUI.instance = nil
		RealUI.spriteIndex = 1

		function RealUI:render(x, y, z, square)
			self.x = x
			self.y = y
			self.z = z
			ISBuildingObject.render(self, x, y, z, square)
		end

		function RealUI:isValid(square)
			return true
		end

		function RealUI:walkTo(x, y, z)
			return true -- Player handles pathfinding
		end

		function RealUI:tryBuild()
			-- DEPRECATED: Subclasses (PlayerShopContext, ShopContext) override this
			-- Do NOT create objects or send commands here
			-- This is just the base no-op implementation
		end

		function RealUI:create(x, y, z, north, sprite)
			-- Delegate to ShopSpriteCursor:create() which has the server-side implementation
			if SHOPSB42.ShopSpriteCursor and SHOPSB42.ShopSpriteCursor.create then
				return SHOPSB42.ShopSpriteCursor:create(x, y, z, north, sprite)
			end
			SharedLogger.log("Shops", "[RealUI:create] ERROR: ShopSpriteCursor:create not available")
		end

		function RealUI:new(character, sprites)
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
			RealUI.instance = o
			return o
		end

		RealUI.toggleSprites = function(key)
			if RealUI.instance == nil then
				return
			end
			if not (key == getCore():getKey("Rotate building")) then
				return
			end
			local spriteIndex = RealUI.instance.spriteIndex
			if spriteIndex == 2 then
				spriteIndex = 1
			else
				spriteIndex = 2
			end
			local nextSprite = RealUI.instance.sprites[spriteIndex]
			RealUI.instance.spriteIndex = spriteIndex
			RealUI.instance:setSprite(nextSprite)
			RealUI.instance:setNorthSprite(nextSprite)
		end

		Events.OnKeyPressed.Add(RealUI.toggleSprites)

		-- Copy over the real UI methods to self
		for key, value in pairs(RealUI) do
			self[key] = value
		end
		setmetatable(self, { __index = RealUI })
		self._isInitialized = true
	end
end

function ShopSpriteCursorUIBase:new(character, sprites)
	self:_ensureInitialized()
	local o = {}
	setmetatable(o, self)
	self.__index = self
	-- Try to call ISBuildingObject methods if available
	if o.init then
		o:init()
	end
	o.sprites = sprites
	if o.setSprite then
		o:setSprite(sprites[1])
		o:setNorthSprite(sprites[1])
	end
	o.character = character
	o.player = character:getPlayerNum()
	o.noNeedHammer = true
	o.skipBuildAction = true
	ShopSpriteCursorUIBase.instance = o
	return o
end

function ShopSpriteCursorUIBase:walkTo(x, y, z)
	return true -- Player handles pathfinding
end

function ShopSpriteCursorUIBase:tryBuild()
	-- DEPRECATED: Subclasses (PlayerShopContext, ShopContext) override this
	-- Do NOT create objects or send commands here
	-- This is just the base no-op implementation
end

function ShopSpriteCursorUIBase:create(x, y, z, north, sprite)
	-- Delegate to ShopSpriteCursor:create() which has the server-side implementation
	if SHOPSB42.ShopSpriteCursor and SHOPSB42.ShopSpriteCursor.create then
		return SHOPSB42.ShopSpriteCursor:create(x, y, z, north, sprite)
	end
	SharedLogger.log("Shops", "[ShopSpriteCursorUIBase:create] ERROR: ShopSpriteCursor:create not available")
end

-- Store the base for later use
SHOPSB42.ShopSpriteCursorUI = ShopSpriteCursorUIBase
local ShopSpriteCursorUI = SHOPSB42.ShopSpriteCursorUI

SharedLogger.log("Shops",
	"[ShopSpriteCursorUI] Using lazy-loading base class (will upgrade to ISBuildingObject on first use if available)")

return ShopSpriteCursorUI
