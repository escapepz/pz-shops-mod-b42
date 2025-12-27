# Server-Side Item Transfer Hooks Guide

## Overview

Project Zomboid's item transfer system has multiple layers where you can intercept and cancel transfers with custom conditions:

1. **Container Validation** - `isItemAllowed()` & `isRemoveItemAllowed()` (Java methods called from Lua)
2. **Transfer Execution** - `ISTransferAction:transferItem()` (Shared code)
3. **Transaction Processing** - `OnProcessTransaction` event (Server-side)
4. **Client Command Handlers** - `ClientCommands.OnClientCommand` (Server-side)

---

## Method 1: Custom Container Accept Functions (Recommended for Item Restrictions)

### How It Works
The `item.AcceptItemFunction` property in item definitions points to a Lua function that validates whether an item can enter a container.

### Example Files
- **Definition**: `server/Items/AcceptItemFunction.lua`
- **Usage in Transfer**: `client/TimedActions/ISInventoryTransferAction.lua:108`

### Implementation Steps

1. **Create custom function in `server/Items/AcceptItemFunction.lua`**:

```lua
function AcceptItemFunction.MyCustomContainer(container, item)
    -- Add your validation logic here
    
    -- Example: Only allow items with weight < 5
    if item:getActualWeight() > 5 then
        return false  -- Cancel transfer
    end
    
    -- Example: Block specific item types
    if item:getType() == "Base.SomeItem" then
        return false
    end
    
    -- Example: Check player permission
    local owner = container:getParent()
    if owner and instanceof(owner, "IsoGameCharacter") then
        -- Custom logic based on player
        return true
    end
    
    return true  -- Allow by default
end
```

2. **Reference in item definitions** (in `items.xml`):

```xml
<item name="MyItemContainer">
    <AcceptItemFunction>AcceptItemFunction.MyCustomContainer</AcceptItemFunction>
</item>
```

### Pros
- Cleanest, most direct way to control container contents
- Automatically blocks invalid transfers at validation stage

### Cons
- Only works if you control the item/container definitions
- Cannot access full context (player, proximity, etc.) as easily

---

## Method 2: Hook `ISTransferAction:transferItem()` (For Flow Control)

### How It Works
Override or wrap the main transfer execution function in `shared/TimedActions/ISTransferAction.lua:95`.

### Implementation Steps

1. **Create a hook module** (`server/CustomTransferHooks.lua`):

```lua
if isClient() then return end

local CustomTransferHooks = {}

-- Store original function
local OriginalTransferItem = ISTransferAction.transferItem

-- Override with custom logic
function ISTransferAction:transferItem(character, item, srcContainer, destContainer, dropSquare)
    -- Perform custom validation BEFORE the transfer
    
    -- Example: Check if player has permission
    if not canPlayerTransferItem(character, item, srcContainer, destContainer) then
        print("Transfer denied for " .. character:getUsername() .. " item: " .. item:getDisplayName())
        return nil  -- Return nil to indicate failure
    end
    
    -- Example: Check location restrictions
    if not isLocationAllowedForTransfer(character:getCurrentSquare()) then
        print("Cannot transfer items in this location")
        return nil
    end
    
    -- Example: Log all transfers
    print("Transfer: " .. character:getUsername() .. 
          " moving " .. item:getDisplayName() .. 
          " from " .. srcContainer:getType() .. 
          " to " .. destContainer:getType())
    
    -- Call the original transfer function
    return OriginalTransferItem(self, character, item, srcContainer, destContainer, dropSquare)
end

-- Helper functions
function canPlayerTransferItem(character, item, srcContainer, destContainer)
    local player = character
    
    -- Example: Block transfers if in combat
    if player:isInCombat() then
        return false
    end
    
    -- Example: Block transfers to/from certain container types
    local blockedTypes = {"safehouse", "othersInventory"}
    if table.contains(blockedTypes, destContainer:getType()) then
        return false
    end
    
    return true
end

function isLocationAllowedForTransfer(square)
    -- Example: No transfers on stairs
    if square:HasStairs() then
        return false
    end
    
    -- Example: No transfers in water
    if square:isInWater() then
        return false
    end
    
    return true
end

function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

return CustomTransferHooks
```

2. **Load in server initialization** (e.g., in `server/Init.lua` or similar):

```lua
require "CustomTransferHooks"
```

### Pros
- Access to full context: character, item, source, destination, location
- Runs before transfer completes, can prevent it entirely
- Works for all transfer types

### Cons
- Modifying shared code can conflict with other mods
- Requires careful handling to preserve original behavior

---

## Method 3: Hook `ISInventoryTransferAction:isValid()` (For Client-Side Prevention)

### How It Works
Override the validation check in `client/TimedActions/ISInventoryTransferAction.lua:10`.

### Implementation Steps

1. **Create hook module** (`client/CustomTransferValidation.lua`):

```lua
if isServer() then return end

local OriginalIsValid = ISInventoryTransferAction.isValid

function ISInventoryTransferAction:isValid()
    -- Call original checks first
    if not OriginalIsValid(self) then
        return false
    end
    
    -- Add custom validation
    if not self.item or not self.srcContainer or not self.destContainer then
        return false
    end
    
    -- Example: Block transfers of favorite items
    if self.item:isFavorite() and not self.destContainer:isInCharacterInventory(self.character) then
        return false
    end
    
    -- Example: Check custom mod data
    local modData = self.item:getModData()
    if modData.isLocked then
        return false
    end
    
    -- Example: Block based on character state
    if self.character:isInCombat() then
        return false
    end
    
    return true
end
```

### Pros
- Prevents action from even starting on client
- Responsive (immediate feedback to player)
- Lighter weight than server hooks

### Cons
- Client-side only (can be bypassed by cheaters)
- Doesn't actually prevent server-side transfer
- Should be combined with server-side validation

---

## Method 4: Hook `OnProcessTransaction` Event (For Special Transactions)

### How It Works
The `OnProcessTransaction` event is called on the server for finalized transactions.

### Implementation Steps

1. **Create hook module** (`server/TransactionHooks.lua`):

```lua
if isClient() then return end

local function onTransactionProcessed(action, character, item, source, destination, args)
    -- This fires AFTER the transfer has been initiated
    
    -- Example: Log special transactions
    if action == "dropOnFloor" then
        print(character:getUsername() .. " dropped " .. item:getDisplayName())
    elseif action == "pickUpMoveable" then
        print(character:getUsername() .. " picked up moveable object")
    end
    
    -- Example: Post-transfer actions
    if action == "dropOnFloor" and item:getType() == "Base.SomeSpecialItem" then
        -- Trigger something after item is dropped
        triggerSpecialEvent(item, destination)
    end
end

Events.OnProcessTransaction.Add(onTransactionProcessed)
```

### Pros
- Fires after transaction completes
- Good for post-transfer side effects or logging
- Doesn't block transfers

### Cons
- Fires AFTER transfer completes (cannot prevent it)
- Limited context (args depend on transaction type)

---

## Method 5: Hook `ClientCommands` for Admin-Level Control

### How It Works
The `ClientCommands.OnClientCommand` event handles server commands from the client.

### Implementation Steps

1. **Extend `server/ClientCommands.lua`** or create separate handler:

```lua
if isClient() then return end

local function customCommandHandler(module, command, player, args)
    -- Block specific commands for certain players
    if module == "transfer" then
        if not player:getRole():hasCapability(Capability.UseContainers) then
            print("Player lacks permission for transfers")
            return false
        end
    end
end

Events.OnClientCommand.Add(customCommandHandler)
```

### Pros
- Intercepts all client commands
- Can enforce role-based permissions
- Server-authoritative

### Cons
- Low-level hook, requires understanding command structure
- Commands may already be partially processed

---

## Method 6: Modify ItemContainer Methods via Moddata

### How It Works
Use Java class methods that are callable from Lua.

### Implementation Steps

1. **Check container properties** (`shared/TimedActions/ISTransferAction.lua:101`):

```lua
-- In your custom transfer hook:

if not srcContainer:isRemoveItemAllowed(item) then
    return nil  -- Block removal
end

if not destContainer:isItemAllowed(item) then
    return nil  -- Block addition
end
```

These methods call Java-side validation; you can't override them directly in Lua, but you CAN prevent the transfer from reaching them.

---

## Complete Working Example

Here's a complete server-side module that cancels transfers based on custom conditions:

**`server/CustomTransferControl.lua`**:

```lua
if isClient() then return end

local CustomTransferControl = {}

-- Override ISTransferAction:transferItem to add custom checks
local OriginalTransferItem = ISTransferAction.transferItem

function ISTransferAction:transferItem(character, item, srcContainer, destContainer, dropSquare)
    -- ======================
    -- CUSTOM VALIDATION HERE
    -- ======================
    
    -- 1. Check if item is marked as "untransferrable"
    if item:getModData().untransferrable then
        print("ERROR: Item " .. item:getDisplayName() .. " cannot be transferred")
        return nil
    end
    
    -- 2. Check player permissions (if using role system)
    if character:getRole() and not character:getRole():hasCapability(Capability.UseContainers) then
        print("ERROR: Player lacks container usage permissions")
        return nil
    end
    
    -- 3. Prevent transfers during combat
    if character:isInCombat() then
        print("ERROR: Cannot transfer items while in combat")
        return nil
    end
    
    -- 4. Check location restrictions
    local square = character:getCurrentSquare()
    if square and square:isInWater() then
        print("ERROR: Cannot transfer items while in water")
        return nil
    end
    
    -- 5. Custom container type restrictions
    local destType = destContainer:getType()
    if destType == "othersInventory" and srcContainer ~= character:getInventory() then
        print("ERROR: Cannot move items between other players' containers")
        return nil
    end
    
    -- 6. Weight limit enforcement (example)
    if item:getActualWeight() > 50 then
        print("ERROR: Item too heavy to transfer")
        return nil
    end
    
    -- ======================
    -- TRANSFER ALLOWED
    -- ======================
    
    -- Log the transfer (optional)
    print("[TRANSFER] " .. character:getUsername() .. " transferred " .. 
          item:getDisplayName() .. " (" .. item:getActualWeight() .. "kg)")
    
    -- Call original transfer function
    return OriginalTransferItem(self, character, item, srcContainer, destContainer, dropSquare)
end

return CustomTransferControl
```

**`server/Init.lua`** (or similar):

```lua
require "CustomTransferControl"
```

---

## Summary Table

| Method | Location | Runs When | Can Block? | Best For |
|--------|----------|-----------|-----------|----------|
| 1. Accept Functions | Item Definition | Validation | ✓ Yes | Container restrictions |
| 2. ISTransferAction Hook | Shared/Server | Transfer execution | ✓ Yes | Full context checks |
| 3. isValid() Hook | Client | Before action starts | ✓ Yes | Client feedback |
| 4. OnProcessTransaction | Server | After completion | ✗ No | Logging, side effects |
| 5. ClientCommands Hook | Server | Command received | ✓ Yes | Permission control |
| 6. ItemContainer Methods | Shared | Validation | ✓ Yes | Native restrictions |

---

## Best Practices

1. **Always use server-side validation** - Client-side can be bypassed
2. **Combine methods** - Use client-side for UX, server-side for enforcement
3. **Log transfers** - For debugging and auditing
4. **Use moddata** - Store custom flags on items: `item:getModData().customFlag = true`
5. **Test edge cases** - Container drops, corpse looting, trading UI, etc.
6. **Provide feedback** - Print messages for denied transfers so players know why

---

## Key Files Reference

- **Main Transfer Logic**: `shared/TimedActions/ISTransferAction.lua`
- **Client Transfer UI**: `client/TimedActions/ISInventoryTransferAction.lua`
- **Container Validation**: `server/Items/AcceptItemFunction.lua`
- **Transaction Processing**: `server/TransactionProcessor.lua`
- **Server Commands**: `server/ClientCommands.lua`
