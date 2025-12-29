**ISHandcraftWindow initialization pattern:**

```lua
function ISHandcraftWindow:new(x, y, width, height, player, isoObject, queryOverride)
    local o = ISCollapsableWindow.new(self, x, y, width, height)

    -- Set properties
    o.x = x
    o.y = y
    o.player = player
    o.playerNum = player:getPlayerNum()
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    o.backgroundColor = {r=0, g=0, b=0, a=0.8}
    o.width = width
    o.height = height

    -- KEY: Enable keyboard input
    o:setWantKeyEvents(true)  -- Line 411 - CRITICAL

    return o
end
```

**Then when opening:**

```lua
local window = ISHandcraftWindow:new(x, y, width, height, player, nil, nil)
window:initialise()              -- Call initialise()
window:addToUIManager()          -- Add to UI manager
window:setKeyboardFocus()        -- Set keyboard focus
```

**Key differences from your code:**

1. **`setWantKeyEvents(true)`** - Line 411 in `:new()` - This is critical!
2. **Call `:initialise()`** after `:new()`
3. **Call `:addToUIManager()`**
4. **Call `:setKeyboardFocus()`**

**Try adding to your KioskShopConfigUI:new():**

```lua
function KioskShopConfigUI:new(player)
    -- ... existing code ...
    o:setWantKeyEvents(true)  -- ADD THIS
    return o
end
```

This is likely why your `onKeyRelease()` isn't being called!
