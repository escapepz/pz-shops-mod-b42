# Price Hook Live Update - Testing Guide

## Quick Test for Base.Apple Price Changes

This guide walks through testing the live price hook update system implemented in Phase 1-4.

---

## Test File Location

**Server-side test hooks**: `Shops/42.13.1/media/lua/server/nshopsb42/TestPriceHooks.lua`

---

## Setup

### 1. Enable Test Hooks in ShopInitServer.lua

Add to `Shops/42.13.1/media/lua/server/nshopsb42/ShopInitServer.lua` (after Shop finalization):

```lua
-- Initialize test hooks (remove in production)
local TestPriceHooks = require("nshopsb42/TestPriceHooks")
TestPriceHooks.initialize()

-- Register console command
local TestPriceHooksCommand = require("nshopsb42/TestPriceHooksCommand")
TestPriceHooksCommand.register()
```

### 2. Restart Server

The test hooks are now active and monitoring for commands.

---

## Calling Test Functions

### Buy Price (Food Tab)

Open the debug console and call:

```lua
SHOPSB42.TestPriceHooksCommand.testapple(2.0)      -- Double buy price
SHOPSB42.TestPriceHooksCommand.testapple(0.5)      -- Half buy price
SHOPSB42.TestPriceHooksCommand.testapple(3.0)      -- Triple buy price
```

### Sell Price (Sell Tab)

```lua
SHOPSB42.TestPriceHooksCommand.testappleSell(2.0)      -- Double sell price
SHOPSB42.TestPriceHooksCommand.testappleSell(0.5)      -- Half sell price
SHOPSB42.TestPriceHooksCommand.testappleSell(3.0)      -- Triple sell price
```

### Reset Both

```lua
SHOPSB42.TestPriceHooksCommand.testappleReset()    -- Reset buy and sell
```

**Example Console Session**:
```
> SHOPSB42.TestPriceHooksCommand.testapple(2.0)
[TestPriceHooks] Apple BUY price multiplier set to: 2.0
  Resync triggered. Check Shop UI for live price update.

> SHOPSB42.TestPriceHooksCommand.testappleSell(1.5)
[TestPriceHooks] Apple SELL price multiplier set to: 1.5
  Resync triggered. Check Shop UI Sell tab for live price update.

> SHOPSB42.TestPriceHooksCommand.testappleReset()
[TestPriceHooks] Test hook disabled, apple prices reset to normal (buy and sell)
```

### Or Use TestPriceHooks Directly

```lua
local T = require("nshopsb42/TestPriceHooks")
T.setAppleMultiplier(2.0)       -- Buy price
T.setAppleSellMultiplier(1.5)   -- Sell price
T.disable()                      -- Reset both
```

---

## Test Scenarios

### Scenario 1: Double Apple Price

**Goal**: Verify that changing apple price triggers live update

**Steps**:

1. Open Shop UI and view Base.Apple price (note initial price)
2. Keep Shop UI open
3. Open debug console and execute:
   ```lua
   SHOPSB42.TestPriceHooksCommand.testapple(2.0)
   ```
4. **Expected**:
   - HaloNote appears: "Shop prices have changed."
   - Base.Apple price doubles immediately in UI
   - No action is needed, prices refresh in-place

### Scenario 2: Half Apple Price

**Goal**: Test multiple price changes

**Steps**:

1. From Scenario 1, execute in console:
   ```lua
   SHOPSB42.TestPriceHooksCommand.testapple(0.5)
   ```
2. **Expected**:
   - HaloNote appears again
   - Apple price halves
   - All UI updates happen smoothly

### Scenario 3: Cancel Action During Price Change

**Goal**: Verify action cancellation works

**Steps**:

1. Open Shop UI
2. Select Base.Apple and add to buy cart
3. **Immediately** (within 1 second) execute in console:
   ```lua
   SHOPSB42.TestPriceHooksCommand.testapple(3.0)
   ```
4. Click "Buy Cart" button during price update window
5. **Expected**:
   - Buy action does NOT proceed
   - Button remains disabled for ~300ms
   - Action is blocked by debounce

### Scenario 4: Hidden Rows Update on Tab Switch

**Goal**: Verify hidden rows recalculate on visibility

**Steps**:

1. Open Shop UI on "All" tab (showing apple)
2. Switch to "Food" tab
3. Execute in console:
   ```lua
   SHOPSB42.TestPriceHooksCommand.testapple(1.5)
   ```
4. Switch back to "All" tab
5. **Expected**:
   - Apple price now shows 1.5x
   - Price was recalculated when row became visible
   - No stale prices shown

### Scenario 5: Silent Update When UI Closed

**Goal**: Verify no feedback when Shop closed

**Steps**:

1. Open Shop UI
2. Close Shop UI
3. Execute in console:
   ```lua
   SHOPSB42.TestPriceHooksCommand.testapple(2.5)
   ```
4. **Expected**:
   - NO HaloNote appears
   - No feedback to player
   - Price update happens silently

### Scenario 6: Test Sell Price Changes

**Goal**: Verify sell price hook changes work independently

**Steps**:

1. Open Shop UI on "Sell" tab (have apples in inventory)
2. Keep Shop UI open
3. Execute in console:
   ```lua
   SHOPSB42.TestPriceHooksCommand.testappleSell(2.0)
   ```
4. **Expected**:
   - HaloNote appears: "Shop prices have changed."
   - Apple sell price doubles immediately in UI
   - Buy prices unchanged (independent)

### Scenario 7: Buy and Sell Independent

**Goal**: Verify buy and sell prices can differ

**Steps**:

1. Set buy price:
   ```lua
   SHOPSB42.TestPriceHooksCommand.testapple(2.0)
   ```
2. Set sell price:
   ```lua
   SHOPSB42.TestPriceHooksCommand.testappleSell(0.5)
   ```
3. **Expected**:
   - Buy price is 2.0x
   - Sell price is 0.5x
   - Both update independently

### Scenario 8: Disable Test Hooks

**Goal**: Return to normal pricing

**Steps**:

1. Execute in console:
   ```lua
   SHOPSB42.TestPriceHooksCommand.testappleReset()
   ```
2. **Expected**:
   - Apple returns to normal price (1.0x multiplier for both buy and sell)
   - HaloNote appears with price reset
   - Future price changes stop until re-enabled

---

## Test Hooks API

### `TestPriceHooks.initialize()`
Registers the test hook into the price system. Call once during server init.

### `TestPriceHooks.setAppleMultiplier(multiplier: number)`
Sets apple price multiplier and triggers immediate resync.

**Parameters**:
- `multiplier`: Price multiplier
  - `0.5` = half price
  - `1.0` = normal price
  - `2.0` = double price
  - `3.0` = triple price, etc.

**Example**:
```lua
TestPriceHooks.setAppleMultiplier(2.0)  -- Double the price
```

### `TestPriceHooks.disable()`
Disables test hook and resets to normal pricing. Triggers resync.

---

## Verification Checklist

- [ ] Scenario 1: UI open, visible row, immediate update (buy)
- [ ] Scenario 2: Multiple price changes work (buy)
- [ ] Scenario 3: Action blocked during price change (buy)
- [ ] Scenario 4: Hidden rows update on visibility (buy)
- [ ] Scenario 5: Silent update when UI closed
- [ ] Scenario 6: Sell price changes work independently
- [ ] Scenario 7: Buy and sell prices can differ
- [ ] Scenario 8: Test hooks can be disabled (buy and sell)
- [ ] HaloNote always appears when UI open
- [ ] No server errors in logs
- [ ] All clients receive price update
- [ ] Revision counter increments
- [ ] Buy hooks triggered correctly
- [ ] Sell hooks triggered correctly

---

## Debugging

### Check Revision Counter

```lua
print("Current revision: " .. SHOPSB42.Shop.PriceHookRevision)
```

### Check Test Hook State

```lua
local TestPriceHooks = require("nshopsb42/TestPriceHooks")
print("Enabled: " .. tostring(TestPriceHooks.enabled))
print("Multiplier: " .. TestPriceHooks.appleMultiplier)
```

### Check Modifiers

```lua
local modifiers = SHOPSB42.Shop.PriceModifiers
if modifiers and modifiers["Base.Apple"] then
	print("Apple modifier: " .. modifiers["Base.Apple"])
end
```

### Enable Debug Logging

Check `SharedLogger` output in console for detailed trace:
```
[ShopSyncClient] Price modifiers updated (revision: N)
[ShopSyncClient] onPriceHooksChanged() called
[ShopUI] Recalculating row price...
```

---

## Production Use

**⚠️ IMPORTANT**: Remove `TestPriceHooks` from production server init before release!

The test hooks file should only be used for development and QA testing.

---

## Notes

- Test hooks trigger revision increment and full resync
- Works with multiplayer (all online players see update)
- Debounce is 300ms by design
- Hidden rows marked dirty but never shown stale
- Server-only prices (requiresServer) show "~" indicator (existing behavior)

---

## Expected Log Output

When test hook is triggered, you should see:

```
[TestPriceHooks] Apple multiplier set to: 2.0
[TestPriceHooks] Price resync triggered
[ShopFinalizeHandler] Price modifiers resynced to all players (revision: 2)
[ShopSyncClient] Received SyncPriceModifiers
[ShopSyncClient] Price modifiers updated (revision: 2)
[ShopSyncClient] Price hook revision changed, triggering onPriceHooksChanged()
[ShopSyncClient] Price hook changed while Shop UI visible, reacting...
[ShopSyncClient] onPriceHooksChanged() complete
```

---

## Quick Test Command Reference

**Buy Price** (Food tab in Shop):

```lua
SHOPSB42.TestPriceHooksCommand.testapple(2.0)      -- Double buy price
SHOPSB42.TestPriceHooksCommand.testapple(0.5)      -- Half buy price
SHOPSB42.TestPriceHooksCommand.testapple(1.5)      -- 1.5x buy price
SHOPSB42.TestPriceHooksCommand.testapple(3.0)      -- Triple buy price
```

**Sell Price** (Sell tab in Shop):

```lua
SHOPSB42.TestPriceHooksCommand.testappleSell(2.0)      -- Double sell price
SHOPSB42.TestPriceHooksCommand.testappleSell(0.5)      -- Half sell price
SHOPSB42.TestPriceHooksCommand.testappleSell(1.5)      -- 1.5x sell price
SHOPSB42.TestPriceHooksCommand.testappleSell(3.0)      -- Triple sell price
```

**Reset Both**:

```lua
SHOPSB42.TestPriceHooksCommand.testappleReset()    -- Reset to normal (buy and sell)
```

**Using TestPriceHooks Directly** (equivalent):

```lua
local T = require("nshopsb42/TestPriceHooks")

-- Buy price
T.setAppleMultiplier(2.0)       -- Double buy price
T.setAppleMultiplier(0.5)       -- Half buy price

-- Sell price
T.setAppleSellMultiplier(2.0)   -- Double sell price
T.setAppleSellMultiplier(0.5)   -- Half sell price

-- Reset both
T.disable()

-- Check state
print("Enabled: " .. tostring(T.enabled))
print("Buy multiplier: " .. T.appleMultiplier)
print("Sell multiplier: " .. T.appleSellMultiplier)
```
