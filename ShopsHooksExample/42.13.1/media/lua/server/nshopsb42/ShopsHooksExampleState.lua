-- ShopsHooksExampleState.lua
-- Configuration state for ShopsHooksExample (server-only)
-- This module demonstrates safe configuration patterns for external mods
-- All variables here are safely accessed by hooks and can be updated at runtime
-- Extends SHOPSB42 namespace
--
-- Configuration is organized modularly:
--   config/_index.lua - Registry and load order
--   config/prices.lua - Price multipliers and overrides
--   config/defaults.lua - Default values and behavior

SHOPSB42.ShopsHooksExampleState = SHOPSB42.ShopsHooksExampleState or {}
local State = SHOPSB42.ShopsHooksExampleState

-- Load all config modules from the config/ directory
local configIndex = require("nshopsb42/config/_index")
for _, configPath in ipairs(configIndex) do
	local configModule = require("nshopsb42/config/" .. configPath)
	for key, value in pairs(configModule) do
		State[key] = value
	end
end

-- ============================================================================
-- Testing Notes
-- ============================================================================
-- To test runtime changes:
--   1. Change values in config/ files and restart server
--   2. Or use admin commands to modify at runtime:
--      SHOPSB42.ShopsHooksExampleState.appleBuyMultiplier = 0.5
--      SHOPSB42.ShopFinalizeHandler.onPriceHooksChanged()
--
-- Server log location: Logs/Server/*_Shops.txt
-- Client log location: Logs/Client/*_Shops.txt

return State
