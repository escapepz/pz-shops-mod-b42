## Keyboard Handling Patterns in Vanilla UI

**Common functions that handle keyboard:**

### 1. **`isKeyConsumed(key)` - Declare consumed keys** (ISHandcraftWindow.lua, line 312)

```lua
function ISHandcraftWindow:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE or getCore():isKey("Crafting UI", key)
end
```

Returns `true` if the panel handles this key (prevents other UIs from receiving it).

### 2. **`onKeyRelease(key)` - Handle key release** (ISHandcraftWindow.lua, lines 316-322)

```lua
function ISHandcraftWindow:onKeyRelease(key)
    if self:isVisible() and (key == Keyboard.KEY_ESCAPE or getCore():isKey("Crafting UI", key)) then
        self:close()
        self:removeFromUIManager()
        return
    end
end
```

### 3. **`onKeyPress(key)` - Handle key press** (ISMapWrapper.lua, lines 127-132)

```lua
function ISMapWrapper:onKeyPress(key)
    if self.mapUI.symbolsUI:onKeyPress(key) then
        return  -- Consumed by child
    end
    return
end
```

### 4. **`onOtherKey(key)` - Special key handling on input widgets** (ISComboBox.lua, lines 22-27)

```lua
function ISComboBoxEditor:onOtherKey(key)
    if key == Keyboard.KEY_ESCAPE then
        self.parentCombo.expanded = false
        self.parentCombo:hidePopup()
    end
end
```

### 5. **Complete pattern with custom binds** (ISHandcraftWindow.lua, lines 312-322)

```lua
function ISHandcraftWindow:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE or getCore():isKey("Crafting UI", key)
end

function ISHandcraftWindow:onKeyRelease(key)
    if self:isVisible() and (key == Keyboard.KEY_ESCAPE or getCore():isKey("Crafting UI", key)) then
        self:close()
        self:removeFromUIManager()
        return
    end
end
```

**Key points:**

- `onKeyRelease` is safer than `onKeyPress` for closing
- Always check `:isVisible()` before processing
- Use `getCore():isKey()` to support custom keybinds
- Return `true` to consume the event (prevent propagation)
- `isKeyConsumed()` helps UI manager route keys correctly
