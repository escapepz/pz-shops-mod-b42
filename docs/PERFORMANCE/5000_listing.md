**With 5000 items, performance becomes a real concern.**

## Calculation Cost Breakdown

```
5000 items × onPriceHooksChanged():

For each item (5000):
  ├─ Read basePrice: 0.001ms
  ├─ Run hooks (5 hooks): 0.1-1ms per hook
  │  └─ Bottleneck: Hook execution, not math
  ├─ Apply modifiers: 0.01ms
  └─ Store result: 0.001ms

Total per item: ~0.5-5ms (depends on hook complexity)
Total for 5000: ~2.5-25 seconds ❌ TOO SLOW
```

## The Real Bottleneck

**Not the calculation, it's the HOOKS:**

```lua
-- SLOW - Executed for each of 5000 items
function MyExpensiveHook(player, itemId, basePrice, context, modifiers)
    local discount = Shop.getPlayerDiscount(player)  -- DB lookup
    table.insert(modifiers, {multiplier = discount})
end

-- Runs 5000 times = slow
```

## Optimization Strategies

### 1. **Cache Hooks Output** (Recommended)

```lua
-- Calculate ONCE per hook change
local hookCache = {}  -- {itemId → modifiers}

function buildCalculatedPrices()
    local calculatedPrices = {}

    for itemId, itemData in pairs(Shop.Items) do
        -- Use cached value if hooks unchanged
        if hookCache[itemId] then
            calculatedPrices.buyPrices[itemId] = itemData.basePrice * hookCache[itemId].multiplier
        else
            -- Only recalc if new
            local modifiers = {}
            ShopPriceEvents.triggerOnShopModifyBuyPrice(nil, itemId, itemData.basePrice, {}, modifiers)
            hookCache[itemId] = modifiers[1]  -- cache result
            calculatedPrices.buyPrices[itemId] = itemData.basePrice * modifiers[1].multiplier
        end
    end
    return calculatedPrices
end
```

### 2. **Async Calculation** (Best for large scale)

```lua
-- Calculate in background, don't block game
function ShopFinalizeHandler.onPriceHooksChanged()
    -- Start async task
    local co = coroutine.create(function()
        for itemId, _ in pairs(Shop.Items) do
            buildCalculatedPrices_Item(itemId)
            coroutine.yield()  -- Allow game to run
        end
    end)

    -- Resume 100 items per frame
    Events.OnGameStart.Add(function()
        for i = 1, 100 do
            coroutine.resume(co)
        end
    end)
end
```

### 3. **Batch Only Changed Items**

```lua
-- If only some hooks changed
function ShopFinalizeHandler.onPriceHooksChanged(changedHookIds)
    local itemsToRecalc = {}

    -- Only recalc items affected by changed hooks
    for _, hookId in ipairs(changedHookIds) do
        for itemId, _ in pairs(hookAffectedItems[hookId]) do
            itemsToRecalc[itemId] = true
        end
    end

    -- Recalc only ~100 items instead of 5000
end
```

## Reality Check

**Do you actually have 5000 items?**

- Most shops have 50-200 items
- Player shops have 10-50 items each

If yes → Use caching + async
If no (typical) → Current approach is fine

**What would you do with 5000 items?**
