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
-- EXAMPLE 3: Sell Item Default Prices (Blacklist Mode)
-- ============================================================================
-- Default sell prices for unregistered items in blacklist mode
-- Demonstrates: Shop.defaultPrice and Shop.defaultPriceBroken safe variables
-- Type: number (what shop pays for unregistered items)
-- Default: 1 (minimal value)
-- Safe: Yes, can be changed at runtime
-- Usage:
--   defaultPrice = 50        -- Unregistered items sell for 50
--   defaultPriceBroken = 25  -- Broken unregistered items sell for 25
-- Impact: Only applies in blacklist mode (Shop.SellIsWhitelist = false)
-- Note: Set these before item registration or use runtime update with onPriceHooksChanged()
State.defaultPrice = 50
State.defaultPriceBroken = 25 -- WIP - still visual looking only

-- ============================================================================
-- EXAMPLE 4: Suppress Default Vanilla Items
-- ============================================================================
-- Prevent Shops mod from loading vanilla items
-- Demonstrates: Shop._suppressDefaults safe variable
-- Type: boolean (true = skip vanilla items, false = load vanilla items)
-- Default: false (vanilla items load normally)
-- Safe: Yes, set before initialization
-- Usage:
--   _suppressDefaults = true   -- Only custom mod items appear
--   _suppressDefaults = false  -- Vanilla + custom items
-- Impact: Must be set BEFORE item registration hooks fire
-- Warning: Setting true means only items registered by external mods will appear
State._suppressDefaults = true

-- ============================================================================
-- EXAMPLE 5: Sell Listing Mode (Whitelist vs Blacklist)
-- ============================================================================
-- Shop sell mode configuration
-- Demonstrates: Shop.SellIsWhitelist safe variable
-- Type: boolean (true = whitelist, false = blacklist)
-- Default: false (blacklist mode)
-- Safe: Yes, can be changed at runtime
--
-- WHERE IT'S USED:
-- This setting is APPLIED in: ShopsHooksExampleItems.configureListingMode()
-- This setting is CONTROLLED by: ShopsHooksExampleItems.ENABLE_WHITELIST_MODE variable
--
-- TO ENABLE WHITELIST MODE:
-- 1. Edit: ShopsHooksExampleItems.lua
-- 2. Find: local ENABLE_WHITELIST_MODE = false
-- 3. Change to: local ENABLE_WHITELIST_MODE = true
-- 4. Restart server
--
-- VALUES:
--   false = BLACKLIST mode (default) - all items sellable except blacklisted
--   true = WHITELIST mode - only registered items sellable
--
-- See: ShopsHooksExampleItems.lua:configureListingMode() function

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
