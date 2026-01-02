# Developer Quick Reference: SHA_A vs SHA_B Behavior

For developers implementing or debugging price sync logic.

---

## Protocol Changes at a Glance

### Broadcasting Model

#### SHA_A (Atomic)
```
onPriceHooksChanged() 
  → [single transaction]
  → Shop.PriceHookRevision++
  → SendServerCommandToAll("SyncPriceModifiers", {...})
  → [all clients receive complete state]
```

#### SHA_B (Split)
```
onPriceHooksChanged()
  → [transaction 1]
  → Shop.BuyPriceRevision++
  → SendServerCommandToAll("SyncBuyPrices", {...})
  → [clients may act on incomplete state]
  → [transaction 2]
  → Shop.SellRuleRevision++
  → SendServerCommandToAll("SyncSellRules", {...})
```

---

## Command Reference

### SHA_A: SyncPriceModifiers
```lua
{
    revision = 5,                    -- Single revision for all changes
    modifiers = {
        buyOverrides = {},           -- Buy calculation rules
        sellOverrides = {},          -- Sell calculation rules
    },
    changed = {                      -- Changed prices only
        ["Base.Apple"] = 2.5,
    },
    calculatedPrices = {             -- Full prices (initial sync only)
        buyPrices = { ... },
        sellPrices = { ... },
    },
    isInitialSync = false,           -- Flag: is this initial sync?
}
```

**Client Storage**:
```lua
Shop.PriceHookRevision = 5
Shop.PriceModifiers = data.modifiers      -- Single container
Shop.CalculatedPrices = data.calculatedPrices
```

---

### SHA_B: SyncBuyPrices
```lua
{
    revision = 5,                    -- Buy revision only
    buyPrices = {                    -- Changed prices only
        ["Base.Apple"] = 2.5,
    },
    isInitialSync = false,           -- Flag: is this initial sync?
}
```

**Client Storage**:
```lua
Shop.BuyPriceRevision = 5
Shop.CalculatedPrices.buyPrices[itemId] = price
```

**Missing in SHA_B**: 
- ❌ `buyOverrides`
- ❌ `sellRevision` (consistency check)

---

### SHA_B: SyncSellRules
```lua
{
    revision = 2,                    -- Sell revision only
    sellModifiers = {                -- Sell modifier rules
        { itemId = "Base.Bat", effect = { value = 2.0 } },
    },
    sellOverrides = {                -- Sell price overrides
        ["Base.Bat"] = 50,
    },
    isInitialSync = false,
}
```

**Client Storage**:
```lua
Shop.SellRuleRevision = 2
Shop.SellModifiers = data.sellModifiers
Shop.SellOverrides = data.sellOverrides
```

**Missing in SHA_B**: 
- ❌ `buyRevision` (consistency check)

---

### SHA_B: SyncInitialComplete (PROPOSED)
```lua
{
    buyRevision = 5,                 -- Final buy revision
    sellRevision = 2,                -- Final sell revision
}
```

**Client**: Sets `ShopSyncClient._initialSyncComplete = true` to allow UI to open.

---

## Revision Checking

### SHA_A (Simple)
```lua
-- Check if anything changed
if Shop.PriceHookRevision ~= oldRevision then
    -- All price state was updated together
    RecalculateAllPrices()
end
```

### SHA_B (Complex)
```lua
-- Must check both revisions
if Shop.BuyPriceRevision ~= oldBuyRev or Shop.SellRuleRevision ~= oldSellRev then
    -- One or both changed
    if Shop.BuyPriceRevision ~= oldBuyRev then
        RecalculateBuyPrices()
    end
    if Shop.SellRuleRevision ~= oldSellRev then
        RecalculateSellPrices()
    end
end
```

---

## Initial Sync Protocol

### SHA_A (Atomic)
```
Server → Player: SyncShopData
                 ↓
Server → Player: SyncPriceModifiers (isInitialSync=true)
                 ↓
         [all data available]
         [safe to open UI]
```

### SHA_B (Fragmented - CURRENT)
```
Server → Player: SyncShopData
                 ↓
Server → Player: SyncBuyPrices (isInitialSync=true)
                 ↓
         [RACE CONDITION - UI might open here]
         [sellModifiers still empty!]
                 ↓
Server → Player: SyncSellRules (isInitialSync=true)
                 ↓
         [UI should refresh, showing prices]
```

### SHA_B (Fragmented - PROPOSED FIX)
```
Server → Player: SyncShopData
                 ↓
Server → Player: SyncBuyPrices (isInitialSync=true)
                 ↓
Server → Player: SyncSellRules (isInitialSync=true)
                 ↓
Server → Player: SyncInitialComplete
                 ↓
         [_initialSyncComplete = true]
         [NOW safe to open UI]
```

---

## Price Calculation Flows

### SHA_A: Buy Price on Client
```lua
function calcBuyPrice(itemId, basePrice)
    -- 1. Try cached calculation
    local price = Shop.CalculatedPrices.buyPrices[itemId]
    if price then return price end
    
    -- 2. Try client-side preview (using modifiers)
    local modifiers = Shop.PriceModifiers  -- Contains buy hooks
    local price = Calculator.calcBuyPrice(itemId, basePrice, modifiers)
    if price then return price end
    
    -- 3. Fallback to base
    return basePrice
end
```

### SHA_B: Buy Price on Client
```lua
function calcBuyPrice(itemId, basePrice)
    -- 1. Try cached calculation
    local price = Shop.CalculatedPrices.buyPrices[itemId]
    if price then return price end
    
    -- 2. Try client-side preview (using modifiers)
    -- WARNING: modifiers may be empty if SyncBuyPrices not arrived yet
    local modifiers = Shop.PriceModifiers  -- MIGHT BE STALE OR EMPTY
    local price = Calculator.calcBuyPrice(itemId, basePrice, modifiers)
    if price then return price end
    
    -- 3. Fallback to base
    return basePrice
end
```

---

### SHA_A: Sell Price on Client
```lua
function calcSellPrice(item, basePrice)
    -- 1. Try cached calculation (empty in SHA_A)
    -- 2. Try client-side preview
    local modifiers = Shop.PriceModifiers  -- Contains both buy AND sell hooks
    local price = Calculator.calcSellPrice(item, basePrice, modifiers)
    if price then return price end
    
    -- 3. Fallback to base
    return basePrice
end
```

### SHA_B: Sell Price on Client
```lua
function calcSellPrice(item, basePrice)
    -- 1. Try cached calculation (empty in SHA_B)
    -- 2. Try client-side preview (buy hooks excluded!)
    local modifiers = {
        sellModifiers = Shop.SellModifiers or {},
        sellOverrides = Shop.SellOverrides or {},
    }
    -- WARNING: Buy hooks are INTENTIONALLY excluded
    local price = Calculator.calcSellPrice(item, basePrice, modifiers)
    if price then return price end
    
    -- 3. Fallback to base
    return basePrice
end
```

---

## Consistency Checks

### SHA_A: Before Any Price Operation
```lua
-- All operations use the same revision
-- No consistency check needed (single revision = always consistent)
function getPrice(...)
    if Shop.PriceHookRevision == nil then
        return basePrice  -- Not synced yet
    end
    return calculatePrice(...)
end
```

### SHA_B: Before Any Price Operation (SHOULD BE)
```lua
-- Operations must use matching revisions
function getPrice(...)
    if Shop.BuyPriceRevision == nil or Shop.SellRuleRevision == nil then
        return basePrice  -- Not fully synced yet
    end
    
    -- OPTIONAL: Verify consistency
    -- (In SHA_B with proposed fixes)
    if not ShopSyncClient._initialSyncComplete then
        return basePrice  -- Still syncing
    end
    
    return calculatePrice(...)
end
```

---

## State Initialization

### SHA_A
```lua
Shop.PriceHookRevision = nil          -- Unknown until first sync
Shop.PriceModifiers = {}              -- Will be populated
Shop.CalculatedPrices = {
    buyPrices = {},
    sellPrices = {},
}
```

### SHA_B (Current)
```lua
Shop.BuyPriceRevision = nil           -- Unknown until SyncBuyPrices
Shop.SellRuleRevision = nil           -- Unknown until SyncSellRules
Shop.CalculatedPrices = {
    buyPrices = {},
    sellPrices = {},
}
Shop.SellModifiers = {}               -- Unknown until SyncSellRules
Shop.SellOverrides = {}               -- Unknown until SyncSellRules
```

### SHA_B (With Proposed Fixes)
```lua
Shop.BuyPriceRevision = nil
Shop.SellRuleRevision = nil
Shop.CalculatedPrices = {
    buyPrices = {},
    sellPrices = {},
}
Shop.SellModifiers = {}
Shop.SellOverrides = {}
ShopSyncClient._initialSyncComplete = false  -- ← ADD THIS
```

---

## Event Handling

### SHA_A
```lua
-- Single event fired on price changes
function ShopSyncClient.onPriceHooksChanged()
    -- All price data is consistent here
    RefreshUI()
end
```

### SHA_B (Current)
```lua
-- Split events fired independently
function ShopSyncClient.onBuyPricesChanged()
    -- Only buy prices changed
    -- Sell rules might not be synchronized
    InvalidateUI("buy_price_delta")
end

function ShopSyncClient.onSellRulesChanged()
    -- Only sell rules changed
    -- Buy prices might not be synchronized
    InvalidateUI("sell_rule_change")
end
```

---

## Testing Checklist

### For SHA_B Implementation
- [ ] `SyncBuyPrices` includes `buyOverrides` field
- [ ] `SyncSellRules` includes `buyRevision` field
- [ ] `SyncBuyPrices` includes `sellRevision` field
- [ ] `SyncInitialComplete` sent after both price broadcasts
- [ ] `Shop.BuyPriceRevision` and `Shop.SellRuleRevision` both set before UI opens
- [ ] No UI render happens between SyncBuyPrices and SyncSellRules
- [ ] Multiplayer: Two clients receive same final revisions

### For Existing Code
- [ ] Price calculations handle nil revisions
- [ ] Retry logic if initial sync incomplete
- [ ] No crashes when `Shop.SellModifiers` is empty

---

## Common Pitfalls

### Pitfall 1: Assuming Single Revision
```lua
-- ❌ WRONG (only checks one revision)
if newRevision ~= Shop.PriceHookRevision then  -- Doesn't exist in SHA_B!
    RecalculateAllPrices()
end

-- ✅ CORRECT (check both revisions)
if (newBuyRev ~= Shop.BuyPriceRevision) or (newSellRev ~= Shop.SellRuleRevision) then
    RecalculateAllPrices()
end
```

### Pitfall 2: Assuming Modifiers Available
```lua
-- ❌ WRONG (assumes buy modifiers in all broadcasts)
local modifiers = Shop.PriceModifiers
-- modifiers.buyOverrides might be nil in SHA_B!

-- ✅ CORRECT (handle missing fields)
local modifiers = {
    buyOverrides = Shop.PriceModifiers and Shop.PriceModifiers.buyOverrides or {},
    sellOverrides = Shop.PriceModifiers and Shop.PriceModifiers.sellOverrides or {},
}
```

### Pitfall 3: Opening UI Too Early
```lua
-- ❌ WRONG (opens after first price broadcast)
function ShopUI:open()
    if Shop.BuyPriceRevision then  -- Only checks one!
        return renderUI()
    end
end

-- ✅ CORRECT (waits for completion signal)
function ShopUI:open()
    if ShopSyncClient._initialSyncComplete then
        return renderUI()
    end
    return false  -- Not ready yet
end
```

### Pitfall 4: Cross-Hook Dependencies
```lua
-- ❌ WRONG in SHA_B (buy hooks not available in sell context)
function calcSellPrice(item, player)
    local buyHooks = Shop.PriceModifiers.buyOverrides  -- Might be nil!
    local sellHooks = Shop.PriceModifiers.sellOverrides  -- Might be nil!
    -- Try to use both
end

-- ✅ CORRECT (split sell calculation)
function calcSellPrice(item, player)
    local sellHooks = {
        sellModifiers = Shop.SellModifiers,
        sellOverrides = Shop.SellOverrides,
    }
    -- Only use sell-specific data
end
```

---

## Migration Path

If you have code written for SHA_A, convert like this:

```lua
-- SHA_A Code
if Shop.PriceHookRevision ~= prevRevision then
    -- Something changed
end

-- SHA_B Equivalent
if (Shop.BuyPriceRevision ~= prevBuyRev) or (Shop.SellRuleRevision ~= prevSellRev) then
    -- Something changed
end
```

```lua
-- SHA_A Code
local modifiers = Shop.PriceModifiers

-- SHA_B Equivalent
local modifiers = {
    buyOverrides = (Shop.PriceModifiers or {}).buyOverrides or {},
    sellOverrides = (Shop.PriceModifiers or {}).sellOverrides or {},
    sellModifiers = Shop.SellModifiers or {},
}
```

---

## Quick Comparison Table

| Feature | SHA_A | SHA_B |
|---------|-------|-------|
| Revision tracking | `PriceHookRevision` | `Buy...` + `Sell...` |
| Broadcast count | 1 per change | Up to 2 per change |
| Atomicity | Guaranteed | No guarantee |
| Buy modifiers sent | ✅ Yes | ❌ No |
| Initial sync commands | 2 | 3 (or 4 with fix) |
| Client storage | Monolithic | Split |
| Cross-hook deps | ✅ Possible | ❌ Not possible |
| UI flicker on join | ❌ No | ✅ Yes (race condition) |

---

## Support

For questions about this analysis:
1. Read `REGRESSION_ANALYSIS.md` for detailed explanation
2. Check `ENFORCEMENT_FIXES.md` for exact code patches
3. See `PHASE_5_TESTING.md` for test scenarios

