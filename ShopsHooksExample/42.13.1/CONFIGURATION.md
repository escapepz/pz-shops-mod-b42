# ShopsHooksExample — Configuration Reference

This example demonstrates safe shop configuration patterns using the Shops mod API.

## Shop Configuration Settings (Safe for External Mods)

These settings from `SHOPSB42.Shop` can be configured by external mods:

### Item Registration via Hooks

**Safe hook:** `ShopEvents.registerOnShopRegisterItems(callback)`

Register items that players can purchase:

```lua
local ShopEvents = SHOPSB42.ShopEvents
ShopEvents.registerOnShopRegisterItems(function()
    SHOPSB42.Shop.RegisterItem("base.YourItem", {
        tab = SHOPSB42.Tab.Food,    -- Tab category (Tab.Food, Tab.Weapons, etc.)
        price = 100,                 -- Buy price in shop
        items = 50,                  -- Stock quantity (0/nil = unlimited)
        brokenPrice = 25,            -- Price for damaged version (optional)
        notes = "Item description"   -- Display notes (optional)
    })
end)
```

### Sell Configuration

**Safe hook:** `ShopSellEvents.registerOnShopRegisterSellItems(callback)`

Control which items players can sell to shop and at what price:

```lua
local ShopSellEvents = SHOPSB42.ShopSellEvents
ShopSellEvents.registerOnShopRegisterSellItems(function()
    SHOPSB42.Shop.RegisterSellItem("base.YourItem", {
        price = 50,           -- What shop pays for this item
        blacklisted = false   -- Prevent sale (blacklist mode only)
    })
end)
```

### Sell Mode: Whitelist vs Blacklist

**Safe variable:** `SHOPSB42.Shop.SellIsWhitelist`

- **`false` (default - Blacklist mode)**: All items sellable except explicitly blacklisted
- **`true` (Whitelist mode)**: Only registered items in `Shop.PlayerSell` can be sold

```lua
-- Set before item registration
SHOPSB42.Shop.SellIsWhitelist = true  -- Whitelist mode (restrictive)
SHOPSB42.Shop.SellIsWhitelist = false -- Blacklist mode (permissive, default)
```

**Example in this mod:**

```lua
-- In config/defaults.lua
Defaults.SellIsWhitelist = false  -- blacklist mode

-- Applied in ShopsHooksExampleMain.configureListingMode()
SHOPSB42.Shop.SellIsWhitelist = ShopsHooksExampleState.SellIsWhitelist
```

### Default Sell Prices (Blacklist Mode)

**Safe variables:** `SHOPSB42.Shop.defaultPrice`, `SHOPSB42.Shop.defaultPriceBroken`

When in **blacklist mode**, unregistered items use these fallback prices:

```lua
SHOPSB42.Shop.defaultPrice = 50       -- Normal item fallback price
SHOPSB42.Shop.defaultPriceBroken = 25 -- Broken item fallback price
```

## Price Modification Hooks

These hooks are called for every buy/sell transaction and are safe for external mods:

### Modify Buy Price

**Safe hook:** `ShopPriceEvents.registerOnShopModifyBuyPrice(callback)`

Apply multipliers or flat adjustments to buy prices:

```lua
local ShopPriceEvents = SHOPSB42.ShopPriceEvents
ShopPriceEvents.registerOnShopModifyBuyPrice(function(player, itemId, basePrice, context, modifiers)
    if itemId == "base.Apple" then
        modifiers:multiplyBy(0.9)  -- 10% discount
    end
end)
```

**Modifiers API:**

- `modifiers:addFlat(amount)` - Add flat amount to price
- `modifiers:multiplyBy(factor)` - Multiply price by factor (stacks with other multipliers)

### Override Buy Price

**Safe hook:** `ShopPriceEvents.registerOnShopOverrideBuyPrice(callback)`

Completely override buy price (first non-nil return wins):

```lua
ShopPriceEvents.registerOnShopOverrideBuyPrice(function(player, itemId, calculatedPrice, context)
    if itemId == "base.Apple" then
        return 5  -- Force price to 5 (ignores modifiers)
    end
    return nil  -- Use calculated price
end)
```

### Modify Sell Price

**Safe hook:** `ShopPriceEvents.registerOnShopModifySellPrice(callback)`

Adjust sell prices based on item condition, type, etc:

```lua
ShopPriceEvents.registerOnShopModifySellPrice(function(player, item, basePrice, context, modifiers)
    if item:getCondition() > 75 then
        modifiers:multiplyBy(1.0)  -- Excellent: full price
    elseif item:getCondition() > 50 then
        modifiers:multiplyBy(0.85) -- Good: 85%
    else
        modifiers:multiplyBy(0.5)  -- Fair/Poor: 50%
    end
end)
```

### Override Sell Price

**Safe hook:** `ShopPriceEvents.registerOnShopOverrideSellPrice(callback)`

Completely override sell price:

```lua
ShopPriceEvents.registerOnShopOverrideSellPrice(function(player, item, calculatedPrice, context)
    if item:getType() == "Food" and calculatedPrice > 100 then
        return math.floor(calculatedPrice * 0.75)  -- Food cap at 75%
    end
    return nil  -- Use calculated price
end)
```

## Configuration in This Example

Configuration is organized modularly in `media/lua/server/nshopsb42/`:

- **`ShopsHooksExampleState.lua`** — Configuration loader (aggregates config/ modules)
- **`config/_index.lua`** — Registry controlling config load order
- **`config/prices.lua`** — Price multipliers and overrides
- **`config/defaults.lua`** — Default values and behavior settings

### Registered Items

**Buy Items:**

- `Base.CannedBolognese` (price: 8, stock: 50)
- `Base.Apple` (price: 2, stock: 100)
- `Base.AxeSteel` (price: 25, brokenPrice: 5, stock: 10)
- `Base.Hammer` (price: 15, brokenPrice: 3, stock: 15)
- `Base.FirstAidKit` (price: 45, stock: 20) — only in non-survival mode

**Sell Items (Blacklist Mode):**

- `Base.CannedBolognese` (sell price: 4)
- `Base.Apple` (sell price: 1)
- `Base.AxeSteel` (sell price: 12)
- `Base.Hammer` (sell price: 7)
- `Base.Bomb`, `Base.C4`, `Base.Explosives` (blacklisted)

### Price Hooks

**Buy Price:**

- Apple: 10% discount via `modifyAppleBuyPrice` (multiplier: 0.9)
- Apple: Optional fixed price override via `appleOverrideBuyPrice` (disabled by default)

**Sell Price:**

- Items: Condition-based multiplier via `modifySellPriceByCondition`
  - Excellent (75-100%): 100% of price
  - Good (50-74%): 85% of price
  - Fair (25-49%): 50% of price
  - Poor (0-24%): 50% of price

### Listing Mode

**Current:** `config/defaults.lua: SellIsWhitelist = false` (blacklist mode)

**To change**: Edit `config/defaults.lua` and restart server

## Suppressing Default Items

**Safe variable:** `SHOPSB42.Shop._suppressDefaults`

Prevent Shops mod from loading vanilla items:

```lua
-- Must be set before hooks fire (very early in initialization)
SHOPSB42.Shop._suppressDefaults = true
```

When set to `true`, only items registered via external mod hooks will appear in the shop. Default: `false` (vanilla items load normally).

**Example:** See `config/defaults.lua` line ~28

### Default Sell Prices (Blacklist Mode Only)

**Safe variables:** `SHOPSB42.Shop.defaultPrice`, `SHOPSB42.Shop.defaultPriceBroken`

When in **blacklist mode**, items not explicitly registered use these fallback prices:

```lua
-- Set these in your initialization
SHOPSB42.Shop.defaultPrice = 50       -- Normal unregistered items
SHOPSB42.Shop.defaultPriceBroken = 25 -- Broken unregistered items
```

These only apply when `Shop.SellIsWhitelist = false` (blacklist mode).

**Example:** See `config/defaults.lua` lines ~16-25

## Logging

All configuration and hook execution is logged to:

**Server**: `Logs/Server/*_Shops.txt`
**Client**: `Logs/Client/*_Shops.txt`

Hook registration logged on server startup. Price hook execution logged per transaction.

## Disabling the Example Mod

To disable:

1. Disable ShopsHooksExample in mod manager
2. Server restart
3. Prices and items revert to default configured Shops mod defaults

## Summary of Safe Configuration Points

| Setting                             | Type     | Default | Purpose                               |
| ----------------------------------- | -------- | ------- | ------------------------------------- |
| `Shop.RegisterItem()`               | Hook API | —       | Register buy items                    |
| `Shop.RegisterSellItem()`           | Hook API | —       | Register sell items                   |
| `Shop.SellIsWhitelist`              | Variable | `false` | Whitelist vs blacklist mode           |
| `Shop.defaultPrice`                 | Variable | `1`     | Fallback sell price (blacklist)       |
| `Shop.defaultPriceBroken`           | Variable | `1`     | Fallback sell price for broken items  |
| `Shop._suppressDefaults`            | Variable | `false` | Skip loading default configured items |
| `registerOnShopRegisterItems()`     | Hook     | —       | Load buy items                        |
| `registerOnShopRegisterSellItems()` | Hook     | —       | Load sell items                       |
| `registerOnShopModifyBuyPrice()`    | Hook     | —       | Adjust buy prices                     |
| `registerOnShopOverrideBuyPrice()`  | Hook     | —       | Override buy prices                   |
| `registerOnShopModifySellPrice()`   | Hook     | —       | Adjust sell prices                    |
| `registerOnShopOverrideSellPrice()` | Hook     | —       | Override sell prices                  |
