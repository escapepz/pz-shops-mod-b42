-- ShopCommandDispatcherClient.lua
-- Unified client-side command dispatcher for all OnServerCommand handlers
-- Consolidates commands from: ShopSyncClient, ShopSpriteCursorUI, PlayerShopClient, BalanceClient
-- Follows EVENTS_RULE.md: Single listener per event, dispatch to command table

if not isClient() then
    return
end

local SharedLogger = require("nshopsb42/utils/SharedLogger")

local Dispatcher = {}
local Commands = {}

-- =============================================================================
-- SHOP SYNC COMMANDS (from ShopSyncClient)
-- =============================================================================

function Commands.SyncShopData(data)
    SharedLogger.log("Shops", "[ShopCommandDispatcher:SyncShopData] Received")

    -- Mark that we've received data so retry logic stops
    SHOPSB42.hasReceivedData = true

    local Shop = SHOPSB42.Shop
    Shop.Items = data.Items or {}
    Shop.PlayerBuy = data.PlayerBuy or {}
    Shop.PlayerSell = data.PlayerSell or {}
    Shop.BuyIsWhitelist = data.BuyIsWhitelist or false
    Shop.SellIsWhitelist = data.SellIsWhitelist or false

    local itemCount = 0
    local buyCount = 0
    local sellCount = 0
    for _ in pairs(Shop.Items) do
        itemCount = itemCount + 1
    end
    for _ in pairs(Shop.PlayerBuy) do
        buyCount = buyCount + 1
    end
    for _ in pairs(Shop.PlayerSell) do
        sellCount = sellCount + 1
    end

    SharedLogger.log(
        "Shops",
        "[ShopCommandDispatcher:SyncShopData] Stored "
        .. itemCount
        .. " total, "
        .. buyCount
        .. " buy, "
        .. sellCount
        .. " sell"
    )

    -- DEBUG: Log if Base.Apple is in the data
    if Shop.PlayerBuy["Base.Apple"] then
        local price = Shop.PlayerBuy["Base.Apple"].price or "unknown"
        SharedLogger.log("Shops", "[ShopCommandDispatcher:SyncShopData] Base.Apple found (price=" .. price .. ")")
    end

    -- Mark initial sync complete so ShopUI can open
    local ShopSyncClient = SHOPSB42.ShopSyncClient
    if ShopSyncClient and ShopSyncClient.handleSyncInitialComplete then
        ShopSyncClient.handleSyncInitialComplete(data)
    end
end

function Commands.SyncBuyPrices(data)
    SharedLogger.log("Shops", "[ShopCommandDispatcher:SyncBuyPrices] Received")

    local ShopSyncClient = require("nshopsb42/sync/ShopSyncClient")
    if ShopSyncClient.handleSyncBuyPrices then
        ShopSyncClient.handleSyncBuyPrices(data)
    end
end

function Commands.SyncSellRules(data)
    SharedLogger.log("Shops", "[ShopCommandDispatcher:SyncSellRules] Received")

    local ShopSyncClient = require("nshopsb42/sync/ShopSyncClient")
    if ShopSyncClient.handleSyncSellRules then
        ShopSyncClient.handleSyncSellRules(data)
    end
end

function Commands.SyncInitialComplete(data)
    SharedLogger.log("Shops", "[ShopCommandDispatcher:SyncInitialComplete] Received")

    local ShopSyncClient = require("nshopsb42/sync/ShopSyncClient")
    if ShopSyncClient.handleSyncInitialComplete then
        ShopSyncClient.handleSyncInitialComplete(data)
    end
end

-- =============================================================================
-- SHOP SPRITE CURSOR COMMANDS (from ShopSpriteCursorUI)
-- =============================================================================

function Commands.ClearShopSpriteDrag(args)
    SharedLogger.log("Shops", "[ShopCommandDispatcher:ClearShopSpriteDrag] Received")

    if getWorld() and getWorld():getCell() then
        getWorld():getCell():setDrag(nil, 0)
        SharedLogger.log("Shops", "[ShopCommandDispatcher:ClearShopSpriteDrag] Sprite drag cleared")
    end

    -- Clear the ShopSpriteCursorUI instance so rotation doesn't work on stale instance
    if SHOPSB42.ShopSpriteCursorUI then
        SHOPSB42.ShopSpriteCursorUI.instance = nil
    end
end

-- =============================================================================
-- PLAYERSHOP COMMANDS (from PlayerShopClient - consolidated into nshopsb42)
-- =============================================================================

function Commands.PlayerShopToggleBusy(args)
    local PlayerShop = SHOPSB42.PlayerShop
    PlayerShop.status[args[1]] = args[2]
    SharedLogger.log("Shops", "[ShopCommandDispatcher:PlayerShopToggleBusy] Status updated")
end

function Commands.PlayerShopSyncStatusData(args)
    SharedLogger.log("Shops", "[ShopCommandDispatcher:PlayerShopSyncStatusData] RECEIVED args from server")
    if not args then
        SharedLogger.log("Shops", "[ShopCommandDispatcher:PlayerShopSyncStatusData] ERROR: args is nil")
        return
    end
    if not args[1] then
        SharedLogger.log("Shops", "[ShopCommandDispatcher:PlayerShopSyncStatusData] ERROR: args[1] is nil")
        return
    end
    local PlayerShop = SHOPSB42.PlayerShop
    PlayerShop.status = args[1]
    SharedLogger.log("Shops", "[ShopCommandDispatcher:PlayerShopSyncStatusData] Status synced successfully")
end

-- =============================================================================
-- BALANCE COMMANDS (from BalanceClient - consolidated into nshopsb42)
-- =============================================================================

function Commands.BalanceTransferReceived(noti)
    SharedLogger.log("Shops", "[ShopCommandDispatcher:BalanceTransferReceived] Received transfer notification")

    local player = getPlayer()
    if not player then
        return
    end

    local sender = noti.sender
    local coin = SHOPSB42.Currency.format(noti.coin)
    local specialCoin = SHOPSB42.Currency.format(noti.specialCoin)
    local msg = getText("IGUI_Balance_TransferReceivedSpecial", sender, coin, specialCoin)
    if not SHOPSB42.Currency.UseSpecialCoin then
        msg = getText("IGUI_Balance_TransferReceived", sender, coin)
    end
    player:playSound("Notification")
    player:setHaloNote(msg, 255, 255, 255, 400)
end

function Commands.BalanceMailboxReceived(noti)
    SharedLogger.log("Shops", "[ShopCommandDispatcher:BalanceMailboxReceived] Received mailbox notification")

    local player = getPlayer()
    if not player then
        return
    end

    local coin = SHOPSB42.Currency.format(noti.coin)
    local specialCoin = SHOPSB42.Currency.format(noti.specialCoin)
    local entryCount = noti.entryCount or 0

    local msg = getText("IGUI_Balance_MailboxReceivedSpecial", coin, specialCoin, entryCount)
    if not SHOPSB42.Currency.UseSpecialCoin then
        msg = getText("IGUI_Balance_MailboxReceived", coin, entryCount)
    end
    player:playSound("Notification")
    player:setHaloNote(msg, 255, 255, 255, 400)
end

-- =============================================================================
-- DISPATCHER FUNCTION
-- =============================================================================

function Dispatcher.onServerCommand(module, command, args)
	if module ~= "nshopsb42" then
		return
	end

	SharedLogger.log("Shops", "[ShopCommandDispatcher] OnServerCommand - module=" .. module .. " command=" .. command)

	if command == "PlayerShopSyncStatusData" then
		SharedLogger.log("Shops",
			"[ShopCommandDispatcher:onServerCommand] DEBUG: PlayerShopSyncStatusData received, args type=" .. type(
				args) .. ", args[1] type=" .. (args and type(args[1]) or "N/A"))
	end

	local handler = Commands[command]
	if handler then
		handler(args)
	else
		SharedLogger.log("Shops", "[ShopCommandDispatcher] UNKNOWN command: " .. command)
	end
end

-- =============================================================================
-- IDEMPOTENT REGISTRATION
-- =============================================================================

if not Dispatcher._registered then
    Dispatcher._registered = true
    Events.OnServerCommand.Add(Dispatcher.onServerCommand)
    SharedLogger.log("Shops", "[ShopCommandDispatcher] Registered single OnServerCommand listener")
end

return Dispatcher
