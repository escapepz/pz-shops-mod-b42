-- ModDataSchema.lua
-- Tracks deprecated and active ModData fields across schema versions
-- Extends SHOPSB42 namespace

local SharedLogger = require("nshopsb42/utils/SharedLogger")

SHOPSB42.ModDataSchema = SHOPSB42.ModDataSchema or {}
local Schema = SHOPSB42.ModDataSchema

-- Current schema version
Schema.version = 2

---
-- Deprecated fields (will be removed in future versions)
Schema.deprecated = {
	itemPrice = {
		version = 1,
		removedInVersion = 3,
		reason = "NPC prices now deterministic from NPCShopCatalog, player shop prices recomputed on transaction",
	},
	itemSpecialCoin = {
		version = 1,
		removedInVersion = 3,
		reason = "Moved to pricing contract",
	},
}

---
-- Active fields (currently in use)
Schema.active = {
	CoinBalance = {
		version = 1,
		description = "User wallet balances (mandatory)",
	},
	owner = {
		version = 1,
		description = "Player shop owner name",
	},
	VehicleID = {
		version = 1,
		description = "Vehicle item ID (for vehicle bundles)",
	},
}

---
-- Check if a field is deprecated
-- @param fieldName string - Field name to check
-- @return boolean - true if field is deprecated
function Schema.isDeprecated(fieldName)
	return Schema.deprecated[fieldName] ~= nil
end

---
-- Check if a field is active
-- @param fieldName string - Field name to check
-- @return boolean - true if field is active
function Schema.isActive(fieldName)
	return Schema.active[fieldName] ~= nil
end

---
-- Get deprecation info for a field
-- @param fieldName string
-- @return table|nil - { version, removedInVersion, reason } or nil
function Schema.getDeprecationInfo(fieldName)
	return Schema.deprecated[fieldName]
end

SharedLogger.log("Shops", "[ModDataSchema] Schema v" .. Schema.version .. " loaded")
return Schema
