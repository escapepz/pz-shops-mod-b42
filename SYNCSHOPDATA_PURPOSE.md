# What Does SyncShopData Actually Provide Now?

**TL;DR**: SyncShopData provides the **SHOP CONFIGURATION** (catalog + permissions), NOT prices. Prices are calculated client-side deterministically.

---

## The Misconception

Many assume that since clients calculate prices deterministically, `SyncShopData` is redundant. **This is incorrect.**

`SyncShopData` is still **CRITICAL** because it provides:

1. ✅ **What items exist** (Shop.Items)
2. ✅ **What items are buyable** (Shop.PlayerBuy)
3. ✅ **What items are sellable** (Shop.PlayerSell)
4. ✅ **Permission modes** (BuyIsWhitelist, SellIsWhitelist)
5. ✅ **Fallback prices** (defaultPrice, defaultPriceBroken)

**NOT included in SyncShopData**:
- ❌ Calculated prices (client calculates these)
- ❌ Price modifiers (client applies these)
- ❌ Hook-based adjustments (client executes hooks)

---

## What Each Part of SyncShopData Is Used For

### 1. Shop.Items - Item Metadata Registry

**Data sent from server**:
```lua
Shop.Items = {
    ["Base.Apple"] = {
        basePrice = 150,
        price = 150,
        type = "Normal",
    },
    ["Base.Banana"] = {
        basePrice = 200,
        price = 200,
    },
    -- ... 40+ items
}
```

**How client uses it** (ShopPriceBuy.lua:L26-L36):
```lua
function Shop.resolvePlayerBuyPrice(player, itemId, context)
    local item = Shop.Items[itemId]  ← LOOKS UP ITEM FROM SYNCSHOPDATA
    if not item then
        error("[ShopBuy] Unknown item: " .. tostring(itemId))
    end
    
    local base = item.basePrice or item.price  ← GETS BASE PRICE FROM SYNCSHOPDATA
    -- Then applies client-side modifiers (traits, skills, difficulty, etc.)
    local price = PriceUtils.applyModifiers(base, modifiers)
    return price
end
```

**Purpose**: **Tells client which items exist and their BASE price** (before modifiers)

---

### 2. Shop.PlayerBuy - Buyable Items Registry

**Data sent from server**:
```lua
Shop.PlayerBuy = {
    ["Base.Apple"] = {
        enabled = true,
        price = 150,
        currency = "coin",
    },
    ["Base.Banana"] = {
        enabled = true,
        price = 200,
    },
    -- Only registered items are here
}
```

**How client uses it** (ShopPriceBuy.lua:L11-L15):
```lua
function Shop.canPlayerBuy(fullType)
    local playerBuy = Shop.PlayerBuy or {}
    local cfg = playerBuy[fullType]
    return cfg and cfg.enabled  ← CHECKS IF ITEM IS BUYABLE
end
```

**Also used in ClientShopListingService.lua:L75-L92**:
```lua
for itemId, catalogEntry in pairs(catalog.items) do
    local itemConfig = Shop.Items[itemId]  ← READS FROM SYNCSHOPDATA
    if itemConfig and catalogEntry.available then
        -- Build list of buyable items for UI
        table.insert(result, {
            itemId = itemId,
            basePrice = basePrice,
            previewPrice = previewPrice,  ← CALCULATED CLIENT-SIDE
            category = catalogEntry.category,
            available = true,
        })
    end
end
```

**Purpose**: **Defines which items the player can buy** (permission/whitelist check)

---

### 3. Shop.PlayerSell - Sellable Items Registry

**Data sent from server**:
```lua
Shop.PlayerSell = {
    ["Base.Apple"] = {
        enabled = true,
        basePrice = 75,
    },
    -- Items the shop will buy back
}
```

**How client uses it** (ShopPriceSell.lua:L10-L27):
```lua
function Shop.canPlayerSell(fullType)
    -- Check if in PlayerSell registry
    local playerSell = Shop.PlayerSell or {}
    local cfg = playerSell[fullType]
    
    -- If not registered:
    if not cfg then
        -- Use whitelist/blacklist mode to decide
        if Shop.SellIsWhitelist then
            return false  ← BLOCKED in whitelist mode
        else
            return true   ← ALLOWED in blacklist mode (use default price)
        end
    end
    return cfg and cfg.enabled
end
```

**Purpose**: **Defines which items the player can sell back** (permission check)

---

### 4. BuyIsWhitelist & SellIsWhitelist - Permission Modes

**Data sent from server**:
```lua
Shop.BuyIsWhitelist = true   -- Only items in PlayerBuy can be bought
Shop.SellIsWhitelist = false  -- All items can be sold except those in blacklist
```

**How client uses it** (ShopPriceBuy.lua:L33-L35):
```lua
if not Shop.canPlayerBuy(itemId) then
    -- Item not in registry
    if Shop.BuyIsWhitelist then
        -- Whitelist: REJECT unregistered items
        -- Only registered items are buyable
    else
        -- Blacklist: ALLOW unregistered items
        -- Use base price for unregistered items
    end
end
```

**Purpose**: **Controls whether unregistered items are allowed or blocked**
- **Whitelist mode** (true): Only listed items can be bought/sold
- **Blacklist mode** (false): All items can be bought/sold except listed ones

---

### 5. defaultPrice & defaultPriceBroken - Fallback Prices

**Data sent from server**:
```lua
Shop.defaultPrice = 100        -- Default price for unregistered items (normal condition)
Shop.defaultPriceBroken = 50   -- Default price for unregistered items (damaged/worn)
```

**How client uses it** (ShopPriceSell.lua:L45-L57):
```lua
function Shop.getPlayerSellPrice(player, item, context)
    local fullType = item:getFullType()
    local cfg = Shop.PlayerSell[fullType]
    
    if not cfg then
        -- Item not registered, use fallback
        if item:getCondition() < 50 then
            return Shop.defaultPriceBroken  ← USES FALLBACK FOR DAMAGED ITEMS
        else
            return Shop.defaultPrice        ← USES FALLBACK FOR GOOD ITEMS
        end
    end
    
    local base = cfg.basePrice or item.basePrice
    -- ... apply modifiers
end
```

**Purpose**: **Provides fallback prices for unregistered items** (items that aren't explicitly priced)

---

## The Hybrid Architecture

This is a **two-phase model**:

```
PHASE A: CLIENT PREVIEW (NO NETWORK)
┌─────────────────────────────────────────────────────┐
│ 1. Client receives SyncShopData (catalog + config)  │
│ 2. Client calculates preview prices locally         │
│    - Uses Shop.Items (base prices)                  │
│    - Applies trait modifiers (client-side)          │
│    - Displays price in UI                           │
│                                                     │
│ RESULT: Instant price preview, no network lag       │
└─────────────────────────────────────────────────────┘

PHASE B: SERVER SETTLEMENT (AUTHORITATIVE)
┌─────────────────────────────────────────────────────┐
│ 1. Player clicks "Buy" button                        │
│ 2. Client sends transaction to server               │
│ 3. Server recalculates price from scratch           │
│    - Re-reads Shop.Items from server state          │
│    - Re-applies all hooks (server-side context)     │
│    - Validates balance                              │
│ 4. Server deducts balance, spawns items             │
│ 5. Server confirms transaction to client            │
│                                                     │
│ RESULT: Authoritative, can't be cheated             │
└─────────────────────────────────────────────────────┘
```

---

## Why SyncShopData Is Still Needed

Without SyncShopData, clients wouldn't know:

| Missing Data | Consequence |
|---|---|
| **Shop.Items** | Can't calculate preview prices (no base prices) |
| **Shop.PlayerBuy** | Can't filter buyable items in UI (no permission check) |
| **Shop.PlayerSell** | Can't filter sellable items in inventory (no permission check) |
| **BuyIsWhitelist** | Can't decide if unregistered items are allowed |
| **SellIsWhitelist** | Can't decide if unregistered items are allowed |
| **defaultPrice** | Can't handle items not explicitly priced |

**Result**: UI would be empty or broken on every client that joins.

---

## Comparison: Before vs After Optimization

### BEFORE (Phase 1-2: With Price Broadcasts)

```
SyncShopData contains:
├─ Shop.Items ✅
├─ Shop.PlayerBuy ✅
├─ Shop.PlayerSell ✅
├─ BuyIsWhitelist ✅
├─ SellIsWhitelist ✅
├─ defaultPrice ✅
└─ SyncBuyPrices  ← CALCULATED PRICES (PER-PLAYER BROADCAST)

Network cost: HIGH (prices calculated on server, sent to all clients)
```

### AFTER (Phase 3+: Deterministic Client Pricing)

```
SyncShopData contains:
├─ Shop.Items ✅
├─ Shop.PlayerBuy ✅
├─ Shop.PlayerSell ✅
├─ BuyIsWhitelist ✅
├─ SellIsWhitelist ✅
├─ defaultPrice ✅
└─ NO SyncBuyPrices  ✅ (Clients calculate deterministically)

Network cost: LOW (only catalog + config sent once per player)

Additional benefit:
├─ Clients calculate prices instantly (no network lag)
├─ If price hooks fire, client recalculates locally
└─ Server validates on transaction (can't be spoofed)
```

---

## Actual SyncShopData Data Flow Example

**Scenario**: Vanilla shop with 42 items, 15 registered for buy, 27 for sell

**T+0**: Client requests
```
Client → Server: RequestShopData {}
```

**T+50ms**: Server sends
```
Server → Client: SyncShopData {
    Items: {
        ["Base.Apple"]: {basePrice: 150, price: 150},
        ["Base.Banana"]: {basePrice: 200, price: 200},
        ["Base.Orange"]: {basePrice: 100, price: 100},
        -- ... 39 more items
    },
    PlayerBuy: {
        ["Base.Apple"]: {enabled: true, price: 150},
        ["Base.Banana"]: {enabled: true, price: 200},
        -- ... 13 more items
    },
    PlayerSell: {
        ["Base.Apple"]: {enabled: true, basePrice: 75},
        ["Base.Banana"]: {enabled: true, basePrice: 100},
        -- ... 25 more items
    },
    BuyIsWhitelist: true,
    SellIsWhitelist: false,
    defaultPrice: 100,
    defaultPriceBroken: 50,
}
```

**T+50ms**: Client processes and caches
```lua
SHOPSB42.Shop.Items = {...}         -- 42 items
SHOPSB42.Shop.PlayerBuy = {...}     -- 15 items
SHOPSB42.Shop.PlayerSell = {...}    -- 27 items
SHOPSB42.Shop.BuyIsWhitelist = true
SHOPSB42.Shop.SellIsWhitelist = false
SHOPSB42.Shop.defaultPrice = 100
SHOPSB42.Shop.defaultPriceBroken = 50
```

**T+50ms onward**: Client uses data
```lua
-- When player opens shop:
for itemId, basePrice in pairs(Shop.Items) do
    if Shop.canPlayerBuy(itemId) then
        -- Calculate preview price
        local preview = ClientShopListingService.calculatePreviewBuyPrice(itemId, basePrice)
        -- Display: "Apple: 150 → 160 (+6.7%)"
    end
end
```

---

## Summary

| Aspect | Before (Phase 1) | After (Phase 3) | Change |
|--------|---|---|---|
| **SyncShopData still sent** | ✅ Yes | ✅ Yes | **NO CHANGE** |
| **SyncBuyPrices broadcast** | ✅ Yes (per-player) | ❌ No | **REMOVED** |
| **Client price calculation** | ❌ No (uses broadcast) | ✅ Yes (deterministic) | **ADDED** |
| **Network packets per sync** | ~20+ (items + prices) | ~5 (items only) | **75% REDUCTION** |
| **UI latency** | High (waits for broadcast) | Low (instant local calc) | **IMPROVED** |
| **Price accuracy** | Server-dependent | Deterministic & verifiable | **SAME** |

**Conclusion**: SyncShopData is **MORE important than ever** because it's the ONLY data sent per player—the client now does all heavy lifting with prices.

---

## Code References

- **SyncShopData handler**: `ShopCommandDispatcherClient.lua:L19-L81`
- **SyncShopData sender**: `ShopFinalizeHandlerServer.lua:L302-L327`
- **Usage in pricing**: `ShopPriceBuy.lua:L26-L50`, `ShopPriceSell.lua:L10-L57`
- **Usage in UI**: `ClientShopListingService.lua:L55-L96`
- **Usage in permissions**: `ShopPriceBuy.lua:L11-L15`, `ShopPriceSell.lua:L10-L27`
