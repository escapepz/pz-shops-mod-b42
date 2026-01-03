-- config/defaults.lua
-- Default values and behavior configuration for ShopsHooksExample

local Defaults = {}

-- ============================================================================
-- EXAMPLE 1: Sell Item Default Prices (Blacklist Mode)
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
Defaults.defaultPrice = 50
Defaults.defaultPriceBroken = 25 -- WIP - still visual looking only

-- ============================================================================
-- EXAMPLE 2: Suppress Default Vanilla Items
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
Defaults._suppressDefaults = true

-- ============================================================================
-- EXAMPLE 3: Sell Listing Mode (Whitelist vs Blacklist)
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
Defaults.SellIsWhitelist = false

return Defaults
