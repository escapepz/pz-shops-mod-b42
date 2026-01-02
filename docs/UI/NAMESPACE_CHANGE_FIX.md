# Namespace Change: Buy Price Live Update Fix

## Problem

Buy price live updates are not working on the "All" tab after the new price hooks implementation.

**Root Cause**: The namespace for calculated buy prices was changed, and the client is not properly referencing the updated prices.

## Namespace Changes in New Implementation

### Old Code (Phase 0-2)
```lua
Shop.BuyPrices = { ... }  -- or similar direct structure
```

### New Code (Phase 3+)
```lua
Shop.CalculatedPrices = {
    buyPrices = { },
    sellPrices = { }
}
```

## Current Problem Flow

1. **Server sends calculated buy prices**: `SyncBuyPrices` command
2. **Client receives and stores**: `Shop.CalculatedPrices.buyPrices[itemId]`
3. **But ShopUI.calcBuyPrice()** tries to use:
   - Line 26: `Shop.CalculatedPrices or {}` ✓ (correct namespace)
   - Line 27: `calculatedPrices.buyPrices[itemId]` ✓ (correct access)
   - Line 46: `Shop.PriceModifiers or {}` ✗ (wrong for buy - this is empty, server-only)

4. **Tab reload issue**: When switching to "All" tab, cached items are used with old prices

## Solution

The fix should ensure that when the "All" tab is reloaded after price changes:

1. The cache is properly invalidated for the "All" tab
2. When items are reloaded, `calcBuyPrice()` gets the correct reference to `Shop.CalculatedPrices.buyPrices`
3. The server-calculated prices are properly merged/updated

### Fix Location 1: ShopSyncClient.lua - Initialize Properly

Ensure `Shop.CalculatedPrices` is accessible as a single reference:

```lua
function ShopSyncClient.Initialize()
    local Shop = SHOPSB42.Shop
    Shop.BuyPriceRevision = nil
    Shop.SellRuleRevision = nil
    
    -- OPTION A: Keep nested structure but ensure reference stability
    Shop.CalculatedPrices = Shop.CalculatedPrices or {}
    Shop.CalculatedPrices.buyPrices = Shop.CalculatedPrices.buyPrices or {}
    Shop.CalculatedPrices.sellPrices = Shop.CalculatedPrices.sellPrices or {}
    
    -- Also expose for backward compatibility (if needed)
    Shop.BuyPrices = Shop.CalculatedPrices.buyPrices
    Shop.SellPrices = Shop.CalculatedPrices.sellPrices
    
    Shop.SellModifiers = {}
    Shop.SellOverrides = {}
    
    ShopSyncClient.pricesChangedWhileClosed = false
    Events.OnServerCommand.Add(ShopSyncClient.handleServerCommand)
    SharedLogger.log("Shops", "[ShopSyncClient] Initialized - event listener registered")
end
```

### Fix Location 2: ShopUI.lua - Use Correct Namespace

Modify `calcBuyPrice()` to properly reference the nested structure:

```lua
local function calcBuyPrice(itemId, player, basePrice)
    if not basePrice then
        return nil
    end

    -- Check if server calculated this price (server-only hooks)
    local calculatedPrices = Shop.CalculatedPrices or {}
    
    -- FIXED: Use the actual nested structure
    if calculatedPrices.buyPrices and calculatedPrices.buyPrices[itemId] then
        local price = calculatedPrices.buyPrices[itemId]
        -- DEBUG logging...
        return price
    end

    -- Fallback: Buy price modifiers are server-only, not previewed on client
    -- So we return base price if no server-calculated price exists
    return basePrice
end
```

### Fix Location 3: ShopUI.lua - Cache Invalidation for All Tab

In the item loading section (around line 638-676), ensure caches are validated:

```lua
-- When loading items for a tab
if tabType == Tab.All then
    -- For All tab, ALWAYS recalculate prices from server, don't use cache
    -- because it may contain stale prices
    self.shopItemsCache[tabType] = nil
    self.reloadItems = true
end
```

Or better approach - when `onActivateView()` is called with rebuild:

```lua
if self.reloadItems then
    shopItems:clear()
    self.shopItemsCache[self.panel.activeView.view.tabType] = nil  -- Clear cache
end
```

## Testing the Fix

1. Open shop, wait for initial load
2. Change a buy price modifier (test hook that modifies Apple buy price)
3. Verify buy prices update live on ALL tabs, especially "All" tab
4. Switch away from "All" tab and back - should still show updated price

## Related Code References

- `ShopSyncClient.lua`: Lines 76-93 (Initialize function)
- `ShopUI.lua`: Lines 20-68 (calcBuyPrice function)
- `ShopUI.lua`: Lines 638-676 (Item loading for tabs)
- `ShopUI.lua`: Lines 1159-1183 (rebuildActiveTab function)

