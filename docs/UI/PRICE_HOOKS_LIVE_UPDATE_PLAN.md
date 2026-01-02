# Live Price Hook Update Implementation Plan

**Objective**: Enable server to detect price-hook changes (caused by other mods post-boot) and push updated price modifiers to clients in real-time, with UI-aware reaction (HaloNote, cancel pending actions, refresh pricing).

**Scope**: Price modifiers only. Item lists remain static (boot-time). MP-safe, deterministic, mod-friendly.

---

## Architecture Overview

### Core Principle
Treat **price modifiers as live, versioned state**, independent of item registries.

- **Server**: Detects price-hook mutations → increments revision counter → rebuilds + pushes modifiers
- **Client**: Tracks revision → detects changes → reacts only if Shop UI open
- **UI Layer**: Cancels pending actions locally, shows feedback, refreshes prices in-place

### Key Components
1. `PriceHookRevision` counter (server-side state)
2. Hook registration listeners (detect mutations)
3. `ShopFinalizeHandler.resyncPriceModifiers()` (rebuild + push)
4. `ShopSyncClient.onPriceHooksChanged()` (UI-aware reaction)
5. Price refresh strategy (no item resync, prices only)

---

## Implementation Phases

### Phase 1: Server-Side Infrastructure

#### 1.1 Add Price Hook Revision Counter
**File**: `Shops/42.13.1/media/lua/shared/Shop.lua`

Add to `Shop` table initialization:
```lua
SHOPSB42.Shop.PriceHookRevision = 0
```

**Purpose**: Tracks mutation state of price logic; incremented when hooks change post-finalization.

---

#### 1.2 Create Hook Mutation Listeners
**File**: `Shops/42.13.1/media/lua/server/ShopFinalizeHandler.lua`

Implement callback function:
```lua
local function onPriceHookAdded()
  if SHOPSB42.Shop._finalized then
    SHOPSB42.Shop.PriceHookRevision =
      SHOPSB42.Shop.PriceHookRevision + 1

    ShopFinalizeHandler.resyncPriceModifiers()
  end
end
```

This must be attached to:
- `OnShopModifyBuyPrice:Add(onPriceHookAdded)`
- `OnShopOverrideBuyPrice:Add(onPriceHookAdded)`
- `OnShopModifySellPrice:Add(onPriceHookAdded)` (if applicable)
- `OnShopOverrideSellPrice:Add(onPriceHookAdded)` (if applicable)

**Location**: Hook listeners should be added in finalization handler after hooks are registered.

---

#### 1.3 Implement Price Modifier Rebuild + Push
**File**: `Shops/42.13.1/media/lua/server/ShopFinalizeHandler.lua`

Implement function:
```lua
function ShopFinalizeHandler.resyncPriceModifiers()
  if not isServer() then return end

  local Builder = require("nshopsb42/pricing/ShopPriceModifierBuilder")
  local modifiers = Builder.buildPriceModifiers()

  SHOPSB42.Shop.PriceModifiers = modifiers

  for _, player in ipairs(getOnlinePlayers()) do
    sendServerCommandTo(
      player,
      "Shops",
      "SyncPriceModifiers",
      {
        revision = SHOPSB42.Shop.PriceHookRevision,
        modifiers = modifiers
      }
    )
  end
end
```

**Purpose**: Deterministically rebuilds price modifiers and broadcasts to all online players.

**Command format**: `{ revision, modifiers }`

---

### Phase 2: Client-Side Price Change Detection

#### 2.1 Handle Price Modifier Sync Command
**File**: `Shops/42.13.1/media/lua/client/ShopSyncClient.lua`

In `handleServerCommand()`, add case:
```lua
elseif command == "SyncPriceModifiers" then
  local Shop = SHOPSB42.Shop
  local newRevision = data.revision or 0

  local revisionChanged =
    Shop.PriceHookRevision ~= nil
    and newRevision ~= Shop.PriceHookRevision

  Shop.PriceHookRevision = newRevision
  Shop.PriceModifiers = data.modifiers or {}

  if revisionChanged then
    ShopSyncClient.onPriceHooksChanged()
  end
end
```

**Purpose**: Detects when price logic has mutated by comparing revisions.

---

#### 2.2 Initialize Client Revision Tracking
**File**: `Shops/42.13.1/media/lua/client/ShopSyncClient.lua`

In `ShopSyncClient:initialize()` or client initialization, add:
```lua
SHOPSB42.Shop.PriceHookRevision = nil  -- Initially unknown
SHOPSB42.Shop.PriceModifiers = {}
```

**Purpose**: Ensures first sync is always treated as a change (nil ≠ any revision).

---

### Phase 3: Client-Side UI Reaction

#### 3.1 Implement onPriceHooksChanged Handler
**File**: `Shops/42.13.1/media/lua/client/ShopSyncClient.lua`

Implement function:
```lua
function ShopSyncClient.onPriceHooksChanged()
  local ui = SHOPSB42.UI and SHOPSB42.UI.ShopUI

  if not ui or not ui:isVisible() then
    return
  end

  -- 1. Cancel any local buy/sell actions
  ui:cancelPendingTransactions()

  -- 2. Notify player
  HaloTextHelper.addText(
    getPlayer(),
    getText("UI_Shops_PricesChanged"),
    HaloTextHelper.getColorGreen()
  )

  -- 3. Refresh prices in-place
  ui:refreshPriceColumns()
end
```

**Purpose**: UI-aware reaction; only acts if Shop is open.

**Localization**: Add key `UI_Shops_PricesChanged` to language files.

---

#### 3.2 Add Transaction Cancellation to Shop UI
**File**: `Shops/42.13.1/media/lua/client/UI/ShopUI.lua`

Implement method:
```lua
function ShopUI:cancelPendingTransactions()
  if self.activeTimedAction then
    self.activeTimedAction:forceStop()
    self.activeTimedAction = nil
  end

  self:setButtonsEnabled(false)

  -- Optional short debounce (300ms)
  self._priceUpdateCooldown = getTimestampMs()
end
```

**Purpose**: Prevents buy/sell actions during price update.

---

#### 3.3 Add Debounce Check Before Transaction Dispatch
**File**: `Shops/42.13.1/media/lua/client/UI/ShopUI.lua`

Before sending any buy/sell command, add check:
```lua
if self._priceUpdateCooldown
   and getTimestampMs() - self._priceUpdateCooldown < 300 then
  return  -- Block action during cooldown
end
```

**Purpose**: Client-side protection; prevents action dispatch during price update window.

---

#### 3.4 Initialize Row Price Revision Tracking
**File**: `Shops/42.13.1/media/lua/client/UI/ShopUI.lua`

When creating or rendering a row, initialize:
```lua
row.priceRevision = nil  -- Marks as "never calculated"
row.price = nil          -- Price value
```

When initially computing a row's price:
```lua
row.price = computedPrice
row.priceRevision = SHOPSB42.Shop.PriceHookRevision
```

**Purpose**: Each row tracks which revision its price was calculated with. If `row.priceRevision != SHOPSB42.Shop.PriceHookRevision`, the price is stale and must be recalculated.

---

#### 3.5 Implement Lazy Price Recalculation
**File**: `Shops/42.13.1/media/lua/client/UI/ShopUI.lua`

Implement method:
```lua
function ShopUI:recalculateRowPrice(row)
  if not row then return end

  local Calculator =
    require("nshopsb42/pricing/ShopPriceCalculatorShared")

  local player = getPlayer()
  local mods = SHOPSB42.Shop.PriceModifiers

  local price =
    Calculator.calcBuyPrice(row.itemId, player, mods)

  if not price then
    price = row.basePrice
    row:setPriceApproximate(true)
  else
    row:setPriceApproximate(false)
  end

  row.price = price
  row.priceRevision = SHOPSB42.Shop.PriceHookRevision
  row:updatePrice(price)
end
```

**Purpose**: Recalculates a single row's price and marks it as current. Called lazily on row activation.

---

#### 3.6 Implement Row Activation Handler
**File**: `Shops/42.13.1/media/lua/client/UI/ShopUI.lua`

Implement method:
```lua
function ShopUI:onRowBecameVisible(row)
  if not row then return end

  -- If row's price revision is stale, recalculate
  if row.priceRevision ~= SHOPSB42.Shop.PriceHookRevision then
    self:recalculateRowPrice(row)
  end
end
```

Hook into row activation events (tab switch, page scroll, filter change):
```lua
function ShopUI:onTabChanged(tabIndex)
  -- ... existing tab switch logic ...

  -- Invalidate and recalc visible rows for new tab
  for _, row in ipairs(self:getVisibleRows()) do
    self:onRowBecameVisible(row)
  end
end

function ShopUI:onPageScrolled()
  -- ... existing scroll logic ...

  -- Invalidate and recalc newly visible rows
  for _, row in ipairs(self:getVisibleRows()) do
    self:onRowBecameVisible(row)
  end
end

function ShopUI:onFilterChanged()
  -- ... existing filter logic ...

  -- Invalidate and recalc filtered rows
  for _, row in ipairs(self:getVisibleRows()) do
    self:onRowBecameVisible(row)
  end
end
```

**Purpose**: Ensures stale prices are recalculated before display. Hidden rows remain marked dirty but are never shown stale.

---

#### 3.7 Update onPriceHooksChanged to Invalidate + Refresh Visible Rows
**File**: `Shops/42.13.1/media/lua/client/ShopSyncClient.lua`

Revise `onPriceHooksChanged()`:
```lua
function ShopSyncClient.onPriceHooksChanged()
  local ui = SHOPSB42.UI and SHOPSB42.UI.ShopUI

  if not ui or not ui:isVisible() then
    return
  end

  -- 1. Cancel any local buy/sell actions
  ui:cancelPendingTransactions()

  -- 2. Invalidate and refresh visible rows immediately
  for _, row in ipairs(ui:getVisibleRows()) do
    ui:onRowBecameVisible(row)  -- Triggers lazy recalc
  end

  -- 3. Notify player
  HaloTextHelper.addText(
    getPlayer(),
    getText("UI_Shops_PricesChanged"),
    HaloTextHelper.getColorGreen()
  )
end
```

**Purpose**: Immediately recalculates visible prices. Hidden rows remain marked dirty and will recalc on activation.

---

### Phase 4: Localization

#### 4.1 Add UI String
**File**: `Shops/common/media/lua/shared/Localization/EN.lua` (or equivalent)

Add entry:
```lua
UI_Shops_PricesChanged = "Shop prices have changed."
```

---

## File Modifications Summary

| File                                               | Change Type     | Complexity |
| -------------------------------------------------- | --------------- | ---------- |
| `Shops/42.13.1/media/lua/shared/Shop.lua`         | Add `PriceHookRevision` | Low        |
| `Shops/42.13.1/media/lua/server/ShopFinalizeHandler.lua` | Add hook listeners + `resyncPriceModifiers()` | Medium     |
| `Shops/42.13.1/media/lua/client/ShopSyncClient.lua`      | Add sync handler + revise `onPriceHooksChanged()` | Medium     |
| `Shops/42.13.1/media/lua/client/UI/ShopUI.lua`           | Add per-row revision tracking + lazy recalc + cancellation + debounce | Medium-High |
| `Shops/common/media/lua/shared/Localization/EN.lua`      | Add UI string | Low        |

---

## Behavior Truth Table

| Situation                    | Expected Behavior                                  |
| ---------------------------- | -------------------------------------------------- |
| UI closed                    | Silent update (no feedback)                        |
| UI open, visible rows        | HaloNote + visible rows recalc immediately        |
| UI open, hidden rows         | Marked dirty; recalc on activation (tab/scroll)   |
| Buy in progress              | Action cancelled locally (no server)               |
| Sell in progress             | Action cancelled locally (no server)               |
| Tab switch / page scroll     | Hidden rows recalc before display                 |
| Filter change                | New rows recalc before display                    |
| Server-only hooks            | "~" price indicator (existing behavior)           |
| Multiple updates             | Revision-based deduplication (hidden rows coalesced) |

---

## Testing Strategy

### Unit Tests
1. **Revision increment**: Verify `PriceHookRevision` increments on hook registration
2. **Modifier rebuild**: Verify `resyncPriceModifiers()` produces deterministic output
3. **Sync handler**: Verify `onPriceHooksChanged()` detects revision changes correctly
4. **UI refresh**: Verify `refreshPriceColumns()` updates all visible rows

### Integration Tests
1. **Boot + finalization**: Confirm revision counter works with existing finalization
2. **Post-boot hook addition**: Add hook after finalization, verify revision increments
3. **Multi-client sync**: Broadcast modifiers to multiple players, verify all receive
4. **UI reaction**: Open Shop UI, trigger price update, verify:
   - HaloNote appears
   - Pending actions cancelled
   - Prices refresh
   - UI remains responsive

### Manual QA
1. Boot with price hooks registered at finalization
2. Open Shop UI with another mod that adds price hooks at runtime
3. Verify HaloNote appears and prices update
4. Start a buy/sell action while price update occurs, verify action cancels

---

## Edge Cases & Safeguards

| Edge Case                      | Handling                                         |
| ------------------------------ | ------------------------------------------------ |
| Hook added before finalization | Ignored (items/mods already locked)              |
| Hook added after finalization  | Revision increments, resync triggered            |
| Shop UI not open               | Silent update (no noise)                         |
| Shop UI closes during update   | Hidden rows remain dirty; recalc on next open    |
| Multiple hooks added at once   | Single resync per tick; hidden rows coalesced    |
| Player offline during resync   | Command cached, sent on reconnect (optional)     |
| `requiresServer` prices        | "~" indicator remains (no calc attempted)        |
| Hidden row activation          | Lazy recalc triggers before display              |
| Stale prices shown briefly     | **Not possible** – `onRowBecameVisible()` gates  |
| Tab/page performance           | Lazy eval only on activation; no full table work |

---

## Interdependencies

- **Requires**: `ShopPriceModifierBuilder` (existing or new)
- **Requires**: `ShopPriceCalculatorShared` (existing)
- **Requires**: `HaloTextHelper.addText()` (existing)
- **Requires**: Finalization handler infrastructure (existing)
- **Uses**: `getTimestampMs()` (PZ API)
- **Uses**: `getOnlinePlayers()` (PZ API)
- **Uses**: `sendServerCommandTo()` (PZ API)

---

## Rollout Phases

### Phase 1 (Immediate)
- Add revision counter
- Implement hook listeners
- Implement `resyncPriceModifiers()`

### Phase 2 (Next)
- Implement sync handler on client
- Add `onPriceHooksChanged()` logic
- Add cancellation + debounce

### Phase 3 (Final)
- Implement `refreshPriceColumns()`
- Add localization
- Full integration testing

---

## Validation Checklist

- [ ] Revision counter initializes correctly
- [ ] Hook listeners fire on post-boot registration
- [ ] `resyncPriceModifiers()` produces deterministic output
- [ ] Sync packet includes revision and modifiers
- [ ] Client detects revision changes
- [ ] `onPriceHooksChanged()` fires only for revision changes
- [ ] UI remains hidden if Shop not open
- [ ] Per-row `priceRevision` tracks correctly
- [ ] `recalculateRowPrice()` updates single row price + revision
- [ ] `onRowBecameVisible()` triggers lazy recalc on stale rows
- [ ] Tab switch calls `onRowBecameVisible()` for visible rows
- [ ] Page scroll calls `onRowBecameVisible()` for visible rows
- [ ] Filter change calls `onRowBecameVisible()` for visible rows
- [ ] Visible rows recalc immediately on price hook change
- [ ] Hidden rows marked dirty; never shown stale
- [ ] Pending actions cancel during price update
- [ ] Debounce prevents action dispatch
- [ ] HaloNote displays with correct message
- [ ] Localization key resolves correctly
- [ ] No server-side errors on multi-client scenarios
- [ ] No item list resync (prices only)
- [ ] No global price cache (player-specific modifiers work)

---

## Notes

- **Determinism**: All price computations use shared calculator; no client-side variance.
- **MP-Safety**: Server authoritative; client only displays, does not compute modifiers.
- **Mod-Friendly**: Late hooks supported; revision self-reports mutations.
- **Low Traffic**: One packet per change; no item list bloat.
- **UI-Aware**: No spam if Shop closed; clear feedback if open.
- **Lazy Invalidation**: Rows marked dirty on price update; recalculated only on activation (tab switch, scroll, filter). Guarantees no stale prices are shown.
- **No Global Cache**: Prices computed per-row on demand; supports player-specific traits, conditions, multiplayer variance.
- **Performance**: Hidden rows incur zero work until activated; massive shops scale cleanly.
