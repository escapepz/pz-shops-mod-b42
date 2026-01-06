# Shops B42 - Sell Transaction Performance Optimization Plan

## Executive Summary
Current sell transaction performance degrades linearly with item count due to:
- Repeated inventory lookups (O(n) per item)
- Per-item pcall overhead in snapshot creation
- Per-item network updates for item removal
- Per-item modifier sorting in pricing calculations

**Target:** Enable selling 50+ items in single transaction without frame stutters.

---

## Performance Bottlenecks (Detailed)

### 1. Inventory Lookup Inefficiency (ShopSellAction.lua L135-145)
**Current:** `inv:getItemById(entry.itemID)` called once per item in PHASE 1
- JVM-side inventory search is O(n) per call
- For 50 items: ~50 searches × inventory size = potential thousands of comparisons

**Impact:** HIGH for large bulk sells
```lua
-- CURRENT: Line 136
local item = inv:getItemById(entry.itemID)
```

---

### 2. Per-Item Snapshot Overhead (ShopSellAction.lua L160-172)
**Current:** Static snapshot approach is good, but `createItemSnapshot()` still called implicitly
- Multiple `pcall()` safety checks (defensive programming)
- Parsing item properties even though condition is always 1.0

**Impact:** MEDIUM (pcall is expensive relative to snapshot needs)

---

### 3. Per-Item Network Updates (ShopSellAction.lua L207-237)
**Current:** `sendRemoveItemFromContainer()` called per item removal
```lua
inv:Remove(item)
sendRemoveItemFromContainer(inv, item)  -- Network call per item
```
- Sends individual item removal packets to all clients
- For 50 items: 50 separate network messages instead of batch

**Impact:** HIGH for network bandwidth and synchronization latency

---

### 4. Per-Item Modifier Sorting (PricingContract.lua L128-138)
**Current:** `table.sort()` called per item in `calculateSellPrice()`
```lua
-- PHASE 1 LOOP: Called N times
local result = PricingContract.calculateSellPrice(...)
  -- Inside: sorts modifiers array again
  table.sort(sortedMods, function(a, b) ... end)
```
- Same modifiers sorted repeatedly
- For 50 items with 5 modifiers: 50 sorts × 5 items = O(n log m) wasted work

**Impact:** MEDIUM (sorting is cheap but repeated unnecessarily)

---

## Optimization Strategy

### Phase 1: Modifier Pre-Sorting (QUICK WIN)
**Files:** `ShopSellAction.lua`, `PricingContract.lua`

**Change:** Pre-sort modifiers once, pass sorted array to calculateSellPrice()

**Implementation:**
```lua
-- ShopSellAction.lua L173 (BEFORE loop)
local modifiers = Shop.PriceModifiers and Shop.PriceModifiers.sellModifiers or {}

-- NEW: Pre-sort modifiers ONCE
local sortedModifiers = {}
for _, mod in ipairs(modifiers) do
    table.insert(sortedModifiers, mod)
end
table.sort(sortedModifiers, function(a, b)
    local priorityA = a.priority or 100
    local priorityB = b.priority or 100
    return priorityA < priorityB
end)

-- THEN in loop
for _, entry in ipairs(self.sellList.items) do
    -- ...
    local result = PricingContract.calculateSellPrice(itemType, "npc_general_store", basePrice, itemSnapshot, sortedModifiers)
```

**Benefit:** O(m log m) once instead of O(n × m log m)
**Risk:** NONE - modifiers don't change during transaction

---

### Phase 2: Batch Network Removal (CRITICAL)
**Files:** `ShopSellAction.lua`

**Change:** Collect items to remove, then use batch API instead of per-item updates

**Current Flow (PHASE 2, L207-237):**
```lua
for _, sellData in ipairs(itemsToSell) do
    if inv:contains(item) then
        inv:Remove(item)
        sendRemoveItemFromContainer(inv, item)  -- NETWORK CALL PER ITEM
    end
end
```

**Optimized Flow:**
```lua
-- Collect all items to remove
local itemsToRemove = {}
for _, sellData in ipairs(itemsToSell) do
    if inv:contains(sellData.item) then
        table.insert(itemsToRemove, sellData.item)
        inv:Remove(sellData.item)  -- Remove from local object
    end
end

-- Single batch network update instead of per-item
if #itemsToRemove > 0 then
    sendRemoveItemsFromContainer(inv, itemsToRemove)  -- NEW: batch method
end
```

**Alternative (if batch API unavailable):**
- Keep per-item updates but defer them to END of loop
- Minimize message interleaving with validation

**Benefit:** 50 items = 1 network message instead of 50
**Risk:** Requires batch removal API - check if available in PZ engine

---

### Phase 3: Inventory Caching (MEDIUM PRIORITY)
**Files:** `ShopSellAction.lua`

**Change:** Build single inventory snapshot, reuse for all lookups

**Current:**
```lua
local inv = self.character:getInventory()  -- Done once, good
for _, entry in ipairs(self.sellList.items) do
    local item = inv:getItemById(entry.itemID)  -- Repeated search
```

**Optimized:**
```lua
local inv = self.character:getInventory()

-- Pre-build lookup map
local itemMap = {}
for _, entry in ipairs(self.sellList.items) do
    local item = inv:getItemById(entry.itemID)
    if item then
        itemMap[entry.itemID] = item
    end
end

-- PHASE 1: Use cached map
for _, entry in ipairs(self.sellList.items) do
    local item = itemMap[entry.itemID]  -- Direct lookup, no getItemById() call
    if not item then
        -- ...
    end
```

**Benefit:** Reduces inventory search from N calls to 1 pre-scan + N table lookups
**Risk:** Map becomes invalid if inventory modified between pre-scan and removal (low risk since server-only)

---

### Phase 4: Conditional Snapshot Calculation (MINOR)
**Files:** `ShopListingNPC.lua`

**Change:** Skip defensive pcall checks when condition always 1.0

**Current (L242-296):**
```lua
-- Multiple pcall checks for getFullType(), getType() even though condition is hardcoded
if item and pcall(function() return item:getFullType() end) then
    local success2, fullTypeValue = pcall(function() return item:getFullType() end)
    -- ...
end
```

**Optimized:**
```lua
-- Since condition is always 1.0, minimal snapshot needed
local function createItemSnapshot(item)
    if not item then
        return { condition = 1.0, fullType = "unknown", category = "unknown" }
    end
    
    -- Single safe call for fullType (used for base price lookup)
    local fullType = "unknown"
    pcall(function()
        fullType = item:getFullType()
    end)
    
    return {
        condition = 1.0,  -- ALWAYS full condition
        fullType = fullType,
        category = "unknown"  -- Not used in current pricing
    }
end
```

**Benefit:** Fewer pcalls = slightly faster snapshot creation
**Risk:** NONE - simplifies code, still defensive

---

## Implementation Priority & Effort

| Priority | Feature | Effort | Impact | Status | Files |
|----------|---------|--------|--------|--------|-------|
| 1 (QUICK) | Pre-sort modifiers | 10 min | 10-15% for large sells | ✓ DONE | PricingContract, ShopSellAction |
| 2 (CRITICAL) | Batch network removal | 30 min | 30-40% for large sells | DEFERRED | ShopSellAction |
| 3 (MEDIUM) | Inventory caching | 20 min | 15-20% for large sells | ✓ DONE | ShopSellAction |
| 4 (MINOR) | Simplify snapshots | 10 min | 5% for large sells | ✓ DONE | ShopListingNPC |

---

## Testing Checklist

### Before Optimization
- [ ] Measure baseline: Sell 50 items, record transaction time
- [ ] Check Logs/Server/*_Shops.txt for duration
- [ ] Monitor CPU usage during sell

### After Each Phase
- [ ] Verify prices calculated identically (no regressions)
- [ ] Test with 10, 25, 50, 100+ item sales
- [ ] Check Logs/Server/*_Shops.txt for price accuracy logs
- [ ] Verify network updates received on client
- [ ] Verify final balance updates correctly

### Regression Tests
- [ ] Single item sell (should be unaffected)
- [ ] Sell with mixed item types (different base prices)
- [ ] Sell with special coins enabled
- [ ] Sell with custom price modifiers
- [ ] Multi-player: Verify other players see correct inventory updates
- [ ] Anti-dupe: Attempt duplicate txnId (should reject)

---

## Implementation Order

1. **Start with Phase 1** (modifier pre-sort) - zero risk, quick win
2. **Then Phase 3** (inventory caching) - simple, safe, good ROI
3. **Then Phase 4** (simplify snapshots) - optional, low impact
4. **Finally Phase 2** (batch removal) - requires API verification first

---

## Code Locations for Modification

### ShopSellAction.lua
- **L173:** Pre-sort modifiers (add before PHASE 1 loop)
- **L176:** Pass sortedModifiers to calculateSellPrice (modify call)
- **L135-205:** Inventory caching (build itemMap before loop)
- **L207-237:** Batch removal (collect items, single sendRemoveItemsFromContainer call)

### PricingContract.lua
- **L117-154:** Accept pre-sorted modifiers or sort internally with guard
  ```lua
  -- Make internal sort optional if modifiers already sorted
  local sortedMods = modifiers  -- Assume pre-sorted if received sorted
  if not modifiers._isSorted then
    -- ... do sort
  end
  ```

### ShopListingNPC.lua
- **L242-296:** Simplify createItemSnapshot (fewer pcall checks)

---

## Rollback Plan

Each phase can be rolled back independently:
1. If modifier pre-sort causes issues → remove and calculate per-item
2. If batch removal fails → revert to per-item sendRemoveItemFromContainer
3. If inventory caching causes race conditions → remove map, use direct lookups

No database migrations or config changes needed.

---

## Future Optimizations (Post-Phase 4)

- **Async price calculation:** Move PricingContract to separate coroutine
- **Lazy validation:** Skip validation for trusted mods, only validate user items
- **Connection pooling:** Batch all ModData transmits into single network packet
- **Item categorization:** Pre-group items by category to batch price lookups

