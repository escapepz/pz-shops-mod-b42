# Example Shop Mod - Implementation Guide

## Overview

This guide explains how the Example Shop mod uses the Shop hook system. Use this as a reference and template when building your own Shop mods.

## Architecture

The mod is split into three modules for clear separation of concerns:

```
ExampleShop (Shared, 532 lines)
├── Configuration (lines 14-19)
├── Utility Functions (lines 23-45)
├── Item Registration (lines 50-140)
├── Buy Price Modifications (lines 145-244)
├── Buy Price Overrides (lines 249-271)
├── Sell Price Modifications (lines 276-327)
├── Sell Price Overrides (lines 412-445)
├── Hook Registration (lines 449-518)
└── Initialization (lines 522-531)

ExampleShopServer (Server-only, 139 lines)
├── Transaction Logging (lines 12-33)
├── Reputation System (lines 35-97)
└── Registry Finalization (lines 100-137)

ExampleShopClient (Client-only, 143 lines)
├── UI Display Helpers (lines 12-88)
├── Time Display (lines 94-106)
├── Item Browser (lines 111-137)
└── Initialization (line 141)
```

## Module Separation

### Shared Module: ExampleShop.lua

**What it contains:**
- Core configuration (CONFIG table)
- Utility functions (logging, reputation getters)
- All item registration (buy and sell)
- All price modification functions
- All price override functions
- Hook registration logic
- Test function

**Why shared?**
- Price hooks must run on both client and server
- Items need to be available to both sides
- Shared allows single source of truth for prices
- Loaded automatically by both client and server

**Loaded by:** Both client and server

### Server Module: ExampleShopServer.lua

**What it contains:**
- Transaction logging (onPlayerBuyFromShop, onPlayerSellToShop)
- Reputation functions (getVIPTierName, getPlayerShopStats, etc.)
- Registry finalization (Shop.FinalizeRegistry, Shop.FinalizeSellRegistry)
- Delayed price hook testing

**Why server-only?**
- Reputation must be authoritative (prevent cheating)
- Transaction logging is server record
- Registry finalization ensures items loaded correctly
- Player properties used for reputation storage

**Key functions:**
- `onPlayerBuyFromShop(player, itemId, quantity, price)` - Award 1 rep per item
- `onPlayerSellToShop(player, itemId, quantity, totalPrice)` - Award 2 rep per item
- `getVIPTierName(reputation)` - Returns: "Standard", "Bronze", "Silver", "Gold"
- `getPlayerShopStats(player)` - Returns table with reputation, tier, discounts

**Loaded by:** Server only

### Client Module: ExampleShopClient.lua

**What it contains:**
- VIP tier display (name and color)
- Price formatting
- Discount text display
- Item tooltips
- Time period display
- Item browser with categories
- Category display names

**Why client-only?**
- UI display only matters on client
- Reduces network overhead
- Client-specific rendering and formatting
- No sensitive data (only read reputation from ExampleShop)

**Key functions:**
- `getVIPTierDisplay(reputation)` - Returns {tier, color}
- `formatPrice(price)` - Returns "$100" format
- `getDiscountText(reputation)` - Returns "15% VIP Discount" or "No discount"
- `createItemTooltip(itemId, price)` - Returns tooltip string
- `showVIPBenefits(player)` - Logs VIP status

**Loaded by:** Client only

## Implementation Patterns

### Pattern 1: Simple Item Registration

**Location:** `ExampleShop.registerBuyItems()` (lines 50-93)

```lua
function ExampleShop.registerBuyItems()
    ExampleShop.log("Registering buy items...")
    
    Shop.RegisterItem("Base.Apple", { tab = Tab.Food, price = 12 })
    Shop.RegisterItem("Base.Banana", { tab = Tab.Food, price = 15 })
    -- ... more items
end
```

**Hook call:**
```lua
ShopEvents.registerOnShopRegisterItems(ExampleShop.registerBuyItems)
```

**Key points:**
- Called once during shop initialization
- No parameters passed to hook callback
- Register all items in single callback or multiple callbacks
- Order doesn't matter
- Must register before Shop.FinalizeRegistry()
- Items have tab (category) and base price

**When it runs:** Before shop becomes locked

---

### Pattern 2: Multiple Modification Hooks on Same Event

**Location:** `registerHooks()` (lines 470-475)

```lua
-- Register 4 different modification hooks
ShopPriceEvents.registerOnShopModifyBuyPrice(ExampleShop.modifyBuyPriceByCategory)
ShopPriceEvents.registerOnShopModifyBuyPrice(ExampleShop.modifyBuyPriceByTime)
ShopPriceEvents.registerOnShopModifyBuyPrice(ExampleShop.modifyBuyPriceVIP)
ShopPriceEvents.registerOnShopModifyBuyPrice(ExampleShop.modifyBuyPriceByBulk)
```

**Each hook receives:**
- `player` - Player making purchase
- `itemId` - Item being purchased (e.g., "Base.Apple")
- `base` - Base price (e.g., 12)
- `context` - Transaction context (shopId, quantity, etc.)
- `modifiers` - Array to modify (add multipliers)

**Key points:**
- All 4 hooks execute in order registered
- Each hook modifies the `modifiers` array
- Final price = base × multiplier1 × multiplier2 × ... × multiplierN
- Example: 12 × 0.9 × 1.15 × 0.85 × 0.85 = 8.97
- Order matters if hooks depend on each other
- Modification hooks ALWAYS execute

**Example: Category Markup**
```lua
function ExampleShop.modifyBuyPriceByCategory(player, itemId, base, context, modifiers)
    if string.find(itemId, "Handgun") or ... then
        table.insert(modifiers, { multiplier = 1.3, label = "weaponMarkup" })
    end
end
```

**Example: Time-based Pricing**
```lua
function ExampleShop.modifyBuyPriceByTime(player, itemId, base, context, modifiers)
    local currentHour = getGameTime():getHour()
    
    if currentHour >= 6 and currentHour < 10 then
        table.insert(modifiers, { multiplier = 0.95, label = "morningDiscount" })
    end
end
```

---

### Pattern 3: Override Hooks (Short-circuit Behavior)

**Location:** `registerHooks()` (lines 481-488)

```lua
ShopPriceEvents.registerOnShopOverrideBuyPrice(ExampleShop.overrideBuyPriceSpecialItems)
ShopPriceEvents.registerOnShopOverrideBuyPrice(ExampleShop.overrideBuyPriceAdmin)
```

**Function signature:**
```lua
function ExampleShop.overrideBuyPriceSpecialItems(player, itemId, price, context)
    -- Must return a value OR nil
    -- First non-nil response stops the chain
end
```

**Key points:**
- Override hooks check conditions
- MUST return a value or nil (not nothing)
- First non-nil return stops other overrides
- Return the final price, or nil to use calculated price
- Override hooks short-circuit: first match wins

**Example: Fixed Prices**
```lua
function ExampleShop.overrideBuyPriceSpecialItems(player, itemId, price, context)
    local specialPrices = {
        ["Base.Water"] = 10,
        ["Base.Pop"] = 15,
    }
    
    if specialPrices[itemId] then
        return specialPrices[itemId]
    end
    
    return nil  -- Use calculated price
end
```

**Example: Admin Free Items**
```lua
function ExampleShop.overrideBuyPriceAdmin(player, itemId, price, context)
    if player and player:isAdmin() then
        return 0  -- Free
    end
    return nil
end
```

**Execution order:**
1. modifyBuyPrice hooks run (all of them)
2. Calculate final price from modifiers
3. overrideBuyPrice hooks run (first match stops)
4. Use override result OR calculated price

---

### Pattern 4: Sell Price Modifications

**Location:** `registerHooks()` (lines 491-496)

```lua
ShopPriceEvents.registerOnShopModifySellPrice(ExampleShop.modifySellPriceByCondition)
ShopPriceEvents.registerOnShopModifySellPrice(ExampleShop.modifySellPriceByQuantity)
ShopPriceEvents.registerOnShopModifySellPrice(ExampleShop.modifySellPriceByReputation)
```

**Function signature:**
```lua
function ExampleShop.modifySellPriceByCondition(player, item, base, context, modifiers)
    -- player: selling player
    -- item: InventoryItem being sold (actual object, not string)
    -- base: base sell price
    -- context: transaction context
    -- modifiers: array to modify
end
```

**Key difference from buy hooks:**
- Receives `item` object (not itemId string)
- Can inspect item properties:
  - `item:getID()` - Item ID string
  - `item:getCondition()` - Condition percentage (0-100)
  - `item:getType()` - Item type

**Example: Condition-based Pricing**
```lua
function ExampleShop.modifySellPriceByCondition(player, item, base, context, modifiers)
    local condition = item:getCondition()
    
    if condition < 25 then
        table.insert(modifiers, { multiplier = 0.2, label = "conditionBad" })
    elseif condition < 50 then
        table.insert(modifiers, { multiplier = 0.5, label = "conditionFair" })
    end
end
```

---

### Pattern 5: Sell Price Overrides

**Location:** `registerHooks()` (lines 502-509)

```lua
ShopPriceEvents.registerOnShopOverrideSellPrice(ExampleShop.overrideSellPriceDamaged)
ShopPriceEvents.registerOnShopOverrideSellPrice(ExampleShop.overrideSellPricePremium)
```

**Function signature:**
```lua
function ExampleShop.overrideSellPriceDamaged(player, item, price, context)
    -- Inspect item and return fixed price or nil
end
```

**Example: Reject Damaged Items**
```lua
function ExampleShop.overrideSellPriceDamaged(player, item, price, context)
    local itemId = item:getID()
    local condition = item:getCondition()
    
    if (string.find(itemId, "Pistol") or string.find(itemId, "Rifle")) and condition < 30 then
        return 0  -- Won't buy
    end
    
    return nil  -- Use calculated price
end
```

**Example: Premium Prices**
```lua
function ExampleShop.overrideSellPricePremium(player, item, price, context)
    local itemId = item:getID()
    local premiumPrices = {
        ["Base.AssaultRifle"] = 150,
        ["Base.HuntingRifle"] = 120,
    }
    
    return premiumPrices[itemId] or nil
end
```

---

### Pattern 6: Reputation System

**Location:** ExampleShop.lua (lines 29-45) + ExampleShopServer.lua

**Shared functions:**
```lua
function ExampleShop.getPlayerReputation(player)
    if not player then return 0 end
    return player:getProperty("exampleshop_reputation") or 0
end

function ExampleShop.setPlayerReputation(player, value)
    if player then
        player:setProperty("exampleshop_reputation", value)
    end
end

function ExampleShop.addPlayerReputation(player, amount)
    local current = ExampleShop.getPlayerReputation(player)
    ExampleShop.setPlayerReputation(player, current + amount)
end
```

**Server-side tracking:**
```lua
function ExampleShopServer.onPlayerBuyFromShop(player, itemId, quantity, price)
    ExampleShop.addPlayerReputation(player, quantity * 1)  -- 1 rep per item
end

function ExampleShopServer.onPlayerSellToShop(player, itemId, quantity, totalPrice)
    ExampleShop.addPlayerReputation(player, quantity * 2)  -- 2 rep per item
end
```

**Using in price hooks:**
```lua
function ExampleShop.modifyBuyPriceVIP(player, itemId, base, context, modifiers)
    if not ExampleShop.CONFIG.enableVIPSystem or not player then return end
    
    local reputation = ExampleShop.getPlayerReputation(player)
    
    if reputation >= 500 then
        table.insert(modifiers, { multiplier = 0.85, label = "vipGold" })
    end
end
```

**Key points:**
- Reputation stored as player property (persistent)
- Server is authority (server-side functions only)
- Client can read reputation (ExampleShop.getPlayerReputation)
- Used in buy/sell hooks for VIP discounts
- Earned on both purchases and sales

---

## Hook Execution Flow

### Buy Price Flow

```
1. Player initiates buy transaction
   ↓
2. Shop.resolvePlayerBuyPrice() called with:
   - player
   - itemId
   - context (quantity, shopId, etc.)
   ↓
3. For each modification hook (in order):
   - Call hook(player, itemId, base, context, modifiers)
   - Hook can add to modifiers array
   ↓
4. Calculate: base × multiplier1 × multiplier2 × ...
   ↓
5. For each override hook (in order):
   - Call hook(player, itemId, calculatedPrice, context)
   - If returns non-nil: STOP and use that price
   - If returns nil: continue to next hook
   ↓
6. Return final price
   ↓
7. Player completes transaction
```

**Example calculation:**
```
Base price: 12 (Apple)
Food discount 0.9x:        12.0 × 0.9 = 10.8
Morning discount 0.95x:    10.8 × 0.95 = 10.26
VIP Gold 0.85x:            10.26 × 0.85 = 8.721
Bulk discount 0.85x:       8.721 × 0.85 = 7.413
Override (none):           7.413 (no override)
FINAL:                     7.41 (rounded)
```

### Sell Price Flow

```
1. Player initiates sell transaction with item
   ↓
2. Shop.resolvePlayerSellPrice() called with:
   - player
   - item (InventoryItem object)
   - context
   ↓
3. For each modification hook (in order):
   - Call hook(player, item, base, context, modifiers)
   - Hook inspects item.condition, item.type, etc.
   - Hook can add to modifiers
   ↓
4. Calculate: base × multiplier1 × multiplier2 × ...
   ↓
5. For each override hook (in order):
   - Call hook(player, item, calculatedPrice, context)
   - If non-nil: STOP and use that price
   - If nil: continue
   ↓
6. Return final price
   ↓
7. Player completes transaction
```

---

## Error Handling Patterns

### Safe Parameter Access

**BAD:**
```lua
function unsafeHook(player, itemId, base, context, modifiers)
    local username = player:getUsername()  -- CRASH if player is nil
end
```

**GOOD:**
```lua
function safeHook(player, itemId, base, context, modifiers)
    if not player then return end  -- Early return
    local username = player:getUsername()
end
```

### Safe Table Access

**BAD:**
```lua
function badModification(player, itemId, base, context, modifiers)
    print(context.shopId)  -- CRASH if key missing
end
```

**GOOD:**
```lua
function goodModification(player, itemId, base, context, modifiers)
    local shopId = context.shopId or "Unknown"
    print(shopId)
end
```

### Type Validation

**BAD:**
```lua
function badValidation(player, itemId, base, context, modifiers)
    local price = base * 2  -- CRASH if base not number
end
```

**GOOD:**
```lua
function goodValidation(player, itemId, base, context, modifiers)
    if type(base) ~= "number" then return end
    local price = base * 2
end
```

### Inventory Check

**BAD:**
```lua
if count >= 10 then  -- CRASH if inventory nil
end
```

**GOOD:**
```lua
if player:getInventory() then
    local count = player:getInventory():getItemCount(itemId)
    if count >= 10 then
        -- safe to use count
    end
end
```

---

## Performance Patterns

### Avoid Expensive Operations in Hooks

**BAD:** File I/O in price hook
```lua
ShopPriceEvents.registerOnShopModifyBuyPrice(function(...)
    local config = io.open("config.txt")  -- Slow! Called every transaction
end)
```

**GOOD:** Load once, reuse
```lua
local CONFIG = loadConfigOnce()

ShopPriceEvents.registerOnShopModifyBuyPrice(function(...)
    -- Use CONFIG directly (already loaded)
end)
```

### Cache Reputation Lookups

**BAD:**
```lua
-- Called every price calculation
local reputation = ExampleShop.getPlayerReputation(player)
```

**GOOD:**
```lua
-- If called multiple times, cache result
local reputation = context.playerReputation or ExampleShop.getPlayerReputation(player)
context.playerReputation = reputation
```

### Early Returns in Overrides

**BAD:**
```lua
if itemId == "special_item" then
    if player then
        -- Expensive check
    end
end
```

**GOOD:** Fastest checks first
```lua
if itemId ~= "special_item" then
    return nil  -- Exit immediately
end

if not player then
    return nil
end

-- Expensive check only if needed
```

---

## Testing Patterns

### Unit Test Template

```lua
function testVIPDiscount()
    local mockPlayer = {
        getProperty = function(self, key)
            if key == "exampleshop_reputation" then
                return 500  -- Gold VIP
            end
        end
    }
    
    local modifiers = {}
    ExampleShop.modifyBuyPriceVIP(mockPlayer, "Base.Apple", 12, {}, modifiers)
    
    assert(modifiers[1].multiplier == 0.85, "VIP Gold discount not applied")
    print("✓ VIP discount test passed")
end
```

### Integration Test Pattern

```lua
function testFullPriceCalculation()
    local player = getPlayer()
    local context = { shopId = "ExampleShop", quantity = 1 }
    
    local finalPrice = Shop.resolvePlayerBuyPrice(player, "Base.Apple", context)
    
    assert(finalPrice > 0, "Price should be positive")
    assert(finalPrice < 20, "Price should be reasonable")
    print("✓ Full price calculation test passed")
end
```

---

## Common Implementation Tasks

### Task 1: Add New Item Category

**Step 1:** Add items in `registerBuyItems()`:
```lua
Shop.RegisterItem("Base.Sword", { tab = Tab.Weapons, price = 500 })
Shop.RegisterItem("Base.Shield", { tab = Tab.Equipment, price = 300 })
```

**Step 2:** Add sell items in `registerSellItems()`:
```lua
Shop.RegisterSellItem("Base.Sword", { price = 250 })
Shop.RegisterSellItem("Base.Shield", { price = 150 })
```

**Step 3:** Add pricing logic:
```lua
function ExampleShop.modifyBuyPriceByCategory(player, itemId, base, context, modifiers)
    -- Existing code...
    
    if string.find(itemId, "Sword") or string.find(itemId, "Shield") then
        table.insert(modifiers, { multiplier = 1.25, label = "weaponEquipmentMarkup" })
    end
end
```

### Task 2: Add Condition-based Buy Pricing

Add new modification hook:
```lua
function ExampleShop.modifyBuyPriceByQuality(player, itemId, base, context, modifiers)
    -- Check if context provides item condition
    if context.itemCondition then
        if context.itemCondition < 50 then
            table.insert(modifiers, { multiplier = 0.8, label = "usedDiscount" })
        end
    end
end

-- Register it:
ShopPriceEvents.registerOnShopModifyBuyPrice(ExampleShop.modifyBuyPriceByQuality)
```

### Task 3: Add Holiday Pricing

Add time-based variation:
```lua
function ExampleShop.modifyBuyPriceByHoliday(player, itemId, base, context, modifiers)
    local gameTime = getGameTime()
    local dayOfYear = gameTime:getDaysSurvived() % 365
    
    -- Christmas pricing (around day 359)
    if dayOfYear > 350 or dayOfYear < 10 then
        table.insert(modifiers, { multiplier = 1.25, label = "holidayMarkup" })
    end
end
```

---

## Debugging and Logging

### Enable Debug Output

```lua
ExampleShop.CONFIG.debugLogging = true
```

Check console for:
```
[ExampleShop] Registering hooks...
[ExampleShop] Registered OnShopRegisterItems
[ExampleShop] Registered OnShopModifyBuyPrice hooks (4x)
[ExampleShop] Total buy modify hooks: 4
```

### Log Price Calculations

Already implemented in `modifyBuyPriceByCategory()`:
```lua
writeLog("ShopsHooksExample", "[Hook] modifyBuyPriceByCategory called: " .. itemId .. " (base: " .. base .. ")")
```

### Print Hook Count

```lua
print("Buy modify hooks: " .. #ShopPriceEvents.OnShopModifyBuyPrice)
print("Buy override hooks: " .. #ShopPriceEvents.OnShopOverrideBuyPrice)
print("Sell modify hooks: " .. #ShopPriceEvents.OnShopModifySellPrice)
print("Sell override hooks: " .. #ShopPriceEvents.OnShopOverrideSellPrice)
```

---

## Next Steps

1. **Review README.md** for feature overview
2. **Review CONFIGURATION.md** for customization guide
3. **Copy ExampleShop.lua** as template for your mod
4. **Customize items** in registration functions
5. **Adjust prices** in modification functions
6. **Add features** using override hooks
7. **Test thoroughly** with logging enabled
8. **Debug** using patterns in this guide

See hooks documentation for complete hook system reference.
