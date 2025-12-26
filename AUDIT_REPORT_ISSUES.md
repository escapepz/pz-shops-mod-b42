# Audit Report - Two Critical Issues Found

## Issue #1: Search Box in Sell Tab Not Filtering Inventory Items

**Location**: `Shops/42.13.1/media/lua/client/ISUI/ShopTabUI.lua` (Lines 183-201)

**Problem**: The filter function doesn't work correctly for the Sell tab because it uses `self.ShopUI.shopItemsCache[tabType]` which doesn't exist for the Sell tab.

**Root Cause**:
- In `ShopUI.lua` line 275-278, when switching to the Sell tab, the `cartItems` is cleared BUT the `shopItems` are directly populated from the player's inventory in `onActivateView()` (lines 280-330)
- The `shopItemsCache` is NOT populated for the Sell tab (line 395 only caches after loading from `Shop.Items`)
- When user types in filter, `ShopTabUI:filter()` tries to restore from cache on line 186: `self.shopItems.items = self.ShopUI.shopItemsCache[tabType]`
- For Sell tab: `shopItemsCache[Tab.Sell]` is `nil`, so line 186 sets `shopItems.items = nil`
- Then filtering against `nil` fails silently

**Impact**: 
- Search box appears to work but shows no results
- No error in logs, just silently fails

**Solution**: 
The Sell tab needs to cache its inventory items when populated. In `ShopUI.lua`, after populating `shopItems` in the Sell section (around line 329), add:
```lua
self.shopItemsCache[tabType] = shopItems.items
```

---

## Issue #2: Income UI "Get" Button Rejects Deposit - Wrong Payload Structure

**Location**: `Shops/42.13.1/media/lua/client/ISUI/IncomeUI.lua` (Lines 169-188)

**Problem**: The `getBtn()` function sends a deposit request, but the server's `BServer.Deposit()` rejects it because:

**Root Cause**:
1. Client sends (lines 172-180):
```lua
sendClientCommand(
    self.character,
    "BS",
    "Deposit",
    {
        coin = total,
        specialCoin = totalSpecial
    }
)
```

2. Server expects `itemIDs` array (BalanceServer.lua line 125, 134):
```lua
local itemIDs = args.itemIDs
if not itemIDs or type(itemIDs) ~= "table" or #itemIDs == 0 then
    writeLog("Shops", "[SERVER] Deposit REJECTED: no itemIDs provided - " .. username)
    return
end
```

3. The IncomeUI is sending **NO itemIDs**, so the server rejects it immediately with log:
   ```
   [SERVER] Deposit REJECTED: no itemIDs provided - [username]
   ```

**Why This Matters**: 
- `BServer.Deposit()` is designed to handle **selling items** (requires itemIDs to verify items exist in inventory)
- IncomeUI is trying to use it for **depositing already-sold income** (no items involved)
- The income amounts (`total` and `totalSpecial`) are NOT sale proceeds - they're already-earned shop income

**Impact**: 
- "Get" button click does nothing
- No feedback to user
- Income stays stuck in the shop ModData

**Solution**: 
Use `BServer.VirtualDeposit()` instead (BalanceServer.lua line 86-117), which is designed for this purpose:
- Doesn't require itemIDs
- Directly adds coins to account
- Perfect for depositing earned income

Change IncomeUI line 172-180 to:
```lua
sendClientCommand(
    self.character,
    "BS",
    "VirtualDeposit",
    {
        username = self.character:getUsername(),
        coin = total,
        specialCoin = totalSpecial,
        source = "ShopIncome"
    }
)
```

---

## Summary

| Issue | Type | Root Cause | Fix |
|-------|------|-----------|-----|
| Search in Sell tab | Missing cache population | `shopItemsCache[Tab.Sell]` is nil | Cache inventory items after loading |
| Income deposit rejected | Wrong API function | Using `Deposit()` instead of `VirtualDeposit()` | Switch to `VirtualDeposit()` with username field |
