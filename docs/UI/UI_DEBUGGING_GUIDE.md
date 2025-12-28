# Project Zomboid Custom UI - Debugging & Troubleshooting Guide

## Common Issues & Solutions

### Issue 1: Window Not Appearing

**Symptoms:** You create a window but it doesn't show on screen.

**Checklist:**
```lua
local win = MyWindow:new(100, 100, 300, 200)
win:initialise()           -- ✓ Did you call this?
win:instantiate()          -- ✓ Did you call this?
win:addToUIManager()       -- ✓ Did you call this?
win:setVisible(true)       -- ✓ Did you call this?
```

**Solution:**
```lua
local win = MyWindow:new(100, 100, 300, 200)
win:initialise()      -- Required: setup object
win:instantiate()     -- Required: create java object
win:addToUIManager()  -- Required: register with UI system
win:setVisible(true)  -- Required: make visible
```

---

### Issue 2: Child Elements Not Showing

**Symptoms:** You add children to window but they don't appear.

**Problem:** Not calling `initialise()` before `addChild()`.

**Solution:**
```lua
-- WRONG
local label = ISLabel:new(10, 10, 20, "Text")
self:addChild(label)  -- Won't work!

-- CORRECT
local label = ISLabel:new(10, 10, 20, "Text")
label:initialise()    -- Must initialize first
self:addChild(label)  -- Now it works
```

---

### Issue 3: Text Cut Off or Not Visible

**Symptoms:** Text in labels appears cut off or invisible.

**Cause 1: Width too small**
```lua
-- WRONG - Text won't fit
local label = ISLabel:new(10, 10, 20, "Very Long Text String", 1, 1, 1, 1, UIFont.Medium)

-- CORRECT - Measure text first
local font = UIFont.Medium
local width = getTextManager():MeasureStringX(font, "Very Long Text String")
local label = ISLabel:new(10, 10, 20, "Very Long Text String", 1, 1, 1, 1, font)
label:setWidth(width)
```

**Cause 2: Wrong color (invisible)**
```lua
-- WRONG - Black text on black background
self:drawText("text", 10, 10, 0, 0, 0, 1, UIFont.Small)  -- Can't see it!

-- CORRECT - White text
self:drawText("text", 10, 10, 1, 1, 1, 1, UIFont.Small)
```

**Cause 3: Text positioned outside visible area**
```lua
-- Use relative positioning
function MyUI:render()
    self:drawText("text", 10, 10, 1, 1, 1, 1, UIFont.Small)  -- Inside window
end

-- NOT absolute positioning
function MyUI:render()
    self:drawText("text", getMouseX(), getMouseY(), 1, 1, 1, 1, UIFont.Small)  -- Wrong!
end
```

---

### Issue 4: Button Click Not Working

**Symptoms:** Button doesn't respond to clicks.

**Solution:**
```lua
-- Step 1: Create button with target and callback
self.button = ISButton:new(10, 10, 100, 20, "Click", self, MyClass.onButtonClick)

-- Step 2: Ensure callback exists
function MyClass:onButtonClick(button)
    print("Button clicked!")
end

-- Step 3: Initialize and add
self.button:initialise()
self.button:instantiate()
self:addChild(self.button)
```

**Common mistake:** Forgetting to pass `self` as target
```lua
-- WRONG
self.button = ISButton:new(10, 10, 100, 20, "Click", nil, MyClass.onButtonClick)

-- CORRECT
self.button = ISButton:new(10, 10, 100, 20, "Click", self, MyClass.onButtonClick)
```

---

### Issue 5: Window Resizing Issues

**Symptoms:** Window becomes too small or elements overlap.

**Solution:**
```lua
function MyWindow:initialise()
    ISWindow.initialise(self)
    
    -- Set minimum size
    self.minimumWidth = 300
    self.minimumHeight = 200
    
    -- Set anchors for responsive layout
    self.content:setAnchorLeft(true)
    self.content:setAnchorRight(true)
    self.content:setAnchorTop(true)
    self.content:setAnchorBottom(true)
end
```

---

### Issue 6: Memory Leaks (Window Won't Close)

**Symptoms:** Closing window doesn't free memory, opens multiple instances.

**Solution:**
```lua
-- Track singleton instance
function MyWindow:getInstance()
    if not MyWindow.instance then
        MyWindow.instance = MyWindow:new(100, 100, 300, 200)
        MyWindow.instance:initialise()
        MyWindow.instance:instantiate()
    end
    return MyWindow.instance
end

function OpenWindow()
    local win = MyWindow:getInstance()
    win:setVisible(true)
    win:addToUIManager()
    win:bringToTop()
end

function OnWindowClose(button)
    -- Properly clean up
    button:setVisible(false)
    button:removeFromUIManager()
    MyWindow.instance = nil  -- Clear reference
end
```

---

### Issue 7: Text Input Not Working

**Symptoms:** ISTextEntryBox doesn't accept input.

**Solution:**
```lua
-- WRONG - Missing instantiate
self.textbox = ISTextEntryBox:new("", 10, 10, 200, 20)
self.textbox:initialise()
self:addChild(self.textbox)

-- CORRECT - With instantiate
self.textbox = ISTextEntryBox:new("", 10, 10, 200, 20)
self.textbox:initialise()
self.textbox:instantiate()
self:addChild(self.textbox)
```

**Retrieve text:**
```lua
local text = self.textbox:getText()
```

---

### Issue 8: Mouse Events Not Firing

**Symptoms:** `onMouseDown`, `onMouseUp` never called.

**Cause:** Events not overridden properly

**Solution:**
```lua
-- Override the method correctly
function MyClass:onMouseDown(x, y)
    print("Mouse down at " .. x .. ", " .. y)
    return true  -- Consume event (important!)
end

-- OR call parent method first
function MyClass:onMouseDown(x, y)
    ISWindow.onMouseDown(self, x, y)
    -- Your code here
    return true
end
```

---

### Issue 9: Window Appears Off-Screen

**Symptoms:** Window created at x,y but doesn't appear, or appears in wrong location.

**Solution:**
```lua
-- Clamp to screen bounds
local screenWidth = getCore():getScreenWidth()
local screenHeight = getCore():getScreenHeight()

local x = math.max(0, math.min(100, screenWidth - 300))
local y = math.max(0, math.min(100, screenHeight - 200))

local win = MyWindow:new(x, y, 300, 200)

-- OR use center function
win:centerOnScreen(0)  -- 0 = player 1
```

---

### Issue 10: Performance Issues (Lag/Stutter)

**Symptoms:** Game slows down when UI is open.

**Causes & Solutions:**

**1. Too much drawing in render()**
```lua
-- WRONG - Drawing every frame
function MyUI:render()
    for i = 1, 1000 do
        self:drawRect(i, i, 10, 10, 1, 1, 0, 0)  -- Expensive!
    end
end

-- CORRECT - Cache results
function MyUI:initialise()
    ISPanel.initialise(self)
    self.cachedRects = {}
    for i = 1, 100 do  -- Reasonable amount
        table.insert(self.cachedRects, {x=i, y=i})
    end
end

function MyUI:render()
    for _, rect in ipairs(self.cachedRects) do
        self:drawRect(rect.x, rect.y, 10, 10, 1, 1, 0, 0)
    end
end
```

**2. Complex calculations every frame**
```lua
-- WRONG
function MyUI:render()
    local expensive = doExpensiveCalculation()  -- Every frame!
    self:drawText(expensive, 10, 10, 1, 1, 1, 1, UIFont.Small)
end

-- CORRECT
function MyUI:update()
    if self.cachedValue == nil or self.updateTimer > 30 then
        self.cachedValue = doExpensiveCalculation()
        self.updateTimer = 0
    else
        self.updateTimer = self.updateTimer + 1
    end
end

function MyUI:render()
    self:drawText(self.cachedValue, 10, 10, 1, 1, 1, 1, UIFont.Small)
end
```

**3. Too many child elements**
```lua
-- Instead of 1000 labels, use ISScrollingListBox
self.listbox = ISScrollingListBox:new(10, 10, 200, 300)
self.listbox:addItem("Item 1")
self.listbox:addItem("Item 2")
-- List only renders visible items
```

---

## Debugging Techniques

### 1. Print Debugging
```lua
function MyUI:initialise()
    print("MyUI initialise called")
    ISWindow.initialise(self)
    print("After parent initialise")
end

function MyUI:onMouseDown(x, y)
    print("Mouse down! x=" .. x .. ", y=" .. y)
    return true
end
```

### 2. Conditional Rendering (Debug Overlay)
```lua
function MyUI:render()
    ISWindow.render(self)
    
    -- Debug info
    if self.debugMode then
        self:drawText("Debug: x=" .. self:getX() .. " y=" .. self:getY(), 10, 10, 1, 1, 0, 1, UIFont.Small)
        self:drawText("Width: " .. self:getWidth() .. " Height: " .. self:getHeight(), 10, 25, 1, 1, 0, 1, UIFont.Small)
        self:drawRectBorder(0, 0, self.width, self.height, 1, 1, 0, 0)  -- Red border
    end
end

function MyUI:onKeyPress(key)
    if key == Keyboard.KEY_F1 then
        self.debugMode = not self.debugMode
        return true
    end
    return false
end
```

### 3. Verification Checklist
```lua
function MyUI:verify()
    -- Check initialization
    assert(self.javaObject ~= nil, "javaObject not created - call instantiate()")
    assert(self.x ~= nil, "x not set")
    assert(self.y ~= nil, "y not set")
    assert(self.width ~= nil, "width not set")
    assert(self.height ~= nil, "height not set")
    
    -- Check children
    for id, child in pairs(self.children) do
        assert(child.javaObject ~= nil, "Child " .. id .. " not instantiated")
    end
    
    print("MyUI verification passed")
end
```

---

## Testing Checklist

- [ ] Window creates without errors
- [ ] Window appears at correct position
- [ ] Window can be dragged (if ISWindow)
- [ ] Window can be resized (if resizable)
- [ ] All child elements visible
- [ ] All buttons clickable and working
- [ ] Text input accepts text
- [ ] Keyboard events work (Escape to close)
- [ ] Window closes properly
- [ ] No memory leaks (can open/close multiple times)
- [ ] Works at different screen resolutions
- [ ] No console errors
- [ ] Performance acceptable

---

## Console Error Messages & Solutions

### "javaObject is nil"
**Cause:** Using element before calling `instantiate()`
```lua
element:instantiate()  -- Call this first
element:getWidth()     -- Now this works
```

### "attempt to call nil"
**Cause:** Method not defined
```lua
function MyClass:myMethod()  -- Lowercase: define correctly
    print("Works")
end

self:myMethod()  -- Uppercase won't work
```

### "attempt to index nil"
**Cause:** Element not initialized
```lua
local button = ISButton:new(...)
button:initialise()  -- Add this
button:setWidth(100) -- Now this works
```

---

## Performance Profiling

```lua
function MyUI:profileRender()
    local startTime = getTimestep()
    
    -- Your render code
    self:drawText("Test", 10, 10, 1, 1, 1, 1, UIFont.Small)
    
    local duration = getTimestep() - startTime
    if duration > 0.016 then  -- More than 16ms is slow
        print("Slow render: " .. duration .. "ms")
    end
end
```

---

## Useful Console Commands

```lua
-- Get screen dimensions
print(getCore():getScreenWidth())
print(getCore():getScreenHeight())

-- Get mouse position
print(getMouseX() .. ", " .. getMouseY())

-- Get font height
print(getTextManager():getFontHeight(UIFont.Small))

-- Measure text
local width = getTextManager():MeasureStringX(UIFont.Small, "Text")
print(width)

-- Find all UI elements
-- Look at UIManager class
```
