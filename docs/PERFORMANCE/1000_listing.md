## Performance: 1000+ Items

### Cost Breakdown

```
onPriceHooksChanged() for 1000 items:

Calculation:              5ms    ✓ Still negligible
Serialize to table:       5-10ms ✓ Still fine
Broadcast network:        50-100ms ⚠️ Starts being noticeable
Client receive/parse:     20-50ms ⚠️ Noticeable
───────────────────────────────────
Total:                    ~80-160ms ⚠️ Noticeable 1-frame hitch
```

### The Real Bottleneck at 1000+

**Not calculation, but NETWORK/SERIALIZATION:**

```lua
-- Broadcasting this is expensive:
{
    calculatedPrices = {
        buyPrices = {
            ["Base.Apple"] = 30,
            ["Base.Banana"] = 45,
            ... (1000 entries)
        }
    }
}
-- ~50KB of data per broadcast
```

## When Optimization Becomes Worth It

**At 1000+ items, consider:**

### 1. **Delta Updates** (Send only changes)

```lua
-- Instead of sending all 1000 prices
-- Send only items that changed
{
    changedPrices = {
        ["Base.Apple"] = 30,
        ["Base.Orange"] = 25
    }
}
-- ~5KB instead of 50KB
```

### 2. **Batch Updates**

```lua
-- Collect changes over 1 second
-- Send once instead of immediate broadcast
```

### 3. **Selective Sync**

```lua
-- Only send to affected players
-- (different players see different shops)
```

## Honest Assessment

```
Current code at 1000 items:
  ❌ Noticeable 1-frame hitch on price change
  ⚠️ Not game-breaking, but visible

Current code at 500 items:
  ✓ Completely unnoticeable
```

## My Recommendation

**Where are you now?**

- ✅ **Under 500 items**: Keep as-is, performance is great
- ⚠️ **500-1000 items**: Monitor, optimize if players report lag
- ❌ **1000+ items**: Implement delta updates

**For now:** Stay with current implementation. If 1000+ items becomes reality, I can add delta update logic.

What's your expected max items?
