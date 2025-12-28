# Project Zomboid Custom UI - Quick Reference Card

## Minimum Template

```lua
require "ISUI/ISWindow"

MyWindow = ISWindow:derive("MyWindow")

function MyWindow:initialise()
    ISWindow.initialise(self)
    -- Add children here
end

function MyWindow:new(x, y, width, height)
    local o = ISWindow:new("Title", x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

-- Usage
local win = MyWindow:new(100, 100, 300, 200)
win:initialise()
win:instantiate()
win:addToUIManager()
```

---

## Key Class Methods

### ISUIElement (Base)
| Method | Usage |
|--------|-------|
| `setX(x)` / `getX()` | Position |
| `setY(y)` / `getY()` | Position |
| `setWidth(w)` / `getWidth()` | Size |
| `setHeight(h)` / `getHeight()` | Size |
| `addChild(element)` | Add nested element |
| `removeChild(element)` | Remove nested element |
| `initialise()` | Setup object |
| `instantiate()` | Create Java object |
| `addToUIManager()` | Make visible |
| `removeFromUIManager()` | Hide/cleanup |
| `setVisible(bool)` | Show/hide |
| `bringToTop()` | Focus window |

---

## Creating UI Elements

### Label
```lua
local label = ISLabel:new(x, y, height, "text", r, g, b, a, font, leftAlign)
label:initialise()
self:addChild(label)
```

### Button
```lua
local btn = ISButton:new(x, y, width, height, "text", self, MyClass.callback)
btn:initialise()
self:addChild(btn)

function MyClass:callback(button)
    -- Handle click
end
```

### Text Input
```lua
local input = ISTextEntryBox:new("default", x, y, width, height)
input:initialise()
self:addChild(input)
local text = input:getText()
```

### Panel
```lua
local panel = ISPanel:new(x, y, width, height)
panel:initialise()
panel.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.8}
self:addChild(panel)
```

### List Box
```lua
local list = ISScrollingListBox:new(x, y, width, height)
list:initialise()
list:addItem("Item", data)
self:addChild(list)
local selected = list:getSelectedItem()
```

---

## Drawing in render()

```lua
function MyUI:prerender()
    -- Background
    self:drawRectStatic(0, 0, width, height, a, r, g, b)
    -- Border
    self:drawRectBorderStatic(0, 0, width, height, a, r, g, b)
end

function MyUI:render()
    -- Text
    self:drawText("text", x, y, r, g, b, a, font)
    self:drawTextCentre("text", x, y, r, g, b, a, font)
    
    -- Shapes
    self:drawRect(x, y, w, h, a, r, g, b)
    self:drawLine(x1, y1, x2, y2, a, r, g, b)
    
    -- Progress
    self:drawProgressBar(x, y, w, h, fraction, color)
    
    -- Texture
    self:drawTexture(texture, x, y, r, g, b, a)
    self:drawTextureScaled(texture, x, y, w, h, r, g, b, a)
end
```

---

## Event Handlers

```lua
function MyUI:onMouseDown(x, y)
    return true  -- Consume event
end

function MyUI:onMouseUp(x, y)
end

function MyUI:onMouseMove(dx, dy)
end

function MyUI:onMouseWheel(delta)
    return true
end

function MyUI:onKeyPress(key)
    if key == Keyboard.KEY_ESCAPE then
        return true
    end
end

function MyUI:update()
    -- Called every frame
end
```

---

## Window Positioning

```lua
-- Client area (inside window)
local left = self:getClientLeft()      -- 12px margin
local right = self:getClientRight()
local top = self:getClientTop()        -- 19px title bar
local bottom = self:getClientBottom()

-- Utility
self:centerOnScreen(playerNum)
self:setAnchorLeft(true)
self:setAnchorRight(true)
self:setAnchorTop(true)
self:setAnchorBottom(true)
```

---

## Font Constants

```lua
UIFont.Small      -- For labels/buttons
UIFont.Medium     -- For text input
UIFont.Large      -- For titles
UIFont.Huge       -- For headers
```

---

## Colors (r, g, b, a)

```lua
-- White
1, 1, 1, 1

-- Black
0, 0, 0, 1

-- Red
1, 0, 0, 1

-- Green
0, 1, 0, 1

-- Blue
0, 0, 1, 1

-- Semi-transparent
r, g, b, 0.5
```

---

## Useful Global Functions

```lua
getCore():getScreenWidth()        -- Screen width
getCore():getScreenHeight()       -- Screen height
getTextManager():getFontHeight(font)
getTextManager():MeasureStringX(font, text)
getMouseX()
getMouseY()
getPlayerScreenLeft(playerNum)
getPlayerScreenTop(playerNum)
getPlayerScreenWidth(playerNum)
getPlayerScreenHeight(playerNum)
```

---

## Template: Responsive Window

```lua
MyWindow = ISWindow:derive("MyWindow")

function MyWindow:initialise()
    ISWindow.initialise(self)
    self.minimumWidth = 300
    self.minimumHeight = 200
    
    -- Content
    self.content = ISPanel:new(
        self:getClientLeft(), 
        self:getClientTop(),
        self:getClientWidth(),
        self:getClientHeight()
    )
    self.content:initialise()
    self.content:setAnchorLeft(true)
    self.content:setAnchorRight(true)
    self.content:setAnchorTop(true)
    self.content:setAnchorBottom(true)
    self:addChild(self.content)
end

function MyWindow:new(x, y, width, height)
    local o = ISWindow:new("Title", x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end
```

---

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Window not showing | Call `addToUIManager()` and `setVisible(true)` |
| Children not visible | Call `initialise()` before `addChild()` |
| Text cut off | Set proper width/height, use `setHeightToName()` |
| Window too small | Set `minimumWidth` and `minimumHeight` |
| Event not firing | Make sure event handler exists in class |
| Jitter/flicker | Use `drawRectStatic()` not `drawRect()` |
| Button text unreadable | Check `backgroundColor` opacity |

---

## File Locations

- Base classes: `client/ISUI/`
- Examples: `client/ISUI/ISTextBox.lua`, `ISInventoryPane.lua`
- Entry point: `client/PZAPI/` for modern UI API

---

## Checklist for New Custom UI

- [ ] Require base class (`require "ISUI/ISWindow"`)
- [ ] Create derived class with `:derive()`
- [ ] Implement `initialise()` method
- [ ] Implement `new()` constructor
- [ ] Call `initialise()` after creation
- [ ] Call `instantiate()` before adding to UIManager
- [ ] Call `addToUIManager()` to display
- [ ] Set minimum size to prevent shrinking
- [ ] Handle all needed events (mouse, keyboard)
- [ ] Call cleanup methods when closing
