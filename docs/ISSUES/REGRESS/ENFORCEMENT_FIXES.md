# Enforcement Fixes for Behavioral Regressions

This document provides exact code locations and patches needed to restore behavioral invariants from SHA_A.

---

## Fix #1: Restore Buy Modifiers in Broadcast

### Location
**File**: `Shops/42.13.1/media/lua/server/nshopsb42/transactions/ShopFinalizeHandlerServer.lua`
**Function**: `ShopFinalizeHandler.broadcastBuyPrices()`
**Lines**: 127-143

### Current Code (SHA_B - BROKEN)
```lua
-- Broadcast buy prices to all players (Phase 2.3)
function ShopFinalizeHandler.broadcastBuyPrices()
	Shop.BuyPriceRevision = Shop.BuyPriceRevision + 1

	local modifiers = Builder.buildPriceModifiers()
	Shop.PriceModifiers = modifiers

	local calculatedPrices = buildCalculatedPrices()
	local changedPrices = detectPriceChanges(calculatedPrices, ShopFinalizeHandler._previousBuyPrices)
	ShopFinalizeHandler._previousBuyPrices = calculatedPrices.buyPrices or {}

	Utilities.SendServerCommandToAll("Shops", "SyncBuyPrices", {
		revision = Shop.BuyPriceRevision,
		buyPrices = changedPrices, -- Delta: only changed items
	})

	SharedLogger.log("Shops", "[ShopFinalizeHandler] BUY prices broadcast (rev=" .. Shop.BuyPriceRevision .. ")")
end
```

### Fixed Code
```lua
-- Broadcast buy prices to all players (Phase 2.3)
function ShopFinalizeHandler.broadcastBuyPrices()
	Shop.BuyPriceRevision = Shop.BuyPriceRevision + 1

	local modifiers = Builder.buildPriceModifiers()
	Shop.PriceModifiers = modifiers

	local calculatedPrices = buildCalculatedPrices()
	local changedPrices = detectPriceChanges(calculatedPrices, ShopFinalizeHandler._previousBuyPrices)
	ShopFinalizeHandler._previousBuyPrices = calculatedPrices.buyPrices or {}

	Utilities.SendServerCommandToAll("Shops", "SyncBuyPrices", {
		revision = Shop.BuyPriceRevision,
		buyPrices = changedPrices, -- Delta: only changed items
		buyOverrides = modifiers.buyOverrides or {}, -- FIX: Include buy modifiers for transparency
		sellRevision = Shop.SellRuleRevision, -- FIX: Both revisions for consistency check
	})

	SharedLogger.log("Shops", "[ShopFinalizeHandler] BUY prices broadcast (rev=" .. Shop.BuyPriceRevision .. ")")
end
```

### Rationale
- **buyOverrides**: Clients need to know buy price rules/overrides for audit purposes
- **sellRevision**: Clients should know what sell revision corresponds to these buy prices, preventing stale reads

---

## Fix #2: Restore Sell Revision in Sell Broadcast

### Location
**File**: `Shops/42.13.1/media/lua/server/nshopsb42/transactions/ShopFinalizeHandlerServer.lua`
**Function**: `ShopFinalizeHandler.broadcastSellRules()`
**Lines**: 146-169

### Current Code (SHA_B - INCOMPLETE)
```lua
-- Broadcast sell rules to all players (Phase 2.5)
function ShopFinalizeHandler.broadcastSellRules()
	Shop.SellRuleRevision = Shop.SellRuleRevision + 1

	local modifiers = Builder.buildPriceModifiers()

	-- Extract sell-specific data
	local sellData = {
		sellModifiers = modifiers.sellModifiers or {},
		sellOverrides = modifiers.sellOverrides or {},
	}

	-- Delta detection (compare with previous rules)
	if not ruleSetsEqual(sellData, ShopFinalizeHandler._previousSellRules) then
		ShopFinalizeHandler._previousSellRules = deepCopy(sellData)

		Utilities.SendServerCommandToAll("Shops", "SyncSellRules", {
			revision = Shop.SellRuleRevision,
			sellModifiers = sellData.sellModifiers,
			sellOverrides = sellData.sellOverrides,
		})

		SharedLogger.log("Shops", "[ShopFinalizeHandler] SELL rules broadcast (rev=" .. Shop.SellRuleRevision .. ")")
	end
end
```

### Fixed Code
```lua
-- Broadcast sell rules to all players (Phase 2.5)
function ShopFinalizeHandler.broadcastSellRules()
	Shop.SellRuleRevision = Shop.SellRuleRevision + 1

	local modifiers = Builder.buildPriceModifiers()

	-- Extract sell-specific data
	local sellData = {
		sellModifiers = modifiers.sellModifiers or {},
		sellOverrides = modifiers.sellOverrides or {},
	}

	-- Delta detection (compare with previous rules)
	if not ruleSetsEqual(sellData, ShopFinalizeHandler._previousSellRules) then
		ShopFinalizeHandler._previousSellRules = deepCopy(sellData)

		Utilities.SendServerCommandToAll("Shops", "SyncSellRules", {
			revision = Shop.SellRuleRevision,
			sellModifiers = sellData.sellModifiers,
			sellOverrides = sellData.sellOverrides,
			buyRevision = Shop.BuyPriceRevision, -- FIX: Both revisions for consistency check
		})

		SharedLogger.log("Shops", "[ShopFinalizeHandler] SELL rules broadcast (rev=" .. Shop.SellRuleRevision .. ")")
	end
end
```

### Rationale
- Client can verify it has matching buy prices and sell rules by comparing revisions
- Prevents transactions using mismatched state

---

## Fix #3: Add Initial Sync Completion Signal

### Location
**File**: `Shops/42.13.1/media/lua/server/nshopsb42/transactions/ShopFinalizeHandlerServer.lua`
**Function**: `ShopFinalizeHandler.sendShopDataToPlayer()`
**Lines**: 268-330

### Current Code (SHA_B - MISSING COMPLETION)
```lua
-- NEW: Send data to a specific player (called when they connect) (Step 5)
function ShopFinalizeHandler.sendShopDataToPlayer(player)
	if not Utilities.IsServerOrSinglePlayer() then
		SharedLogger.log("Shops", "[ShopFinalizeHandler] sendShopDataToPlayer not in server context, aborting")
		return
	end

	if not player then
		SharedLogger.log("Shops", "[ShopFinalizeHandler] sendShopDataToPlayer called with nil player, aborting")
		return
	end

	SharedLogger.log("Shops", "[ShopFinalizeHandler] sendShopDataToPlayer starting for " .. player:getUsername())

	local itemCount = 0
	for _ in pairs(Shop.Items) do
		itemCount = itemCount + 1
	end
	SharedLogger.log("Shops", "[ShopFinalizeHandler] Preparing SyncShopData with " .. itemCount .. " items")

	-- Send shop items and config
	local shopData = {
		Items = Shop.Items,
		PlayerBuy = Shop.PlayerBuy,
		PlayerSell = Shop.PlayerSell,
		BuyIsWhitelist = Shop.BuyIsWhitelist,
		SellIsWhitelist = Shop.SellIsWhitelist,
	}

	SharedLogger.log("Shops", "[ShopFinalizeHandler] Sending SyncShopData command...")
	Utilities.SendServerCommandTo(player, "Shops", "SyncShopData", shopData)
	SharedLogger.log("Shops", "[ShopFinalizeHandler] SyncShopData sent")

	-- Send buy prices (initial sync) (Phase 2.8)
	local buyData = buildCalculatedPrices()
	SharedLogger.log(
		"Shops",
		"[ShopFinalizeHandler] Sending SyncBuyPrices (revision: " .. tostring(Shop.BuyPriceRevision or 0) .. ")"
	)

	Utilities.SendServerCommandTo(player, "Shops", "SyncBuyPrices", {
		revision = Shop.BuyPriceRevision,
		buyPrices = buyData.buyPrices,
		isInitialSync = true,
	})
	SharedLogger.log("Shops", "[ShopFinalizeHandler] SyncBuyPrices sent")

	-- Send sell rules (initial sync) (Phase 2.8)
	local modifiers = Builder.buildPriceModifiers()
	SharedLogger.log(
		"Shops",
		"[ShopFinalizeHandler] Sending SyncSellRules (revision: " .. tostring(Shop.SellRuleRevision or 0) .. ")"
	)

	Utilities.SendServerCommandTo(player, "Shops", "SyncSellRules", {
		revision = Shop.SellRuleRevision,
		sellModifiers = modifiers.sellModifiers or {},
		sellOverrides = modifiers.sellOverrides or {},
		isInitialSync = true,
	})
	SharedLogger.log("Shops", "[ShopFinalizeHandler] SyncSellRules sent")

	SharedLogger.log("Shops", "[ShopFinalizeHandler] Synced all data to " .. player:getUsername())
end
```

### Fixed Code
```lua
-- NEW: Send data to a specific player (called when they connect) (Step 5)
function ShopFinalizeHandler.sendShopDataToPlayer(player)
	if not Utilities.IsServerOrSinglePlayer() then
		SharedLogger.log("Shops", "[ShopFinalizeHandler] sendShopDataToPlayer not in server context, aborting")
		return
	end

	if not player then
		SharedLogger.log("Shops", "[ShopFinalizeHandler] sendShopDataToPlayer called with nil player, aborting")
		return
	end

	SharedLogger.log("Shops", "[ShopFinalizeHandler] sendShopDataToPlayer starting for " .. player:getUsername())

	local itemCount = 0
	for _ in pairs(Shop.Items) do
		itemCount = itemCount + 1
	end
	SharedLogger.log("Shops", "[ShopFinalizeHandler] Preparing SyncShopData with " .. itemCount .. " items")

	-- Send shop items and config
	local shopData = {
		Items = Shop.Items,
		PlayerBuy = Shop.PlayerBuy,
		PlayerSell = Shop.PlayerSell,
		BuyIsWhitelist = Shop.BuyIsWhitelist,
		SellIsWhitelist = Shop.SellIsWhitelist,
	}

	SharedLogger.log("Shops", "[ShopFinalizeHandler] Sending SyncShopData command...")
	Utilities.SendServerCommandTo(player, "Shops", "SyncShopData", shopData)
	SharedLogger.log("Shops", "[ShopFinalizeHandler] SyncShopData sent")

	-- Send buy prices (initial sync) (Phase 2.8)
	local buyData = buildCalculatedPrices()
	SharedLogger.log(
		"Shops",
		"[ShopFinalizeHandler] Sending SyncBuyPrices (revision: " .. tostring(Shop.BuyPriceRevision or 0) .. ")"
	)

	Utilities.SendServerCommandTo(player, "Shops", "SyncBuyPrices", {
		revision = Shop.BuyPriceRevision,
		buyPrices = buyData.buyPrices,
		buyOverrides = (Builder.buildPriceModifiers() or {}).buyOverrides or {}, -- FIX: Include buy modifiers
		isInitialSync = true,
	})
	SharedLogger.log("Shops", "[ShopFinalizeHandler] SyncBuyPrices sent")

	-- Send sell rules (initial sync) (Phase 2.8)
	local modifiers = Builder.buildPriceModifiers()
	SharedLogger.log(
		"Shops",
		"[ShopFinalizeHandler] Sending SyncSellRules (revision: " .. tostring(Shop.SellRuleRevision or 0) .. ")"
	)

	Utilities.SendServerCommandTo(player, "Shops", "SyncSellRules", {
		revision = Shop.SellRuleRevision,
		sellModifiers = modifiers.sellModifiers or {},
		sellOverrides = modifiers.sellOverrides or {},
		isInitialSync = true,
	})
	SharedLogger.log("Shops", "[ShopFinalizeHandler] SyncSellRules sent")

	-- FIX: Signal initial sync completion to prevent UI race condition
	Utilities.SendServerCommandTo(player, "Shops", "SyncInitialComplete", {
		buyRevision = Shop.BuyPriceRevision,
		sellRevision = Shop.SellRuleRevision,
	})
	SharedLogger.log("Shops", "[ShopFinalizeHandler] SyncInitialComplete sent")

	SharedLogger.log("Shops", "[ShopFinalizeHandler] Synced all data to " .. player:getUsername())
end
```

### Rationale
- Explicit completion signal prevents UI from opening until all three commands received
- Client can validate initial state is consistent before displaying shop

---

## Fix #4: Client-Side Handler for Initial Sync

### Location
**File**: `Shops/42.13.1/media/lua/client/nshopsb42/sync/ShopSyncClient.lua`
**Function**: `ShopSyncClient.handleServerCommand()`
**Lines**: 237-281

### Current Code (SHA_B - NO COMPLETION CHECK)
```lua
function ShopSyncClient.handleServerCommand(module, command, data)
	if module ~= "Shops" then
		return
	end

	local Shop = SHOPSB42.Shop

	if command == "SyncShopData" then
		SharedLogger.log("Shops", "[ShopSyncClient] Received SyncShopData from server")
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
			"[ShopSyncClient] Stored items: " .. itemCount .. " total, " .. buyCount .. " buy, " .. sellCount .. " sell"
		)

		-- DEBUG: Log if Base.Apple is in the data
		if Shop.PlayerBuy["Base.Apple"] then
			local price = Shop.PlayerBuy["Base.Apple"].price or "unknown"
			SharedLogger.log("Shops", "[ShopSyncClient] Base.Apple found in PlayerBuy (price=" .. price .. ")")
		end
	elseif command == "SyncBuyPrices" then
		ShopSyncClient.handleSyncBuyPrices(data)
	elseif command == "SyncSellRules" then
		ShopSyncClient.handleSyncSellRules(data)
	else
		SharedLogger.log("Shops", "[ShopSyncClient] Unknown command: " .. command)
	end
end
```

### Fixed Code
```lua
function ShopSyncClient.handleServerCommand(module, command, data)
	if module ~= "Shops" then
		return
	end

	local Shop = SHOPSB42.Shop

	if command == "SyncShopData" then
		SharedLogger.log("Shops", "[ShopSyncClient] Received SyncShopData from server")
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
			"[ShopSyncClient] Stored items: " .. itemCount .. " total, " .. buyCount .. " buy, " .. sellCount .. " sell"
		)

		-- DEBUG: Log if Base.Apple is in the data
		if Shop.PlayerBuy["Base.Apple"] then
			local price = Shop.PlayerBuy["Base.Apple"].price or "unknown"
			SharedLogger.log("Shops", "[ShopSyncClient] Base.Apple found in PlayerBuy (price=" .. price .. ")")
		end
	elseif command == "SyncBuyPrices" then
		ShopSyncClient.handleSyncBuyPrices(data)
	elseif command == "SyncSellRules" then
		ShopSyncClient.handleSyncSellRules(data)
	elseif command == "SyncInitialComplete" then
		-- FIX: Signal that all initial sync data has arrived
		SharedLogger.log(
			"Shops",
			"[ShopSyncClient] Received SyncInitialComplete - buyRev=" .. (data.buyRevision or 0) .. ", sellRev=" .. (data.sellRevision or 0)
		)
		ShopSyncClient._initialSyncComplete = true
		-- Now safe for UI to open
	else
		SharedLogger.log("Shops", "[ShopSyncClient] Unknown command: " .. command)
	end
end
```

### Rationale
- `_initialSyncComplete` flag prevents UI from rendering incomplete state
- Shop only opens after all three price broadcasts received

---

## Fix #5: Guard UI Opening Until Sync Complete

### Location
**File**: `Shops/42.13.1/media/lua/client/nshopsb42/ui/ShopUI.lua`
**Function**: ShopUI `open()` or wherever UI initialization happens

### Add Guard (Pseudo-code Example)
```lua
-- In ShopUI initialization or open method:
function ShopUI:open()
    -- FIX: Guard against opening before initial sync
    if not ShopSyncClient._initialSyncComplete and not isServerOrSinglePlayer() then
        SharedLogger.log("Shops", "[ShopUI] Initial sync not complete, deferring UI open")
        -- Re-queue open event to try again after a short delay
        return false
    end
    
    -- ... proceed with normal UI open logic ...
end
```

### Rationale
- Prevents flicker from incomplete price data on initial UI open
- Ensures all revisions are initialized before UI queries them

---

## Summary of Changes

| Fix # | File | Function | Lines | Change |
|-------|------|----------|-------|--------|
| 1 | ShopFinalizeHandlerServer.lua | broadcastBuyPrices() | 127-143 | Add buyOverrides + sellRevision |
| 2 | ShopFinalizeHandlerServer.lua | broadcastSellRules() | 146-169 | Add buyRevision |
| 3 | ShopFinalizeHandlerServer.lua | sendShopDataToPlayer() | 268-330 | Add SyncInitialComplete signal |
| 4 | ShopSyncClient.lua | handleServerCommand() | 237-281 | Add SyncInitialComplete handler |
| 5 | ShopUI.lua | open() | TBD | Add guard: wait for _initialSyncComplete |

---

## Testing After Fixes

Run these scenarios to verify regressions are fixed:

1. **Test: Buy-only broadcast has buy overrides**
   ```lua
   -- Command should have: revision, buyPrices, buyOverrides, sellRevision
   ASSERT: data.buyOverrides ~= nil
   ```

2. **Test: Both revisions in each broadcast**
   ```lua
   -- SyncBuyPrices should have: buyRevision, sellRevision
   -- SyncSellRules should have: buyRevision, sellRevision
   ASSERT: BuyPrices.sellRevision == SellRules.buyRevision (same time)
   ```

3. **Test: Initial sync completes atomically**
   ```lua
   -- New player connects
   -- Should receive in order: SyncShopData, SyncBuyPrices, SyncSellRules, SyncInitialComplete
   ASSERT: _initialSyncComplete flag set
   ASSERT: UI does not open until flag set
   ```

4. **Test: Multiplayer consistency**
   ```lua
   -- Two players join
   -- Both should see same revisions after all broadcasts
   ASSERT: Player A revisions == Player B revisions
   ```

