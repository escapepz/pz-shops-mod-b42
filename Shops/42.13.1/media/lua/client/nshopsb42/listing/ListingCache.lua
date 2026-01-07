-- ListingCache.lua (Client-side)
-- Handles persistent disk caching of SyncShopData listings
-- Persists to: ~/.../Zomboid/Lua/shops/listing_snapshot_<serverId>.lua
-- Format: Lua table source (human-readable, no external deps)

local SharedLogger = require("nshopsb42/utils/SharedLogger")

local ListingCache = {}

-- =============================================================================
-- SERIALIZATION: Lua Table -> Source Code
-- =============================================================================

-- Escape string values for safe source code representation
local function escapeString(s)
	-- Use string.format with %q to safely quote strings
	return string.format("%q", s)
end

-- Recursively serialize a table to Lua source code with indentation
local function serializeTable(tbl, indent)
	indent = indent or 0
	local indentStr = string.rep("\t", indent)
	local nextIndentStr = string.rep("\t", indent + 1)

	local lines = {}
	table.insert(lines, "{")

	for k, v in pairs(tbl) do
		local keyStr
		-- Handle string keys (item IDs like "Base.Apple")
		if type(k) == "string" then
			keyStr = "[" .. escapeString(k) .. "]"
		else
			keyStr = "[" .. tostring(k) .. "]"
		end

		local valueStr
		if type(v) == "string" then
			valueStr = escapeString(v)
		elseif type(v) == "number" then
			valueStr = tostring(v)
		elseif type(v) == "boolean" then
			valueStr = v and "true" or "false"
		elseif type(v) == "table" then
			-- Recursively serialize nested tables
			valueStr = serializeTable(v, indent + 1)
		else
			-- Fallback for other types (functions, userdata, etc.) - skip
			valueStr = nil
		end

		if valueStr then
			table.insert(lines, nextIndentStr .. keyStr .. " = " .. valueStr .. ",")
		end
	end

	table.insert(lines, indentStr .. "}")
	return table.concat(lines, "\n")
end

-- =============================================================================
-- DESERIALIZATION: Lua Source Code -> Table
-- =============================================================================

-- Safely load a Lua table from a file using dofile
-- Returns: table on success, nil on failure
local function deserializeFromFile(filePath)
	if not dofile then
		SharedLogger.log("Shops", "[ListingCache.deserializeFromFile] dofile is not available")
		return nil
	end

	local success, result = pcall(function()
		return dofile(filePath)
	end)

	if not success then
		-- File doesn't exist or failed to load - this is normal for first run
		return nil
	end

	if type(result) ~= "table" then
		SharedLogger.log("Shops", "[ListingCache.deserializeFromFile] File did not return a table: " .. filePath)
		return nil
	end

	return result
end

-- =============================================================================
-- FILE I/O
-- =============================================================================

-- Get cache file path for a specific server
-- File stored in: ~/.../Zomboid/Lua/nshopsb42/listing_snapshot_<serverId>.lua
-- @param serverId: Stable server UUID from ModData
-- @return string: File path for cache snapshot
local function getCacheFilePath(serverId)
	assert(serverId, "[ListingCache] serverId is required (server UUID must be transmitted)")

	-- Use safe server ID (alphanumeric + underscore + dash + colon for UUID format)
	local safeId = string.gsub(serverId, "[^%w_:-]", "_")
	return "nshopsb42/listing_snapshot_" .. safeId .. ".lua"
end

-- Write listing snapshot to disk
-- Returns: true on success, false on failure
function ListingCache.saveSnapshot(snapshot, serverId)
	if not snapshot then
		SharedLogger.log("Shops", "[ListingCache.saveSnapshot] snapshot is nil, aborting")
		return false
	end

	if not serverId then
		SharedLogger.log("Shops", "[ListingCache.saveSnapshot] serverId is nil, aborting")
		return false
	end

	-- Phase 2.5: Enforce snapshot monotonicity
	-- Never overwrite a newer cache with an older revision
	local existingCache = ListingCache.loadSnapshot(serverId)
	if existingCache and existingCache.revision then
		local incomingRevision = snapshot.revision or 0
		if incomingRevision < existingCache.revision then
			SharedLogger.log(
				"Shops",
				"[ListingCache.saveSnapshot] WARN: Rejecting downgrade (incoming="
					.. incomingRevision
					.. " existing="
					.. existingCache.revision
					.. ")"
			)
			return false
		end
	end

	local filePath = getCacheFilePath(serverId)
	local serialized = "return " .. serializeTable(snapshot)

	local success, err = pcall(function()
		local writer = getFileWriter(filePath, false, false)
		if not writer then
			error("getFileWriter returned nil for " .. filePath)
		end
		writer:write(serialized)
		writer:close()
	end)

	if not success then
		SharedLogger.log("Shops", "[ListingCache.saveSnapshot] Failed to save to " .. filePath .. ": " .. tostring(err))
		return false
	end

	SharedLogger.log(
		"Shops",
		"[ListingCache.saveSnapshot] Saved revision " .. (snapshot.revision or 0) .. " to " .. filePath
	)
	return true
end

-- Load listing snapshot from disk
-- Returns: table on success, nil if file doesn't exist or is invalid
function ListingCache.loadSnapshot(serverId)
	if not serverId then
		return nil
	end

	local filePath = getCacheFilePath(serverId)
	if not filePath then
		return nil
	end

	local snapshot = deserializeFromFile(filePath)

	if snapshot then
		SharedLogger.log(
			"Shops",
			"[ListingCache.loadSnapshot] Loaded revision " .. (snapshot.revision or 0) .. " from " .. filePath
		)
	else
		SharedLogger.log("Shops", "[ListingCache.loadSnapshot] No cache found at " .. filePath)
	end

	return snapshot
end

-- =============================================================================
-- CACHE MANAGEMENT
-- =============================================================================

-- Check if cached snapshot exists for server
function ListingCache.hasCached(serverId)
	local filePath = getCacheFilePath(serverId)
	return deserializeFromFile(filePath) ~= nil
end

-- Get cached snapshot's revision (or 0 if no cache)
function ListingCache.getCachedRevision(serverId)
	local snapshot = ListingCache.loadSnapshot(serverId)
	return snapshot and snapshot.revision or 0
end

-- Validate snapshot structure (has required fields)
function ListingCache.isValidSnapshot(snapshot)
	if type(snapshot) ~= "table" then
		return false
	end

	-- Required fields for a valid listing snapshot
	if not snapshot.revision or type(snapshot.revision) ~= "number" then
		return false
	end

	if not snapshot.Items or type(snapshot.Items) ~= "table" then
		return false
	end

	if not snapshot.PlayerBuy or type(snapshot.PlayerBuy) ~= "table" then
		return false
	end

	if not snapshot.PlayerSell or type(snapshot.PlayerSell) ~= "table" then
		return false
	end

	return true
end

return ListingCache
