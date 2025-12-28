# Project Zomboid - Custom UI Creation Guide for Mods

## Overview

Project Zomboid uses an object-oriented Lua UI framework based on `ISUIElement`, which is the base class for all UI components. Custom UI is created by extending these base classes and overriding key methods.

---

## UI Hierarchy & Architecture

```
ISUIElement (base)
    ├── ISPanel (basic container, no decoration)
    ├── ISWindow (titled window with resizing)
    ├── ISLabel (text display)
    ├── ISButton (clickable button)
    ├── ISTextBox (text input)
    ├── ISScrollBar (scrolling)
    ├── ISTabPanel (tabbed interface)
    └── [Many other specialized components]
```

Each UI element:
- Has a **javaObject** (native Java binding)
- Can have **children** (nested UI elements)
- Can have a **parent** (containing element)
- Implements key lifecycle methods: `initialise()`, `instantiate()`, `render()`, `update()`

---

## Core Concepts

### 1. **Deriving from Base Classes**

All custom UI inherits from `ISUIElement` or one of its subclasses:

```lua
require "ISUI/ISUIElement"

MyCustomUI = ISUIElement:derive("MyCustomUI")

function MyCustomUI:initialise()
    ISUIElement.initialise(self)
    -- Initialize your properties here
end

function MyCustomUI:new(x, y, width, height)
    local o = {}
    o = ISUIElement:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    -- Set defaults
    o.myProperty = "value"
    return o
end
```

### 2. **Key Methods to Override**

| Method | Purpose | When Called |
|--------|---------|-------------|
| `initialise()` | Initialize properties & child components | After creation |
| `instantiate()` | Create javaObject (native binding) | Before rendering |
| `render()` | Draw UI elements | Every frame if visible |
| `prerender()` | Setup before rendering | Before render() |
| `update()` | Logic/animation updates | Every frame if visible |
| `onMouseDown(x, y)` | Handle mouse click | On mouse press |
| `onMouseUp(x, y)` | Handle mouse release | On mouse release |
| `onMouseMove(dx, dy)` | Handle mouse movement | On mouse move |
| `onKeyPress(key)` | Handle keyboard input | On key press |

### 3. **Adding Child Elements**

```lua
local label = ISLabel:new(10, 10, 20, "My Label")
label:initialise()
self:addChild(label)

-- Also works with complex elements
local button = ISButton:new(10, 40, 100, 20, "Click Me", self, MyClass.onButtonClick)
button:initialise()
self:addChild(button)
```

---

## Practical Example: Custom Window with UI Elements

```lua
require "ISUI/ISWindow"
require "ISUI/ISButton"
require "ISUI/ISLabel"

MyCustomWindow = ISWindow:derive("MyCustomWindow")

function MyCustomWindow:initialise()
    ISWindow.initialise(self)
    
    -- Add a title label
    self.titleLabel = ISLabel:new(
        10, 10, 20,           -- x, y, height
        "Welcome to My Mod",   -- text
        1, 1, 1, 1,           -- r, g, b, a (white)
        UIFont.Medium
    )
    self.titleLabel:initialise()
    self:addChild(self.titleLabel)
    
    -- Add a button
    self.myButton = ISButton:new(
        10, 40, 100, 20,      -- x, y, width, height
        "Click Me",            -- text
        self,                  -- target (self for callback)
        MyCustomWindow.onButtonClick  -- callback function
    )
    self.myButton:initialise()
    self:addChild(self.myButton)
    
    -- Set minimum size to prevent shrinking too much
    self.minimumWidth = 200
    self.minimumHeight = 150
end

function MyCustomWindow:onButtonClick(button)
    print("Button clicked!")
    -- Do something here
end

function MyCustomWindow:render()
    ISWindow.render(self)
    -- Draw any custom content
    self:drawTextCentre("Custom Content Here", self:getCentreX(), 100, 1, 1, 1, 1)
end

function MyCustomWindow:new(x, y, width, height)
    local o = ISWindow:new("My Custom Window", x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end
```

### Creating and Showing the Window

```lua
local window = MyCustomWindow:new(100, 100, 300, 200)
window:initialise()
window:instantiate()
window:addToUIManager()
window:setVisible(true)
```

---

## Common UI Components

### ISButton
```lua
local button = ISButton:new(x, y, width, height, text, target, function)
button:initialise()
button.onClick = MyClass.onClickHandler  -- callback: onClick(button)
self:addChild(button)
```

### ISLabel
```lua
local label = ISLabel:new(x, y, height, text, r, g, b, a, font, leftAlign)
label:initialise()
label:setName("New text")  -- Update text
label:setColor(1, 0, 0)    -- Red text
self:addChild(label)
```

### ISTextEntryBox
```lua
local textbox = ISTextEntryBox:new("default text", x, y, width, height)
textbox:initialise()
textbox:setMultipleLine(true)
self:addChild(textbox)
local text = textbox:getText()  -- Get input
```

### ISPanel
```lua
local panel = ISPanel:new(x, y, width, height)
panel:initialise()
panel.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.8}
panel.borderColor = {r=0.5, g=0.5, b=0.5, a=1}
self:addChild(panel)
```

### ISScrollingListBox
```lua
local listbox = ISScrollingListBox:new(x, y, width, height)
listbox:initialise()
listbox:addItem("Item 1")
listbox:addItem("Item 2")
listbox.onSelect = function(item) print(item) end
self:addChild(listbox)
```

---

## Position & Size Management

### Absolute Positioning
```lua
element:setX(100)
element:setY(50)
element:setWidth(200)
element:setHeight(100)
```

### Getting Position/Size
```lua
local x = element:getX()
local y = element:getY()
local w = element:getWidth()
local h = element:getHeight()
local right = element:getRight()      -- x + width
local bottom = element:getBottom()    -- y + height
```

### Anchoring (Responsive Layout)
```lua
-- Anchor to specific edges
element:setAnchorLeft(true)    -- Stays fixed distance from left
element:setAnchorRight(true)   -- Scales with window width
element:setAnchorTop(true)     -- Stays fixed distance from top
element:setAnchorBottom(true)  -- Scales with window height
```

### Center on Screen
```lua
window:centerOnScreen(playerNum)
```

---

## Drawing & Rendering

### Drawing Methods Available in render()

```lua
-- Text
self:drawText(text, x, y, r, g, b, a, font)
self:drawTextCentre(text, x, y, r, g, b, a, font)
self:drawTextRight(text, x, y, r, g, b, a, font)

-- Shapes
self:drawRect(x, y, width, height, a, r, g, b)          -- Filled
self:drawRectStatic(x, y, width, height, a, r, g, b)    -- Static (no scroll)
self:drawRectBorder(x, y, width, height, a, r, g, b)    -- Border only
self:drawLine(x1, y1, x2, y2, a, r, g, b)

-- Textures
self:drawTexture(texture, x, y, r, g, b, a)
self:drawTextureScaled(texture, x, y, width, height, r, g, b, a)

-- Progress bars
self:drawProgressBar(x, y, w, h, fraction, {r, g, b, a})
```

### Example render() implementation

```lua
function MyUI:prerender()
    -- Draw background
    self:drawRectStatic(0, 0, self.width, self.height, 0.8, 0.1, 0.1, 0.1)
    self:drawRectBorderStatic(0, 0, self.width, self.height, 1, 0.5, 0.5, 0.5)
end

function MyUI:render()
    -- Draw custom content
    self:drawText("Custom Text", 20, 20, 1, 1, 1, 1, UIFont.Small)
    if self.customValue then
        self:drawProgressBar(20, 50, 100, 10, self.customValue / 100, {r=0, g=1, b=0, a=1})
    end
end
```

---

## Lifecycle Flow

```
1. Create instance
   local ui = MyUIClass:new(...)

2. Initialise (setup properties)
   ui:initialise()

3. Instantiate (create Java objects)
   ui:instantiate()

4. Add children
   ui:addChild(childElement)

5. Add to UI manager
   ui:addToUIManager()

6. Set visible
   ui:setVisible(true)

7. Every frame (while visible):
   - update() called
   - prerender() called
   - render() called
   - Event handlers (onMouseDown, onKeyPress, etc.)

8. Cleanup
   ui:removeFromUIManager()
   ui:setVisible(false)
```

---

## Event Handling

### Mouse Events
```lua
function MyUI:onMouseDown(x, y)
    print("Mouse down at " .. x .. ", " .. y)
    return true  -- Consume event
end

function MyUI:onMouseUp(x, y)
    print("Mouse up")
end

function MyUI:onMouseMove(dx, dy)
    print("Mouse moved " .. dx .. ", " .. dy)
end

function MyUI:onMouseWheel(delta)
    print("Mouse wheel: " .. delta)
    return true
end
```

### Keyboard Events
```lua
function MyUI:onKeyPress(key)
    if key == Keyboard.KEY_ESCAPE then
        self:setVisible(false)
        self:removeFromUIManager()
        return true
    end
    return false
end
```

### Button Callbacks
```lua
function MyClass:onMyButtonClick(button)
    print("Button clicked: " .. button:getTitle())
    -- button is the ISButton object
end
```

---

## Common Patterns

### Modal Dialog
```lua
local dialog = ISTextBox:new("Enter value:", 100, 100, 300, 100, "", function(target, button, text)
    if button == "OK" then
        print("User entered: " .. text)
    end
end)
dialog:initialise()
dialog:addToUIManager()
```

### Context Menu
```lua
local menu = ISContextMenu:new(x, y)
menu:addOption("Option 1", function() print("Option 1") end)
menu:addOption("Option 2", function() print("Option 2") end)
menu:addToUIManager()
menu:setVisible(true)
```

### Scrollable Panel with Content
```lua
local panel = ISPanel:new(x, y, width, height)
panel:initialise()
panel:addScrollBars(false)  -- Add vertical scrollbar

for i = 1, 50 do
    local label = ISLabel:new(10, i * 25, 20, "Item " .. i)
    label:initialise()
    panel:addChild(label)
end

panel:setScrollHeight(50 * 25)
self:addChild(panel)
```

---

## Best Practices

1. **Always call initialise() and instantiate()**
   ```lua
   local ui = MyUI:new(...)
   ui:initialise()
   ui:instantiate()
   ```

2. **Add to UIManager to make visible**
   ```lua
   ui:addToUIManager()
   ui:setVisible(true)
   ```

3. **Use proper cleanup**
   ```lua
   ui:setVisible(false)
   ui:removeFromUIManager()
   ```

4. **Set minimum sizes to prevent UI breaking**
   ```lua
   self.minimumWidth = 200
   self.minimumHeight = 150
   ```

5. **Use anchoring for responsive layouts**
   ```lua
   element:setAnchorLeft(true)
   element:setAnchorRight(true)
   ```

6. **Handle screen boundaries**
   ```lua
   window:centerOnScreen(playerNum)
   ```

7. **Test with different resolutions**
   - Different screen sizes may affect UI layout

8. **Use UIFont constants**
   ```lua
   UIFont.Small, UIFont.Medium, UIFont.Large
   ```

---

## File Organization for Mods

```
YourMod/
├── media/
│   └── lua/
│       ├── client/
│       │   └── UI/
│       │       ├── MyCustomWindow.lua
│       │       ├── MyCustomPanel.lua
│       │       └── MyUIManager.lua
│       ├── shared/
│       └── server/
└── mod.info
```

---

## Key Files to Reference

- `client/ISUI/ISUIElement.lua` - Base class
- `client/ISUI/ISWindow.lua` - Window template
- `client/ISUI/ISPanel.lua` - Panel template
- `client/ISUI/ISButton.lua` - Button implementation
- `client/ISUI/ISLabel.lua` - Label implementation
- `client/ISUI/ISTextBox.lua` - Complex UI example
- `client/ISUI/ISScrollingListBox.lua` - List template
