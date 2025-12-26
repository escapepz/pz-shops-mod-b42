# Audit Report: Move Coins to Account Implementation

## Code Path: Client → Server

### Client Side (CurrencyContext.lua:38-55)
```lua
function Currency.coinsToAccount(worldobjects, items, coinQuantity)
    local player = getPlayer()
    local itemIDs = {}
    for k, v in pairs(items) do
        table.insert(itemIDs, v:getID())
    end
    -- Server will remove items from inventory after validation
    sendClientCommand(
        player,
        "BS",
        "Deposit",
        {
            coin = coinQuantity.coin,
            specialCoin = coinQuantity.specialCoin,
            itemIDs = itemIDs
        }
    )
end
```

**Client Analysis:**
- ✅ No client-side inventory mutation
- ✅ Sends item IDs to server
- ✅ Server-side removal deferred

### Server Side (BalanceServer.lua:86-135)
```lua
function BServer.Deposit(player, args)
    -- ... validation ...
    
    -- Perform atomic mutation
    account.coin = account.coin + coin
    account.specialCoin = account.specialCoin + specialCoin
    
    -- Remove coin items from player inventory
    for i, item in ipairs(itemsToRemove) do
        item:getContainer():Remove(item)
    end
    
    ModData.transmit("CoinBalance")
end
```

**Server Analysis:**
- ✅ Server is authoritative (ModData.get)
- ✅ Balance updated atomically
- ✅ Items removed via Remove()
- ❌ **CRITICAL: Missing sync call after Remove()**
- ✅ ModData.transmit() broadcasts balance update

## Decision Matrix Classification

| Mutation | Type | Actual Sync | Required Sync | Status |
|----------|------|-------------|---------------|--------|
| Coins deposited | Item removed | None | `sendRemoveItemFromContainer` | **MISSING** |
| Balance updated | ModData changed | `ModData.transmit` | (balance only) | ✅ |

## Anti-Pattern Detected

**VIOLATION:** BalanceServer.lua line 131
```lua
item:getContainer():Remove(item)
```
Immediately followed by:
```lua
ModData.transmit("CoinBalance")
```

**Problem:** 
- `Remove()` mutates server inventory
- `ModData.transmit()` syncs the balance
- **But NO `sendRemoveItemFromContainer()` to sync inventory to client**

This creates:
1. **Stale UI**: Client still sees coins
2. **Rollback risk**: Coins reappear on next sync/relog
3. **Silent data loss**: Balance correct but coins visible

## Verification Against Playbook

### Step 1: Server Execution Path
✅ Code runs in `BServer.Deposit()` handler via `Events.OnClientCommand`

### Step 2: Inventory Side Effects
✅ Detected: `item:getContainer():Remove(item)`

### Step 3: Apply Correct Sync Primitive
❌ **FAILED**: No `sendRemoveItemFromContainer(inv, item)` after Remove()

### Step 4: Client Cleanup
✅ Passed: No client-side cleanup code

## Root Cause

The implementation follows the decision matrix for ModData but ignores the inventory mutation.

**Canonical rule violation:**
> "In B42 MP, inventory logic mutates the server model and explicitly instructs the client how to mirror it."

The server mutates but does NOT instruct the client.

## Required Fix

After line 131 (the Remove() call), add:
```lua
sendRemoveItemFromContainer(item:getContainer(), item)
```

Full corrected sequence (lines 129-135):
```lua
-- Remove coin items from player inventory
for i, item in ipairs(itemsToRemove) do
    item:getContainer():Remove(item)
    sendRemoveItemFromContainer(item:getContainer(), item)
end

ModData.transmit("CoinBalance")
```

## Reference Pattern

This pattern is correctly implemented in ShopSellAction.lua:79:
```lua
sendRemoveItemFromContainer(inv, item)
```

And PlayerShopBuyAction.lua:73:
```lua
sendRemoveItemFromContainer(shopContainer, invItem)
```

Both follow the canonical model: mutate → sync → broadcast.
