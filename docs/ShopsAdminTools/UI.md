Below is a **concise, agent-ready guide** that **applies the official Crafting/Building UI best practices** from the uploaded guide to your **minimalist Kiosk Shop Configurator UI**, **without violating your minimalist constraints**.

This tells the agent **what patterns to copy**, **what to avoid**, and **how to adapt them correctly**.

---

## Best-Practice UI Guide

### Applying Crafting/Building UI Patterns to the Kiosk Configurator

Target: **Project Zomboid B42.13 MP**

Reference source: _Project Zomboid Crafting/Building UI Implementation Guide_

---

## 1. Correct Base Class (Mandatory)

### Use This

```lua
ISCollapsableWindow
```

### Do NOT Use

- Custom window bases
- Raw `ISPanel` as root
- Entity Crafting panels

**Reason (from guide):**

- `ISCollapsableWindow` is the stable, admin-tool-style window
- Matches Debug UI behavior
- Handles dragging, focus, and close lifecycle correctly

---

## 2. UI Hierarchy (Minimal Adaptation)

### Follow This Structure

```
ISKioskConfigPanel (ISCollapsableWindow)
├─ TopBar (ISPanel)
│  ├─ SearchBox (ISTextEntryBox)
│  └─ ModeCombo (ISComboBox)
├─ ItemList (ISScrollingListBox)
├─ ConfigPanel (ISPanel)
└─ Footer (ISPanel)
   ├─ PrevButton
   ├─ PageLabel
   └─ NextButton
```

### Why This Matches Best Practice

- Mirrors `ISCraftingUI` → list + detail panel pattern
- Uses `ISScrollingListBox` for large datasets
- No nested tabs or complex entity panels

---

## 3. List Component Choice (Important)

### Required Component

```lua
ISScrollingListBox
```

### Configuration

```lua
list.itemHeight = 22
list.font = UIFont.Small
list.doDrawItem = self.drawItem
list:setOnClickFunction(self, self.onSelect)
```

**Why**

- This is exactly how recipes are listed in crafting UI
- Proven performance with thousands of entries

---

## 4. Rendering Rules (Minimalist-Safe)

### Allowed Rendering

- `drawText`
- `drawTextureScaledAspect` (item icon only)

### Forbidden

- Custom colors
- Alpha overlays
- Animations
- Icon stacks
- Tooltip-driven UI

**Adaptation Rule**

> Copy **structure**, not **visual richness**, from crafting UI.

---

## 5. Data Flow (Critical Best Practice)

### UI Reads Only

```lua
cached item list
working config
original config
```

### UI Never Does

- Item validation
- Price calculation
- Inventory access
- ModData writes

This matches crafting UI separation:

- UI renders
- Actions happen elsewhere

---

## 6. Selection → Detail Pattern (Direct Copy)

Use the same pattern as recipe → ingredient panel:

```lua
function ISKioskConfigPanel:onItemSelected()
    local item = self.itemList.items[self.itemList.selected]
    if not item then return end
    self.configPanel:setItem(item)
end
```

**Why**

- Proven pattern
- Avoids UI desync
- Simple mental model

---

## 7. Update / Refresh Discipline

### Follow Crafting UI Rule

- UI updates **only when state changes**
- No per-frame rebuilding
- No heavy logic in `render()`

Example:

```lua
function ISKioskConfigPanel:update()
    if self.needsRefresh then
        self:refreshList()
        self.needsRefresh = false
    end
end
```

This avoids UI lag with large modpacks

---

## 8. Input Handling (Keep Minimal)

### Required

- ESC → close window
- Mouse click → select / apply

### Optional (Later)

- Joypad navigation

Do **not** add crafting-style hotkeys (Enter, A/B buttons).
Admin tools should remain mouse-first.

---

## 9. Close / Cleanup (Non-Optional)

Follow the guide’s cleanup pattern:

```lua
function ISKioskConfigPanel:close()
    ISCollapsableWindow.close(self)
    self.character = nil
    self.itemList = nil
end
```

Prevents:

- Memory leaks
- Zombie UI references
- Joypad focus bugs

---

## 10. What You Explicitly Do NOT Copy from Crafting UI

| Crafting Feature   | Reason                |
| ------------------ | --------------------- |
| Timed Actions      | Not a gameplay UI     |
| Container scanning | Server responsibility |
| Recipe validation  | Not applicable        |
| Favorites          | Adds clutter          |
| Category tabs      | Breaks minimalism     |
| Ingredient icons   | Not relevant          |

---

## 11. Summary for the Agent (One-Line Rule)

> **Build the kiosk UI exactly like a stripped-down crafting UI: same structure, same list mechanics, same lifecycle — but without gameplay logic, colors, or automation.**

If it feels boring, it is correct.

---
