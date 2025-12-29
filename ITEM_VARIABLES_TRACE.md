# Item Variables Trace - Kiosk System

Comprehensive map of all item-related variables and key functions across KioskShopConfigUI.lua, KioskItemsTable.lua, and KioskItemConfigPanel.lua.

---

## Key Functions

### `applyLeftTableFilters()` (KioskShopConfigUI)

- **Purpose**: Filter left table items by name, displayName, and type
- **Called from**:
  - Line 158: `leftNameFilterBox.onCommandEntered`
  - Line 177: `displayNameFilterBox.onCommandEntered`
  - Line 803: `onTypeFilterChange()`
  - Line 1008: `onClearLeftFilters()`
  - Line 1122: `initList()` - initial population
- **What it does**:
  - Clears `globalItemsList`
  - Loops through `self.scriptItems`
  - Applies all active filters (name, displayName, type)
  - Populates `self.filteredScriptItems` with matching items
  - Rebuilds pagination

### `onClearLeftFilters()` (KioskShopConfigUI)

- **Purpose**: Clear all left table filters and reapply
- **Called from**:
  - Line 197: Clear Filters button callback
- **What it does**:
  - Clears `leftNameFilterBox` text
  - Clears `displayNameFilterBox` text
  - Resets `typeFilterCombo` to "<Any>"
  - Calls `applyLeftTableFilters()`

### `onRemoveItemFromSelectedScriptItems()` (KioskShopConfigUI)

- **Purpose**: Remove an item from SELECTED_SCRIPT_ITEMS (double-click handler)
- **Called from**:
  - Line 414: `selectedItemsList.setOnMouseDoubleClick()` callback
- **What it does**:
  - Finds item by `fullType` in `SELECTED_SCRIPT_ITEMS`
  - Removes from list
  - Rebuilds right table via `applyRightFilters()`
  - Clears editor panel

### `applyRightFilters()` (KioskShopConfigUI)

- **Purpose**: Filter right table items by name, buy/sell status
- **Called from**:
  - Line 676: `onRemoveItemFromSelectedScriptItems()`
  - Line 714: `onAddItemToSelectedScriptItems()`
  - Line 856: `onDeselectAllPage()`
  - Line 1142: `loadSelectedScriptItems()`
  - Right panel filter onChange handlers
- **What it does**:
  - Iterates through `self.SELECTED_SCRIPT_ITEMS`
  - Applies right-side filters
  - Populates `selectedItemsList` with filtered items

---

## Master Variables

### 1. `self.scriptItems` (KioskShopConfigUI)

- **Type**: Table of item objects
- **Initialized**: Line 535 - `self.scriptItems = {}`
- **Populated**: Lines 1080-1092 in `initList()`
- **Content**: All game items from `getAllItems()` loop
- **Item structure**:
  ```lua
  {
    scriptItem = scriptItem,      -- Full scriptItem object
    id = i,                       -- Index from getAllItems()
    type = itemType,              -- Item type string
    fullType = fullType,          -- "Module.Name"
    name = name,                  -- Item name
    displayName = displayName,    -- Display name
    module = moduleName,          -- Module name
    buyPrice = 0,                 -- Default price
    sellPrice = 0,                -- Default price
    buyPriceSpecial = false,      -- Flag
    sellPriceSpecial = false      -- Flag
  }
  ```
- **Usage**:
  - Line 1095: Logged for count
  - Lines 1100-1106: Iterated to extract unique types for filter combo
  - Lines 865-871: `applyLeftFilters()` - cache check (buggy self-copy logic)
  - Lines 877-895: `applyLeftFilters()` - filtered into `self.filteredScriptItems`
  - Lines 904-905, 908: Logged for debug output
  - Line 1189: Set to `nil` in cleanup

---

### 2. `self.filteredScriptItems` (KioskShopConfigUI)

- **Type**: Table of item objects
- **Initialized**: Line 536 - `self.filteredScriptItems = {}`
- **Populated**: Lines 874-895 in `applyLeftFilters()`
- **Purpose**: Filtered results after applying name/displayName/type filters to `self.scriptItems`
- **Usage**:
  - Line 893: Items inserted from filter loop
  - Lines 904-906, 909, 914-915: Debug logging
  - Line 921: Get max pages for pagination
  - Line 922: Paginate for current page display

---

### 3. `self.SELECTED_SCRIPT_ITEMS` (KioskShopConfigUI)

- **Type**: Table of item objects with buy/sell data
- **Initialized**: Line 540 - `self.SELECTED_SCRIPT_ITEMS = {}`
- **Purpose**: **Source of truth** for items selected to be added to kiosk configuration
- **Persistence**: Saved to/loaded from character sandbox via `KioskItemConfigPanel`
- **Item structure** (extended from scriptItems):
  ```lua
  {
    -- All fields from scriptItems PLUS:
    buyPrice = 0,                 -- User-configured
    sellPrice = 0,                -- User-configured
    buyPriceSpecial = false,      -- Special coin flag
    sellPriceSpecial = false,     -- Special coin flag
    buy = false,                  -- Toggle
    sell = false                  -- Toggle
  }
  ```
- **Usage**:
  - Line 228-232: `globalItemsList.onMouseDown` - check for duplicates
  - Line 218: `drawGlobalItemRow()` - pass to draw function
  - Line 540: Declaration in constructor
  - Line 602-613: `applyRightFilters()` - iterate and filter for display
  - Line 690-711: `onAddItemToSelectedScriptItems()` - add item from global list
  - Line 667-669: `onRemoveItemFromSelectedScriptItems()` - remove from right panel
  - Line 828-848: `onDeselectAllPage()` - bulk remove filtered items
  - Line 972: `onRightNextPage()` - get max pages
  - Line 985-986: `rebuildRightPagination()` - paginate
  - Line 1001: `rightTotalLabel` display
  - Line 1138: Initialize empty in `loadSelectedItems()`
  - Line 1190: Set to `nil` in cleanup
  - Line 1151: Save count in `saveSelectedScriptItems()`

---

## Display Variables (UI Lists)

### 4. `self.globalItemsList` (ISScrollingListBox)

- **Type**: ISScrollingListBox - renders global items
- **Initialized**: Lines 203-204
- **Content**: Paginated view of `self.filteredScriptItems`
- **Drawing**: `KioskItemsTable.drawGlobalItemRow()` (line 209)
- **Selection**: Line 235 - stores index in `listBox.selected`
- **Items added**: Lines 1034-1036 in `rebuildLeftPagination()` from `self.filteredScriptItems`
- **Mouse handler**: Lines 221-238 - left click to select (checks SELECTED_ITEMS for duplicates)
- **Double click**: Line 241 - calls `onGlobalItemDoubleClick()` (add to selected)
- **Cleared**: Line 1029 in `rebuildLeftPagination()`
- **Cleared**: Line 862 in `applyLeftTableFilters()`

---

### 5. `self.selectedItemsList` (ISScrollingListBox)

- **Type**: ISScrollingListBox - renders selected items
- **Initialized**: Lines 381-383
- **Content**: Paginated view of `self.SELECTED_SCRIPT_ITEMS` (after right-side filtering)
- **Drawing**: `KioskItemsTable.drawSelectedItemRow()` (line 396)
- **Selection**: Line 407 - stores index in `listBox.selected`
- **Items added**: Lines 988-990 in `rebuildRightPagination()` from paginated `SELECTED_SCRIPT_ITEMS`
- **Mouse handler**: Lines 399-412 - left click selects and updates editor panel
- **Double click**: Line 414 - calls `onRemoveItemFromSelectedScriptItems()` (remove from SELECTED_SCRIPT_ITEMS)
- **Cleared**: Line 594 in `applyRightFilters()`
- **Cleared**: Line 982 in `rebuildRightPagination()`

---

## Filtered Results

_(See `self.filteredScriptItems` above - it IS the actively used filtered results)_

---

## Pagination & Filtering

### 7. Right Panel Filtered Results (implicit)

- **Name Filter**: `self.rightNameFilterBox:getInternalText()`
  - Lines 597 - get filter value
  - Line 570-574 `filterRightName()` - substring match on item.name
- **Buy Filter**: `self.rightBuyFilterCombo:getOptionText()`
  - Lines 598 - get filter value
  - Line 576-580 `filterRightBuy()` - check buyPrice > 0
- **Sell Filter**: `self.rightSellFilterCombo:getOptionText()`
  - Lines 599 - get filter value
  - Line 582-586 `filterRightSell()` - check sellPrice > 0
- **Loop in `applyRightFilters()`**: Lines 601-625
  ```lua
  for i = 1, #self.SELECTED_SCRIPT_ITEMS do
    local item = self.SELECTED_SCRIPT_ITEMS[i]
    if passes_right_filters(item) then
      self.selectedItemsList:addItem(item.name, item)
    end
  end
  ```

---

## Editor Panel State

### 8. `self.selectedItem` (KioskShopConfigUI)

- **Type**: Single item object or nil
- **Initialized**: Line 533 - `self.selectedItem = nil`
- **Set in**: Line 626 `onSelectedItemRightTable(item)` - clicked item from right panel table list
- **Used in**: `onSelectedItemEditorUpdate()` (lines 628-650)
  - Updates buy/sell price fields
  - Updates special price checkboxes
  - Loads item icon
- **Used in**: `onBuyCheckboxChange()` - toggle buy state
- **Used in**: `onSellCheckboxChange()` - toggle sell state
- **Used in**: `onBuyPriceChange()` - update buyPrice
- **Used in**: `onSellPriceChange()` - update sellPrice

---

## KioskItemsTable Static Functions

### 9. Function Parameters: `item` (local parameter)

- **`drawGlobalItemRow(listBox, y, item, alt, _selectedScriptItems, comboboxOpen)`**

  - Line 10: Guard check
  - Line 29: Access `item.name`
  - Line 61: Access `item.fullType`
  - Line 74-101: Read all item fields for rendering

- **`drawSelectedItemRow(listBox, y, item, alt, comboboxOpen)`**
  - Line 110: Guard check
  - Line 143: Access `item.fullType`
  - Line 155-166: Read item.item for icon
  - Line 169: Access `item.name`
  - Line 172: Access `item.buyPrice`
  - Line 175: Access `item.sellPrice`

---

## KioskItemConfigPanel Functions

### 10. `_selectedScriptItems` (parameter)

- **`serializeSelectedScriptItems(_selectedScriptItems)`**

  - Line 10: Guard check
  - Lines 15-26: Loop through each item, serialize:
    - `id`, `name`, `type`, `displayName`
    - `buy`, `sell`, `buyPrice`, `sellPrice`

- **`deserializeSelectedItems(serializedStr)`**

  - Lines 33-42: Placeholder (returns empty table)

- **`saveToSandbox(character, selectedItems)`**

  - Line 49: Serialize items
  - Line 54: Save to character sandbox as "KioskSelectedItems"

- **`loadFromSandbox(character)`**
  - Line 66: Load from character sandbox

---

## Summary Table

| Variable                     | Type   | Scope           | Purpose                           | Status  |
| ---------------------------- | ------ | --------------- | --------------------------------- | ------- |
| `self.scriptItems`           | Table  | Config UI       | Master list of all game items     | ✅ Used |
| `self.filteredScriptItems`   | Table  | Config UI       | Results after name/type filters   | ✅ Used |
| `self.SELECTED_SCRIPT_ITEMS` | Table  | Config UI       | Source of truth for kiosk items   | ✅ Used |
| `self.selectedItem`          | Object | Config UI       | Currently selected item in editor | ✅ Used |
| `self.globalItemsList`       | UIList | Config UI       | Display widget for global items   | ✅ Used |
| `self.selectedItemsList`     | UIList | Config UI       | Display widget for selected items | ✅ Used |
| `item` (parameter)           | Object | ItemsTable      | Passed to draw functions          | ✅ Used |
| `_selectedScriptItems`       | Table  | ItemConfigPanel | Serialization parameter           | ✅ Used |

---

## Data Flow

```
getAllItems()
    ↓
initList() loops items
    ↓
self.scriptItems (all items)
    ↓
applyLeftFilters()
    ↓
self.filteredScriptItems (filtered by name/type)
    ↓
rebuildPagination()
    ↓
self.globalItemsList (paginated display)
    ↓
onGlobalItemDoubleClick() or right-click
    ↓
self.SELECTED_SCRIPT_ITEMS (add item)
    ↓
applyRightFilters()
    ↓
self.selectedItemsList (paginated display)
    ↓
onSelectedItemSelected()
    ↓
self.selectedItem (editor panel)
    ↓
Update buy/sell/prices in SELECTED_SCRIPT_ITEMS
    ↓
saveSelectedItems() → KioskItemConfigPanel → sandbox
```
