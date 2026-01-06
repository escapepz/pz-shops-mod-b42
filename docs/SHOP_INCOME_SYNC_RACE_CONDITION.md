# Race Condition: Shop Income Not Updating for Owner on Join

## Problem Summary

When a shop owner logs out and other players make purchases from their shop, the income accumulates on the shop object in the world. When the owner logs back in and opens the Income UI, they may not see the updated income that was earned while they were offline.

**Expected Behavior:** Owner sees all income earned since they last logged in  
**Actual Behavior:** Income UI shows incomplete or stale income data

## Current Implementation

### How Income is Stored
Income is stored in the shop object's `modData`:
```lua
-- IncomeUI.lua:150-155 (reading income)
local income = IncomeUI.instance.shop:getModData().income
for k, v in pairs(income) do
    -- v.buyer = player who bought
    -- v.t.tl = coins earned
    -- v.t.tls = special coins earned
end
```

### How Income UI Loads Data
When the owner opens the Income UI:
```lua
function IncomeUI:show(player, shop)
    -- Lines 18-31
    -- Creates UI instance with reference to shop object
    -- Gets income from: shop:getModData().income
    -- Lists all income entries
end
```

The issue: **The shop object reference comes from the IncomeUI initialization**, which relies on the shop object already being loaded in the player's game world. But if the shop object's modData was modified while the owner was offline, and the world hasn't been reloaded properly, the client may have a stale reference.

### On Player Join/Reconnect (AClientInit.lua:77-129)
```lua
local function onGameStart()
    -- Sends RequestShopData to server
    sendClientCommand("nshopsb42", "RequestShopData", {})
end

Events.OnGameStart.Add(onGameStart)
```

This requests **shop configuration data** (items, prices, rules), not **world object data** (shop instances in the world, their income).

### On Server (ShopFinalizeHandlerServer.lua:272-358)
```lua
function ShopFinalizeHandler.sendShopDataToPlayer(player)
    -- Sends shop registry/config (Items, PlayerBuy, PlayerSell, prices)
    local shopData = {
        Items = Shop.Items,
        PlayerBuy = Shop.PlayerBuy,
        PlayerSell = Shop.PlayerSell,
        defaultPrice = Shop.defaultPrice,
    }
    Utilities.SendServerCommandTo(player, "nshopsb42", "SyncShopData", shopData)
end
```

This sends **configuration data**, not **world object modData** (income).

## Root Cause

**The gap:** When a player joins/reconnects:
1. **World objects ARE loaded** - PZ engine loads all shops in the world with their current modData
2. **Configuration IS synced** - Shop.Items, prices, etc. are sent to client
3. **Problem:** The Income UI reads from `shop:getModData().income` at the moment it's opened

**BUT there's a race condition:**
- If a shop object's modData.income was updated while owner was offline
- The PZ engine loads the world with the current modData (correct)
- **BUT** if there's any lag or timing issue with object replication, the client might have a different version

More likely: **The income IS loaded correctly, but the shop reference in IncomeUI is stale if the shop object was despawned/respawned or if modData events didn't fire**.

## Likely Scenarios

### Scenario 1: World Reload / Object Respawn
1. Owner logs out
2. Server performs world save with shop modData.income intact
3. Other players buy items → income accumulates
4. Server saves again with updated income
5. Owner logs back in
6. PZ loads world from save
7. **Issue:** If the shop object reference becomes invalid or modData isn't re-synchronized

### Scenario 2: Missing ModData Sync Event
1. Income is updated: `shop:getModData().income = {...}`
2. This change is NOT explicitly broadcast to the owner
3. Owner logs in later
4. They see their local cache version, not the server version
5. Income UI shows old data

### Scenario 3: Object Reference Validity
```lua
-- IncomeUI.lua line 150
local income = IncomeUI.instance.shop:getModData().income
```

If the `shop` object reference becomes invalid (despawned/unloaded) before IncomeUI reads modData, it could return nil or stale data.

## Required Fixes

### Fix 1: Force ModData Reload on Income UI Open (RECOMMENDED)
File: `Shops/42.13.1/media/lua/client/nshopsb42/ui/IncomeUI.lua` (line 18-31)

```lua
function IncomeUI:show(player, shop)
    if IncomeUI.instance == nil then
        IncomeUI.instance = IncomeUI:new(0, 0, width, height, player)
        IncomeUI.instance.shop = shop
        IncomeUI.instance:initialise()
        IncomeUI.instance:instantiate()
    end
    
    -- NEW: Re-fetch income data in case it was updated while offline
    -- This ensures we get the latest modData from the shop object
    if IncomeUI.instance.shop then
        local currentIncome = IncomeUI.instance.shop:getModData().income
        if currentIncome then
            IncomeUI.instance.tickets:clear()
            IncomeUI.instance.ticketsCache = {}
            local total = 0
            local totalSpecial = 0
            for k, v in pairs(currentIncome) do
                IncomeUI.instance.tickets:addItem(v.buyer, v)
                IncomeUI.instance.ticketsCache[k] = { item = v }
                total = total + (v.t.tl or 0)
                totalSpecial = totalSpecial + (v.t.tls or 0)
            end
            -- Update totals
            local totalFormatted = Currency.format(total)
            IncomeUI.instance.totalCoinLabel:setName("" .. totalFormatted)
            local totalSpecialFormatted = Currency.format(totalSpecial)
            IncomeUI.instance.totalSpecialCoinLabel:setName("" .. totalSpecialFormatted)
        end
    end
    
    IncomeUI.instance.pinButton:setVisible(false)
    IncomeUI.instance.collapseButton:setVisible(false)
    IncomeUI.instance:addToUIManager()
    IncomeUI.instance:setVisible(true)
    return IncomeUI.instance
end
```

### Fix 2: Refresh on Update (Secondary)
Add a method to refresh income data:

```lua
function IncomeUI:refreshIncome()
    if not self.shop then
        return
    end
    
    self.tickets:clear()
    self.ticketsCache = {}
    local total = 0
    local totalSpecial = 0
    
    local income = self.shop:getModData().income
    if not income then
        return
    end
    
    for k, v in pairs(income) do
        self.tickets:addItem(v.buyer, v)
        self.ticketsCache[k] = { item = v }
        total = total + (v.t.tl or 0)
        totalSpecial = totalSpecial + (v.t.tls or 0)
    end
    
    local totalFormatted = Currency.format(total)
    self.totalCoinLabel:setName("" .. totalFormatted)
    local totalSpecialFormatted = Currency.format(totalSpecial)
    self.totalSpecialCoinLabel:setName("" .. totalSpecialFormatted)
end

-- Call in update() if needed
function IncomeUI:update()
    ISCollapsableWindow.update(self)
    -- Can add: self:refreshIncome() if periodic refresh is needed
end
```

### Fix 3: Server-Side - Explicit Income Sync on Request (BACKUP)
Add server-side handler in `ShopCommandDispatcherServer.lua`:

```lua
function ShopCommandDispatcher.RequestIncomeData(player, args)
    local username = player:getUsername()
    local shopId = args[1] -- If passed as parameter
    
    if not shopId then
        return
    end
    
    -- Find shop in world (if needed)
    -- or if shop is passed as world object ref:
    local shop = args.shop  -- Depends on how you call this
    
    if shop and shop:getModData() then
        local income = shop:getModData().income
        Utilities.SendServerCommandTo(player, "nshopsb42", "SyncIncomeData", {
            shopId = shopId,
            income = income,
        })
    end
end
```

Then on client, add handler in `ShopCommandDispatcherClient.lua`:

```lua
function ShopCommandDispatcher.SyncIncomeData(args)
    -- Update the shop's modData with latest income
    -- This ensures Income UI sees fresh data
end
```

## Testing Checklist

- [ ] Shop owner opens shop and adds items for sale
- [ ] Shop owner closes shop and logs out (don't save world yet)
- [ ] Different player joins, buys items from shop (income is earned)
- [ ] Original owner logs back in
- [ ] Owner opens Income UI on that shop
  - Expected: Income UI shows all purchases made while offline
  - Verify: Total amount matches what buyers paid
- [ ] Owner collects income
  - Expected: Money transfers to their account
  - Verify: Shop modData.income is cleared
- [ ] Test with multiple transactions while offline
- [ ] Test with mixed coin types (regular + special coin)
- [ ] Test with server restart/world reload

## Edge Cases

1. **Multiple Shops** - Owner has multiple shops; check each one syncs income
2. **Large Income** - Shops with many transactions should show all entries
3. **Server Crash During Save** - Income loss (expected, PZ limitation)
4. **Concurrent Access** - Multiple players viewing/collecting income simultaneously

## Files to Modify

1. `Shops/42.13.1/media/lua/client/nshopsb42/ui/IncomeUI.lua` - Add refresh logic in `:show()` method
2. (Optional) `Shops/42.13.1/media/lua/client/nshopsb42/ui/IncomeUI.lua` - Add `:refreshIncome()` method
3. (Optional) `Shops/42.13.1/media/lua/server/nshopsb42/ShopCommandDispatcherServer.lua` - Add explicit income sync on request

## Severity

**MEDIUM** - Income data is usually available (PZ engine loads modData correctly), but stale references or timing issues can cause players to not see their earnings.

## Implementation Notes

- **PZ Architecture:** The game engine (`modData.transmit()`) handles persistence automatically when world saves
- **The Real Issue:** Not with persistence, but with UI cache freshness when owner logs back in
- **Simple Fix:** Always reload modData when IncomeUI opens, don't rely on cached references
- **Performance:** Reading modData is cheap, no performance concerns

## Related Code Paths

1. **World Object Sync:** `ISWorldObjectContextMenu` spawning → `playerShopUI()` in `PlayerShopContext.lua`
2. **ModData Persistence:** PZ engine auto-saves `modData` with world
3. **UI Reference:** IncomeUI stores shop reference, needs to check validity on open
