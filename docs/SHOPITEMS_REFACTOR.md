# ShopItems Refactoring - Declarative Item Lists

## Overview

ShopItems modules have been refactored to be **data-driven** rather than **behavior-driven**. Each item definition file now returns a declarative list of items, which are registered by `ShopDefaultItems.lua`.

## Benefits

✅ **Separation of Concerns**: Data (item definitions) separated from behavior (registration)  
✅ **Easier Testing**: Item lists can be tested independently of registration logic  
✅ **Composability**: Item lists can be merged, filtered, or transformed before registration  
✅ **Cleaner Code**: Each module is smaller and focused on data  
✅ **Pattern Consistency**: Matches `ShopsHooksExample` approach with listing definitions  

## Before: Procedural Registration

```lua
-- ShopItems/Food.lua (OLD)
if Utilities.IsServerOrSinglePlayer() then
    local Tab = SHOPSB42.Tab
    local Shop = SHOPSB42.Shop
    if Shop and Shop.RegisterItem then
        Shop.RegisterItem("Base.Apple", {
            tab = Tab.Food,
            price = 15,
        })
        Shop.RegisterItem("Base.OatsRaw", {
            tab = Tab.Food,
            price = 20,
        })
    end
end
```

## After: Declarative Lists

```lua
-- ShopItems/Food.lua (NEW)
local Tab = SHOPSB42.Tab

return {
    {
        id = "Base.Apple",
        config = {
            tab = Tab.Food,
            price = 15,
        },
    },
    {
        id = "Base.OatsRaw",
        config = {
            tab = Tab.Food,
            price = 20,
        },
    },
}
```

## Registration Flow

### ShopDefaultItems.lua

```lua
function ShopDefaultItems.loadDefaultBuyItems()
    local itemSources = {
        "nshopsb42/ShopItems/Food",
        "nshopsb42/ShopItems/Weapons",
        "nshopsb42/ShopItems/FirstAid",
        "nshopsb42/ShopItems/Vehicles",
        "nshopsb42/ShopItems/Event",
    }

    for _, source in ipairs(itemSources) do
        local items = require(source)
        if items then
            for _, entry in ipairs(items) do
                if entry.id and entry.config then
                    Shop.RegisterItem(entry.id, entry.config)
                end
            end
        end
    end
end
```

**Flow**:
1. Load item list from each ShopItems module
2. Iterate over items
3. Register each item via `Shop.RegisterItem(id, config)`

## Item Definition Structure

Each item in the returned list must follow this structure:

```lua
{
    id = "ItemID",          -- Unique identifier (string)
    config = {              -- Item configuration (table)
        tab = Tab.Category,
        price = 100,
        -- ... other config options
    },
}
```

### Optional Config Fields

```lua
{
    id = "Base.Apple",
    config = {
        tab = Tab.Food,
        price = 15,
        specialCoin = true,                  -- Payment type
        isVirtualBundle = true,              -- Bundle flag
        items = {                            -- Bundle contents
            { item = "Base.Bandaid", qty = 5 },
        },
        basePrice = 15,                      -- Override base price
        -- ... any other Shop.RegisterItem config
    },
}
```

## Files Modified

| File | Change |
|------|--------|
| `ShopItems/Food.lua` | Now returns `{ { id = "...", config = {...} }, ... }` |
| `ShopItems/Weapons.lua` | Now returns declarative list |
| `ShopItems/FirstAid.lua` | Now returns declarative list |
| `ShopItems/Vehicles.lua` | Now returns declarative list |
| `ShopItems/Event.lua` | Now returns declarative list |
| `ShopItems/ForSell.lua` | Now returns sell items as declarative list |
| `ShopDefaultItems.lua` | Loads and iterates over item lists |

## Adding New Default Items

To add a new default item:

1. **Choose the appropriate category** (Food, Weapons, FirstAid, etc.)
2. **Edit the corresponding file** (e.g., `ShopItems/Food.lua`)
3. **Add entry to the returned list**:

```lua
-- ShopItems/Food.lua
return {
    {
        id = "Base.Apple",
        config = { tab = Tab.Food, price = 15 },
    },
    -- NEW ITEM:
    {
        id = "Base.Potato",
        config = { tab = Tab.Food, price = 12 },
    },
}
```

4. **Restart server** — registration happens automatically

## Creating a New Category

If you need a new item category:

1. **Create `ShopItems/NewCategory.lua`**:

```lua
local Tab = SHOPSB42.Tab

return {
    {
        id = "Base.Item1",
        config = { tab = Tab.NewCategory, price = 100 },
    },
}
```

2. **Add to `ShopDefaultItems.loadDefaultBuyItems()`**:

```lua
local itemSources = {
    -- ... existing sources
    "nshopsb42/ShopItems/NewCategory",
}
```

## Backward Compatibility

- ✅ External mods using `Shop.RegisterItem()` directly are unaffected
- ✅ Suppression flag works identically
- ✅ Item registration order is preserved
- ✅ All existing configs and options supported

## Verification

After refactoring, verify in server logs:

```
[ShopDefaultItems] Suppression flag detected - default hooks NOT registered
[ShopInitServer] All modules loaded. Beginning initialization...
[ShopBuyInit] Hooks registered for item registration: 1.
[ShopBuyInit] Phase 1: Executing 1 hook(s) to gather buy items.
RegisterItem: Base.Apple (tab: Food, price: 2).
RegisterItem: Base.Banana (tab: Food, price: 2).
...
[ShopBuyInit] FinalizeRegistry complete. Total NPC Shop buy items: 30.
```

All items should register correctly with no errors.

## Future: Runtime Item Composition

This refactoring enables future features:

```lua
-- Merge default items with custom items at registration time
local allItems = {}
table.insert(allItems, defaultItems)
table.insert(allItems, customModItems)
table.insert(allItems, balanceOverrides)
-- Register merged list
```

Declarative structure makes this composition clean and testable.
