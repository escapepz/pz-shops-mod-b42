-- ShopsHooksExampleState.lua
-- Configuration and state for ShopsHooksExample (server-only)
-- Extends SHOPSB42 namespace

SHOPSB42.ShopsHooksExampleState = SHOPSB42.ShopsHooksExampleState or {}
local State = SHOPSB42.ShopsHooksExampleState

-- Apple buy price multiplier
-- Default: 0.9 = 10% discount for fruit category
-- This demonstrates modifier hook pattern: multipliers stack with other modifiers
-- If you change this at runtime, you MUST call:
--   SHOPSB42.ShopFinalizeHandler.onPriceHooksChanged()
-- to invalidate price caches and trigger client resync
State.appleBuyMultiplier = 0.9

-- Apple buy price override (optional)
-- nil = disabled (use calculated price from modifiers)
-- numeric value = force apple buy price to this value (short-circuits modifiers)
-- Example: Set to 5 to force apple buy price to exactly 5 regardless of multipliers
-- This demonstrates override hook pattern: returns final price or nil
State.appleOverrideBuyPrice = nil

return State
