-- WorldObjectContextMenuDispatcher.lua
-- Unified client-side dispatcher for world object context menu events
-- Consolidates handlers from: ShopContext, PlayerShopContext
-- Follows EVENTS_RULE.md: Single listener per event, dispatch to handler table

if not isClient() then
	return
end

local SharedLogger = require("nshopsb42/utils/SharedLogger")

local Dispatcher = {}

-- =============================================================================
-- ONFILLWORLDOBJECTCONTEXTMENU HANDLER
-- =============================================================================

function Dispatcher.onFillWorldObjectContextMenu(playerNum, context, worldobjects)
	SharedLogger.log("Shops", "[WorldObjectContextMenuDispatcher:onFill] playerNum=" .. playerNum)

	-- ShopContext handler
	local Shop = SHOPSB42.Shop
	if Shop.ShopViewContextMenu then
		Shop.ShopViewContextMenu(playerNum, context, worldobjects)
	end
end

-- =============================================================================
-- ONPREFILLWORLDOBJECTCONTEXTMENU HANDLER
-- =============================================================================

function Dispatcher.onPreFillWorldObjectContextMenu(playerNum, context, worldobjects)
	SharedLogger.log("Shops", "[WorldObjectContextMenuDispatcher:onPreFill] playerNum=" .. playerNum)

	-- ShopContext handlers
	local Shop = SHOPSB42.Shop
	if Shop.ShopContextMenu then
		Shop.ShopContextMenu(playerNum, context, worldobjects)
	end
	if Shop.ShopUIContextMenu then
		Shop.ShopUIContextMenu(playerNum, context, worldobjects)
	end

	-- PlayerShopContext handler
	local PlayerShop = SHOPSB42.PlayerShop
	if PlayerShop.PlayerShopContextMenu then
		PlayerShop.PlayerShopContextMenu(playerNum, context, worldobjects)
	end
end

-- =============================================================================
-- IDEMPOTENT REGISTRATION
-- =============================================================================

if not Dispatcher._registered then
	Dispatcher._registered = true
	Events.OnFillWorldObjectContextMenu.Add(Dispatcher.onFillWorldObjectContextMenu)
	Events.OnPreFillWorldObjectContextMenu.Add(Dispatcher.onPreFillWorldObjectContextMenu)
	SharedLogger.log(
		"Shops",
		"[WorldObjectContextMenuDispatcher] Registered single listeners for world object context menu events"
	)
end

return Dispatcher
