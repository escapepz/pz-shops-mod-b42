# Shops Mod - Hooks & Registry API Reference

External mods can use these hook functions to extend Shops mod functionality. All hook registration functions are **safe for external mods** and follow consistent patterns.

## Location
All files are in: `Shops/42.13.1/media/lua/shared/nshopsb42/`

---

## Item Registry Hooks

### File: `events/ShopEvents.lua`

#### `ShopEvents.registerOnShopRegisterItems(callback)`
**Type:** Hook registration (safe for external mods)

Register a callback to load buy items. Called once during mod initialization.

**Parameters:**
- `callback`: `function()` - Your callback function with no parameters

**Example:**
```lua
local ShopEvents = SHOPSB42.ShopEvents
ShopEvents.registerOnShopRegisterItems(function()
    -- Register your items here
    SHOPSB42.Shop.RegisterItem("base.YourItem", {
        tab = "tabName",
        price = 100,
        -- ... other properties
    })
end)
```

**Safety:** ✓ Safe - Uses table.insert, type-checked, logged

---

#### `ShopEvents.triggerOnShopRegisterItems()`
**Type:** Internal trigger (do NOT call from external mods)

Executes all registered buy item callbacks sequentially. Called internally during Shop initialization.

---

### File: `sales/ShopSellEvents.lua`

#### `ShopSellEvents.registerOnShopRegisterSellItems(callback)`
**Type:** Hook registration (safe for external mods)

Register a callback to load sell items. Called once during mod initialization.

**Parameters:**
- `callback`: `function()` - Your callback function with no parameters

**Example:**
```lua
local ShopSellEvents = SHOPSB42.ShopSellEvents
ShopSellEvents.registerOnShopRegisterSellItems(function()
    -- Register your sellable items here
    -- Use same SHOPSB42.Shop.RegisterItem() API
    SHOPSB42.Shop.RegisterItem("base.YourSellItem", {
        tab = "tabName",
        price = 50,
        -- ... other properties
    })
end)
```

**Safety:** ✓ Safe - Uses table.insert, type-checked

---

#### `ShopSellEvents.triggerOnShopRegisterSellItems()`
**Type:** Internal trigger (do NOT call from external mods)

Executes all registered sell item callbacks sequentially.

---

## Item Registration Function

### File: `core/ShopRegistry.lua`

#### `Shop.RegisterItem(itemId, def)`
**Type:** Item registry (safe for external mods)

Register an item in the shop. Call this from within a hook callback or initialization.

**Parameters:**
- `itemId`: `string` - Unique identifier (e.g., `"base.WaterBottle"`)
- `def`: `table` - Item definition with properties:
  - `tab`: Tab category for display
  - `price`: Base price (number)
  - Other item-specific properties

**Safety:** ✓ Safe - Type-checked, prevents registration after lockdown

**State:**
- `Shop._pendingRegistrations`: Table of pending items (internal)
- `Shop._locked`: Boolean flag (true = registration locked, no new items accepted)

**Example:**
```lua
SHOPSB42.Shop.RegisterItem("base.IcePack", {
    tab = "tabFirstAid",
    price = 400,
})
```

---

## Price Hook Functions

### File: `pricing/ShopPriceEvents.lua`

#### Buy Price Modification

##### `ShopPriceEvents.registerOnShopModifyBuyPrice(callback)`
**Type:** Hook registration (safe for external mods)

Register a callback to **modify** buy prices. Called for every buy transaction.

**Callback Parameters:**
```lua
function callback(player, itemId, basePrice, context, modifiers)
    -- player: IsoPlayer - Buying player
    -- itemId: string - Item identifier
    -- basePrice: number - Base price from item def
    -- context: table - Price calculation context (shop, shop_type, etc.)
    -- modifiers: table - ModifierBuilder object to adjust price
end
```

**Modifiers API:**
- `modifiers:addFlat(amount)` - Add flat amount
- `modifiers:multiplyBy(factor)` - Multiply by factor

**Safety:** ✓ Safe - Type-checked, all callbacks executed in order

**Example:**
```lua
SHOPSB42.ShopPriceEvents.registerOnShopModifyBuyPrice(function(player, itemId, basePrice, context, modifiers)
    if itemId == "base.WaterBottle" then
        modifiers:multiplyBy(0.9)  -- 10% discount
    end
end)
```

---

##### `ShopPriceEvents.registerOnShopOverrideBuyPrice(callback)`
**Type:** Hook registration (safe for external mods)

Register a callback to **override** buy prices completely. First non-nil return value wins.

**Callback Parameters:**
```lua
function callback(player, itemId, calculatedPrice, context)
    -- player: IsoPlayer - Buying player
    -- itemId: string - Item identifier
    -- calculatedPrice: number - Price after modifications
    -- context: table - Price calculation context
    
    -- Return a number to override, or nil to use calculated price
    return newPrice
end
```

**Safety:** ✓ Safe - Type-checked, first override wins (short-circuit)

**Example:**
```lua
SHOPSB42.ShopPriceEvents.registerOnShopOverrideBuyPrice(function(player, itemId, price, context)
    if itemId == "base.Pistol" then
        return 5000  -- Fixed price for pistols
    end
    return nil  -- Use calculated price
end)
```

---

##### `ShopPriceEvents.triggerOnShopModifyBuyPrice(player, itemId, basePrice, context, modifiers)`
**Type:** Internal trigger (do NOT call from external mods)

Executes all buy price modification callbacks.

---

##### `ShopPriceEvents.triggerOnShopOverrideBuyPrice(player, itemId, price, context)`
**Type:** Internal trigger (do NOT call from external mods)

Executes buy price override callbacks, returns first non-nil override.

---

#### Sell Price Modification

##### `ShopPriceEvents.registerOnShopModifySellPrice(callback)`
**Type:** Hook registration (safe for external mods)

Register a callback to **modify** sell prices.

**Callback Parameters:**
```lua
function callback(player, item, basePrice, context, modifiers)
    -- player: IsoPlayer - Selling player
    -- item: InventoryItem - Item being sold
    -- basePrice: number - Base sell price
    -- context: table - Price calculation context
    -- modifiers: table - ModifierBuilder object to adjust price
end
```

**Safety:** ✓ Safe - Type-checked, all callbacks executed

**Example:**
```lua
SHOPSB42.ShopPriceEvents.registerOnShopModifySellPrice(function(player, item, basePrice, context, modifiers)
    if item:getType() == "Food" then
        modifiers:multiplyBy(0.5)  -- 50% of normal for food
    end
end)
```

---

##### `ShopPriceEvents.registerOnShopOverrideSellPrice(callback)`
**Type:** Hook registration (safe for external mods)

Register a callback to **override** sell prices completely.

**Callback Parameters:**
```lua
function callback(player, item, calculatedPrice, context)
    -- player: IsoPlayer - Selling player
    -- item: InventoryItem - Item being sold
    -- calculatedPrice: number - Price after modifications
    -- context: table - Price calculation context
    
    -- Return a number to override, or nil to use calculated price
    return newPrice
end
```

**Safety:** ✓ Safe - Type-checked, first override wins

**Example:**
```lua
SHOPSB42.ShopPriceEvents.registerOnShopOverrideSellPrice(function(player, item, price, context)
    -- Buy back items at 75% of shop price
    return math.floor(price * 0.75)
end)
```

---

##### `ShopPriceEvents.triggerOnShopModifySellPrice(player, item, basePrice, context, modifiers)`
**Type:** Internal trigger (do NOT call from external mods)

---

##### `ShopPriceEvents.triggerOnShopOverrideSellPrice(player, item, price, context)`
**Type:** Internal trigger (do NOT call from external mods)

---

## Shop Configuration

Core shop configuration is defined in `core/Shop.lua` and accessible via the `SHOPSB42.Shop` namespace. These settings affect global shop behavior.

### File: `core/Shop.lua`

#### Registry & State Variables

**`Shop.Items`** - Dictionary of all registered shop items
- Type: `table` (key = itemId string, value = item definition table)
- Access: Read/write
- Used by: Client UI, price calculation, item validation
- Example: `Shop.Items["base.WaterBottle"] = { tab = "tabFood", price = 100, ... }`

**`Shop.Tabs`** - Dictionary of shop category tabs
- Type: `table` (key = Tab constant, value = localized display name)
- Access: Read-only (set by Shop.lua)
- Pre-populated tabs: Favorite, Sell, All, Food, Weapons, Vehicles, FirstAid, Event
- Example: `Shop.Tabs[Tab.Food] = "Food & Drink"`

**`Shop.PlayerBuy`** - Registry of items for player purchasing
- Type: `table` (key = itemId string, value = `{ enabled = boolean }`)
- Access: Server sets, client reads
- Set during: `Shop.FinalizeRegistry()`

**`Shop.PlayerSell`** - Registry of items for player selling
- Type: `table` (key = itemId string, value = item price config)
- Access: Server sets, client reads
- Used in: `Shop.canPlayerSell()`, `Shop.resolvePlayerSellPrice()`

---

#### Sale/Sell Configuration

**`Shop.SellIsWhitelist`** (note: case-sensitive!)
- Type: `boolean`
- Default: `false`
- **Whitelist mode (`true`)**: Only items explicitly registered in `Shop.PlayerSell` can be sold. Unregistered items cannot be sold.
- **Blacklist mode (`false`)**: All items can be sold except those explicitly blacklisted. Unregistered items use `Shop.defaultPrice`.
- Location: Line 33 of Shop.lua (note: actually named `SellisWhitelist` in code, but used as `SellIsWhitelist`)
- Used in: `ShopPriceSell.lua:21`

**`Shop.defaultPrice`**
- Type: `number`
- Default: `1`
- Base sell payout for unregistered items when in **blacklist mode**
- Used when item has no explicit `PlayerSell` config and is not broken
- Location: Line 34

**`Shop.defaultPriceBroken`**
- Type: `number`
- Default: `1`
- Base sell payout for unregistered broken items when in **blacklist mode**
- Used when item has no explicit `PlayerSell` config and `context.isBroken` is true
- Location: Line 35

---

#### UI Configuration (Client-side)

**`Shop.spritePrefix`**
- Type: `string`
- Default: `"npcshop_"`
- Prefix for NPC shop sprite names

**`Shop.sprites`**
- Type: `table`
- Contains sprite ID lists for different NPC genders (FemaleA, FemaleB, MaleA, MaleB)
- Used by: Client UI for NPC shop rendering

**`Shop.textures`**
- Type: `table`
- Contains texture references for UI buttons: AddButton, RemoveButton, PreviewButton, Browse, Cart, Sort, MoveAll
- Used by: Client UI rendering

---

#### State Management

**`Shop._finalized`**
- Type: `boolean`
- Default: `false`
- Set to `true` after item registration is complete via `Shop.FinalizeRegistry()`
- Controls: Whether live price hook updates are broadcast to clients
- Location: Line 18 in Shop.lua

**`Shop._locked`**
- Type: `boolean`
- Default: `false`
- Set to `true` after finalization to prevent new item registrations
- If `true`, calls to `Shop.RegisterItem()` are ignored
- Location: Line 13 in ShopRegistry.lua

**`Shop.PriceHookRevision`**
- Type: `number`
- Default: `0`
- Incremented when price hooks change post-finalization
- Used by: Client UI to detect stale cached prices
- Location: Line 19 in Shop.lua

**`Shop._pendingRegistrations`**
- Type: `table` (array of registration entries)
- Internal storage for items registered before finalization
- Cleared after finalization
- Location: Line 12 in ShopRegistry.lua

**`Shop._suppressDefaults`**
- Type: `boolean`
- Default: `false`
- External mods can set to `true` before default items load to skip loading vanilla items
- Example: `SHOPSB42.Shop._suppressDefaults = true`
- Location: Referenced in ShopDefaultItems.lua:22, 40

---

## Configuration Access from ShopDefaultItems.lua

The `ShopDefaultItems.lua` file uses these Shop configurations:

```lua
-- Check if default items should be loaded
if Shop._suppressDefaults then
    return  -- External mod set this flag, skip defaults
end

-- Register items using Shop.RegisterItem()
Shop.RegisterItem("base.Food", { tab = "tabFood", price = 100 })
```

This is the entry point for item registration, accessed via hooks:
- `ShopEvents.registerOnShopRegisterItems()` → calls `ShopDefaultItems.loadDefaultBuyItems()`
- `ShopSellEvents.registerOnShopRegisterSellItems()` → calls `ShopDefaultItems.loadDefaultSellItems()`

---

## Configuration Usage Examples

### Suppress Default Items
```lua
-- In an external mod, before Shops initialization
SHOPSB42.Shop._suppressDefaults = true
-- Now only your mod's items will load
```

### Switch to Whitelist Sell Mode
```lua
-- Only registered items can be sold
SHOPSB42.Shop.SellIsWhitelist = true
```

### Change Default Prices for Unregistered Items
```lua
-- Blacklist mode: adjust fallback prices
SHOPSB42.Shop.defaultPrice = 50       -- Normal items sell for 50
SHOPSB42.Shop.defaultPriceBroken = 25 -- Broken items sell for 25
```

### Access Item Registry
```lua
local itemDef = SHOPSB42.Shop.Items["base.WaterBottle"]
if itemDef then
    print("Item found: " .. itemDef.tab .. ", price: " .. itemDef.price)
end
```

---

## Summary Table

### Hook Registration Functions

| Function | File | Type | Safe for Mods | Purpose |
|----------|------|------|-------|---------|
| `Shop.RegisterItem()` | ShopRegistry.lua | Registry | ✓ Yes | Register items in shop |
| `ShopEvents.registerOnShopRegisterItems()` | ShopEvents.lua | Hook Register | ✓ Yes | Load buy items |
| `ShopSellEvents.registerOnShopRegisterSellItems()` | ShopSellEvents.lua | Hook Register | ✓ Yes | Load sell items |
| `ShopPriceEvents.registerOnShopModifyBuyPrice()` | ShopPriceEvents.lua | Hook Register | ✓ Yes | Modify buy prices |
| `ShopPriceEvents.registerOnShopOverrideBuyPrice()` | ShopPriceEvents.lua | Hook Register | ✓ Yes | Override buy prices |
| `ShopPriceEvents.registerOnShopModifySellPrice()` | ShopPriceEvents.lua | Hook Register | ✓ Yes | Modify sell prices |
| `ShopPriceEvents.registerOnShopOverrideSellPrice()` | ShopPriceEvents.lua | Hook Register | ✓ Yes | Override sell prices |

### Configuration Variables (Shop.lua)

| Variable | Type | Default | Mutable | Purpose |
|----------|------|---------|---------|---------|
| `Shop.Items` | table | `{}` | ✓ Yes | All registered items (itemId → definition) |
| `Shop.Tabs` | table | Pre-set | Read-only | Tab display names (Tab → localized text) |
| `Shop.PlayerBuy` | table | `{}` | Server | Items available for purchase |
| `Shop.PlayerSell` | table | `{}` | Server | Items available for selling |
| `Shop.SellIsWhitelist` | boolean | `false` | ✓ Yes | Sell mode: whitelist=true, blacklist=false |
| `Shop.defaultPrice` | number | `1` | ✓ Yes | Default sell price for unregistered items |
| `Shop.defaultPriceBroken` | number | `1` | ✓ Yes | Default sell price for broken unregistered items |
| `Shop._suppressDefaults` | boolean | `false` | ✓ Yes | Set to `true` to skip loading vanilla items |
| `Shop._finalized` | boolean | `false` | Internal | Set when initialization complete |
| `Shop._locked` | boolean | `false` | Internal | Prevents new registrations after finalize |
| `Shop.PriceHookRevision` | number | `0` | Internal | Tracks price hook changes for client cache |
| `Shop._pendingRegistrations` | table | `[]` | Internal | Pre-finalization registration queue |

---

## Integration Pattern

External mods should follow this pattern:

```lua
-- 1. Get references to hook systems
local ShopEvents = SHOPSB42.ShopEvents
local ShopSellEvents = SHOPSB42.ShopSellEvents
local ShopPriceEvents = SHOPSB42.ShopPriceEvents
local Shop = SHOPSB42.Shop

-- 2. Register item loading callbacks
ShopEvents.registerOnShopRegisterItems(function()
    Shop.RegisterItem("mymod.MyItem", { tab = "tabGeneral", price = 100 })
end)

-- 3. Register price hooks (optional)
ShopPriceEvents.registerOnShopModifyBuyPrice(function(player, itemId, price, context, modifiers)
    if itemId == "mymod.MyItem" then
        modifiers:multiplyBy(0.9)
    end
end)
```

---

## Key Characteristics

- **Type Safety**: All registration functions validate callback is a function
- **Thread-Safe Queuing**: Uses `table.insert()` for callback storage
- **No Global Pollution**: All hooks live under `SHOPSB42` namespace
- **Logged**: Hook registrations are logged via SharedLogger
- **Execution Order**: Callbacks execute in registration order (FIFO)
- **Override Short-Circuit**: Override hooks stop at first non-nil return
