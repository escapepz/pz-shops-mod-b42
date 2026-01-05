# Phase 2.3: Add Client Price Mismatch Handler

## Purpose

Detect and handle price differences between client preview and server final price.

**Cases**:
1. **Expected Mismatch**: Server applies modifiers, final price differs from preview
2. **Tolerance**: ±1 coin variance acceptable (rounding differences)
3. **Logging**: Silent logging for development aid (not user-facing)
4. **No Resync**: UI updates without rebuild (no broadcast triggered)

---

## Implementation Plan

### 1. Validation Function

**File**: `client/nshopsb42/ui/ShopUI.lua`

**New Function**:
```lua
function ShopUI.validateTransactionPrice(itemId, clientPrice, serverPrice, tolerance)
    tolerance = tolerance or 1  -- Default: ±1 coin
    
    if not clientPrice or not serverPrice then
        return false, "missing_price"
    end
    
    local diff = math.abs(clientPrice - serverPrice)
    if diff > tolerance then
        SharedLogger.log("Shops",
            "[ShopUI] Price mismatch: " .. itemId ..
            " client=" .. clientPrice ..
            " server=" .. serverPrice ..
            " diff=" .. diff)
        return false, "mismatch"
    end
    
    return true, nil
end
```

**When Called**:
- On transaction result received
- Before updating UI
- After server validates transaction

---

### 2. Transaction Result Handler

**File**: `client/nshopsb42/ui/ShopUI.lua` or `ShopBuyAction.lua`

**Current Behavior** (WRONG):
```lua
function onTransactionResult(data)
    -- Store server price
    Shop.BuyPrices[itemId] = data.finalPrice
    
    -- Trigger full UI rebuild (reactive)
    ShopSyncClient.invalidateUI(...)
end
```

**New Behavior** (CORRECT):
```lua
function onTransactionResult(data)
    local itemId = data.itemId
    local clientPrice = ui.lastPreviewPrice[itemId]  -- What client calculated
    local serverPrice = data.finalPrice             -- What server computed
    
    -- Validate price (logs mismatch silently)
    ShopUI.validateTransactionPrice(itemId, clientPrice, serverPrice)
    
    -- Update UI silently (no rebuild)
    Shop.BuyPrices[itemId] = serverPrice
    
    -- Show feedback to user
    displayMessage("Purchase successful!")
    
    -- Do NOT trigger full shop rebuild
    -- Do NOT call ShopSyncClient.invalidateUI()
end
```

**Key Differences**:
- ✅ Validates instead of rebuilds
- ✅ Updates silently (no resync)
- ✅ No reactive UI rebuild
- ✅ User feedback shown (success message)

---

### 3. Insufficient Funds Case

**Current Behavior** (WRONG):
```lua
if not player:hasMoneyTo(finalPrice) then
    sendServerCommand(player, "Shop", "RequestDataRefresh", {})  -- Bad: triggers resync
    displayError("Insufficient funds")
    return false
end
```

**New Behavior** (CORRECT):
```lua
if not player:hasMoneyTo(finalPrice) then
    sendServerCommand(player, "Shop", "TransactionFailed", {
        reason = "insufficient_funds",
        itemId = itemId,
        required = finalPrice,
        current = player:getMoney()
    })
    
    displayError("Insufficient funds: need " .. finalPrice .. ", have " .. player:getMoney())
    
    -- Do NOT send refresh request
    -- Do NOT trigger broadcast
    -- User can add money and retry
    return false
end
```

**Key Differences**:
- ✅ Returns error without resync
- ✅ Shows user the price + balance
- ✅ User can act (add money, try again)
- ✅ No unnecessary network traffic

---

### 4. Inventory Full Case

**Current Behavior** (WRONG):
```lua
if not hasInventorySpace(itemId) then
    sendServerCommand(player, "Shop", "RequestDataRefresh", {})  -- Bad: resync
    displayError("Inventory full")
    return false
end
```

**New Behavior** (CORRECT):
```lua
if not hasInventorySpace(itemId) then
    sendServerCommand(player, "Shop", "TransactionFailed", {
        reason = "inventory_full",
        itemId = itemId
    })
    
    displayError("Inventory full: need space for " .. getItemSize(itemId))
    
    -- Do NOT trigger resync
    return false
end
```

---

## Files to Modify

### 1. ShopUI.lua (Client)

**Add**:
- `validateTransactionPrice()` function
- Call validation in transaction result handler
- Remove `invalidateUI()` calls on mismatch

**Search for**:
- `function onTransactionResult()`
- `ShopSyncClient.invalidateUI`
- `insufficient_funds`

### 2. ShopBuyAction.lua (Client) if exists

**Add**:
- Validation call before updating prices
- Proper error handling without resync

**Search for**:
- `hasMoneyTo()`
- `RequestDataRefresh`

---

## Testing Scenarios

### Test 1: Expected Mismatch (Modifiers Applied)
1. Admin increases apple buy multiplier to 2.0
2. Client shows preview price: 30 (base: 15 × 2.0)
3. Server may apply different modifiers
4. Server returns final price: 33
5. Client validates: 33 - 30 = 3, exceeds default tolerance (1)
6. Mismatch logged silently
7. UI updates price to 33, no rebuild
8. User sees updated price, transaction succeeds

**Expected**: Log shows mismatch, UI works correctly

### Test 2: Exact Match (No Modifiers)
1. Client calculates: 15
2. Server returns: 15
3. Validation passes (0 diff)
4. UI updates silently
5. No mismatch logged

**Expected**: No log, UI updates quietly

### Test 3: Insufficient Funds
1. Player has 100 coins
2. Item costs 150
3. Purchase attempt
4. Server validates: balance < price
5. Server returns error (not success)
6. UI shows error message
7. No resync triggered
8. User can add coins and retry

**Expected**: Error shown, shop still open, no broadcast

### Test 4: Inventory Full
1. Player inventory full
2. Try to buy item
3. Server validates: inventory full
4. Server returns error
5. UI shows error
6. Shop remains open
7. User can drop items and retry

**Expected**: Error shown, no resync

---

## Implementation Checklist

- [ ] Create `validateTransactionPrice()` in ShopUI
- [ ] Add tolerance parameter (default: 1 coin)
- [ ] Call validation in transaction result handler
- [ ] Remove `invalidateUI()` from successful transactions
- [ ] Handle error cases (insufficient funds, inventory full)
- [ ] Update error messages to be user-friendly
- [ ] Test all four scenarios above
- [ ] Verify: zero resync broadcasts
- [ ] Verify: UI updates silently on mismatch

---

## Integration Notes

### Backward Compatibility
- Existing mismatch behavior replaced with validation
- No breaking changes to hook API
- Late-join sync still works (Phase 2.2 preserved it)

### Future Extensions
- Configurable tolerance per item
- Different tolerance for player shops vs NPC
- Admin notification of large mismatches
- Price history tracking (if needed later)

---

## Success Criteria

✅ Implementation complete when:
1. Price mismatches logged silently (development aid)
2. UI updates without rebuild (no resync)
3. Error cases handled gracefully (insufficient funds, inventory full)
4. Zero broadcast packets sent
5. User sees success/error messages (not technical details)
6. Transaction flow works end-to-end

