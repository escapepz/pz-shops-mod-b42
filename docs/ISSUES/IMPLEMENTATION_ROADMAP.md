# Implementation Roadmap - B42 MP Contract Compliance

## Status: VALIDATED & APPROVED

Per BUILD_FIX.md review - all 6 changes are correct, complete, and necessary. No gaps in logic.

---

## Critical Implementation Requirements (Non-Optional)

### ✅ AddTileObject() vs AddSpecialObject()
**Standardize on `AddTileObject()`**
- Proper indexing for persistence
- Save/load reliability  
- Correct chunk replication
- Used in both ISAddPlayerShopAction and ISAddShopAction

### ✅ transmitCompleteItemToClients() Is Mandatory
**Call immediately after `square:AddTileObject(shop)`**
- Without it: invisible objects, relog loss, silent desync
- No exceptions for admin/SP modes
- Both action classes must include this call

### ✅ Dual Validation Strategy
**Validation in TWO places is intentional:**
| Layer | Purpose | Method |
|-------|---------|--------|
| Cursor `isValid()` | UX feedback | Instant visual response |
| Action `complete()` | Authority & security | Server anti-cheat guardrail |

Never rely on cursor-only validation.

---

## Implementation Sequence

### Phase 1: Create New Timed Actions (Server)
- [ ] Create `Shops/42.13.1/media/lua/server/nshopsb42/actions/ISAddPlayerShopAction.lua`
- [ ] Create `Shops/42.13.1/media/lua/server/nshopsb42/actions/ISAddShopAction.lua`
- [ ] Verify both require shared classes and inherit from ISBuildAction
- [ ] Test: both actions exist and compile without errors

### Phase 2: Modify Client Context Layer
- [ ] Modify `PlayerShopContext.lua` - override `cursor.tryBuild()` to queue ISAddPlayerShopAction
- [ ] Modify `ShopContext.lua` - override `cursor.tryBuild()` to queue ISAddShopAction
- [ ] Ensure both pass sprite, coordinates, ownership flags to action constructors
- [ ] Test: context menus appear, cursor shows, no direct creation

### Phase 3: Deprecate Old Cursor Logic
- [ ] Modify `ShopSpriteCursorUI.lua` - make `tryBuild()` empty or error
- [ ] Modify `ShopSpriteCursor.lua` - stub out `create()` with deprecation warning
- [ ] Keep both methods for backward compatibility (add comments)
- [ ] Test: cursor renders but does not create objects

### Phase 4: Verify Cleanup
- [ ] Search codebase for remaining `sendClientCommand("PS", "PlacePlayerShop"...)`
- [ ] Search for remaining `sendClientCommand("Shop", "PlaceAdminShop"...)`
- [ ] All occurrences should be removed or replaced
- [ ] Verify no server-side handlers for those commands still exist

### Phase 5: Testing (Singleplayer First)
- [ ] Load mod in SP
- [ ] Test Player Shop placement: right-click → drag → click
  - Should queue action with animation
  - Object should appear on map
  - Item should be consumed from inventory
- [ ] Test Admin Shop placement: same flow
- [ ] Verify logs show `complete()` execution, not `ShopSpriteCursor:create()`

### Phase 6: Testing (Multiplayer)
- [ ] Load mod in MP with 2+ players
- [ ] Player 1: Place player shop
  - Verify Player 2 sees it immediately (transmitCompleteItemToClients)
  - Verify Player 1 inventory shows removal
  - Verify Player 2 sees correct ownership in mod data
- [ ] Admin: Place shop
  - Verify all players see it
  - Verify no item consumed (admin shops)
- [ ] Disconnect/reconnect: verify shops persist

### Phase 7: Edge Case Testing
- [ ] Try placing while inventory full → action should fail gracefully
- [ ] Try placing on occupied square → cursor should show invalid, action should validate
- [ ] Try placing during lag spike → verify no duplication
- [ ] Try canceling action mid-animation → verify cleanup

---

## Required Code Blocks (Reference)

### In ISAddPlayerShopAction:complete()
```lua
-- CRITICAL: Must appear in this order
square:AddTileObject(shop)
shop:transmitCompleteItemToClients()

player:getInventory():Remove(item)
sendRemoveItemFromContainer(player:getInventory(), item)
```

### In ISAddShopAction:complete()
```lua
square:AddTileObject(shop)
shop:transmitCompleteItemToClients()
-- No inventory removal (admin shops)
```

### In PlayerShopContext.addPlayerShop()
```lua
cursor.tryBuild = function(self)
    local action = ISAddPlayerShopAction:new(
        player,
        square,
        spriteName,
        self.north or false,
        true,  -- isPlayerShop
        isFreezer or false
    )
    ISTimedActionQueue.add(action)
    getWorld():getCell():setDrag(nil, 0)
end
```

### In ShopContext.addShop()
```lua
cursor.tryBuild = function(self)
    local action = ISAddShopAction:new(
        player,
        square,
        spriteName,
        self.north or false
    )
    ISTimedActionQueue.add(action)
    getWorld():getCell():setDrag(nil, 0)
end
```

---

## Expected Behavior After Implementation

| Aspect | Before | After |
|--------|--------|-------|
| Object creation location | Click-time, cursor context | `complete()`, server authority |
| Animation | None | Full ISBuildAction progress bar |
| Inventory sync | Separate command, race condition | Atomic with object creation |
| MP persistence | Unreliable (no transmitComplete) | Reliable (explicit sync call) |
| Admin bypass | Partial (sendClientCommand) | None (same pipeline as player) |
| Validation layers | Single (cursor only) | Dual (cursor + complete) |
| B42 compliance | ❌ Violated | ✅ Full compliance |

---

## Files Modified Summary

| File | Type | Lines Changed | Notes |
|------|------|---|---|
| ISAddPlayerShopAction.lua | CREATE | ~100 | New server action |
| ISAddShopAction.lua | CREATE | ~80 | New admin action |
| PlayerShopContext.lua | MODIFY | ~20 | Override tryBuild |
| ShopContext.lua | MODIFY | ~20 | Override tryBuild |
| ShopSpriteCursorUI.lua | MODIFY | ~5 | Stub tryBuild/create |
| ShopSpriteCursor.lua | MODIFY | ~5 | Add deprecation warning |

**Total: 2 new files, 4 modified files**

---

## Rollback Strategy (If Needed)

If critical issue discovered during testing:
1. Revert to git commit before Phase 1
2. Root cause analysis in BUILD_FIX.md context
3. Re-implement with identified fixes

No partial rollback recommended - refactor is atomic.

---

## Sign-Off

**Architecture:** ✅ Valid, complete, B42-compliant
**Logic:** ✅ No gaps, dual validation correct
**Edge Cases:** ✅ Identified and documented
**Testing Plan:** ✅ Sequence defined (SP → MP → edge cases)

Ready for implementation.
