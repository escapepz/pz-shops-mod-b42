# Shop Extension API (B42-Compliant)

This document describes the **official, supported way** for external mods to integrate with the Project Zomboid Shop system in **Build 42.13+**.

---

## Quick Start

### Register Items via Event

```lua
-- In your mod's shared Lua file (e.g., MyAddon_ShopExtension.lua)
ShopEvents.registerOnShopRegisterItems(function()
    Shop.RegisterItem("MyMod.CustomHammer", {
        tab = "Weapons",
        price = 150,
        items = { { item = "Base.Hammer" } }
    })
end)
```

### Register Sell Items via Event

```lua
ShopSellEvents.registerOnShopRegisterSellItems(function()
    Shop.RegisterSellItem("Base.CustomScrap", { price = 15 })
end)
```

### Hook into Price Calculations

```lua
-- Modify buy prices
ShopPriceEvents.registerOnShopModifyBuyPrice(function(player, itemId, base, context, modifiers)
    table.insert(modifiers, { multiplier = 0.9 })  -- 10% discount
end)

-- Override buy prices completely
ShopPriceEvents.registerOnShopOverrideBuyPrice(function(player, itemId, price, context)
    if itemId:match("Admin") then return 0 end
    return nil  -- use calculated price
end)

-- Modify sell prices
ShopPriceEvents.registerOnShopModifySellPrice(function(player, item, base, context, modifiers)
    if item:getCondition() < 50 then
        table.insert(modifiers, { multiplier = 0.5 })
    end
end)

-- Override sell prices completely
ShopPriceEvents.registerOnShopOverrideSellPrice(function(player, item, price, context)
    if item:getFullType() == "Base.Priceless" then return 0 end
    return nil  -- use calculated price
end)
```

---

## Event System (B42-Safe Custom Events)

The Shop system uses **Lua callback dispatchers**, not engine events. This is the **correct B42 pattern** for custom events (see `docs/CUSTOM_EVENTS.md`).

### How It Works

1. **During mod load**, your mod registers a callback function
2. **During Shop initialization**, the callbacks are executed in order
3. **Callbacks can call `Shop.RegisterItem()` directly**

This is deterministic, MP-safe, and extensible.

---

## API Reference

### Item Registration

#### `ShopEvents.registerOnShopRegisterItems(callback)`

Register a callback to be executed during shop item initialization.

**Parameters:**
- `callback` (function) - Function to call with no arguments. Inside, call `Shop.RegisterItem()`.

**Example:**

```lua
ShopEvents.registerOnShopRegisterItems(function()
    for _, item in ipairs(MY_CUSTOM_ITEMS) do
        Shop.RegisterItem(item.id, {
            tab = item.tab,
            price = item.price,
            items = { { item = item.itemType } }
        })
    end
end)
```

#### `Shop.RegisterItem(itemId, def)`

Register a single item in the shop. Call this **inside your `registerOnShopRegisterItems` callback**.

**Parameters:**

| Parameter | Type   | Required | Description                               |
| --------- | ------ | -------- | ----------------------------------------- |
| `itemId`  | string | ✔        | Unique item ID (e.g., `"Base.Hammer"`)  |
| `def`     | table  | ✔        | Item definition (see below)               |

**Item Definition:**

```lua
{
    tab = "Weapons",           -- Required: tab name
    price = 100,               -- Required: base price
    items = {                  -- Optional: bundled items
        { item = "Base.Hammer" },
        { item = "Base.Axe" }
    },
    brokenPrice = 10,          -- Optional: broken item price
    notes = "A custom weapon"  -- Optional: description
}
```

---

### Sell Item Registration

#### `ShopSellEvents.registerOnShopRegisterSellItems(callback)`

Register a callback to be executed during sell registry initialization.

**Parameters:**
- `callback` (function) - Function to call with no arguments. Inside, call `Shop.RegisterSellItem()`.

**Example:**

```lua
ShopSellEvents.registerOnShopRegisterSellItems(function()
    Shop.RegisterSellItem("MyMod.CustomScrap", { price = 25 })
    Shop.RegisterSellItem("Base.Junk", { blacklisted = true })  -- cannot be sold
end)
```

#### `Shop.RegisterSellItem(itemId, def)`

Register an item that can be sold to the shop. Call this **inside your `registerOnShopRegisterSellItems` callback**.

**Parameters:**

| Parameter | Type   | Required | Description                                    |
| --------- | ------ | -------- | ---------------------------------------------- |
| `itemId`  | string | ✔        | Item type ID (e.g., `"Base.ScrapMetal"`)     |
| `def`     | table  | ✔        | Sell definition (see below)                    |

**Sell Definition:**

```lua
{
    price = 50,           -- Required: base sell price
    blacklisted = false   -- Optional: if true, item cannot be sold
}
```

---

### Price Hooks

#### `ShopPriceEvents.registerOnShopModifyBuyPrice(callback)`

Register a callback to modify buy price calculations.

**Callback signature:**

```lua
function(player, itemId, basePrice, context, modifiers)
    -- player: ISCharacter
    -- itemId: string (item ID being bought)
    -- basePrice: number (base price from Shop.Items)
    -- context: table (contextual data)
    -- modifiers: table (array to insert multipliers/additions)
end
```

**Example - Loyalty discount:**

```lua
ShopPriceEvents.registerOnShopModifyBuyPrice(function(player, itemId, base, ctx, mods)
    if player:HasTrait("Loyal") then
        table.insert(mods, { multiplier = 0.85 })  -- 15% discount
    end
end)
```

---

#### `ShopPriceEvents.registerOnShopOverrideBuyPrice(callback)`

Register a callback to completely override buy prices.

**Callback signature:**

```lua
function(player, itemId, calculatedPrice, context)
    -- Returns: price (number) or nil (use calculated price)
end
```

**Example - Admin items are free:**

```lua
ShopPriceEvents.registerOnShopOverrideBuyPrice(function(player, itemId, price, ctx)
    if player:IsAdmin() and itemId:match("Admin") then
        return 0
    end
    return nil  -- use calculated price
end)
```

---

#### `ShopPriceEvents.registerOnShopModifySellPrice(callback)`

Register a callback to modify sell price calculations.

**Callback signature:**

```lua
function(player, item, basePrice, context, modifiers)
    -- player: ISCharacter
    -- item: InventoryItem (actual item being sold)
    -- basePrice: number (from Shop.Sell or defaultPrice)
    -- context: table (contextual data)
    -- modifiers: table (array to insert multipliers/additions)
end
```

**Example - Condition-based pricing:**

```lua
ShopPriceEvents.registerOnShopModifySellPrice(function(player, item, base, ctx, mods)
    local condition = item:getCondition()
    if condition < 25 then
        table.insert(mods, { multiplier = 0.25 })
    elseif condition < 50 then
        table.insert(mods, { multiplier = 0.5 })
    end
end)
```

---

#### `ShopPriceEvents.registerOnShopOverrideSellPrice(callback)`

Register a callback to completely override sell prices.

**Callback signature:**

```lua
function(player, item, calculatedPrice, context)
    -- Returns: price (number) or nil (use calculated price)
end
```

**Example - Rare items have special pricing:**

```lua
ShopPriceEvents.registerOnShopOverrideSellPrice(function(player, item, price, ctx)
    local itemType = item:getFullType()
    if itemType == "Base.RareGem" then
        return price * 5  -- 5x multiplier for rare items
    end
    return nil  -- use calculated price
end)
```

---

## Examples

### Example 1: Complete Food Mod Extension

```lua
-- MyFoodMod_ShopExtension.lua

-- Register items to buy
ShopEvents.registerOnShopRegisterItems(function()
    Shop.RegisterItem("MyFood.Burger", {
        tab = "Food",
        price = 25,
        items = { { item = "MyFood.Burger" } },
        notes = "A delicious burger"
    })
    Shop.RegisterItem("MyFood.Pizza", {
        tab = "Food",
        price = 40,
        items = { { item = "MyFood.Pizza" } }
    })
end)

-- Register items to sell
ShopSellEvents.registerOnShopRegisterSellItems(function()
    Shop.RegisterSellItem("MyFood.LeftoverBurger", { price = 10 })
    Shop.RegisterSellItem("MyFood.LeftoverPizza", { price = 15 })
end)

-- Hook into price calculations
ShopPriceEvents.registerOnShopModifyBuyPrice(function(player, itemId, base, ctx, mods)
    -- Food items on sale: 20% off on weekends
    local hour = getGameTime():getTimeOfDay()
    local dayOfWeek = getGameTime():getDayOfTheWeek()
    if (dayOfWeek == 6 or dayOfWeek == 0) then  -- Sat/Sun
        table.insert(mods, { multiplier = 0.8 })
    end
end)
```

### Example 2: Condition-Based Sell Pricing

```lua
-- MyMod_PriceHooks.lua

ShopPriceEvents.registerOnShopModifySellPrice(function(player, item, base, ctx, mods)
    local condition = item:getCondition()
    
    -- Items below 25% condition worth much less
    if condition < 25 then
        table.insert(mods, { multiplier = 0.1 })
    -- Items below 50% condition worth half
    elseif condition < 50 then
        table.insert(mods, { multiplier = 0.5 })
    -- Items below 75% condition worth 75%
    elseif condition < 75 then
        table.insert(mods, { multiplier = 0.75 })
    end
end)
```

### Example 3: Server-Only Admin Items

```lua
-- AdminMod_ShopExtension.lua

ShopEvents.registerOnShopRegisterItems(function()
    if isServer() then
        Shop.RegisterItem("AdminMod.AdminWeapon", {
            tab = "Weapons",
            price = 999,
            items = { { item = "AdminMod.AdminWeapon" } },
            notes = "Server admins only"
        })
    end
end)
```

---

## Load Order

**Guaranteed order in the mod system:**

1. `Shop.lua` (defines Shop namespace)
2. `ShopRegistry.lua` / `ShopSellRegistry.lua` (defines registration APIs)
3. `ShopPriceEvents.lua` (defines price hook dispatcher)
4. Your mod's extension code loads (calls register functions)
5. `ShopInit.lua` calls `Shop.FinalizeRegistry()` (executes item callbacks)
6. `ShopSellInit.lua` calls `Shop.FinalizeSellRegistry()` (executes sell callbacks)

All price hooks are available immediately and execute during price calculations.

---

## Error Handling

### Registration After Lock

```lua
ShopEvents.registerOnShopRegisterItems(function()
    -- This is fine
    Shop.RegisterItem("MyMod.Item", {...})
end)

-- But calling outside the callback after initialization fails:
Shop.RegisterItem("MyMod.Item2", {...})
-- ❌ Error: "[Shop] RegisterItem after registry lock"
```

**Solution**: Register inside your callback passed to `registerOnShopRegisterItems()`.

### Invalid Arguments

```lua
ShopEvents.registerOnShopRegisterItems(123)
-- ❌ Error: registerOnShopRegisterItems requires a function

Shop.RegisterItem(123, {})
-- ❌ Error: itemId must be string
```

---

## B42 Design Philosophy

This API follows the **B42-Safe Custom Event pattern** from `docs/CUSTOM_EVENTS.md`:

✔ **Deterministic** - Registration happens in a known phase  
✔ **MP-Safe** - Shared Lua runs identically on all clients  
✔ **Explicit** - Clear registration APIs, no implicit globals  
✔ **Extensible** - Callbacks allow conditional logic  
✔ **Debuggable** - Easy to trace which mod registered what  

---

## FAQ

**Q: Can I register items after the game starts?**

A: No. Registration is locked after initialization. Register during mod load in shared Lua.

**Q: Does this work in multiplayer?**

A: Yes. Shared Lua runs on all clients, so all clients register the same items. The server enforces pricing.

**Q: Can I modify an existing item?**

A: Not via registration API. Use price hooks instead to dynamically change pricing behavior.

**Q: What if two mods register the same item ID?**

A: The last one wins. Use unique prefixes to avoid conflicts (e.g., `"MyModName.ItemId"`).

**Q: Can I delete items?**

A: No. Design your mod to not register conflicting items instead.

---

## Deprecated Methods

The following are **no longer recommended**:

- ❌ Direct calls to `Shop.RegisterItem()` outside callbacks
- ❌ Attempting to use engine events for custom hooks

Use the event dispatcher APIs instead:
- ✅ `ShopEvents.registerOnShopRegisterItems()`
- ✅ `ShopPriceEvents.registerOnShopModifyBuyPrice()`
- etc.

---

## Support

For issues or questions, see the main Shop mod documentation or the B42 modding guide.
