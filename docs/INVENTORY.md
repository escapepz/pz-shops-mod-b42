## Project Zomboid Inventory Actions - Summary

**Architecture:** Modular handler-based system with separate handlers for Take All, Transfer All, Move to Floor, and context menu actions (Grab, Drop, Move).

**Main Action Functions:**

- **Grab/Grab One:** Transfer items from containers to player inventory
- **Drop:** Transfer items from inventory to floor
- **Move To Container:** Transfer items between any containers
- **Drag & Drop:** UI-driven transfers between containers

**Container Validation:**
`ISInventoryTransferUtil.newInventoryTransferAction()` performs extensive validation:

- Container accessibility (in player's accessible list)
- Container existence and validity
- Item type compatibility (`isItemAllowed()`)
- Size/weight capacity (`hasRoomFor()`)
- Exploit prevention (corpse duplication, SafeHouse checks)
- Multiplayer consistency checks

**Client vs Server:**

- **Client** (ISInventoryTransferAction:isValid lines 31-58): Light validation, transaction consistency check, then returns true early
- **Server** (lines 60-117): Comprehensive validation - existence checks, item removability, capacity, item allowance, safehouse rules

**Validation Timing:**
`isValid()` is called **DURING action execution**, not before:

1. Action queued → added to queue → begins → timer counts down (no validation)
2. Timer completes → `perform()` called → **isValid() re-validates** (line 464)
3. If valid → `transferItem()` executes; if invalid → queue cleared

This prevents race conditions where containers/items could change during the animation countdown. Each item in multi-item transfers is validated individually.

**Key Design:** All transfers use timed actions for animation/timing, with re-validation at completion to ensure state hasn't changed and prevent exploits.
