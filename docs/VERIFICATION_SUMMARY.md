# Code Verification Summary

**Date**: Dec 27, 2025  
**Commits Verified**: 90ba5a3b..422b71c (5 commits)  
**Files Analyzed**: 15+ Lua files

---

## ✅ What's Working Well

### 1. **Hook-Based Architecture**
- Clean separation between registry, events, and price calculation
- Two-phase price system (modify + override) enables flexible pricing mods
- Callback dispatchers follow B42-compliant Lua patterns
- Immutable registries with runtime calculation

### 2. **Registry System**
- Proper lock mechanism prevents late registration
- Type validation on all inputs
- Clear error messages for debugging
- Parallel buy/sell registry design

### 3. **Initialization Order**
- Correct event bindings (OnGameBoot for client, OnServerStarted for server)
- Tab constants defined early for item definitions
- All dependencies properly required in correct order

### 4. **Price Calculation Pipeline**
- Server-authoritative price recomputation in timed actions
- Anti-dupe transaction tracking
- Proximity validation for kiosk purchases
- Proper balance validation before and after price recalculation

### 5. **Backward Compatibility**
- Legacy `Shop.Buy`/`Shop.Sell` tables have migration path
- Fallback to default items if no external registrations

---

## ⚠️ Issues Found

### 1. **CRITICAL: Inverted Legacy Table Mapping** [ShopInit.lua:26-32]
**Severity**: High (breaks semantic correctness)

The legacy migration maps tables backwards:
```lua
Shop.Buy  →  Shop.PlayerSell  (should be PlayerBuy)
Shop.Sell →  Shop.PlayerBuy   (should be PlayerSell)
```

**Current behavior**: System functionally works because items are registered directly via `Shop.RegisterItem()` and `Shop.RegisterSellItem()`, bypassing the legacy tables. However, the mapping is semantically incorrect.

**Fix**:
```lua
if Shop.Buy and not Shop.PlayerBuy then
    Shop.PlayerBuy = Shop.Buy
end
if Shop.Sell and not Shop.PlayerSell then
    Shop.PlayerSell = Shop.Sell
end
```

---

### 2. **Dead Code in Sell Action** [ShopSellAction.lua:105-114]
**Severity**: Low (unreachable code)

```lua
-- In server-only function:
if isClient() then
    Nfunction.logShop(coords, "Sell")
end
```

This block never executes because the entire `complete()` function has `if not isServer() return true` at the start.

**Fix**: Remove the dead block. Client-side logging should happen elsewhere.

---

### 3. **Trust Client-Provided Coin Type** [ShopSellAction.lua:81]
**Severity**: Medium (security concern)

```lua
isSpecialCoin = entry.specialCoin or false,  -- From client, should validate on server
```

The sell action trusts the client to tell it whether an item uses special coins. Should verify against server-side `Shop.PlayerSell[id].specialCoin`.

**Fix**:
```lua
local sellRule = Shop.PlayerSell[id]
isSpecialCoin = sellRule and sellRule.specialCoin or false,
```

---

### 4. **Redundant Context Construction** [ShopBuyAction.lua:87-92]
**Severity**: Low (code quality)

Context includes `isSpecialCoin` from item definition, but this is checked again separately:
```lua
isSpecialCoin = Shop.Items[itemType].specialCoin or false,
...
if Shop.Items[itemType].specialCoin then
    totalSpecialCoin = totalSpecialCoin + (finalPrice * quantity)
end
```

**Fix**: Use context value consistently or remove from context.

---

## Summary Table

| Issue | File | Line | Severity | Type |
|-------|------|------|----------|------|
| Inverted legacy mapping | ShopInit.lua | 26-32 | 🔴 High | Logic Error |
| Dead client code | ShopSellAction.lua | 113 | 🟡 Low | Code Quality |
| Trust unvalidated client data | ShopSellAction.lua | 81 | 🟠 Medium | Security |
| Redundant context | ShopBuyAction.lua | 87-92 | 🟡 Low | Code Quality |

---

## Commit Verification

| Commit | Message | Matches Code | Status |
|--------|---------|--------------|--------|
| f8fb8f8 | Registry & pricing system | ✅ Yes | Correct |
| 220aed9 | Hook-based shop system | ✅ Yes | Correct |
| d3efcf9 | Moving docs | ✅ Yes | Correct |
| 0e5e8ea | Refactor with legacy migration | ⚠️ Partial | **See Issue #1** |
| 422b71c | Create common folder | ✅ Yes | Correct |

---

## Recommendations (Priority Order)

1. **FIX IMMEDIATELY**: Correct the legacy table mapping in ShopInit.lua
2. **FIX SOON**: Validate coin type on server in ShopSellAction.lua
3. **CLEAN UP**: Remove dead code from ShopSellAction.lua
4. **REFACTOR**: Simplify context construction in ShopBuyAction.lua

---

## Code Quality Notes

**Positive aspects**:
- Clear function separation of concerns
- Proper error handling with descriptive messages
- Type validation on public APIs
- Good use of comments explaining phases

**Areas for improvement**:
- Some redundant validation (double-checking item existence)
- Client/server boundary not always clear in comments
- Could benefit from more inline documentation on hook parameters

---

## Testing Recommendations

1. Test legacy migration with old `Shop.Buy`/`Shop.Sell` tables
2. Verify buy/sell prices are correctly applied to right item categories
3. Test special coin items work correctly on both buy and sell
4. Verify transaction anti-dupe works under concurrent load
5. Test external mod hooks can successfully modify prices
6. Verify proximity check prevents purchases outside kiosk range

---

## Conclusion

The hook-based architecture is **well-designed and implements the intended system correctly**. The implementation follows B42-compliant patterns and enables flexible mod integration.

However, **the inverted legacy mapping in ShopInit.lua is a critical semantic error** that should be fixed to ensure correctness, even though current usage patterns happen to work around it.

**Overall Code Quality**: 8/10 (would be 9/10 with the issues fixed)
