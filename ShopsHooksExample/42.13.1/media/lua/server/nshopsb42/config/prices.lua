-- config/prices.lua
-- Price configuration for ShopsHooksExample
-- Defines buy/sell price multipliers and overrides

local Prices = {}

-- ============================================================================
-- EXAMPLE 1: Buy Price Modifier Configuration
-- ============================================================================
-- Apple buy price multiplier
-- Demonstrates: Modifier hook pattern where multipliers stack with other mods
-- Type: number (0.0 = free, 1.0 = normal, 2.0 = double)
-- Default: 0.9 (10% discount on apples)
-- Safe: Yes, can be changed at runtime
-- Impact: Affects buy price of "Base.Apple" items
Prices.appleBuyMultiplier = 0.9

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
Prices.appleOverrideBuyPrice = nil

return Prices
