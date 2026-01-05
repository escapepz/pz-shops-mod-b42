-- LazyMigration.lua
-- Lazy-migrates save files from old ModData schema (prices in items) to new schema (deterministic pricing)
-- Runs on-demand when items/players are accessed, not on server init
-- Extends SHOPSB42 namespace

local SharedLogger = require("nshopsb42/utils/SharedLogger")

if not isServer() then
	return
end

SHOPSB42.LazyMigration = SHOPSB42.LazyMigration or {}
local Migration = SHOPSB42.LazyMigration

-- Track which items have been migrated this session (avoid repeated logging)
Migration.migratedItems = Migration.migratedItems or {}

-- Migration statistics (for admin reporting)
Migration.migrationStats = Migration.migrationStats or {
	itemsMigrated = 0,
	pricesDiscarded = 0,
	sessions = 0,
}

---
-- Migrate item ModData from old schema to new
-- Called when item is accessed (player shop, player inventory)
-- Does nothing if item has no deprecated fields
--
-- @param item isa InventoryItem - Item to migrate
-- @return boolean - true if migration happened
function Migration.migrateItemIfNeeded(item)
	if not item then
		return false
	end

	local itemId = item:getID()
	if not itemId then
		return false
	end

	-- Skip if already migrated this session
	if Migration.migratedItems[itemId] then
		return false
	end

	local modData = item:getModData()
	if not modData then
		return false
	end

	-- Check for deprecated fields
	local hadOldPrice = modData.price ~= nil
	local hadOldSpecialCoin = modData.specialCoin ~= nil

	if hadOldPrice or hadOldSpecialCoin then
		-- Log the migration
		SharedLogger.log(
			"Shops",
			"[LazyMigration] Migrating item "
				.. item:getType()
				.. " (ID="
				.. itemId
				.. "): price="
				.. tostring(modData.price)
				.. ", specialCoin="
				.. tostring(modData.specialCoin)
		)

		-- Store in migration history (for audit)
		Migration.migratedItems[itemId] = {
			type = item:getType(),
			oldPrice = modData.price,
			oldSpecialCoin = modData.specialCoin,
			timestamp = getTimestampMs(),
		}

		-- DELETE OLD FIELDS (critical - prevents re-use of stale prices)
		modData.price = nil
		modData.specialCoin = nil

		-- Update statistics
		Migration.migrationStats.itemsMigrated = Migration.migrationStats.itemsMigrated + 1
		if hadOldPrice then
			Migration.migrationStats.pricesDiscarded = Migration.migrationStats.pricesDiscarded + 1
		end

		return true
	end

	return false
end

---
-- Migrate all items in a player's inventory
-- Called when player enters world or accesses player shop
--
-- @param player isa IsoPlayer - Player to migrate
function Migration.migratePlayerInventory(player)
	if not player then
		return
	end

	local inventory = player:getInventory()
	if not inventory then
		return
	end

	local items = inventory:getItems()
	if not items then
		return
	end

	local migratedCount = 0
	for i = 0, items:size() - 1 do
		local item = items:get(i)
		if Migration.migrateItemIfNeeded(item) then
			migratedCount = migratedCount + 1
		end
	end

	if migratedCount > 0 then
		SharedLogger.log(
			"Shops",
			"[LazyMigration] Migrated " .. migratedCount .. " items in inventory for player " .. player:getUsername()
		)
	end
end

---
-- Migrate all items in a specific container (player shop shelf, etc.)
-- Called when container is accessed
--
-- @param container isa ItemContainer - Container to migrate
function Migration.migrateContainer(container)
	if not container then
		return
	end

	local items = container:getItems()
	if not items then
		return
	end

	local migratedCount = 0
	for i = 0, items:size() - 1 do
		local item = items:get(i)
		if Migration.migrateItemIfNeeded(item) then
			migratedCount = migratedCount + 1
		end
	end

	if migratedCount > 0 then
		SharedLogger.log("Shops", "[LazyMigration] Migrated " .. migratedCount .. " items in container")
	end
end

---
-- Get migration statistics
-- Used by admin commands to check migration progress
--
-- @return table - { itemsMigrated, pricesDiscarded, sessions }
function Migration.getStats()
	return copyTable(Migration.migrationStats)
end

---
-- Report migration statistics to log
function Migration.reportStats()
	local stats = Migration.getStats()
	SharedLogger.log(
		"Shops",
		"[LazyMigration] Statistics: "
			.. "items="
			.. stats.itemsMigrated
			.. " prices_discarded="
			.. stats.pricesDiscarded
			.. " sessions="
			.. stats.sessions
	)
end

---
-- Reset statistics (for testing)
function Migration.resetStats()
	Migration.migrationStats = {
		itemsMigrated = 0,
		pricesDiscarded = 0,
		sessions = 0,
	}
	Migration.migratedItems = {}
end

SharedLogger.log("Shops", "[LazyMigration] Module loaded (on-demand migration)")
return Migration
