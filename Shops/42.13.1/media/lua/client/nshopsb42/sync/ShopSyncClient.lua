-- ShopSyncClient.lua
-- Client-side receiver for shop data synchronization
-- Extends SHOPSB42 namespace (no new globals)

local SharedLogger = require("nshopsb42/utils/SharedLogger")

SHOPSB42.ShopSyncClient = SHOPSB42.ShopSyncClient or {}
local ShopSyncClient = SHOPSB42.ShopSyncClient

-- Invalidation reason constants (defines explicit UI refresh contract)
-- This prevents future changes from accidentally blurring Sell/All behavior
ShopSyncClient.InvalidateReason = {
	BUY_PRICE_DELTA = "buy_price_delta", -- Price values changed, rows self-heal
	SELL_RULE_CHANGE = "sell_rule_change", -- Sell rules changed, inventory rebuild needed
	STRUCTURAL_CHANGE = "structural_change", -- Registry/membership changed, full rebuild needed
}

-- Unified UI invalidation entry point (enforces explicit decision logic)
-- Reason determines whether to rebuild tab or just invalidate prices
function ShopSyncClient.invalidateUI(reason)
	local ui = SHOPSB42.ShopUI and SHOPSB42.ShopUI.instance
	if not ui then
		SharedLogger.log("Shops", "[ShopSyncClient] invalidateUI called but ShopUI not open - deferring")
		return false
	end

	if not ui.panel or not ui.panel.activeView then
		SharedLogger.log("Shops", "[ShopSyncClient] invalidateUI called but no active tab - deferring")
		return false
	end

	local tab = ui.panel.activeView.view
	if not tab then
		return false
	end

	local tabType = tab.tabType

	-- Dispatch based on invalidation reason (explicit contract)
	if reason == ShopSyncClient.InvalidateReason.SELL_RULE_CHANGE then
		-- Sell tab rules changed: always rebuild (inventory rows don't self-heal)
		SharedLogger.log("Shops", "[ShopSyncClient] Invalidating due to SELL_RULE_CHANGE")
		if tabType == 2 then -- Tab.Sell
			ui:rebuildActiveTab()
			SharedLogger.log("Shops", "[ShopSyncClient] Rebuilt Sell tab on rule change")
		else
			---@diagnostic disable-next-line: unnecessary-if
			-- Sell is not active: cache will be invalidated on next activation
			if ui.shopItemsCache then
				ui.shopItemsCache[2] = nil
			end
		end
		return true
	elseif reason == ShopSyncClient.InvalidateReason.BUY_PRICE_DELTA then
		-- Buy prices changed: rebuild active tab to update basePrice and current prices
		SharedLogger.log("Shops", "[ShopSyncClient] Invalidating due to BUY_PRICE_DELTA")
		if ui.cancelPendingTransactions then
			ui:cancelPendingTransactions()
		end
		---@diagnostic disable-next-line: unnecessary-if
		-- Invalidate all tab caches for rebuild
		if ui.shopItemsCache then
			ui.shopItemsCache = {}
		end
		-- Clear cart when prices change (Phase 3.8)
		-- Users must re-add items after price changes to ensure they see current prices
		if ui.clearCartOnPriceChange then
			ui:clearCartOnPriceChange()
			SharedLogger.log("Shops", "[ShopSyncClient] Cleared cart due to buy price change")
		end
		-- Rebuild the active tab to reflect new prices
		if ui.rebuildActiveTab then
			ui:rebuildActiveTab()
			SharedLogger.log("Shops", "[ShopSyncClient] Rebuilt active tab due to buy price change")
		end
		return true
	elseif reason == ShopSyncClient.InvalidateReason.STRUCTURAL_CHANGE then
		-- Registry/membership changed: rebuild all tabs (items added/removed or mode changed)
		SharedLogger.log("Shops", "[ShopSyncClient] Invalidating due to STRUCTURAL_CHANGE")
		-- Clear cart when structural changes occur (items may no longer be available)
		if ui.clearCartOnPriceChange then
			ui:clearCartOnPriceChange()
			SharedLogger.log("Shops", "[ShopSyncClient] Cleared cart due to structural change")
		end
		ui:rebuildActiveTab()
		---@diagnostic disable-next-line: unnecessary-if
		if ui.shopItemsCache then
			ui.shopItemsCache = {}
		end
		SharedLogger.log("Shops", "[ShopSyncClient] Rebuilt active tab and cleared cache due to structural change")
		return true
	else
		SharedLogger.log("Shops", "[ShopSyncClient] Unknown invalidation reason: " .. tostring(reason))
		return false
	end
end

-- Refresh UI components when prices change (cancel actions, refresh rows)
function ShopSyncClient.refreshUIForPriceChange()
	local ui = SHOPSB42.ShopUI.instance
	SharedLogger.log(
		"Shops",
		"[ShopSyncClient.refreshUIForPriceChange] ENTRY - ui instance exists: " .. tostring(ui ~= nil)
	)

	---@diagnostic disable-next-line: unnecessary-if
	-- Mark cache as invalidated (will be handled on next access)
	if ui then
		ui.cacheInvalidated = true
		SharedLogger.log(
			"Shops",
			"[ShopSyncClient.refreshUIForPriceChange] Marked cache as invalidated for price recalculation"
		)
	end

	if not ui or not ui.panel or not ui.panel.activeView then
		SharedLogger.log(
			"Shops",
			"[ShopSyncClient.refreshUIForPriceChange] Shop UI not open (ui="
				.. tostring(ui ~= nil)
				.. ", panel="
				.. tostring(ui and ui.panel ~= nil)
				.. ", activeView="
				.. tostring(ui and ui.panel and ui.panel.activeView ~= nil)
				.. "), deferring refresh"
		)
		return false
	end

	SharedLogger.log("Shops", "[ShopSyncClient.refreshUIForPriceChange] Price hook changed, refreshing UI...")

	-- Cancel any local buy/sell actions if available
	if ui.cancelPendingTransactions then
		ui:cancelPendingTransactions()
	end

	-- Get active tab (only materialized tab)
	local activeTab = ui.panel.activeView.view
	local activeTabType = activeTab.tabType
	SharedLogger.log("Shops", "[ShopSyncClient.refreshUIForPriceChange] Active tab type: " .. tostring(activeTabType))

	---@diagnostic disable-next-line: unnecessary-if
	-- Step 1: Invalidate caches for NON-active tabs
	-- These will rebuild fresh when activated next
	if ui.shopItemsCache then
		for tabType, _ in pairs(ui.shopItemsCache) do
			if tabType ~= activeTabType then
				ui.shopItemsCache[tabType] = nil
				SharedLogger.log(
					"Shops",
					"[ShopSyncClient.refreshUIForPriceChange] Invalidated cache for inactive tab: " .. tostring(tabType)
				)
			end
		end
	end

	-- Step 2: Rebuild the ACTIVE tab using standard ShopUI method
	-- This reuses onActivateView() logic and respects ISScrollingListBox redraw contract
	local success, result = pcall(function()
		if ui.rebuildActiveTab then
			SharedLogger.log("Shops", "[ShopSyncClient.refreshUIForPriceChange] Calling ui:rebuildActiveTab()...")
			local rebuilt = ui:rebuildActiveTab()
			SharedLogger.log(
				"Shops",
				"[ShopSyncClient.refreshUIForPriceChange] rebuildActiveTab returned: " .. tostring(rebuilt)
			)
			if rebuilt then
				SharedLogger.log(
					"Shops",
					"[ShopSyncClient.refreshUIForPriceChange] Successfully rebuilt active tab with updated prices"
				)
			else
				SharedLogger.log(
					"Shops",
					"[ShopSyncClient.refreshUIForPriceChange] rebuildActiveTab returned false/nil"
				)
			end
			return rebuilt
		else
			SharedLogger.log("Shops", "[ShopSyncClient.refreshUIForPriceChange] ui.rebuildActiveTab not available")
		end
		return false
	end)

	if not success then
		SharedLogger.log(
			"Shops",
			"[ShopSyncClient.refreshUIForPriceChange] Error rebuilding active tab: " .. tostring(result)
		)
	end

	-- Clear the flag since UI refresh was successful
	ShopSyncClient.pricesChangedWhileClosed = false
	SharedLogger.log("Shops", "[ShopSyncClient.refreshUIForPriceChange] EXIT - pricesChangedWhileClosed reset to FALSE")
	return true
end

-- Register server command handlers
function ShopSyncClient.Initialize()
	-- Phase 3.1: Initialize independent revision tracking
	local Shop = SHOPSB42.Shop
	Shop.BuyPriceRevision = nil
	Shop.SellRuleRevision = nil

	-- Initialize CalculatedPrices with proper namespace (Phase 3+)
	-- Ensure we preserve any existing data and create stable references
	Shop.CalculatedPrices = Shop.CalculatedPrices or {}
	Shop.CalculatedPrices.buyPrices = Shop.CalculatedPrices.buyPrices or {}
	Shop.CalculatedPrices.sellPrices = Shop.CalculatedPrices.sellPrices or {}

	-- Expose as top-level references for backward compatibility and direct access
	-- This ensures ShopUI can access prices via Shop.BuyPrices directly
	Shop.BuyPrices = Shop.CalculatedPrices.buyPrices
	Shop.SellPrices = Shop.CalculatedPrices.sellPrices

	Shop.SellModifiers = {}
	Shop.SellOverrides = {}

	-- Track initial sync completion (Phase 3: atomicity handshake)
	Shop._initialSyncComplete = false
	Shop._initialSyncStartTime = nil
	Shop._initialSyncCompleteTime = nil

	-- Track if prices changed while UI was closed
	ShopSyncClient.pricesChangedWhileClosed = false

	-- Event listener consolidated into ShopCommandDispatcherClient
	SharedLogger.log("Shops", "[ShopSyncClient] Initialized (dispatcher registered separately)")
end

-- Handle SyncBuyPrices broadcast (Phase 3.3)
function ShopSyncClient.handleSyncBuyPrices(data)
	SharedLogger.log("Shops", "[ShopSyncClient] Received SyncBuyPrices from server")

	local Shop = SHOPSB42.Shop
	local oldBuyRevision = Shop.BuyPriceRevision or 0
	local newBuyRevision = data.buyRevision or 0
	local newSellRevision = data.sellRevision or 0

	-- Phase 4: Reject stale updates (regression guard for network reorder)
	if newBuyRevision < oldBuyRevision then
		SharedLogger.log(
			"Shops",
			"[ShopSyncClient] Rejected stale SyncBuyPrices (rev " .. newBuyRevision .. " < " .. oldBuyRevision .. ")"
		)
		return false
	end

	-- NOTE: Do NOT update revisions yet! We need oldBuyRevision to remain unchanged for the comparison below
	-- Revisions will be stored AFTER the change detection logic

	-- Initialize modifier metadata storage if needed (Phase 2)
	if not Shop._buyModifierMetadata then
		Shop._buyModifierMetadata = {}
	end

	if data.isInitialSync then
		-- Initial sync: store all prices
		Shop.CalculatedPrices.buyPrices = {}
		-- Clear old modifier metadata on initial sync (Phase 4: lifecycle management)
		Shop._buyModifierMetadata = {}

		-- Extract and store modifier metadata (Phase 2: transparency)
		for itemId, priceData in pairs(data.buyPrices or {}) do
			if type(priceData) == "table" then
				-- Store full price data object (includes price, basePrice, modifiers)
				-- Phase 4 Fix: Store entire priceData, not just .price
				Shop.CalculatedPrices.buyPrices[itemId] = priceData
				-- Store full price data with modifiers for external consumers
				if priceData.modifiers then
					Shop._buyModifierMetadata[itemId] = priceData.modifiers
					SharedLogger.log(
						"Shops",
						"[ShopSyncClient] Stored modifiers for "
							.. itemId
							.. " ("
							.. #priceData.modifiers
							.. " modifiers)"
					)
				end
			else
				-- Legacy format: just a number
				Shop.CalculatedPrices.buyPrices[itemId] = priceData
			end
		end

		SharedLogger.log(
			"Shops",
			"[ShopSyncClient] Initial BUY price sync (buyRev="
				.. newBuyRevision
				.. ", sellRev="
				.. newSellRevision
				.. ")"
		)
	elseif data.buyPrices then
		-- Delta update: merge changed prices
		for itemId, priceData in pairs(data.buyPrices) do
			if type(priceData) == "table" then
				-- Store full price data object (includes price, basePrice, modifiers)
				-- Phase 4 Fix: Store entire priceData, not just .price
				Shop.CalculatedPrices.buyPrices[itemId] = priceData
				-- Store full price data with modifiers for external consumers (Phase 2)
				if priceData.modifiers then
					Shop._buyModifierMetadata[itemId] = priceData.modifiers
					SharedLogger.log("Shops", "[ShopSyncClient] Updated modifiers for " .. itemId)
				end
			else
				-- Legacy format: just a number
				Shop.CalculatedPrices.buyPrices[itemId] = priceData
			end
		end
		SharedLogger.log(
			"Shops",
			"[ShopSyncClient] Delta BUY price update (buyRev="
				.. tostring(oldBuyRevision)
				.. "->"
				.. newBuyRevision
				.. ", sellRev="
				.. newSellRevision
				.. ")"
		)
	end

	-- Trigger UI invalidation if revision changed
	-- Use explicit reason-based dispatch: buy price deltas invalidate rows, not tabs
	if oldBuyRevision ~= nil and newBuyRevision ~= oldBuyRevision then
		-- Check if UI is open - if not, mark that prices changed while closed
		local uiOpen = SHOPSB42.ShopUI and SHOPSB42.ShopUI.instance
		SharedLogger.log(
			"Shops",
			"[ShopSyncClient] BUY revision changed ("
				.. tostring(oldBuyRevision)
				.. "->"
				.. tostring(newBuyRevision)
				.. "), UI open="
				.. tostring(uiOpen)
		)
		if not uiOpen then
			ShopSyncClient.pricesChangedWhileClosed = true
			SharedLogger.log(
				"Shops",
				"[ShopSyncClient] Price change detected while UI closed - pricesChangedWhileClosed set to TRUE"
			)
		else
			SharedLogger.log(
				"Shops",
				"[ShopSyncClient] Price change detected with UI open - notifying and invalidating"
			)
			-- Notify player of buy price change if UI is open (Phase 4.2)
			ShopSyncClient._notifyPriceChange()
		end
		ShopSyncClient.invalidateUI(ShopSyncClient.InvalidateReason.BUY_PRICE_DELTA)
	else
		SharedLogger.log(
			"Shops",
			"[ShopSyncClient] BUY revision unchanged (oldRev="
				.. tostring(oldBuyRevision)
				.. ", newRev="
				.. tostring(newBuyRevision)
				.. ")"
		)
	end

	-- NOW store the BUY revision AFTER change detection (Phase 1: atomicity, post-comparison)
	-- IMPORTANT: Only update BUY revision here! Do NOT update SellRuleRevision
	-- The SellRules handler will update SellRuleRevision to prevent race conditions
	Shop.BuyPriceRevision = newBuyRevision
end

-- Handle SyncSellRules broadcast (Phase 3.4)
function ShopSyncClient.handleSyncSellRules(data)
	SharedLogger.log("Shops", "[ShopSyncClient] Received SyncSellRules from server")

	local Shop = SHOPSB42.Shop
	local oldSellRevision = Shop.SellRuleRevision or 0
	local newBuyRevision = data.buyRevision or 0
	local newSellRevision = data.sellRevision or 0

	-- Phase 4: Reject stale updates (regression guard for network reorder)
	if newSellRevision < oldSellRevision then
		SharedLogger.log(
			"Shops",
			"[ShopSyncClient] Rejected stale SyncSellRules (rev " .. newSellRevision .. " < " .. oldSellRevision .. ")"
		)
		return false
	end

	-- NOTE: Do NOT update revisions yet! We need oldSellRevision to remain unchanged for the comparison below
	-- Revisions will be stored AFTER the change detection logic

	-- Store sell modifiers/overrides (these don't affect revision comparison, only prices do)
	Shop.SellModifiers = data.sellModifiers or {}
	Shop.SellOverrides = data.sellOverrides or {}

	SharedLogger.log(
		"Shops",
		"[ShopSyncClient] SELL rules updated (buyRev="
			.. newBuyRevision
			.. ", sellRev="
			.. tostring(oldSellRevision)
			.. "->"
			.. newSellRevision
			.. ")"
	)

	-- Trigger UI invalidation if revision changed
	-- Use explicit reason-based dispatch: sell rules always rebuild (not lazy-recalcable)
	if oldSellRevision ~= nil and newSellRevision ~= oldSellRevision then
		-- Check if UI is open - if not, mark that prices changed while closed
		local uiOpen = SHOPSB42.ShopUI and SHOPSB42.ShopUI.instance
		SharedLogger.log(
			"Shops",
			"[ShopSyncClient] SELL revision changed ("
				.. tostring(oldSellRevision)
				.. "->"
				.. tostring(newSellRevision)
				.. "), UI open="
				.. tostring(uiOpen)
		)
		if not uiOpen then
			ShopSyncClient.pricesChangedWhileClosed = true
			SharedLogger.log(
				"Shops",
				"[ShopSyncClient] Sell rule change detected while UI closed - pricesChangedWhileClosed set to TRUE"
			)
		else
			SharedLogger.log(
				"Shops",
				"[ShopSyncClient] Sell rule change detected with UI open - notifying and invalidating"
			)
			-- Notify player of sell rule change if UI is open (Phase 4.2)
			ShopSyncClient._notifyPriceChange()
		end
		ShopSyncClient.invalidateUI(ShopSyncClient.InvalidateReason.SELL_RULE_CHANGE)
	else
		SharedLogger.log(
			"Shops",
			"[ShopSyncClient] SELL revision unchanged (oldRev="
				.. tostring(oldSellRevision)
				.. ", newRev="
				.. tostring(newSellRevision)
				.. ")"
		)
	end

	-- NOW store the SELL revision AFTER change detection (Phase 1: atomicity, post-comparison)
	-- IMPORTANT: Only update SELL revision here! Do NOT update BuyPriceRevision
	-- The BuyPrices handler will update BuyPriceRevision to prevent race conditions
	-- However, we DO need to record the buy revision from the message for consistency checking
	Shop.SellRuleRevision = newSellRevision
	-- Note: BuyPriceRevision was already updated by handleSyncBuyPrices if it changed
end

-- Command dispatcher consolidated into ShopCommandDispatcherClient
-- This function is kept for reference but is no longer called directly
-- function ShopSyncClient.handleServerCommand(module, command, data) ... end

-- Handle SyncInitialComplete (Phase 3: completion handshake)
function ShopSyncClient.handleSyncInitialComplete(data)
	SharedLogger.log("Shops", "[ShopSyncClient] Received SyncInitialComplete from server")

	local Shop = SHOPSB42.Shop
	local incomingBuyRev = data.buyRevision or 0
	local incomingSellRev = data.sellRevision or 0

	-- Verify revision consistency before marking complete (Phase 3: validation)
	if Shop.BuyPriceRevision ~= incomingBuyRev or Shop.SellRuleRevision ~= incomingSellRev then
		SharedLogger.log(
			"Shops",
			"WARNING: Initial sync revision mismatch! Expected (buy="
				.. incomingBuyRev
				.. ", sell="
				.. incomingSellRev
				.. ") but have (buy="
				.. (Shop.BuyPriceRevision or 0)
				.. ", sell="
				.. (Shop.SellRuleRevision or 0)
				.. ")"
		)
		-- Continue anyway - might be race condition with updates
	end

	-- Mark initial sync as complete (Phase 3: critical gate)
	Shop._initialSyncComplete = true
	Shop._initialSyncCompleteTime = getGameTime()

	SharedLogger.log(
		"Shops",
		"[ShopSyncClient] Initial sync COMPLETE (buyRev=" .. incomingBuyRev .. ", sellRev=" .. incomingSellRev .. ")"
	)

	---@diagnostic disable-next-line: unnecessary-if
	-- Notify listeners that initial sync is complete
	-- External code (like ShopUI) can use this to know when rendering is safe
	if ShopSyncClient._initialSyncCompleteCallbacks then
		for _, callback in ipairs(ShopSyncClient._initialSyncCompleteCallbacks) do
			pcall(callback)
		end
	end
end

-- Helper: Register a callback for when initial sync completes (Phase 3)
function ShopSyncClient.onInitialSyncComplete(callback)
	if not ShopSyncClient._initialSyncCompleteCallbacks then
		ShopSyncClient._initialSyncCompleteCallbacks = {}
	end
	table.insert(ShopSyncClient._initialSyncCompleteCallbacks, callback)
end

-- Helper: Check if initial sync is complete (Phase 3: public API)
function ShopSyncClient.isShopReady()
	local Shop = SHOPSB42.Shop
	return Shop and Shop._initialSyncComplete == true
end

-- ============================================================================
-- PHASE 4: Composite-State Helpers
-- ============================================================================
-- These helpers allow code to reason about pricing state without manually
-- tracking two revision counters. They provide semantic clarity.

-- Check if pricing state is complete and ready to use (Phase 4)
function ShopSyncClient.isPricingStateComplete()
	local Shop = SHOPSB42.Shop
	if not Shop then
		return false
	end

	-- Complete means: initial sync finished AND both revisions are set
	return Shop._initialSyncComplete and Shop.BuyPriceRevision ~= nil and Shop.SellRuleRevision ~= nil
end

-- Check if pricing state changed since last known state (Phase 4)
-- Useful for detecting changes without gating on specific revision numbers
function ShopSyncClient.isPricingStateChanged(prevBuyRev, prevSellRev)
	local Shop = SHOPSB42.Shop
	if not Shop then
		return false
	end

	-- Changed if either revision is different
	-- Handle nil comparisons gracefully
	local buyChanged = (Shop.BuyPriceRevision or 0) ~= (prevBuyRev or 0)
	local sellChanged = (Shop.SellRuleRevision or 0) ~= (prevSellRev or 0)

	return buyChanged or sellChanged
end

-- Get both revisions as a composite tuple (Phase 4)
function ShopSyncClient.getPricingRevisions()
	local Shop = SHOPSB42.Shop
	if not Shop then
		return nil, nil
	end
	return Shop.BuyPriceRevision, Shop.SellRuleRevision
end

-- Capture current pricing state for later comparison (Phase 4)
-- Returns a snapshot that can be compared with future state
function ShopSyncClient.capturePricingState()
	local Shop = SHOPSB42.Shop
	if not Shop then
		return nil
	end

	return {
		buyRevision = Shop.BuyPriceRevision,
		sellRevision = Shop.SellRuleRevision,
		timestamp = getGameTime():getWorldAgeHours(),
		isComplete = Shop._initialSyncComplete,
	}
end

-- Check if captured state is different from current state (Phase 4)
function ShopSyncClient.isPricingStateDifferent(capturedState)
	if not capturedState then
		return true
	end

	local currentBuy, currentSell = ShopSyncClient.getPricingRevisions()
	return (currentBuy ~= capturedState.buyRevision) or (currentSell ~= capturedState.sellRevision)
end

-- Handler for price hook changes (Phase 3.1 + 3.7)
function ShopSyncClient.onPriceHooksChanged()
	SharedLogger.log("Shops", "[CLIENT] [ShopSyncClient] onPriceHooksChanged() called")
	ShopSyncClient._notifyAndRefreshUI()
	SharedLogger.log("Shops", "[CLIENT] [ShopSyncClient] onPriceHooksChanged() complete")
end

-- Helper: Notify player if ShopUI is open (Phase 4.2: contextual notifications)
function ShopSyncClient._notifyPriceChange()
	local ShopUI = SHOPSB42.ShopUI and SHOPSB42.ShopUI.instance
	---@diagnostic disable-next-line: unnecessary-if
	if ShopUI then
		local player = getPlayer()
		---@diagnostic disable-next-line: unnecessary-if
		if player then
			player:setHaloNote(getText("IGUI_Shop_PricesChanged") or "Shop prices have changed", 0, 255, 0, 400)
			SharedLogger.log("Shops", "[ShopSyncClient] Showed 'prices changed' halo note (UI is open)")
		end
	else
		SharedLogger.log("Shops", "[ShopSyncClient] Skipped price change notification (ShopUI not open)")
	end
end

-- Helper: Notify player and refresh UI when price hooks change (Phase 3.1 + 3.7 + 4.2)
function ShopSyncClient._notifyAndRefreshUI()
	-- 1. Notify if ShopUI is open (player is actively browsing shop)
	ShopSyncClient._notifyPriceChange()

	-- 2. Refresh UI (if UI is open)
	-- - Invalidates caches for inactive tabs (will rebuild on activation)
	-- - Recalculates visible rows in the active tab only
	ShopSyncClient.refreshUIForPriceChange()
end

-- Called by ShopUI when it opens to check if prices changed while closed
function ShopSyncClient.checkAndHandlePriceChanges()
	SharedLogger.log("Shops", "[ShopSyncClient.checkAndHandlePriceChanges] ENTRY")
	local Shop = SHOPSB42.Shop
	SharedLogger.log(
		"Shops",
		"[ShopSyncClient.checkAndHandlePriceChanges] Flag value: pricesChangedWhileClosed="
			.. tostring(ShopSyncClient.pricesChangedWhileClosed)
	)
	SharedLogger.log(
		"Shops",
		"[ShopSyncClient.checkAndHandlePriceChanges] Current revisions: buyRev="
			.. tostring(Shop.BuyPriceRevision)
			.. ", sellRev="
			.. tostring(Shop.SellRuleRevision)
	)

	---@diagnostic disable-next-line: unnecessary-if
	if ShopSyncClient.pricesChangedWhileClosed then
		SharedLogger.log(
			"Shops",
			"[ShopSyncClient.checkAndHandlePriceChanges] Flag is TRUE - prices changed while UI was closed, calling refreshUIForPriceChange()..."
		)
		-- Only refresh UI - cache was already updated when price change arrived
		local refreshResult = ShopSyncClient.refreshUIForPriceChange()
		SharedLogger.log(
			"Shops",
			"[ShopSyncClient.checkAndHandlePriceChanges] refreshUIForPriceChange returned: " .. tostring(refreshResult)
		)
	else
		SharedLogger.log(
			"Shops",
			"[ShopSyncClient.checkAndHandlePriceChanges] Flag is FALSE - no price changes detected while UI was closed"
		)
	end
	SharedLogger.log("Shops", "[ShopSyncClient.checkAndHandlePriceChanges] EXIT")
end

-- ============================================================================
-- PHASE 4: Public API Exports to Shop namespace
-- ============================================================================
-- These make the semantic helpers available via SHOPSB42.Shop for external mods

local Shop = SHOPSB42.Shop

-- Public: Get pricing state readiness (combines both revisions + sync flag)
Shop.isPricingStateComplete = function()
	return ShopSyncClient.isPricingStateComplete()
end

-- Public: Check if pricing changed since known state (works with revision tuples)
Shop.isPricingStateChanged = function(prevBuyRev, prevSellRev)
	return ShopSyncClient.isPricingStateChanged(prevBuyRev, prevSellRev)
end

-- Public: Get current buy and sell revisions as tuple
Shop.getPricingRevisions = function()
	return ShopSyncClient.getPricingRevisions()
end

-- Public: Capture state snapshot for later comparison
Shop.capturePricingState = function()
	return ShopSyncClient.capturePricingState()
end

-- Public: Check if captured state differs from current
Shop.isPricingStateDifferent = function(capturedState)
	return ShopSyncClient.isPricingStateDifferent(capturedState)
end

return ShopSyncClient
