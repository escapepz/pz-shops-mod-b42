-- InventoryObjectContextMenuDispatcher.lua
-- Unified client-side dispatcher for inventory object context menu events
-- Consolidates handlers from: CurrencyContext, PlayerShopContext
-- Follows EVENTS_RULE.md: Single listener per event, dispatch to handler table

if not isClient() then
	return
end

local SharedLogger = require("nshopsb42/utils/SharedLogger")

local Dispatcher = {}

-- =============================================================================
-- ONPREFILLINTENTORYOBJECTCONTEXTMENU HANDLER
-- =============================================================================

function Dispatcher.onPreFillInventoryObjectContextMenu(playerNum, context, item)
	SharedLogger.log("Shops", "[InventoryObjectContextMenuDispatcher:onPreFill] playerNum=" .. playerNum)

	if not item then
		return
	end

	-- Currency context handlers
	local Currency = SHOPSB42.Currency
	---@diagnostic disable-next-line: unnecessary-if
	if Currency.LootCoinsObjectContextMenu then
		Currency.LootCoinsObjectContextMenu(playerNum, context, item)
	end
	---@diagnostic disable-next-line: unnecessary-if
	if Currency.LinkWalletObjectContextMenu then
		Currency.LinkWalletObjectContextMenu(playerNum, context, item)
	end
	---@diagnostic disable-next-line: unnecessary-if
	if Currency.UnlinkWalletObjectContextMenu then
		Currency.UnlinkWalletObjectContextMenu(playerNum, context, item)
	end
	---@diagnostic disable-next-line: unnecessary-if
	if Currency.CoinsToAccountObjectContextMenu then
		Currency.CoinsToAccountObjectContextMenu(playerNum, context, item)
	end

	-- PlayerShop context handler
	local PlayerShop = SHOPSB42.PlayerShop
	---@diagnostic disable-next-line: unnecessary-if
	if PlayerShop.ItemsSellPrice then
		PlayerShop.ItemsSellPrice(playerNum, context, item)
	end
end

-- =============================================================================
-- ONFILLINTENTORYOBJECTCONTEXTMENU HANDLER (for future use)
-- =============================================================================

function Dispatcher.onFillInventoryObjectContextMenu(playerNum, context, item)
	-- Reserve for future handlers if needed
	SharedLogger.log("Shops", "[InventoryObjectContextMenuDispatcher:onFill] playerNum=" .. playerNum)
end

-- =============================================================================
-- IDEMPOTENT REGISTRATION
-- =============================================================================

---@diagnostic disable-next-line: unnecessary-if
if not Dispatcher._registered then
	Dispatcher._registered = true
	Events.OnPreFillInventoryObjectContextMenu.Add(Dispatcher.onPreFillInventoryObjectContextMenu)
	Events.OnFillInventoryObjectContextMenu.Add(Dispatcher.onFillInventoryObjectContextMenu)
	SharedLogger.log(
		"Shops",
		"[InventoryObjectContextMenuDispatcher] Registered single listeners for inventory object context menu events"
	)
end

return Dispatcher
