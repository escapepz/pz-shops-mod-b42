# Project Zomboid - Custom UI for Mods

## Documentation Files Overview

This directory contains comprehensive guides and examples for creating custom user interface elements for Project Zomboid mods.

### Files Included

1. **CUSTOM_UI_MOD_GUIDE.md**
   - Comprehensive guide to UI architecture and concepts
   - How to derive from base classes
   - Key methods to override
   - Common UI components with examples
   - Position & size management
   - Drawing and rendering
   - Event handling
   - Best practices

2. **CUSTOM_UI_QUICKREF.md**
   - Quick reference card for rapid development
   - Template code snippets
   - Common patterns
   - Troubleshooting quick fixes
   - Keyboard shortcut reference

3. **CUSTOM_UI_EXAMPLE.lua**
   - Complete working example of a custom window
   - Shows all major UI patterns
   - Demonstrates initialization, events, and rendering
   - Ready to copy and modify for your mod

4. **UI_PATTERNS_EXAMPLES.lua**
   - 8 common UI design patterns
   - Simple alert dialogs
   - Forms with validation
   - Data tables/lists
   - Status dashboards
   - Tabbed interfaces
   - Modal popups
   - Context menus
   - Floating tooltips

5. **UI_DEBUGGING_GUIDE.md**
   - Solutions to 10 most common issues
   - Debugging techniques
   - Testing checklist
   - Console error messages and fixes
   - Performance profiling

---

## Quick Start

### 1. Basic Template
```lua
require "ISUI/ISWindow"

MyWindow = ISWindow:derive("MyWindow")

function MyWindow:initialise()
    ISWindow.initialise(self)
    -- Add UI elements here
end

function MyWindow:new(x, y, width, height)
    local o = ISWindow:new("Title", x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

-- Open the window
local win = MyWindow:new(100, 100, 300, 200)
win:initialise()
win:instantiate()
win:addToUIManager()
```

### 2. Key Classes

| Class | Purpose |
|-------|---------|
| `ISUIElement` | Base class for all UI |
| `ISWindow` | Titled, resizable window |
| `ISPanel` | Simple container |
| `ISButton` | Clickable button |
| `ISLabel` | Text display |
| `ISTextEntryBox` | Text input |
| `ISScrollingListBox` | List of items |
| `ISTabPanel` | Tabbed interface |

---

## Basic Workflow

```
Create:         MyWindow:new(x, y, width, height)
Initialise:     window:initialise()
Instantiate:    window:instantiate()
Add to UI:      window:addToUIManager()
Show:           window:setVisible(true)
Hide/Close:     window:removeFromUIManager()
```

---

## Key Methods

### Position & Size
- `setX(x)` / `getX()` - Horizontal position
- `setY(y)` / `getY()` - Vertical position
- `setWidth(w)` / `getWidth()` - Width
- `setHeight(h)` / `getHeight()` - Height

### Visibility
- `setVisible(bool)` - Show/hide
- `getIsVisible()` - Check if visible

### Children
- `addChild(element)` - Add nested element
- `removeChild(element)` - Remove element
- `clearChildren()` - Remove all children

### Drawing (in render())
- `drawText(text, x, y, r, g, b, a, font)` - Draw text
- `drawRect(x, y, w, h, a, r, g, b)` - Draw rectangle
- `drawTexture(texture, x, y, r, g, b, a)` - Draw image

---

## Events to Override

```lua
onMouseDown(x, y)           -- Mouse clicked
onMouseUp(x, y)             -- Mouse released
onMouseMove(dx, dy)         -- Mouse moved
onMouseWheel(delta)         -- Scroll wheel
onKeyPress(key)             -- Key pressed
update()                    -- Every frame (logic)
render()                    -- Every frame (drawing)
```

---

## Colors (RGBA format)

```lua
White:      1, 1, 1, 1
Black:      0, 0, 0, 1
Red:        1, 0, 0, 1
Green:      0, 1, 0, 1
Blue:       0, 0, 1, 1
```

---

## Fonts

```lua
UIFont.Small    -- Default small font
UIFont.Medium   -- Medium font
UIFont.Large    -- Large font
```

---

## Common Mistakes

1. Not calling `initialise()` before `addChild()`
2. Not calling `instantiate()` before `addToUIManager()`
3. Forgetting `addToUIManager()` - window won't appear
4. Text width too small - use `getTextManager()` to measure
5. Buttons not clickable - must pass `self` as target parameter
6. Window gets too small - set `minimumWidth` and `minimumHeight`
7. Memory leaks - properly clean up in close/destroy
8. Events not firing - check method name and signature
9. Using absolute coordinates in `render()` instead of relative
10. Not checking if `javaObject` is nil before use

---

## Directory Structure

```
YourMod/
├── media/
│   └── lua/
│       ├── client/
│       │   └── UI/
│       │       ├── MyWindow.lua
│       │       └── UIManager.lua
│       ├── shared/
│       └── server/
└── mod.info
```

---

## Learning Path

1. Start with **CUSTOM_UI_EXAMPLE.lua** - see a complete working example
2. Read **CUSTOM_UI_MOD_GUIDE.md** - understand the architecture
3. Look at **UI_PATTERNS_EXAMPLES.lua** - find patterns for your needs
4. Use **CUSTOM_UI_QUICKREF.md** - quick lookup while coding
5. Check **UI_DEBUGGING_GUIDE.md** - when you hit issues

---

## Useful Functions

```lua
-- Screen info
getCore():getScreenWidth()
getCore():getScreenHeight()

-- Text measurement
getTextManager():getFontHeight(font)
getTextManager():MeasureStringX(font, text)

-- Input
getMouseX()
getMouseY()

-- Localization
getText("UI_Ok")  -- Get translated text
```

---

## Example: Simple Button Window

```lua
require "ISUI/ISWindow"
require "ISUI/ISButton"

SimpleWindow = ISWindow:derive("SimpleWindow")

function SimpleWindow:initialise()
    ISWindow.initialise(self)
    
    self.button = ISButton:new(10, 30, 100, 20, "Click Me", self, SimpleWindow.onClick)
    self.button:initialise()
    self:addChild(self.button)
end

function SimpleWindow:onClick(button)
    print("Button clicked!")
end

function SimpleWindow:new(x, y)
    local o = ISWindow:new("Simple", x, y, 150, 80)
    setmetatable(o, self)
    self.__index = self
    return o
end

-- Usage
local win = SimpleWindow:new(100, 100)
win:initialise()
win:instantiate()
win:addToUIManager()
```

---

## Next Steps

- Read the comprehensive guides for deep understanding
- Study the example files for implementation patterns
- Reference the quick guide while developing
- Check debugging guide when encountering issues
- Look at actual game code in `client/ISUI/` for inspiration

---

## Resources

- **Project Zomboid Wiki**: https://pzwiki.net/wiki/Modding
- **Game Code**: Look at `client/ISUI/` directory for examples
- **Complex Example**: Study `client/ISUI/ISTextBox.lua`
- **Advanced Example**: Study `client/ISUI/ISInventoryPane.lua`

---

## File Organization

All guides and examples are included:
- `CUSTOM_UI_MOD_GUIDE.md` - Full documentation
- `CUSTOM_UI_QUICKREF.md` - Quick reference
- `CUSTOM_UI_EXAMPLE.lua` - Complete example
- `UI_PATTERNS_EXAMPLES.lua` - Design patterns
- `UI_DEBUGGING_GUIDE.md` - Troubleshooting
- `README_CUSTOM_UI.md` - This file
