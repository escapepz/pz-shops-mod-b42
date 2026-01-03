-- ShopsHooksExampleState.lua
-- Configuration state for ShopsHooksExample (server-only)
-- This module demonstrates safe configuration patterns for external mods
-- All variables here are safely accessed by hooks and can be updated at runtime
-- Extends SHOPSB42 namespace

SHOPSB42.ShopsHooksExampleState = SHOPSB42.ShopsHooksExampleState or {}
local State = SHOPSB42.ShopsHooksExampleState

-- ============================================================================
-- EXAMPLE 1: Buy Price Modifier Configuration
-- ============================================================================
-- Apple buy price multiplier
-- Demonstrates: Modifier hook pattern where multipliers stack with other mods
-- Type: number (0.0 = free, 1.0 = normal, 2.0 = double)
-- Default: 0.9 (10% discount on apples)
-- Safe: Yes, can be changed at runtime
-- Impact: Affects buy price of "Base.Apple" items
State.appleBuyMultiplier = 0.9

-- ============================================================================
-- EXAMPLE 2: Buy Price Override Configuration
-- ============================================================================
-- Apple buy price override (optional, for fixed pricing)
-- Demonstrates: Override hook pattern where fixed price bypasses all modifiers
-- Type: nil (disabled) or number (fixed price in shop dollars)
-- Default: nil (disabled - use calculated price from modifiers)
-- Safe: Yes, can be changed at runtime
-- Usage:
--   nil   = disabled, use modifier-calculated price
--   5     = force apple buy to exactly 5 (ignores modifiers)
--   10    = force apple buy to exactly 10
--   0     = apple cannot be bought
-- Impact: When set to a number, completely overrides appleBuyMultiplier
State.appleOverrideBuyPrice = nil

-- ============================================================================
-- EXAMPLE 3: Item Registration Configuration
-- ============================================================================
-- Item registration mode (whitelist vs blacklist)
-- Demonstrates: Shop.SellIsWhitelist safe variable
-- This is set in ShopsHooksExampleItems.configureListingMode()
-- Not stored here since it's set directly on Shop object
-- See: ShopsHooksExampleItems.ENABLE_WHITELIST_MODE = false

-- ============================================================================
-- Testing Notes
-- ============================================================================
-- To test runtime changes:
--   1. Change values here and restart server
--   2. Or use admin commands to modify at runtime:
--      SHOPSB42.ShopsHooksExampleState.appleBuyMultiplier = 0.5
--      SHOPSB42.ShopFinalizeHandler.onPriceHooksChanged()
--
-- Server log location: Logs/Server/*_Shops.txt
-- Client log location: Logs/Client/*_Shops.txt

return State
