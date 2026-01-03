Perfect. Now I have the complete answer. Let me provide a clear summary:

## Server Data Structures

**1. SyncShopData (initial listing items)**

- Each item in `Shop.Items` has `.price` and `.basePrice`

```lua
{
  Items = {
    ["Base.Apple"] = { price = 25.00, basePrice = 50.00, ... }
  },
  PlayerBuy = { ... },
  PlayerSell = { ... },
  BuyIsWhitelist = bool,          -- Sent for consistency; server always enforces whitelist (PlayerBuy registry only)
  SellIsWhitelist = bool          -- Controls sell mode: true = whitelist only, false = blacklist (all items with fallback price)
}
```

**Default Price Fallback (NOT in SyncShopData):**
- When inventory item is not registered (in blacklist mode), client uses hardcoded defaults from `Shop.lua`:
  - `Shop.defaultPrice = 1` (normal items)
  - `Shop.defaultPriceBroken = 1` (broken items)
- **WARNING:** These are NOT sent in any broadcast. If server changes these values post-init, client won't know.
- Defined in both server and client `Shop.lua` (shared init)

**Potential Bug - defaultPrice Not Synced:**
- If server modifies `Shop.defaultPrice` or `Shop.defaultPriceBroken` after initial sync, client retains old values
- Unregistered inventory items will display incorrect basePrice based on stale defaults
- **Fix Required:** Either:
  1. Send defaultPrice/defaultPriceBroken in SyncShopData, or
  2. Prevent runtime changes to these values, or
  3. Broadcast defaultPrice changes as a separate sync command

**2. SyncBuyPrices (live price changes for buy)**

- Each item in `buyPrices` has `.price` and `.basePrice` plus `.modifiers`
- Sent on initial sync (all prices) and on delta updates (changed items only)

```lua
{
  buyRevision = number,        -- Incremented each time buy prices change (for change detection)
  sellRevision = number,       -- Current sell revision (for atomicity checks)
  isInitialSync = bool,        -- true = full sync, false/omitted = delta update
  buyPrices = {
    ["Base.Apple"] = {
      price = 25.00,      -- final calculated price
      basePrice = 50.00,  -- base price before modifiers
      modifiers = { ... } -- array of applied modifiers (stored but not currently displayed in UI)
    }
  }
}
```

**Revision Semantics:**
- `buyRevision`: Incremented on server when buy prices change; client compares to detect changes
- Both revisions sent together for atomicity (prevents stale state if messages reorder)

**Note on `modifiers`:**
- Stored in client's `Shop._buyModifierMetadata[itemId]` for transparency and extensibility
- Preserves the breakdown of how the final price was calculated
- Not currently actively displayed in UI; client primarily uses `.price` and `.basePrice` for display
- Available for future use or external mod consumers needing detailed modifier breakdown

**3. SyncSellRules (live price changes for sell)**

- Does NOT include individual item prices, only modifier rules
- Sent when sell modifiers or overrides change (delta detection)

```lua
{
  buyRevision = number,        -- Current buy revision (for atomicity checks)
  sellRevision = number,       -- Incremented each time sell rules change (for change detection)
  sellModifiers = { ... },     -- global sell modifier rules (condition + effect)
  sellOverrides = { ... },     -- global sell price overrides (itemId -> price)
  isInitialSync = bool         -- true = full sync, false/omitted = delta update (if rules changed)
}
```

**Revision Semantics:**
- `sellRevision`: Incremented on server when sell rules change; client compares to detect changes
- Both revisions sent together for atomicity (prevents stale state if messages reorder)

**Summary:** Buy prices include `.price` and `.basePrice` on each item. Sell rules only broadcast modifiers, not individual prices.

## Client Update Flow (SyncBuyPrices)

When client receives `SyncBuyPrices`:

1. **Data Storage** (`handleSyncBuyPrices`):
   - Updates `Shop.CalculatedPrices.buyPrices[itemId]` with new price
   - Stores modifier metadata in `Shop._buyModifierMetadata[itemId]`
   - Checks if revision changed

2. **UI Invalidation** (if revision changed):
   - Calls `ShopSyncClient.invalidateUI(BUY_PRICE_DELTA)`

3. **Cache & Cart Clearing**:
   - Clears `ui.shopItemsCache` (all tab caches invalidated)
   - Calls `ui:clearCartOnPriceChange()` (users must re-add items to see new prices)
   - Calls `ui:cancelPendingTransactions()` (prevents errors from stale data)

4. **UI Rebuild**:
   - Calls `ui:rebuildActiveTab()` to re-render listing with updated prices

**UI State Handling:**
- If UI is OPEN: Immediately invalidates cache and rebuilds active tab
- If UI is CLOSED: Sets `ShopSyncClient.pricesChangedWhileClosed = true` flag
  - When UI reopens, it detects flag and rebuilds all tabs
  - Prevents showing stale prices to player

## ShopUI Price Display Verification

**YES, ShopUI correctly uses finalPrice from broadcast:**

- **ShopUI.lua line 1362** (`recalculateRowPrice`): Retrieves `Shop.CalculatedPrices.buyPrices[itemId]` (finalPrice)
- **ShopUI.lua line 51** (`calcBuyPrice`): Returns server-calculated price from cache
- **ShopTabUI.lua line 112** (`doDrawShopItem`): Displays `item.item.price` (which is finalPrice from cache)

Flow: `SyncBuyPrices.buyPrices[itemId].price` → `Shop.CalculatedPrices.buyPrices[itemId]` → `row.price` → displayed as finalPrice

## Known Bug: basePrice Storage

**BUG LOCATION:** `ShopSyncClient.lua` lines 251, 283

**Issue:**
```lua
-- Current code (WRONG):
Shop.CalculatedPrices.buyPrices[itemId] = priceData.price  -- Only stores finalPrice
```

**Problem:**
- Server broadcasts both `.price` (finalPrice) and `.basePrice` for each item
- Client only extracts and stores `.price`, discarding `.basePrice`
- When UI rebuilds with `recalculateRowPrice`, it only has the finalPrice
- basePrice defaults to finalPrice (line 1354-1355 in ShopUI.lua): `row.basePrice = row.price`
- Result: Visual bug - no basePrice comparison, discount/markup not shown

**Fix Required:**
Store the full `priceData` object, not just the price number:
```lua
-- Fixed code:
Shop.CalculatedPrices.buyPrices[itemId] = priceData  -- Store full table with price + basePrice
```

Then update consumers to access:
- `Shop.CalculatedPrices.buyPrices[itemId].price` for finalPrice
- `Shop.CalculatedPrices.buyPrices[itemId].basePrice` for basePrice

## SyncSellRules: Pricing Architecture

**IMPORTANT: SyncSellRules does NOT create `.price` and `.basePrice` per item**

**Key Differences:**
- **SyncBuyPrices**: Server sends pre-calculated finalPrice + basePrice for each item
- **SyncSellRules**: Server sends only modifier rules; prices are calculated on CLIENT per inventory item

**Sell Price Calculation (Client-Side):**
1. Item's basePrice determined from:
   - Registry (ShopPriceSell.lua) if registered
   - `Shop.defaultPrice` or `Shop.defaultPriceBroken` if unregistered
2. Modifiers applied (from SyncSellRules):
   - sellModifiers (condition-based, reputation, etc.)
   - sellOverrides (global overrides)
3. Result stored in `row.price` (finalPrice)
4. basePrice preserved from step 1 for display comparison

**Flow for Sell Tab Items:**
- basePrice: Set from registry/default on first calculation
- finalPrice: Calculated from basePrice + modifiers from SyncSellRules (per item's condition)
- Both stored in row object, used for UI display with comparison

## Examples: sellModifiers and sellOverrides

### sellModifiers (Array of Rules)
Condition-based price multipliers applied to each item:

```lua
{
  {
    itemId = "Base.BaseballBat",
    type = "sell",
    priority = 50,
    condition = { kind = "always" },
    effect = { kind = "multiply", value = 0.8 }  -- 20% discount
  },
  {
    itemId = "Base.Apple",
    type = "sell",
    priority = 50,
    condition = { kind = "always" },
    effect = { kind = "multiply", value = 1.5 }  -- 50% markup
  }
}
```

### sellOverrides (Key-Value Pairs)
Fixed sell prices that completely replace base price calculations:

```lua
{
  ["Base.BaseballBat"] = 100,   -- Sell for exactly 100 coins
  ["Base.Hammer"] = 50,         -- Sell for exactly 50 coins
}
```

**Notes:**
- **sellModifiers**: Applied per-item; multipliers are evaluated based on conditions (always, item_condition_ge, etc.)
- **sellOverrides**: Direct price replacement; bypasses all modifier calculations
- Both sent as part of SyncSellRules and used by client calculator (ShopPriceCalculatorShared.lua)
