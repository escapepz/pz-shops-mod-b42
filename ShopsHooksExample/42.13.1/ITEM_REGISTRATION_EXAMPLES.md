# ShopsHooksExample — Item Registration & Listing Examples

This document provides comprehensive examples for extending ShopsHooksExample with item registration, buy/sell configuration, and whitelist/blacklist controls.

## Overview

The Shops mod supports three main extension hooks:

1. **Buy Items** - Register items players can purchase from the shop
2. **Sell Items** - Configure which items the shop will buy from players (with whitelist/blacklist control)
3. **Price Hooks** - Modify or override prices dynamically (see README.md)

---

## Hook System Overview

### Buy Item Registration Hook

**Event**: `ShopEvents.registerOnShopRegisterItems(callback)`

Called during initialization to allow external mods to register buy items.

**Function signature**:

```lua
function registerMyBuyItems()
    -- Call Shop.RegisterItem() for each item
end
```

**Available at**: Server-only (checked via `Utilities.IsServerOrSinglePlayer()`)

---

### Sell Item Registration Hook

**Event**: `ShopSellEvents.registerOnShopRegisterSellItems(callback)`

Called during initialization to allow external mods to register sell items and configure whitelist/blacklist.

**Function signature**:

```lua
function registerMySellItems()
    -- Call Shop.RegisterSellItem() for each item
end
```

**Available at**: Server-only

---

## Example 1: Basic Buy Item Registration

Register a single item for purchase from the shop.

### Implementation

**File**: `media/lua/server/nshopsb42/ShopsHooksExampleItems.lua`

```lua
-- ShopsHooksExampleItems.lua
-- Item registration for ShopsHooksExample
-- Extends SHOPSB42 namespace

local Utilities = require("nshopsb42/utils/Utilities")
local SharedLogger = require("nshopsb42/utils/SharedLogger")

SHOPSB42.ShopsHooksExampleItems = SHOPSB42.ShopsHooksExampleItems or {}
local Items = SHOPSB42.ShopsHooksExampleItems

-- Register buy items (items players can purchase from shop)
function Items.registerBuyItems()
    if not Utilities.IsServerOrSinglePlayer() then
        return
    end

    local Shop = SHOPSB42.Shop
    if not Shop or not Shop.RegisterItem then
        SharedLogger.log("Shops", "[ShopsHooksExample] ERROR: Shop.RegisterItem not available")
        return
    end

    -- Register a canned food item
    -- Players can buy this from the shop at the specified price
    Shop.RegisterItem("Base.CannedBolognese", {
        tab = SHOPSB42.Tab.Food,
        price = 8,
        items = 50,  -- Stock quantity
    })

    SharedLogger.log(
        "Shops",
        "[ShopsHooksExample] Registered buy item: Base.CannedBolognese (price=8, stock=50)"
    )

    -- Register a weapon item
    Shop.RegisterItem("Base.AxeSteel", {
        tab = SHOPSB42.Tab.Weapons,
        price = 25,
        items = 10,
        brokenPrice = 5,  -- Price if item is broken/damaged
    })

    SharedLogger.log(
        "Shops",
        "[ShopsHooksExample] Registered buy item: Base.AxeSteel (price=25, broken=5, stock=10)"
    )
end

-- Register sell items (items shop will buy from players)
function Items.registerSellItems()
    if not Utilities.IsServerOrSinglePlayer() then
        return
    end

    local Shop = SHOPSB42.Shop
    if not Shop or not Shop.RegisterSellItem then
        SharedLogger.log("Shops", "[ShopsHooksExample] ERROR: Shop.RegisterSellItem not available")
        return
    end

    -- Register items the shop will buy
    -- Without blacklist = shop accepts this item when in blacklist mode
    Shop.RegisterSellItem("Base.CannedBolognese", {
        price = 4,  -- Sell price (typically half buy price)
    })

    SharedLogger.log(
        "Shops",
        "[ShopsHooksExample] Registered sell item: Base.CannedBolognese (sell=4)"
    )

    Shop.RegisterSellItem("Base.AxeSteel", {
        price = 12,
    })

    SharedLogger.log(
        "Shops",
        "[ShopsHooksExample] Registered sell item: Base.AxeSteel (sell=12)"
    )
end

return Items
```

### Registration in Init File

**File**: `media/lua/server/nshopsb42/ShopsHooksExampleInit.lua`

Add these lines to your `initialize()` function:

```lua
-- Get Shop events
local ShopEvents = SHOPSB42.ShopEvents
local ShopSellEvents = SHOPSB42.ShopSellEvents

if ShopEvents and ShopEvents.registerOnShopRegisterItems then
    ShopEvents.registerOnShopRegisterItems(Items.registerBuyItems)
    SharedLogger.log("Shops", "[ShopsHooksExample] Registered buy items hook")
end

if ShopSellEvents and ShopSellEvents.registerOnShopRegisterSellItems then
    ShopSellEvents.registerOnShopRegisterSellItems(Items.registerSellItems)
    SharedLogger.log("Shops", "[ShopsHooksExample] Registered sell items hook")
end
```

---

## Example 2: Buy Items with Conditional Registration

Register items only if certain conditions are met.

```lua
-- ShopsHooksExampleItems.lua (extended)

function Items.registerConditionalBuyItems()
    if not Utilities.IsServerOrSinglePlayer() then
        return
    end

    local Shop = SHOPSB42.Shop
    if not Shop or not Shop.RegisterItem then
        return
    end

    local SandboxVars = SandboxVars or {}

    -- Register high-end weapon only if sandbox var enables it
    if SandboxVars.ShopsHooksExample_EnablePistols then
        Shop.RegisterItem("Base.Pistol9mm", {
            tab = SHOPSB42.Tab.Weapons,
            price = 120,
            items = 5,
        })
        SharedLogger.log(
            "Shops",
            "[ShopsHooksExample] Registered conditional item: Base.Pistol9mm"
        )
    end

    -- Register medical items based on difficulty
    if not SandboxVars.SurvivalMode then
        Shop.RegisterItem("Base.FirstAidKit", {
            tab = SHOPSB42.Tab.FirstAid,
            price = 45,
            items = 20,
        })
    end
end
```

---

## Example 3: Whitelist Mode (Sell Items)

Configure which items can be sold to the shop using whitelist mode.

### Setup

In `ShopsHooksExampleState.lua`, add configuration:

```lua
SHOPSB42.ShopsHooksExampleState = SHOPSB42.ShopsHooksExampleState or {}
local State = SHOPSB42.ShopsHooksExampleState

-- Whitelist mode: Set Shop.SellisWhitelist to true
-- Only items explicitly registered can be sold
State.enableWhitelistMode = false  -- Set to true to enable

function State.setupWhitelistMode()
    if State.enableWhitelistMode then
        SHOPSB42.Shop.SellisWhitelist = true
        SharedLogger.log("Shops", "[ShopsHooksExample] Enabled whitelist mode for sell items")
    end
end

return State
```

### Register Only Whitelisted Items

```lua
-- ShopsHooksExampleItems.lua (whitelist mode)

function Items.registerWhitelistSellItems()
    if not Utilities.IsServerOrSinglePlayer() then
        return
    end

    local Shop = SHOPSB42.Shop
    if not Shop or not Shop.RegisterSellItem then
        return
    end

    -- In whitelist mode, ONLY these items can be sold
    local whitelistedItems = {
        "Base.CannedBolognese",
        "Base.AxeSteel",
        "Base.Apple",
        "Base.Banana",
    }

    for _, itemId in ipairs(whitelistedItems) do
        Shop.RegisterSellItem(itemId, {
            price = 5,  -- Generic sell price
        })
    end

    SharedLogger.log(
        "Shops",
        "[ShopsHooksExample] Registered " .. #whitelistedItems .. " whitelisted sell items"
    )
end
```

---

## Example 4: Blacklist Mode (Sell Items)

Configure which items CANNOT be sold using blacklist mode (default).

### Setup

```lua
-- ShopsHooksExampleState.lua (blacklist mode)

local State = SHOPSB42.ShopsHooksExampleState

-- Blacklist mode is default
-- All items can be sold EXCEPT those marked blacklisted=true
State.enableBlacklistMode = true

function State.setupBlacklistMode()
    SHOPSB42.Shop.SellisWhitelist = false  -- Ensure blacklist mode
    SharedLogger.log("Shops", "[ShopsHooksExample] Enabled blacklist mode for sell items")
end
```

### Blacklist Specific Items

```lua
-- ShopsHooksExampleItems.lua (blacklist mode)

function Items.registerBlacklistSellItems()
    if not Utilities.IsServerOrSinglePlayer() then
        return
    end

    local Shop = SHOPSB42.Shop
    if not Shop or not Shop.RegisterSellItem then
        return
    end

    -- Items the shop will NOT buy (blacklisted)
    local blacklistedItems = {
        "Base.C4",
        "Base.Bomb",
        "Base.RadioFrequencyModulator",
    }

    for _, itemId in ipairs(blacklistedItems) do
        Shop.RegisterSellItem(itemId, {
            blacklisted = true,
        })
    end

    SharedLogger.log(
        "Shops",
        "[ShopsHooksExample] Blacklisted " .. #blacklistedItems .. " items from sale"
    )
end
```

---

## Example 5: Complex Sell Configuration with Multiple Categories

Register items with different prices and special configurations.

```lua
-- ShopsHooksExampleItems.lua (complex sell config)

function Items.registerComplexSellItems()
    if not Utilities.IsServerOrSinglePlayer() then
        return
    end

    local Shop = SHOPSB42.Shop
    if not Shop or not Shop.RegisterSellItem then
        return
    end

    -- Food items (low value)
    Shop.RegisterSellItem("Base.CannedBolognese", { price = 4 })
    Shop.RegisterSellItem("Base.Apple", { price = 2 })
    Shop.RegisterSellItem("Base.Banana", { price = 2 })

    -- Weapons (higher value, but blacklist damaged ones)
    Shop.RegisterSellItem("Base.AxeSteel", { price = 12 })
    Shop.RegisterSellItem("Base.Hammer", { price = 8 })
    Shop.RegisterSellItem("Base.Shovel", { price = 6 })

    -- Valuable items (blacklist damaged versions)
    Shop.RegisterSellItem("Base.Radio", { price = 35 })
    Shop.RegisterSellItem("Base.Watch", { price = 20 })

    -- Explicitly blacklist extremely dangerous items
    Shop.RegisterSellItem("Base.Explosives", { blacklisted = true })
    Shop.RegisterSellItem("Base.Bomb", { blacklisted = true })

    SharedLogger.log(
        "Shops",
        "[ShopsHooksExample] Registered complex sell item configuration"
    )
end
```

---

## Example 6: Combining Item Registration with Price Hooks

Register items AND apply dynamic pricing to them.

```lua
-- ShopsHooksExampleInit.lua (combined)

function ShopsHooksExample.initialize()
    local ShopEvents = SHOPSB42.ShopEvents
    local ShopSellEvents = SHOPSB42.ShopSellEvents
    local ShopPriceEvents = SHOPSB42.ShopPriceEvents

    -- Step 1: Register items
    if ShopEvents and ShopEvents.registerOnShopRegisterItems then
        ShopEvents.registerOnShopRegisterItems(Items.registerBuyItems)
    end

    if ShopSellEvents and ShopSellEvents.registerOnShopRegisterSellItems then
        ShopSellEvents.registerOnShopRegisterSellItems(Items.registerSellItems)
    end

    -- Step 2: Apply dynamic pricing to registered items
    if ShopPriceEvents then
        ShopPriceEvents.registerOnShopModifyBuyPrice(
            ShopsHooksExampleHooks.modifyBuyPrices
        )
        ShopPriceEvents.registerOnShopModifySellPrice(
            ShopsHooksExampleHooks.modifySellPrices
        )
    end

    SharedLogger.log("Shops", "[ShopsHooksExample] Initialization complete")
end
```

### Matching Price Hooks

```lua
-- ShopsHooksExampleHooks.lua (matching hooks)

function Hooks.modifyBuyPrices(player, itemId, basePrice, context, modifiers)
    -- Reduce prices for our registered items
    if itemId == "Base.CannedBolognese" then
        table.insert(modifiers, { multiplier = 0.85, label = "example_food_discount" })
    elseif itemId == "Base.AxeSteel" then
        table.insert(modifiers, { multiplier = 0.9, label = "example_weapon_discount" })
    end
end

function Hooks.modifySellPrices(player, item, basePrice, context, modifiers)
    local itemId = item:getFullType()

    -- Pay more for items in good condition
    if itemId == "Base.AxeSteel" then
        local condition = item:getCondition()
        if condition >= 90 then
            table.insert(modifiers, { multiplier = 1.1, label = "example_excellent_condition" })
        end
    end
end
```

---

## Example 7: Whitelist Mode with Dynamic Item Additions

Register whitelisted items at runtime (useful for player shops or admin commands).

```lua
-- ShopsHooksExampleItems.lua (dynamic whitelist)

function Items.setupDynamicWhitelist()
    -- Enable whitelist mode
    SHOPSB42.Shop.SellisWhitelist = true

    -- Track dynamically added items
    State.dynamicWhitelistItems = State.dynamicWhitelistItems or {}
end

function Items.addWhitelistItem(itemId, price)
    if not SHOPSB42.Shop or not SHOPSB42.Shop.RegisterSellItem then
        return false
    end

    -- Register the item
    SHOPSB42.Shop.RegisterSellItem(itemId, { price = price or 5 })

    -- Track it
    State.dynamicWhitelistItems[itemId] = price or 5

    SharedLogger.log(
        "Shops",
        "[ShopsHooksExample] Dynamically added to whitelist: " .. itemId .. " (price=" .. (price or 5) .. ")"
    )

    -- Trigger price resync
    SHOPSB42.ShopFinalizeHandler.onPriceHooksChanged()

    return true
end

function Items.removeWhitelistItem(itemId)
    -- Note: This doesn't remove items from registry (Shops doesn't support removal)
    -- Instead, update internal tracking for logic purposes
    if State.dynamicWhitelistItems then
        State.dynamicWhitelistItems[itemId] = nil
        SharedLogger.log("Shops", "[ShopsHooksExample] Removed from whitelist: " .. itemId)
    end
end

function Items.listWhitelistedItems()
    local list = {}
    if State.dynamicWhitelistItems then
        for itemId, price in pairs(State.dynamicWhitelistItems) do
            table.insert(list, itemId .. " (" .. price .. ")")
        end
    end
    return list
end
```

---

## Whitelist vs Blacklist Mode Summary

| Aspect           | Whitelist Mode                       | Blacklist Mode                                 |
| ---------------- | ------------------------------------ | ---------------------------------------------- |
| **Default**      | `false`                              | `true`                                         |
| **Control**      | `SHOPSB42.Shop.SellisWhitelist`      | Same flag                                      |
| **What Sells**   | ONLY registered items                | All items EXCEPT blacklisted                   |
| **Use Case**     | Curated shop (restricted inventory)  | Open shop (most items allowed)                 |
| **Example**      | Admin shop sells only specific items | Default shop blacklists explosives/quest items |
| **Registration** | Must register every sellable item    | Only register blacklisted items                |

**Toggle at runtime**:

```lua
-- Enable whitelist mode
SHOPSB42.Shop.SellisWhitelist = true

-- Switch back to blacklist
SHOPSB42.Shop.SellisWhitelist = false
```

---

## Shop.RegisterItem() Reference

Register items for purchase from the shop.

```lua
Shop.RegisterItem(itemId, definition)
```

**Parameters**:

- `itemId` (string): Full item type (e.g., "Base.Apple")
- `definition` (table):
  - `tab` (string): Tab category (Tab.Food, Tab.Weapons, etc.)
  - `price` (number): Buy price from shop
  - `items` (number, optional): Stock quantity (default: no limit)
  - `brokenPrice` (number, optional): Price if item is broken/damaged
  - `notes` (string, optional): Description text

**Example**:

```lua
Shop.RegisterItem("Base.Apple", {
    tab = SHOPSB42.Tab.Food,
    price = 15,
    items = 100,
    notes = "Fresh apples"
})
```

---

## Shop.RegisterSellItem() Reference

Configure which items the shop will buy from players.

```lua
Shop.RegisterSellItem(itemId, definition)
```

**Parameters**:

- `itemId` (string): Full item type
- `definition` (table):
  - `price` (number): Price shop pays for this item
  - `blacklisted` (boolean, optional): If `true`, prevents sale in blacklist mode
  - `specialCoin` (string, optional): Special currency type

**Example**:

```lua
-- Item can be sold (blacklist mode)
Shop.RegisterSellItem("Base.Apple", { price = 5 })

-- Item cannot be sold (blacklist mode)
Shop.RegisterSellItem("Base.Bomb", { blacklisted = true })
```

---

## Complete Integration Example

Full file showing all patterns together:

**File**: `media/lua/server/nshopsb42/ShopsHooksExampleItemsComplete.lua`

```lua
-- ShopsHooksExampleItemsComplete.lua
-- Complete item registration with buy, sell, whitelist, and price hooks

local Utilities = require("nshopsb42/utils/Utilities")
local SharedLogger = require("nshopsb42/utils/SharedLogger")

SHOPSB42.ShopsHooksExampleItemsComplete = SHOPSB42.ShopsHooksExampleItemsComplete or {}
local Items = SHOPSB42.ShopsHooksExampleItemsComplete

-- Buy items
function Items.registerBuyItems()
    if not Utilities.IsServerOrSinglePlayer() then return end

    local Shop = SHOPSB42.Shop
    if not Shop or not Shop.RegisterItem then return end

    -- Food
    Shop.RegisterItem("Base.CannedBolognese", {
        tab = SHOPSB42.Tab.Food,
        price = 8,
        items = 50,
    })
    Shop.RegisterItem("Base.Apple", {
        tab = SHOPSB42.Tab.Food,
        price = 2,
        items = 100,
    })

    -- Weapons
    Shop.RegisterItem("Base.AxeSteel", {
        tab = SHOPSB42.Tab.Weapons,
        price = 25,
        items = 10,
        brokenPrice = 5,
    })

    SharedLogger.log("Shops", "[ShopsHooksExample] Registered buy items")
end

-- Sell items (with blacklist)
function Items.registerSellItems()
    if not Utilities.IsServerOrSinglePlayer() then return end

    local Shop = SHOPSB42.Shop
    if not Shop or not Shop.RegisterSellItem then return end

    -- Items shop will buy
    Shop.RegisterSellItem("Base.CannedBolognese", { price = 4 })
    Shop.RegisterSellItem("Base.Apple", { price = 1 })
    Shop.RegisterSellItem("Base.AxeSteel", { price = 12 })

    -- Items shop will NOT buy
    Shop.RegisterSellItem("Base.Bomb", { blacklisted = true })
    Shop.RegisterSellItem("Base.C4", { blacklisted = true })

    SharedLogger.log("Shops", "[ShopsHooksExample] Registered sell items")
end

return Items
```

---

## Testing

Enable debug logging in server logs:

```bash
# Check for successful registration
tail -f Logs/Server/*_Shops.txt | grep ShopsHooksExample
```

Expected output:

```
[ShopsHooksExample] Registered buy items
[ShopsHooksExample] Registered sell items
[ShopsHooksExample] Registered buy item: Base.CannedBolognese
[ShopsHooksExample] Registered sell item: Base.AxeSteel (sell=12)
```

---

## Common Issues

### Items Don't Appear in Shop

1. Check that `registerBuyItems()` is called via `ShopEvents.registerOnShopRegisterItems()`
2. Verify item IDs exist in the game (check logs for item registration)
3. Ensure mods are loaded in correct order (Shops before ShopsHooksExample)

### Can't Sell Items (Whitelist Mode)

1. Verify `SHOPSB42.Shop.SellisWhitelist = true` is set
2. Ensure items are registered via `registerSellItems()` hook
3. Check logs for registration errors

### Wrong Sell Prices

1. Verify `Shop.RegisterSellItem()` price parameter
2. Check if price hooks are modifying the price
3. Look for conflicting mods

---

## References

- **Shops API**: `.libraries/library/lua/` for engine type definitions
- **Price Hooks**: See README.md for buy/sell price hook examples
- **Default Items**: `Shops/ShopItems/*.lua` for vanilla examples
