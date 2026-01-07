-- ShopCommandDispatcherClient.lua
-- Unified client-side command dispatcher for all OnServerCommand handlers
-- Consolidates commands from: ShopSyncClient, ShopSpriteCursorUI, PlayerShopClient, BalanceClient
-- Follows EVENTS_RULE.md: Single listener per event, dispatch to command table

if not isClient() then
	return
end

local SharedLogger = require("nshopsb42/utils/SharedLogger")
local ListingCache = require("nshopsb42/listing/ListingCache")

local Dispatcher = {}
local Commands = {}

-- =============================================================================
-- SHOP SYNC COMMANDS (from ShopSyncClient)
-- =============================================================================

-- Phase 4: Server confirms revision match (cold path - no data sync)
function Commands.ListingRevisionOK(data)
	SharedLogger.log("Shops", "[ShopCommandDispatcher:ListingRevisionOK] Received")

	local serverRevision = data.serverRevision or 0
	local Shop = SHOPSB42.Shop

	-- Confirm revision is current
	if serverRevision ~= Shop.currentRevision then
		SharedLogger.log(
			"Shops",
			"[ShopCommandDispatcher:ListingRevisionOK] WARN: Server revision mismatch (server="
				.. serverRevision
				.. " local="
				.. (Shop.currentRevision or 0)
				.. "), ignoring"
		)
		return
	end

	-- Revision confirmed: no full sync needed
	-- Mark that we've received server confirmation
	SHOPSB42.hasReceivedData = true

	SharedLogger.log("Shops", "[ShopCommandDispatcher:ListingRevisionOK] Server confirmed revision " .. serverRevision)
end

function Commands.SyncShopData(data)
	SharedLogger.log("Shops", "[ShopCommandDispatcher:SyncShopData] Received")

	local Shop = SHOPSB42.Shop
	local incomingRevision = data.revision or 0

	-- Phase 1/3: Defensive check—reject out-of-order packets
	-- Phase 3: Monotonicity enforced in memory (same rule as disk cache)
	-- If bootstrap loaded cached listing, this guard prevents server from downgrading
	if Shop.currentRevision and incomingRevision < Shop.currentRevision then
		SharedLogger.log(
			"Shops",
			"[ShopCommandDispatcher:SyncShopData] WARN: Rejecting downgrade (incoming="
				.. incomingRevision
				.. " current="
				.. Shop.currentRevision
				.. ")"
		)
		return
	end

	-- Mark that we've received data so retry logic stops
	SHOPSB42.hasReceivedData = true

	-- Phase 1: Store revision for future version tracking
	Shop.currentRevision = incomingRevision
	-- Phase 1: Also track in global for easy access
	SHOPSB42.serverRevision = Shop.currentRevision

	Shop.Items = data.Items or {}
	Shop.PlayerBuy = data.PlayerBuy or {}
	Shop.PlayerSell = data.PlayerSell or {}
	Shop.BuyIsWhitelist = data.BuyIsWhitelist or false
	Shop.SellIsWhitelist = data.SellIsWhitelist or false

	-- Phase 4 Fix: Receive default prices from server (for unregistered items)
	if data.defaultPrice then
		Shop.defaultPrice = data.defaultPrice
		SharedLogger.log("Shops", "[ShopCommandDispatcher:SyncShopData] Synced defaultPrice=" .. data.defaultPrice)
	end
	if data.defaultPriceBroken then
		Shop.defaultPriceBroken = data.defaultPriceBroken
		SharedLogger.log(
			"Shops",
			"[ShopCommandDispatcher:SyncShopData] Synced defaultPriceBroken=" .. data.defaultPriceBroken
		)
	end

	SharedLogger.log("Shops", "[ShopCommandDispatcher:SyncShopData] Revision=" .. (Shop.currentRevision or 0))

	-- Phase 2: Persist to disk cache (using server UUID transmitted in SyncShopData)
	local serverId = data.serverUUID
	assert(serverId, "[ShopCommandDispatcher:SyncShopData] Server UUID missing from SyncShopData")

	local cacheSnapshot = {
		revision = Shop.currentRevision,
		Items = Shop.Items,
		PlayerBuy = Shop.PlayerBuy,
		PlayerSell = Shop.PlayerSell,
		BuyIsWhitelist = Shop.BuyIsWhitelist,
		SellIsWhitelist = Shop.SellIsWhitelist,
		defaultPrice = Shop.defaultPrice,
		defaultPriceBroken = Shop.defaultPriceBroken,
	}
	local cacheSaved = ListingCache.saveSnapshot(cacheSnapshot, serverId)
	if cacheSaved then
		SharedLogger.log(
			"Shops",
			"[ShopCommandDispatcher:SyncShopData] Cached revision "
				.. Shop.currentRevision
				.. " to disk for server="
				.. serverId
		)
	else
		SharedLogger.log(
			"Shops",
			"[ShopCommandDispatcher:SyncShopData] WARNING: Cache save rejected (downgrade or I/O error)"
		)
	end

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

	-- Phase 3: Mark initial sync complete so ShopUI can rebuild if needed
	-- NOTE: This call is idempotent and safe to invoke multiple times
	-- (e.g., on reconnect or server upgrade) because:
	-- - It only rebuilds active tabs if revision changed
	-- - It is safe to call when UI is not visible
	-- - It is safe when called during loading
	-- Future contributors: do not optimize this away; keep it explicit
	local ShopSyncClient = SHOPSB42.ShopSyncClient
	---@diagnostic disable-next-line: unnecessary-if
	if ShopSyncClient and ShopSyncClient.handleSyncInitialComplete then
		ShopSyncClient.handleSyncInitialComplete(data)
	end
end

function Commands.SyncBuyPrices(data)
	-- Phase 2.2: Per-player broadcast handler REMOVED
	-- Clients now calculate prices deterministically using PricingContract + NPCShopCatalog
	-- No need to receive or store prices from broadcast
	SharedLogger.log("Shops", "[ShopCommandDispatcher:SyncBuyPrices] IGNORED (Phase 2.2: broadcasts removed)")
end

function Commands.SyncSellRules(data)
	-- Phase 2.2: Per-player broadcast handler REMOVED
	-- Clients calculate sell prices deterministically (same as buy prices)
	-- Server validates on transaction (Phase 3)
	SharedLogger.log("Shops", "[ShopCommandDispatcher:SyncSellRules] IGNORED (Phase 2.2: broadcasts removed)")
end

function Commands.SyncInitialComplete(data)
	SharedLogger.log("Shops", "[ShopCommandDispatcher:SyncInitialComplete] Received")

	local ShopSyncClient = require("nshopsb42/sync/ShopSyncClient")
	---@diagnostic disable-next-line: unnecessary-if
	if ShopSyncClient.handleSyncInitialComplete then
		ShopSyncClient.handleSyncInitialComplete(data)
	end
end

-- =============================================================================
-- SHOP SPRITE CURSOR COMMANDS (from ShopSpriteCursorUI)
-- =============================================================================

function Commands.ClearShopSpriteDrag(args)
	SharedLogger.log("Shops", "[ShopCommandDispatcher:ClearShopSpriteDrag] Received")

	---@diagnostic disable-next-line: unnecessary-if
	if getWorld() and getWorld():getCell() then
		---@diagnostic disable-next-line: param-type-mismatch
		getWorld():getCell():setDrag(nil, 0)
		SharedLogger.log("Shops", "[ShopCommandDispatcher:ClearShopSpriteDrag] Sprite drag cleared")
	end

	---@diagnostic disable-next-line: unnecessary-if
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
	---@diagnostic disable-next-line: unnecessary-if
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
	---@diagnostic disable-next-line: unnecessary-if
	if not SHOPSB42.Currency.UseSpecialCoin then
		msg = getText("IGUI_Balance_MailboxReceived", coin, entryCount)
	end
	player:playSound("Notification")
	player:setHaloNote(msg, 255, 255, 255, 400)
end

-- =============================================================================
-- TRANSACTION RESULT (Phase 3c: Targeted Response)
-- =============================================================================

function Commands.TransactionResult(data)
	SharedLogger.log(
		"Shops",
		"[ShopCommandDispatcher:TransactionResult] Received - txnId=" .. (data.txnId or "unknown")
	)

	-- Route to TransactionValidationClient for confirmation
	local ValidationClient = SHOPSB42.TransactionValidationClient
	---@diagnostic disable-next-line: unnecessary-if
	if ValidationClient and ValidationClient.handleTransactionResult then
		ValidationClient.handleTransactionResult(data)
	else
		SharedLogger.log("Shops", "[ShopCommandDispatcher:TransactionResult] WARNING: ValidationClient not available")
	end
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
		SharedLogger.log(
			"Shops",
			"[ShopCommandDispatcher:onServerCommand] DEBUG: PlayerShopSyncStatusData received, args type="
				.. type(args)
				.. ", args[1] type="
				.. (args and type(args[1]) or "N/A")
		)
	end

	local handler = Commands[command]
	---@diagnostic disable-next-line: unnecessary-if
	if handler then
		handler(args)
	else
		SharedLogger.log("Shops", "[ShopCommandDispatcher] UNKNOWN command: " .. command)
	end
end

-- =============================================================================
-- IDEMPOTENT REGISTRATION
-- =============================================================================

---@diagnostic disable-next-line: unnecessary-if
if not Dispatcher._registered then
	Dispatcher._registered = true
	Events.OnServerCommand.Add(Dispatcher.onServerCommand)
	SharedLogger.log("Shops", "[ShopCommandDispatcher] Registered single OnServerCommand listener")
end

return Dispatcher
