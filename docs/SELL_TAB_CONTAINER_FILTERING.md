# NPC/Kiosk Shop - Sell Tab Container Filtering

## Problem Statement

The Sell tab in the NPC/Kiosk shop UI currently lists all items that can be sold, including bags/containers with items inside them. This can create unintuitive UX:

1. **Player sees a backpack in Sell list** → Clicks to sell backpack
2. **Shop rejects sale** → Because backpack has items inside (server-side check prevents selling non-empty containers)
3. **Poor UX** → Player is confused why they can't sell the backpack they selected

**Desired Behavior:** Filter out containers that have items inside them from the Sell tab listing. Only show empty bags/containers.

## Current Implementation

### Sell Tab Population (ShopUI.lua:770-840)
```lua
if tabType == Tab.Sell then
    -- ... button setup ...
    local inventory = character:getInventory():getItems()
    for i = 0, inventory:size() - 1 do
        local item = inventory:get(i)
        local itemType = item:getFullType()
        
        -- Filter: Not equipped, not favorite, not currency
        if not (item:isEquipped() or item:isFavorite() or Currency.Coins[itemType]) then
            local canSell = false
            
            -- Whitelist/Blacklist check
            if Shop.SellisWhitelist then
                canSell = itemSell ~= nil
            else
                canSell = not (itemSell and itemSell.blacklisted)
            end
            
            -- Add to Sell list if can sell
            if canSell then
                -- ... create item entry ...
                if price > 0 then
                    shopItems:addItem(itemType, v)  -- NO CHECK for containers with items!
                end
            end
        end
    end
end
```

### Container Detection (ShopTabUI.lua:411-414)
```lua
if selectedRow.item.invItem and selectedRow.item.invItem:IsInventoryContainer() then
    ContainerViewerUI:show(selectedRow.item.invItem)  -- Browse button works
    return
end
```

The code can detect containers but doesn't filter them from the Sell listing.

### Server-Side Validation (Likely exists but not checked)
On the server, there should be validation that prevents selling non-empty containers. The client-side fix makes this UX smoother by not showing them in the first place.

## Required Fix

### Location
File: `Shops/42.13.1/media/lua/client/nshopsb42/ui/ShopUI.lua` (lines 770-840)

### Solution
Add a check to skip containers with items inside:

```lua
if tabType == Tab.Sell then
    tab.moveAllButton.enable = true
    tab.moveAllButton:setVisible(true)
    shopItems:clear()
    if not self.viewMode then
        self.sellCartButton.enable = false
        self.sellCartButton:setVisible(true)
        self.buyCartButton.enable = false
        self.buyCartButton:setVisible(false)
    end
    local inventory = character:getInventory():getItems()
    for i = 0, inventory:size() - 1 do
        local item = inventory:get(i)
        local itemType = item:getFullType()
        local playerSell = Shop.PlayerSell or {}
        local itemSell = playerSell[itemType]
        local isBroken = item:isBroken()
        
        -- Original filter: not equipped, not favorite, not currency
        if not (item:isEquipped() or item:isFavorite() or Currency.Coins[itemType]) then
            -- NEW: Skip containers with items inside
            if item:IsInventoryContainer() then
                local containerInventory = item:getInventory()
                if containerInventory and not containerInventory:isEmpty() then
                    goto continue  -- Skip this container
                end
            end
            
            local canSell = false
            
            if Shop.SellisWhitelist then
                canSell = itemSell ~= nil
            else
                canSell = not (itemSell and itemSell.blacklisted)
            end
            
            if canSell then
                local v = {}
                v.type = itemType
                local price = Shop.defaultPrice
                if isBroken then
                    price = Shop.defaultPriceBroken
                end
                if itemSell then
                    v.specialCoin = itemSell.specialCoin
                    if isBroken then
                        price = itemSell.priceBroken or Shop.defaultPriceBroken
                    else
                        price = itemSell.price or Shop.defaultPrice
                    end
                end
                v.priceFull = price
                price = Nfunction.drainablePrice(item, price)
                v.basePrice = price
                local context = {
                    shopId = self.shop and self.shop:getName() or "Unknown",
                    quantity = 1,
                    isSpecialCoin = v.specialCoin or false,
                    isBroken = isBroken,
                }
                local calculatedPrice = calcSellPrice(item, character, price)
                local dynamicPrice = calculatedPrice or Shop.resolvePlayerSellPrice(character, item, context)
                v.price = dynamicPrice or price
                v.id = item:getID()
                v.name = Nfunction.trimString(item:getName(), 42)
                v.invItem = item
                if price > 0 then
                    shopItems:addItem(itemType, v)
                end
            end
            
            ::continue::  -- Goto label for skipping containers with items
        end
    end
    self.shopItemsCache[tabType] = shopItems.items
    return
end
```

### Alternative (Cleaner) - Extract to Helper Function

```lua
-- Add at top of ShopUI.lua or in a shared utils module
local function isContainerWithItems(item)
    if not item:IsInventoryContainer() then
        return false
    end
    local inventory = item:getInventory()
    return inventory and not inventory:isEmpty()
end

-- Then in Sell tab population:
if tabType == Tab.Sell then
    -- ... existing code ...
    for i = 0, inventory:size() - 1 do
        local item = inventory:get(i)
        
        if not (item:isEquipped() or item:isFavorite() or Currency.Coins[itemType]) then
            -- Skip containers that have items inside
            if isContainerWithItems(item) then
                goto continue
            end
            
            -- ... rest of existing logic ...
            
            ::continue::
        end
    end
end
```

## Testing Checklist

- [ ] Open NPC/Kiosk shop with a Sell tab
- [ ] Player inventory has: empty backpack, full backpack, regular items
- [ ] Sell tab shows: empty backpack, regular items
- [ ] Sell tab DOES NOT show: full backpack
- [ ] Browse button still works on empty backpacks (can view empty contents)
- [ ] Broken containers with items → also filtered out
- [ ] Favored containers with items → also filtered out (if not already excluded)
- [ ] Currency containers → excluded by Currency.Coins check (verify this works)

## Edge Cases to Consider

1. **Nested Containers** - If a container has sub-containers with items, current check only looks at direct items. Should be fine for most use cases.
2. **Broken Containers** - A broken container with items should still be filtered out.
3. **Large Inventories** - The `isEmpty()` check is O(1) in most implementations, so performance should be fine.
4. **Multi-tab Shop** - This change only affects Sell tab. Buy/All tabs should be unaffected.

## Files to Modify

1. `Shops/42.13.1/media/lua/client/nshopsb42/ui/ShopUI.lua` - Add container check in Sell tab population (lines 788-840)

## Severity

**LOW-MEDIUM** - UX improvement. Not a critical bug, but improves player experience and prevents confusion.

## Related Issues

- Server-side validation for empty containers should exist to prevent exploits
- Consider adding a tooltip when hovering over a container: "Empty items before selling"
- Consider adding a "Move All" button equivalent for containers (move all contents out, then sell)

## Implementation Priority

After race condition fix (CRITICAL). This is a UX improvement, not a bug.
