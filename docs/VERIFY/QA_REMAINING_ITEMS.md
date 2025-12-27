# QA Verification Checklist - Remaining 12 Items

**Date**: 2025-12-27  
**Status**: Ready for QA testing  
**Estimated Time**: 2-4 hours

---

## A. Currency System

### A3. Admin Tests - Log Verification

- [ ] Check server logs for "rollback" messages during currency operations
- [ ] Verify no "desync" warnings appear in logs
- [ ] Confirm transaction audit entries show correct old/new balance
- [ ] Verify log format matches expected pattern: `VirtualDeposit: username (source) oldBalance: Coin: X SpecialCoin Y newBalance: Coin: A SpecialCoin B`

**Log File Location**: `<PZ_Server_Logs>/Shops_economy.log` or default PZ log system

---

## B. Kiosk Shop Tests

### B1. Player Tests - Car Viewer

- [ ] Create/find a vehicle pinkslip item (Vehicle ID assigned)
- [ ] Add pinkslip to kiosk shop cart
- [ ] Verify "preview" button appears in cart
- [ ] Click preview button → vehicle preview UI opens
- [ ] Verify vehicle renders correctly in preview
- [ ] Close preview → back to shop UI

**Expected Files**: `PreviewUI.lua` handles vehicle preview

---

## C. Player Shop Tests

### C1. Owner Tests - Crafting

#### Crafting Recipe

- [ ] Locate Carpentry recipe tab in crafting menu
- [ ] Verify "Player Shop" item appears in recipe list
- [ ] Verify recipe requirements (materials, skill level)
- [ ] Craft Player Shop item successfully
- [ ] Item appears in inventory with proper name/icon

**Expected Result**: Player Shop item available to place

---

### C1. Owner Tests - Write Tag

#### Write Tag Requirement

- [x] Place Player Shop in world
- [x] Try to set price on item WITHOUT "Write" tag
  - **Current behavior**: UI allows price setting on any item
  - **Expected behavior (per checklist)**: Should require Write tag
- [x] Result: Either UI blocks, or price setting fails silently
- [x] If Write tag is required: Get item with Write tag, set price succeeds

**Note**: Code inspection shows no tag enforcement - may be intended feature gap

---

### C1. Owner Tests - Transfer Mechanics

#### Container Transfer

- [x] Place Player Shop in world
- [x] Open shop container (right-click → Manage)
- [x] Drag items from player inventory into shop container
- [x] Verify item appears in shop container UI
- [x] Close and reopen shop → item still present
- [x] Set price on transferred item
- [x] Verify item appears in Customer view of shop

**Expected**: Drag-drop mechanics standard PZ behavior

---

### C1. Owner Tests - Container Traits

#### Organized/Disorganized Effects

- [ ] Note Player Shop container type (standard, freezer)
- [ ] Add items until capacity approaches limit
- [ ] Observe actual capacity (should be ~100 units)
- [ ] Check if container has Organized or Disorganized traits
- [ ] If traits applied: Verify capacity changes by trait percentage
- [ ] If no traits: Confirm capacity stays at base (100)

**Expected**: Traits follow standard PZ container behavior

---

### C1. Owner Tests - Ownership Rules

#### Item Removal Restriction

- [ ] Place Player Shop as Player A
- [ ] Have Player B browse the shop
- [ ] Player B tries to extract items from container view
- [ ] **Expected**: B cannot remove items (ownership lock)
- [ ] Player A removes items from same container
- [ ] **Expected**: A can remove any item

**Mechanism**: Container lock (setLockedByPadlock) or ownership check

---

### C1. Owner Tests - Sign Options

#### All 10 Sprite Variations

- [ ] Place Player Shop
- [ ] Right-click shop → "Change Sign" option
- [ ] Verify menu shows all 10 sign options:
  - [ ] NoSign (0, 1)
  - [ ] FirstAid (2, 3)
  - [ ] Food (4, 5)
  - [ ] Melee (6, 7)
  - [ ] Guns (8, 9)
  - [ ] Ammo (16, 17)
  - [ ] Furniture (10, 11)
  - [ ] Materials (12, 13)
  - [ ] Misc (14, 15)
  - [ ] Freezer (20, 21)
- [ ] Select each option → sprite changes on shop tile
- [ ] Close and reopen world → sprite persists

**Code Reference**: `PlayerShop.lua` lines 9-54 defines all sprites

---

### C2. Customer Tests - Remove Restriction

#### Container Lock Enforcement

- [ ] Place Player Shop as Player A
- [ ] Lock shop container (right-click → Lock)
- [ ] Have Player B open shop UI
- [ ] Player B tries to drag items from shop container to inventory
- [ ] **Expected**: B cannot remove items while locked
- [ ] Player A unlocks container
- [ ] Player B tries again → **Expected**: Can now remove items

**Mechanism**: Standard PZ padlock prevents unauthorized access

---

### C1/C2. Income Deposit

#### Virtual Balance Credit for Seller

- [ ] Place Player Shop as Player A with 0 balance
- [ ] Have Player B purchase item from shop (50 coins)
- [ ] Check Player A's account balance
- [ ] **Expected**: A's balance increases by 50 coins
- [ ] Open Income UI on shop
- [ ] **Expected**: Income entry shows "Player B, 50 coins"
- [ ] Select income entry → "Get Income" button
- [ ] Click "Get Income"
- [ ] Check Player A's balance again
- [ ] **Expected**: Income transferred to linked account

**Code Reference**: `IncomeUI.lua` shows entries, deposit mechanism in purchase action

---

### C1. Owner Tests - Duplication Safety

#### Crash/Reconnect Safety

1. **Setup**:
   - [ ] Place Player Shop with items inside
   - [ ] Have customer purchasing item
   - [ ] During purchase transaction, kill server process
2. **Verification**:
   - [ ] Restart server
   - [ ] Check player's inventory → **Expected**: Transaction rolled back OR completed consistently
   - [ ] Check shop contents → **Expected**: Item count matches expected state
   - [ ] Check seller's balance → **Expected**: No duplication of payment
   - [ ] **Expected Outcome**: No items duplicated, transaction either rolled back or completed atomically

**Notes**: This is an edge case - PZ engine handles much of this via container sync

---

## E. Hooks System

### Hook Testing - Performance

#### Large Hook Count Performance

1. **Setup**:

   - [ ] Register 50+ price modification hooks (programmatically or test mod)
   - [ ] Each hook adds dummy modifier

2. **Test**:

   - [ ] Open kiosk shop
   - [ ] Browse items (triggers price calculation hooks)
   - [ ] **Measure**: Frame rate, purchase completion time
   - [ ] Expected: No significant lag (<50ms per item)
   - [ ] Open item with 10+ pack items
   - [ ] **Measure**: Shop open time with 50 hooks registered
   - [ ] Expected: Responsive UI (<200ms latency)

3. **Results**:
   - [ ] Hook iteration completes in <5ms
   - [ ] No noticeable FPS drops
   - [ ] Shop UI remains responsive

**Technical Note**: Linear O(n) performance expected for hook iteration

---

## Testing Guidelines

### Before You Start

1. Create clean test world (fresh save)
2. Set up 2-3 test players
3. Enable server logging to file
4. Note starting timestamps for log correlation

### During Testing

1. Record exact steps taken
2. Note any errors or warnings in console
3. Screenshot any UI anomalies
4. Record timing for performance tests

### After Testing

1. Export relevant log sections
2. Verify no unexplained errors in logs
3. Summarize any issues found
4. Note which features appear working vs. issues

### Success Criteria

- [ ] All 12 items tested
- [ ] No critical issues found
- [ ] Performance acceptable
- [ ] All changes properly synced in MP
- [ ] Logs show no unexpected errors

---

## Estimated Timeline

| Test Group            | Time        | Priority |
| --------------------- | ----------- | -------- |
| Currency Logs         | 15 min      | HIGH     |
| Kiosk Car Viewer      | 10 min      | MEDIUM   |
| Player Shop Crafting  | 10 min      | HIGH     |
| Player Shop Ownership | 20 min      | HIGH     |
| Player Shop Signs     | 15 min      | MEDIUM   |
| Player Shop Income    | 20 min      | HIGH     |
| Concurrency/Safety    | 30 min      | HIGH     |
| Hook Performance      | 20 min      | MEDIUM   |
| **TOTAL**             | **140 min** |          |

---

## Rollback/Contingency

If any critical issues found:

1. Document exact reproduction steps
2. Provide relevant log excerpts
3. Include screenshot if UI-related
4. Note game version and build date

For minor issues: Log for post-release patch consideration
For critical issues: Escalate to development for code review

---

## Sign-Off

QA Tester: **\*\***\_\_\_\_**\*\***  
Date Completed: **\*\***\_\_\_\_**\*\***  
All Items Passed: ☐ Yes ☐ No (note issues below)

**Issues Found**:
(none if all passed)

---
