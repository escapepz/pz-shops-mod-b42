# Debug Plan: Balance Not Updating + Tooltip Not Showing

## Issues Reported
1. **Balance not updating** after buy/sell transactions
2. **Tooltip not showing** on wallet items

## Root Cause Analysis

### Potential Issues

#### Issue 1: ModData Transmission Blocked
- ShopBuyAction/ShopSellAction call `ModData.transmit("CoinBalance")` 
- If this fails silently, client never receives the update
- **Evidence needed**: Server logs must show "Balance transmitted successfully"

#### Issue 2: Shop Lookup Failure  
- In `complete()`, code looks up shop at coordinates: `Utilities.FindShopAtCoords(coords, spritePrefix)`
- If shop is nil, transaction returns false without transmitting balance
- **Evidence needed**: Logs should show "Shop found, proceeding with transaction"

#### Issue 3: Client Not Receiving ModData Update
- Server transmits, but client dispatcher may not be receiving or processing it
- `ModDataDispatcher:onReceiveGlobalModData` logs the update
- `BalanceClient:OnReceiveGlobalModData` updates local ModData
- **Evidence needed**: Client logs must show `[ModDataDispatcher:onReceiveGlobalModData] key=CoinBalance`

#### Issue 4: Tooltip Not Triggered
- Tooltip renders only when player hovers over wallet item
- Tooltip logic queries `Balance.getUserAccount(username)` which reads from ModData
- If ModData is not updated, tooltip shows stale data
- **Evidence needed**: Need to verify if tooltip is being rendered at all

#### Issue 5: Client UI Not Refreshed
- Shop UI clears cart after action completes
- But shop items list may not reload
- Balance display in wallet/inventory UI depends on render cycle
- **Evidence needed**: Verify that Balance.getUserBalance() is called after transaction

## Debugging Steps Added

### Code Changes
1. **ShopBuyAction.lua**:
   - Added log before shop lookup: "Looking for shop at X,Y,Z"
   - Added log after shop found: "Shop found, proceeding with transaction"  
   - Added log before transmit: "Transmitting balance update..."
   - Added log after transmit: "Balance transmitted successfully"

2. **ShopSellAction.lua**:
   - Added log showing amounts being added: "Adding balance - total=X, totalSpecial=Y"
   - Added log before transmit: "Transmitting balance update..."
   - Added log after transmit: "Balance transmitted successfully"
   - Added log for zero-value case: "No balance to add"

### What to Check in Logs
Look for in server Shops.txt:
```
[ShopBuyAction:complete] Looking for shop at...
[ShopBuyAction:complete] Shop found, proceeding...
[ShopBuyAction:complete] Transmitting balance update...
[ShopBuyAction:complete] Balance transmitted successfully
```

If "Shop found" is missing, the transaction fails at shop lookup.
If "Balance transmitted successfully" is missing, the transmit may be failing.

Look for in client Shops.txt:
```
[ModDataDispatcher:onReceiveGlobalModData] key=CoinBalance
```

If this is missing, the client never receives the balance update.

## Next Steps
1. Run test transactions with updated logging
2. Check server logs for transmit completion
3. Check client logs for ModData reception
4. If both are present, balance should update
5. If tooltip still doesn't show, check rendering code

## Tooltip Rendering Chain
1. Player hovers over wallet item in inventory
2. ISToolTipInv shows tooltip
3. ISToolTipInvPatch:render() is called
4. Gets account: `Balance.getUserAccount(username)`
5. Reads from ModData: `ModData.get("CoinBalance")[username]`
6. Displays coin/specialCoin values

If balance updates in ModData but tooltip doesn't show:
- Check if tooltip is being rendered at all (hover might not be working)
- Check if Balance.getUserAccount is returning nil (ModData issue)
- Check if wallet item has correct linkedTo field

---

**Status**: Debugging logging added to transaction complete() methods
**Next Action**: Run test and check logs for transmit completion
