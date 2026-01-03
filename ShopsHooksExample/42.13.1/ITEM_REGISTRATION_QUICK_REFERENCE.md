# Item Registration Quick Reference

Quick lookup for shop item registration patterns.

## Register Buy Items

Items players can purchase from the shop.

```lua
Shop.RegisterItem("Base.Apple", {
    tab = SHOPSB42.Tab.Food,      -- Category tab
    price = 2,                     -- Buy price
    items = 100,                   -- Stock (0/nil = unlimited)
    brokenPrice = 1,               -- Price if broken/damaged (optional)
    notes = "Fresh apples"         -- Description (optional)
})
```

**Register via hook**:
```lua
local ShopEvents = SHOPSB42.ShopEvents
ShopEvents.registerOnShopRegisterItems(function()
    Shop.RegisterItem("Base.Apple", { ... })
end)
```

---

## Register Sell Items

Items the shop will buy from players.

```lua
Shop.RegisterSellItem("Base.Apple", {
    price = 1,                     -- Sell price (what shop pays)
    blacklisted = false,           -- Block sale in blacklist mode (optional)
    specialCoin = nil              -- Special currency (optional)
})
```

**Register via hook**:
```lua
local ShopSellEvents = SHOPSB42.ShopSellEvents
ShopSellEvents.registerOnShopRegisterSellItems(function()
    Shop.RegisterSellItem("Base.Apple", { price = 1 })
end)
```

---

## Whitelist/Blacklist Mode

### Blacklist Mode (Default)

- **All items** can be sold to shop
- **Except** items marked `blacklisted = true`
- Use for open shops

```lua
SHOPSB42.Shop.SellisWhitelist = false

Shop.RegisterSellItem("Base.Bomb", { blacklisted = true })
```

### Whitelist Mode

- **Only registered items** can be sold to shop
- All other items rejected
- Use for curated/restricted shops

```lua
SHOPSB42.Shop.SellisWhitelist = true

Shop.RegisterSellItem("Base.Apple", { price = 1 })
Shop.RegisterSellItem("Base.Hammer", { price = 8 })
-- Everything else: rejected
```

---

## Tab Categories

Available item categories:

| Tab | Display Name |
|---|---|
| `SHOPSB42.Tab.Favorite` | Favorites |
| `SHOPSB42.Tab.Food` | Food |
| `SHOPSB42.Tab.Weapons` | Weapons |
| `SHOPSB42.Tab.Vehicles` | Vehicles |
| `SHOPSB42.Tab.FirstAid` | First Aid |
| `SHOPSB42.Tab.Event` | Events |
| `SHOPSB42.Tab.All` | All |

---

## Common Patterns

### Register Multiple Items

```lua
local items = {
    { id = "Base.Apple", price = 2, stock = 100 },
    { id = "Base.Banana", price = 3, stock = 75 },
    { id = "Base.Orange", price = 4, stock = 50 },
}

for _, item in ipairs(items) do
    Shop.RegisterItem(item.id, {
        tab = SHOPSB42.Tab.Food,
        price = item.price,
        items = item.stock,
    })
end
```

### Register with Condition Check

```lua
function registerConditionalItems()
    local Shop = SHOPSB42.Shop
    if not Shop then return end
    
    -- Only add in non-survival mode
    if not SandboxVars.SurvivalMode then
        Shop.RegisterItem("Base.FirstAidKit", {
            tab = SHOPSB42.Tab.FirstAid,
            price = 45,
            items = 20,
        })
    end
end

ShopEvents.registerOnShopRegisterItems(registerConditionalItems)
```

### Blacklist Dangerous Items

```lua
function registerSellItems()
    local Shop = SHOPSB42.Shop
    
    -- Accept normal items
    Shop.RegisterSellItem("Base.Apple", { price = 1 })
    Shop.RegisterSellItem("Base.Hammer", { price = 8 })
    
    -- Reject dangerous items
    Shop.RegisterSellItem("Base.Bomb", { blacklisted = true })
    Shop.RegisterSellItem("Base.C4", { blacklisted = true })
    Shop.RegisterSellItem("Base.Explosives", { blacklisted = true })
end

ShopSellEvents.registerOnShopRegisterSellItems(registerSellItems)
```

### Whitelist Only Safe Items

```lua
function registerWhitelistItems()
    SHOPSB42.Shop.SellisWhitelist = true
    local Shop = SHOPSB42.Shop
    
    -- Only these items can be sold
    Shop.RegisterSellItem("Base.Apple", { price = 1 })
    Shop.RegisterSellItem("Base.Banana", { price = 2 })
    Shop.RegisterSellItem("Base.Hammer", { price = 8 })
    -- Everything else: rejected automatically
end

ShopSellEvents.registerOnShopRegisterSellItems(registerWhitelistItems)
```

---

## Integration with Price Hooks

Combine item registration with dynamic pricing:

```lua
-- Register items
function registerItems()
    Shop.RegisterItem("Base.Apple", { tab = Tab.Food, price = 2 })
end

-- Apply price modifiers
function modifyApplePrice(player, itemId, basePrice, context, modifiers)
    if itemId ~= "Base.Apple" then return end
    table.insert(modifiers, { multiplier = 0.9, label = "discount" })
end

-- Register both
ShopEvents.registerOnShopRegisterItems(registerItems)
ShopPriceEvents.registerOnShopModifyBuyPrice(modifyApplePrice)
```

---

## Errors & Debugging

**Items don't appear?**
- Check `Shop.RegisterItem` is called within `registerOnShopRegisterItems()` hook
- Verify item ID exists in game (e.g., "Base.Apple")
- Check server logs for registration errors

**Can't sell items in whitelist mode?**
- Verify `SHOPSB42.Shop.SellisWhitelist = true` is set
- Ensure item is registered with `Shop.RegisterSellItem()`
- Check shop logs

**Wrong sell price?**
- Verify `Shop.RegisterSellItem()` price parameter
- Check if price hooks are modifying the price
- Look for conflicting mods

---

## References

- **Full Guide**: ITEM_REGISTRATION_EXAMPLES.md
- **README**: Overview and all hook types
- **API Docs**: `.libraries/library/lua/`

See **ShopsHooksExampleItems.lua** for working implementation examples.
