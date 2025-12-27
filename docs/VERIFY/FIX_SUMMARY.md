# Fix Summary - ShopSellAction.lua Syntax Error

## Issue
Server failed to start with Lua compilation error:
```
ShopSellAction.lua:88: '=' expected near `continue` at LexState.lexerror
```

## Root Cause
Project Zomboid uses Lua 5.1 (via Kahlua), which does **not support** the `goto` and `label` syntax (`goto label` and `::label::`). These were added in Lua 5.2+.

The code was using:
```lua
if itemPrice == nil then
    goto continue  -- Invalid in Lua 5.1
end
-- ... code ...
::continue::  -- Invalid in Lua 5.1
```

## Solution
Replaced the `goto`/label pattern with standard Lua 5.1 control flow using a nested `if` statement:

```lua
if itemPrice ~= nil then
    -- Remove item from inventory
    inv:Remove(item)
    sendRemoveItemFromContainer(inv, item)
    
    -- Accumulate payment with recomputed price
    if entry.specialCoin then
        totalSpecial = totalSpecial + itemPrice
    else
        total = total + itemPrice
    end
    
    -- Log sale
    Nfunction.buildLogShop(item:getFullType())
end
-- If itemPrice is nil (blacklisted/invalid), simply skip this item
```

## Files Modified
- `Shops/42.13.1/media/lua/shared/TimedActions/ShopSellAction.lua` (lines 73-103)

## Testing
Run server to verify:
1. Lua compilation completes without syntax errors
2. Items can be sold through shops
3. Invalid items are properly skipped (no transaction recorded for blacklisted items)

## Notes
- Registry finalization errors may still appear but should be secondary to the syntax error
- The logic flow remains identical: items with nil prices are skipped
