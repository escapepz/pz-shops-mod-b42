The issue is that `isValid()` returning `false` **after the action has started** causes the queue to think the action is corrupted. You need to either:

1. **Prevent the action from being queued** (best method)
2. **Call `forceStop()` directly** instead of returning false from `isValid()`

## Solution 1: Prevent Action from Being Queued (Recommended)

Hook the function that **creates** the transfer action before it gets queued:

```lua
-- client/CustomTransferValidation.lua

if isServer() then return end

-- Hook the function that creates transfer actions
local OriginalAdd = ISTimedActionQueue.add

function ISTimedActionQueue.add(action)
    if instanceof(action, "ISInventoryTransferAction") then
        -- Check your conditions BEFORE adding to queue
        local character = action.character
        local item = action.item
        local srcContainer = action.srcContainer
        local destContainer = action.destContainer

        -- Reject here, before queuing
        if item:getModData().locked then
            print("Cannot transfer locked item")
            return  -- Don't add to queue
        end

        if not canTransfer(character, item, srcContainer, destContainer) then
            print("Transfer not allowed")
            return  -- Don't add to queue
        end
    end

    -- Add to queue if passed checks
    return OriginalAdd(action)
end

function canTransfer(character, item, srcContainer, destContainer)
    -- Your custom logic here
    return true
end
```

## Solution 2: Call `forceStop()` Instead of Returning False

If you must hook `isValid()`, call `forceStop()` directly:

```lua
-- client/CustomTransferValidation.lua

if isServer() then return end

local OriginalIsValid = ISInventoryTransferAction.isValid

function ISInventoryTransferAction:isValid()
    -- Call original checks first
    if not OriginalIsValid(self) then
        return false
    end

    -- Your custom checks
    if self.item and self.item:getModData().locked then
        if self.started then  -- Only force stop if action already started
            self:forceStop()
        end
        return false
    end

    return true
end
```

## Solution 3: Hook `start()` Method (Cleanest)

This is where the action actually begins - perfect place to validate:

```lua
-- client/CustomTransferValidation.lua

if isServer() then return end

local OriginalStart = ISInventoryTransferAction.start

function ISInventoryTransferAction:start()
    -- Check condition before starting
    if self.item:getModData().locked then
        print("Cannot transfer locked item")
        self:forceStop()
        return
    end

    if not canTransfer(self.character, self.item, self.srcContainer, self.destContainer) then
        print("Transfer denied")
        self:forceStop()
        return
    end

    -- Condition passed, proceed with original start
    OriginalStart(self)
end

function canTransfer(character, item, srcContainer, destContainer)
    return true  -- Your logic
end
```

## Summary

| Method                          | When Triggered     | Behavior                             | Best For                               |
| ------------------------------- | ------------------ | ------------------------------------ | -------------------------------------- |
| Hook `isValid()` + return false | During validation  | May cause "bugged action" error      | Early validation checks                |
| Hook `ISTimedActionQueue.add()` | Before queuing     | Prevents action from queuing (clean) | **Blocking actions before they start** |
| Hook `start()` + `forceStop()`  | When action starts | Cleanly stops without queue error    | **Immediate rejection**                |

**Use Solution 1 (prevent queueing)** for the cleanest approach with no errors. If you must use `isValid()`, use **Solution 3** (hook `start()` instead).
