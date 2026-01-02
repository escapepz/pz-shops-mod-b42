# Server-Side Price Calculation Cases

## Overview
When the server calculates prices via `buildCalculatedPrices()`, there are distinct cases based on:
1. **Item type** (defined items vs. sell-list items)
2. **Sell mode** (whitelist vs. blacklist)
3. **Modifier availability** (time-based, item-based hooks)

---

## Case 1: Buy Prices (All Items in Shop.Items)

**Files:**
- `ShopFinalizeHandlerServer.lua` line 31-36 (`buildCalculatedPrices()`)
- `ShopPriceBuy.lua` lines 24-53 (`resolvePlayerBuyPrice()`)

**Behavior:**
```lua
-- All items in Shop.Items get a calculated price
for itemId, itemData in pairs(Shop.Items) do
    local buyPrice = Shop.resolvePlayerBuyPrice(nil, itemId, { type = "sync" })
    if buyPrice then
        calculatedPrices.buyPrices[itemId] = buyPrice
    end
end
```

**Price Resolution Pipeline:**
1. Check if item is registered in `Shop.PlayerBuy` and enabled
   - If NOT registered → use `item.basePrice or item.price`
   - If registered → proceed to hooks

2. **Phase 1: Modify Hooks** (Time-based, Item-based discounts)
   - Hooks add multipliers to the `modifiers` list
   - Examples: time-of-day discount, category discount
   - Applied via `PriceUtils.applyModifiers(base, modifiers)`

3. **Phase 2: Override Hooks**
   - Can completely replace the price
   - Last resort for custom pricing

**Result:** All buy items have a price (either base or modified)

---

## Case 2: Sell Prices - Current Implementation

**Files:**
- `ShopFinalizeHandlerServer.lua` line 39-42 (`buildCalculatedPrices()`)
- `ShopPriceSell.lua` lines 23-44 (`resolvePlayerSellPrice()`)

**Current Behavior:**
```lua
-- SKIP: PlayerSell maps item IDs to sell configs, not actual item objects
-- For sell price calculation, we need item objects, so we skip this for now
-- The UI will calculate sell prices dynamically using inventory items
```

**Why NOT calculated on server:**
- Sell prices require actual inventory **item objects**
- Server doesn't have player inventory objects at sync time
- Client needs to calculate on-the-fly for each inventory item

---

## Case 3: Sell Prices - Client-Side Calculation

**Files:**
- `ShopUI.lua` lines 71-121 (`getSellPrice()`)
- Triggered when player opens sell tab

**Process:**
1. Iterate inventory items
2. For each item, check `Shop.PlayerSell[itemId]`:
   - **Whitelist mode** (`Shop.SellIsWhitelist == true`):
     - If config is `nil` → item is NOT sellable
     - If config exists & not blacklisted → item IS sellable
     - Price may be undefined if not explicitly set (`config.price` missing)
   
   - **Blacklist mode** (`Shop.SellIsWhitelist == false`):
     - If config is `nil` → item IS sellable (default)
     - If config exists & `blacklisted == true` → item is NOT sellable
     - Price may be undefined if not explicitly set

3. Apply modifiers via hooks:
   ```lua
   local modifiers = {}
   ShopPriceEvents.triggerOnShopModifySellPrice(player, item, base, context, modifiers)
   local price = PriceUtils.applyModifiers(base, modifiers)
   ```

**Price Determination:**
```lua
local sellPrice = nil

-- If not in PlayerSell registry, use base price (blacklist mode only)
if not Shop.PlayerSell[itemId] then
    sellPrice = item.basePrice or item.price
end

-- If in registry, use configured price or base
local rule = Shop.PlayerSell[itemId]
if rule and rule.enabled and not rule.blacklisted then
    sellPrice = rule.basePrice or rule.price  -- MAY BE NIL
end
```

---

## Case 3A: Sell Item with NO defined price (Whitelist/Blacklist Edge Cases)

**Scenarios:**

### Scenario A1: Whitelist Mode, Item Not in Registry
```lua
Shop.SellIsWhitelist = true
Shop.PlayerSell["Base.Apple"] = nil  -- Not defined
```
- **Result:** Item NOT sellable (returns `nil`)
- UI won't show in sell list

### Scenario A2: Whitelist Mode, Item in Registry but No Price
```lua
Shop.SellIsWhitelist = true
Shop.PlayerSell["Base.Apple"] = { enabled = true }  -- No price field
```
- **Result:** `sellPrice = nil` (undefined)
- UI shows item but price is `nil` / calculated as 0 / error?
- **ACTION NEEDED:** Should use `item.basePrice or item.price` as fallback

### Scenario A3: Blacklist Mode, Item Not in Registry
```lua
Shop.SellIsWhitelist = false  -- Blacklist mode
Shop.PlayerSell["Base.Apple"] = nil  -- Not explicitly registered
```
- **Result:** Item IS sellable
- Price = `item.basePrice or item.price` (from item data)

### Scenario A4: Blacklist Mode, Item Explicitly Blacklisted
```lua
Shop.SellIsWhitelist = false
Shop.PlayerSell["Base.Apple"] = { enabled = true, blacklisted = true }
```
- **Result:** Item NOT sellable (returns `nil`)
- UI won't show in sell list

### Scenario A5: Blacklist Mode, Item Registered with Price
```lua
Shop.SellIsWhitelist = false
Shop.PlayerSell["Base.Apple"] = { enabled = true, price = 50 }
```
- **Result:** Item IS sellable with price = 50
- Hooks can modify this price

---

## Modifier & Hook Coverage

### Time-Based Modifiers
**Files:** `ExampleShop.lua` lines 181-204

**Coverage:**
- ✅ Buy prices: Applied via `OnShopModifyBuyPrice` hook
- ⚠️ Sell prices: Should be applied via `OnShopModifySellPrice` hook, but **only if calculated on server**

**Current Issue:** Sell prices calculated client-side, so time-based mods may not sync perfectly across clients.

### Item-Based (Category) Modifiers
**Files:** `ExampleShop.lua` lines 147-178

**Coverage:**
- ✅ Buy prices: Applied via `OnShopModifyBuyPrice` hook (itemId available)
- ✅ Sell prices: Applied via `OnShopModifySellPrice` hook (item object available)

---

## To-Do: Server-Side Sell Price Calculation

### Current Limitation
Sell prices are calculated client-side because:
- Need player inventory item objects
- Server doesn't have access to player inventory at sync time

### Potential Solutions
1. **Maintain list of all possible item IDs** that could be sold, calculate their sell prices at sync time
2. **Send full sell price map** from server (similar to buy prices)
3. **Accept client-side calculation** but ensure modifier hooks are fully accessible to client

### Impact on Broadcast Optimization
The broadcast optimization plan assumes:
- Buy prices = 500 items, fully calculated on server ✅
- Sell prices = variable per player inventory, client-calculated ⚠️

**If implementing sell price calculation on server:**
- Can pre-calculate for all base items
- Still need dynamic calculation for modded items (player inventory)
- Broadcast would include both buy AND sell prices (~1000 items total)

---

## Summary Table

| Case | Type | Registry | Whitelist | Blacklist | Price Defined? | Sellable? | Calculated |
|------|------|----------|-----------|-----------|----------------|-----------|------------|
| 1    | Buy  | ✅ Required | - | - | ✅ Always | ✅ Yes | Server |
| 2    | Sell | ❌ Not in list | N/A | N/A | ❌ No | ❌ No | - |
| 3A1  | Sell | ❌ Missing | ✅ Whitelist | - | ❌ No | ❌ No | Client |
| 3A2  | Sell | ✅ Defined, empty | ✅ Whitelist | - | ❌ Missing | ❌ No | Client |
| 3A3  | Sell | ❌ Missing | - | ✅ Blacklist | ✅ Default | ✅ Yes | Client |
| 3A4  | Sell | ✅ Blacklisted | - | ✅ Blacklist | ❌ Ignored | ❌ No | - |
| 3A5  | Sell | ✅ Defined, price | - | ✅ Blacklist | ✅ Yes | ✅ Yes | Client |

---

## Required Code Review

1. **ShopUI.lua** (`getSellPrice()`) - Verify handling of undefined prices
2. **ShopPriceSell.lua** - Check fallback logic for missing prices in whitelist mode
3. **Broadcast plan** - Account for sell price calculation limitations
