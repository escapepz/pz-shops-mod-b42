Below is a **concise but implementation-ready UI design specification** for the **Shops B42 – Admin Tools** mod, focused on the **Kiosk Shop Config** tab. The design intentionally mirrors **vanilla ISItemsListViewer** to minimize cognitive load, maintenance cost, and MP risk.

---

## Kiosk Shop Config — UI Design Specification (B42)

### Design Goals

- Match **vanilla Item List Viewer** visual language
- Minimal UI surface, admin-grade clarity
- Zero custom rendering complexity where vanilla widgets suffice
- Safe for MP (configuration only, no item spawning)

---

## 1. Window Container

**Base Class**

- Extend `ISItemsListViewer` (preferred) or `ISPanel` with copied sizing logic

**Window Size (Vanilla-accurate)**

```lua
width  = 1150 + (getCore():getOptionFontSizeReal() * 50)
height =  650 + (getCore():getOptionFontSizeReal() * 50)
```

**Positioning**

- Centered on screen (same behavior as `ISItemsListViewer:new()`)

**Title**

```
Kiosk Shop Config
```

---

## 2. Layout Overview

```
+---------------------------------------------------------------+
| Kiosk Shop Config                                             |
+---------------------------+-----------------------------------+
| GLOBAL ITEMS              | SELECTED ITEMS                   |
| (Read-only)               | (Shop Config)                    |
|                           |                                   |
| Type | Name               | Type | Name | Buy | Sell | Price |
|---------------------------|-----------------------------------|
|                           |                                   |
|                           |                                   |
|                           |                                   |
|                           |                                   |
|---------------------------|-----------------------------------|
| Filters                   | Item Config Panel                |
| Type [____] Name [____]   | Buy [ ]  Sell [ ]                |
|                           | Buy Price  [____]                |
| Page < 1 2 3 >  Total: X | Sell Price [____]                |
+---------------------------------------------------------------+
```

---

## 3. Left Panel — Global Items Table

**Purpose**

- Source selector from **all registered items**
- No spawning, no mutation

**Widget**

- `ISScrollingListBox`

**Columns (ONLY)**

| Column | Notes                            |
| ------ | -------------------------------- |
| Type   | Full item type (`Module.ItemID`) |
| Name   | `item:getDisplayName()`          |

**Behavior**

- Single-click: select
- Double-click OR “Add →” button: add to Selected Items table
- Read-only list

---

## 4. Filtering (Left Panel – Bottom)

**Widgets**

- `ISTextEntryBox` — Type filter
- `ISTextEntryBox` — Name filter

**Logic**

- Case-insensitive substring match
- Reuse `onFilterChange()` pattern from `ISItemsListTable`
- No category, loot, or spawn filters (intentionally removed)

---

## 5. Pagination Footer (Left Panel)

**Components**

- `< Prev` button
- Page number label (or minimal numeric buttons)
- `Next >` button
- Total Results label

**Example**

```
Page 2 / 14    Total Results: 684
```

Pagination is **mandatory** to avoid UI stall with large item registries.

---

## 6. Right Panel — Selected Items Table

**Purpose**

- Represents **Kiosk Shop inventory configuration**
- Backed by Shops Mod config table

**Widget**

- `ISScrollingListBox`

**Columns**

| Column | Description                     |
| ------ | ------------------------------- |
| Type   | Item type                       |
| Name   | Display name                    |
| Buy    | Yes / No                        |
| Sell   | Yes / No                        |
| Price  | Effective price (context-aware) |

**Behavior**

- Single-click selects item → loads config panel
- Delete key or Remove button → remove from kiosk config

---

## 7. Item Config Panel (Right Panel – Bottom)

**Visible when**

- A Selected Item is highlighted

**Controls**

- Checkbox: `Allow Buy`
- Checkbox: `Allow Sell`
- Numeric Entry: `Buy Price`
- Numeric Entry: `Sell Price`

**Rules**

- Buy/Sell toggles enable their respective price fields
- Prices are integers only
- No implicit defaults (admin must define explicitly)

---

## 8. Data Flow (Important for MP Safety)

```
Global Item Registry (Read-Only)
        ↓
Selected Items Table (Local Admin UI)
        ↓
Shops Mod Config Table
        ↓
Saved via Admin Action (Apply / Save)
```

- **No inventory actions**
- **No Timed Actions**
- **No client-side item creation**
- Configuration changes sync via Shops Mod’s existing admin command path

---

## 9. UX Principles Applied

- Vanilla look → zero retraining
- Minimal columns → scan speed
- Right-side config mirrors player shop logic
- Deterministic behavior → no hidden state

---

## 10. Recommended File Structure

```
media/lua/client/admin/
 ├─ AdminToolsUI.lua
 ├─ KioskShopConfigUI.lua
 ├─ KioskItemsTable.lua
 └─ KioskItemConfigPanel.lua
```

---

## 11. Explicit Non-Goals (By Design)

- No item spawning
- No category trees
- No drag & drop
- No live price calculation
- No sandbox options here

---

### Result

This design produces a **clean, vanilla-consistent admin configuration UI** that feels native to B42, scales with font size, avoids MP pitfalls, and cleanly separates **item discovery** from **shop configuration logic**.
