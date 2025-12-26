# Hook-Based Shop Registry - Developer Guide

## Quick Start for External Mod Developers

### Objective
Register shop items without modifying the core Shops mod.

### Method
Hook into `Events.OnShopRegisterItems` event and call `Shop.RegisterItem()`.

### Minimal Example

```lua
-- In your mod's shared Lua file
Events.OnShopRegisterItems.Add(function()
    Shop.RegisterItem("YourMod.MyItem", {
        tab = Tab.Weapons,  -- Required: which tab to display in
        price = 100,        -- Required: sale price
        items = {           -- Optional: multi-item pack
            { item = "Base.Item1", quantity = 2 },
            { item = "Base.Item2" }
        },
        specialCoin = true  -- Optional: use special currency
    })
end)
```

---

## Core API

### `Shop.RegisterItem(itemId, definition)`

**Parameters:**
- `itemId` (string): Unique identifier for the item. Examples:
  - `"Base.Crowbar"` (vanilla item)
  - `"YourMod.CustomItem"` (custom item)
  
- `definition` (table): Item configuration with required fields:

**Required Fields:**
| Field | Type | Example | Purpose |
|-------|------|---------|---------|
| `tab` | string | `Tab.Weapons` | Which shop tab to display in |
| `price` | number | `250` | Sale price (or cost if buying from player) |

**Optional Fields:**
| Field | Type | Example | Purpose |
|-------|------|---------|---------|
| `items` | table | (see below) | Multi-item packing (for bundles) |
| `specialCoin` | boolean | `true` | Use special currency instead of regular |

**Item Packing Format (items field):**
```lua
items = {
    { item = "Base.Item1", quantity = 5 },  -- 5 units of Item1
    { item = "Base.Item2" }                  -- 1 unit of Item2 (implicit)
}
```

**Full Example:**
```lua
Shop.RegisterItem("Base.SurvivalPack", {
    tab = Tab.FirstAid,
    price = 100,
    items = {
        { item = "Base.Antibiotics" },
        { item = "Base.PillsBeta" },
        { item = "Base.Bandaid", quantity = 5 }
    }
})
```

---

## Event Hook: `Events.OnShopRegisterItems`

### When Does It Fire?
- **Client:** During `OnGameBoot` event, before UI is created
- **Server:** During `OnServerStarted` event
- Fires **once** at startup

### How to Hook It
```lua
Events.OnShopRegisterItems.Add(function()
    -- Your registration code here
end)
```

### What Happens When You Register?
1. Your item is added to a pending registration queue
2. The core system notes that ≥1 external registration occurred
3. **Default items are skipped** (because external registration detected)
4. After finalization, your items appear in the shop

---

## Tab Constants

Use these predefined tabs to categorize your items:

```lua
Tab.Favorite  -- Special: favorites (auto-populated)
Tab.Sell      -- Special: player selling to NPC
Tab.All       -- Special: all items
Tab.Food      -- Consumables, food
Tab.Weapons   -- Melee weapons, tools
Tab.FirstAid  -- Medical supplies
Tab.Vehicles  -- Vehicles, parts
Tab.Event     -- Limited-time/event items
```

---

## Complete External Mod Structure

**Directory Layout:**
```
YourMod/
├── mod.info
└── media/lua/shared/
    └── YourMod_Shop.lua
```

**mod.info:**
```ini
name=Your Mod Name
id=YourModId
description=Registers custom shop items
require=Shops
```

**YourMod_Shop.lua:**
```lua
Events.OnShopRegisterItems.Add(function()
    Shop.RegisterItem("YourMod.Sword", {
        tab = Tab.Weapons,
        price = 500
    })
    
    Shop.RegisterItem("YourMod.HealthKit", {
        tab = Tab.FirstAid,
        price = 200,
        items = {
            { item = "Base.Bandage", quantity = 10 },
            { item = "Base.Pills", quantity = 5 }
        }
    })
end)
```

---

## Important Rules

### ✓ DO:
- Register items in `OnShopRegisterItems` event handler
- Use valid item IDs (base game or your mod items)
- Provide both `tab` and `price` fields
- Use `require=Shops` in mod.info (for load ordering)
- Test with your item IDs to ensure they exist

### ✗ DON'T:
- Write directly to `Shop.Items[...]` (will fail)
- Call `Shop.RegisterItem()` outside the event
- Register items after finalization (error will be thrown)
- Use undefined tabs (use constants from `Tab` table)
- Create items with missing required fields (validation will fail)

---

## Behavior Notes

### Default Items
If **no external mod registers any items**, the core system loads default items:
- Base.OatsRaw (Food tab)
- Base.Crowbar (Weapons tab)
- Base.SurvivalPack, Base.Bandaid (FirstAid tab)
- PinkSlip.CarNormal (Vehicles tab)
- Base.HairDyeBlonde, Base.Bag_BigHikingBag (Event tab)

### Item Overrides
If **any external mod registers ≥1 item**, defaults are completely **skipped**. This means:
- You are responsible for providing all items your shop needs
- You can't augment defaults; you replace them entirely
- All mods that register items contribute to the shared catalog

### Registry Locking
After finalization:
- `Shop._locked = true` (prevents late writes)
- Calling `Shop.RegisterItem()` will throw an error
- This ensures a stable, immutable catalog for the session

---

## Debugging & Validation

### Validation Errors
If your item fails validation, you'll see an error message:
```
[Shop] Missing tab: Base.MyItem
[Shop] Missing price: Base.MyItem
[Shop] Pack entry missing item: Base.MyItem
```

**Solutions:**
1. Ensure `tab` field is present and valid
2. Ensure `price` field is a number
3. For packing, ensure each entry has `item` field

### Check If Item Loaded
```lua
if Shop.Items["YourMod.MyItem"] then
    print("Item loaded successfully")
else
    print("Item not in registry")
end
```

### Check Registration Status
```lua
if Shop._locked then
    print("Registry finalized")
else
    print("Registry still initializing")
end
```

---

## Examples

### Simple Weapon
```lua
Shop.RegisterItem("YourMod.Machete", {
    tab = Tab.Weapons,
    price = 450
})
```

### Bundle with Multiple Items
```lua
Shop.RegisterItem("YourMod.AdvancedKit", {
    tab = Tab.FirstAid,
    price = 350,
    items = {
        { item = "Base.Antibiotics", quantity = 2 },
        { item = "Base.PillsBeta", quantity = 3 },
        { item = "Base.Bandage", quantity = 10 },
        { item = "Base.Disinfectant" }
    }
})
```

### Special Currency Item
```lua
Shop.RegisterItem("YourMod.EventDye", {
    tab = Tab.Event,
    price = 25,
    specialCoin = true
})
```

### Vehicle
```lua
Shop.RegisterItem("YourMod.Truck", {
    tab = Tab.Vehicles,
    price = 2500
})
```

---

## Migration from Old System

If you had custom shop items registered directly:

**Old Way (Deprecated):**
```lua
-- Don't do this anymore
Shop.Items["YourMod.Item"] = { tab = Tab.Weapons, price = 100 }
```

**New Way (Use This):**
```lua
Events.OnShopRegisterItems.Add(function()
    Shop.RegisterItem("YourMod.Item", {
        tab = Tab.Weapons,
        price = 100
    })
end)
```

---

## FAQ

**Q: Can I modify items after registration?**
A: No. Registry locks after finalization. If you need to adjust items, modify the registration before shutdown and restart the server.

**Q: What if two mods register the same item ID?**
A: The second registration will overwrite the first. Item IDs must be unique (use your mod prefix to avoid collisions).

**Q: Can I register items dynamically during play?**
A: No. Registry finalizes at startup and locks. Hot registration is a post-MVP feature.

**Q: Do player shops use the same catalog?**
A: Yes. The finalized `Shop.Items` is used by both NPC shops and player shops.

**Q: How do I know my items loaded?**
A: Check `Shop.Items["YourMod.Item"]` after finalization, or check server logs for validation errors.

---

## Support

For issues:
1. Check validation error messages (console logs)
2. Verify item IDs exist in your mod or base game
3. Ensure `tab` and `price` are present
4. Confirm mod.info has `require=Shops`
5. Test with minimal example first

