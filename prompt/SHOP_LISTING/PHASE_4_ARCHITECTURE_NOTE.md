# Phase 4: Architecture Correction Note

**Date**: 2025-01-06  
**Corrected**: Phase 4 approach simplified based on existing architecture

---

## Key Insight

The codebase **already has separate UI classes** for NPC and Player shops:

| Shop Type | UI Class | File |
|-----------|----------|------|
| **NPC** | ShopUI | `ShopUI.lua` |
| **Player** | PlayerShopUI | `PlayerShopUI.lua` |

This means **no routing logic is needed** — just integrate the listing services into each class.

---

## Phase 4 Corrected Architecture

### NPC Shops (ShopUI) — Already Complete ✅

```
ShopUI.lua:
  ├─ Imports: ClientShopListingService (Phase 3b)
  ├─ calcBuyPrice(): calls ClientShopListingService.calculatePreviewBuyPrice()
  ├─ calcSellPrice(): calls ClientShopListingService.calculatePreviewSellPrice()
  └─ Result: Zero network during listing + deterministic pricing
```

**Status**: Phase 3b ✅ DONE (no further changes needed)

### Player Shops (PlayerShopUI) — Phase 4 Task

```
PlayerShopUI.lua:
  ├─ Imports: PlayerShopListingService (NEW - Phase 4)
  ├─ calcBuyPrice(): calls PlayerShopListingService.calculatePreviewBuyPrice()
  ├─ calcSellPrice(): calls PlayerShopListingService.calculatePreviewSellPrice()
  └─ Result: Zero network during listing + deterministic pricing
```

**Status**: Phase 4 🔄 IN PROGRESS

---

## Phase 4 Deliverables (Simplified)

### 4a: Create PlayerShopListingService

New module identical in interface to ClientShopListingService but reads from player ModData:

```lua
-- PlayerShopListingService.lua
SHOPSB42.PlayerShopListingService = {
    initialize = function() ... end,
    calculatePreviewBuyPrice = function(itemId, playerId, basePrice, player) ... end,
    calculatePreviewSellPrice = function(itemId, playerId, basePrice, condition, player) ... end,
}
```

### 4b: Update PlayerShopUI

```lua
-- Add import at top
local PlayerShopListingService = require("nshopsb42/ui/PlayerShopListingService")

-- Update calcBuyPrice()
if PlayerShopListingService and PlayerShopListingService.calculatePreviewBuyPrice then
    return PlayerShopListingService.calculatePreviewBuyPrice(...)
end

-- Update calcSellPrice()
if PlayerShopListingService and PlayerShopListingService.calculatePreviewSellPrice then
    return PlayerShopListingService.calculatePreviewSellPrice(...)
end
```

### 4c: Update Client Init

```lua
-- AClientInit.lua
require("nshopsb42/ui/PlayerShopListingService")  -- After line 18

-- In onGameStart() (after line 90):
if SHOPSB42.PlayerShopListingService then
    SHOPSB42.PlayerShopListingService.initialize()
end
```

---

## Why This Architecture Works

1. **Separation**: NPC and Player shops are already separate UI classes
2. **Reuse**: Both use PricingContract for deterministic pricing
3. **Safety**: Server always re-reads/revalidates on transaction
4. **Clarity**: No complex routing logic
5. **Extensibility**: Can optimize each path independently later

---

## Timeline

- **Phase 3b**: ✅ NPC shops complete (ClientShopListingService)
- **Phase 4**: 🔄 Player shops (PlayerShopListingService)
- **Phase 5**: ⏳ Determinism validator
- **Phase 6**: ⏳ Migration & testing
- **Phase 7**: ⏳ Documentation & rollout

---

## No Routing Needed

Original (incorrect) approach:
```
Single calcBuyPrice() with routing logic:
  if shop == NPC:
    use ClientShopListingService
  else if shop == Player:
    use PlayerShopListingService
```

Correct approach:
```
NPC ShopUI.calcBuyPrice() → ClientShopListingService
Player PlayerShopUI.calcBuyPrice() → PlayerShopListingService
```

Each class handles its own UI logic — simpler and cleaner!

