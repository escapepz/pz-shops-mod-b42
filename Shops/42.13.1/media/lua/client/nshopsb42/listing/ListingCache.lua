-- ListingCache.lua (Client-side)
-- Handles persistent disk caching of SyncShopData listings
-- Persists to: ~/.../Zomboid/Lua/nshopsb42/listing_snapshot_<serverId>.lua
-- Format: Manual string serialization (no JSON library, avoids Kahlua edge cases)

local SharedLogger = require("nshopsb42/utils/SharedLogger")

local ListingCache = {}

-- =============================================================================
-- FILE I/O
-- =============================================================================

-- Get cache file path for a specific server
-- File stored in: ~/.../Zomboid/Lua/nshopsb42/listing_snapshot_<serverId>.json
-- @param serverId: Stable server UUID from ModData
-- @return string: File path for cache snapshot
local function getCacheFilePath(serverId)
	assert(serverId, "[ListingCache] serverId is required (server UUID must be transmitted)")

	-- Use safe server ID (alphanumeric + underscore + dash + colon for UUID format)
	local safeId = string.gsub(serverId, "[^%w_:-]", "_")
	return "nshopsb42/listing_snapshot_" .. safeId .. ".lua"
end

-- =============================================================================
-- SAVE: Manual string serialization (no JSON library)
-- =============================================================================

-- Write listing snapshot to disk using manual string serialization
-- Format: Lua table literal (safe for Kahlua, no encoder bugs)
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
	local existingCache = ListingCache.loadSnapshot(serverId)
	---@diagnostic disable-next-line: unnecessary-if
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
	local revision = tonumber(snapshot.revision) or 0
	local defaultPrice = tonumber(snapshot.defaultPrice) or 10
	local defaultPriceBroken = tonumber(snapshot.defaultPriceBroken) or 5
	local buyWhitelist = snapshot.BuyIsWhitelist == true
	local sellWhitelist = snapshot.SellIsWhitelist == true

	local success, err = pcall(function()
		local writer = getFileWriter(filePath, true, false)
		if not writer then
			error("getFileWriter returned nil for " .. filePath)
		end

		-- Write header
		writer:write(
			string.format(
				"return{schema=4,revision=%d,defaults={price=%d,broken=%d},flags={buyWhitelist=%s,sellWhitelist=%s},",
				revision,
				defaultPrice,
				defaultPriceBroken,
				tostring(buyWhitelist),
				tostring(sellWhitelist)
			)
		)

		-- Write items array
		writer:write("items={")
		local itemCount = 0
		for itemId, data in pairs(snapshot.Items or {}) do
			if type(itemId) == "string" and type(data) == "table" then
				local price = tonumber(data.price) or defaultPrice
				local stock = tonumber(data.stock) or -1
				if itemCount > 0 then
					writer:write(",")
				end
				writer:write(string.format('{"%s",%d,%d}', itemId, price, stock))
				itemCount = itemCount + 1
			end
		end
		writer:write("},")

		-- Write buy array
		writer:write("buy={")
		local buyCount = 0
		for itemId, data in pairs(snapshot.PlayerBuy or {}) do
			if type(itemId) == "string" and type(data) == "table" then
				local price = tonumber(data.price) or defaultPrice
				if buyCount > 0 then
					writer:write(",")
				end
				writer:write(string.format('{"%s",%d}', itemId, price))
				buyCount = buyCount + 1
			end
		end
		writer:write("},")

		-- Write sell array
		writer:write("sell={")
		local sellCount = 0
		for itemId, data in pairs(snapshot.PlayerSell or {}) do
			if type(itemId) == "string" and type(data) == "table" then
				local price = tonumber(data.price) or defaultPrice
				if sellCount > 0 then
					writer:write(",")
				end
				writer:write(string.format('{"%s",%d}', itemId, price))
				sellCount = sellCount + 1
			end
		end
		writer:write("}}")

		writer:close()
	end)

	if not success then
		SharedLogger.log("Shops", "[ListingCache.saveSnapshot] Failed to save to " .. filePath .. ": " .. tostring(err))
		return false
	end

	SharedLogger.log("Shops", "[ListingCache.saveSnapshot] Saved revision " .. revision .. " to " .. filePath)
	return true
end

-- =============================================================================
-- LOAD: Manual parsing (no JSON decoder)
-- =============================================================================

-- Load listing snapshot from disk using manual parsing
-- Returns: table on success, nil if file doesn't exist or is invalid
function ListingCache.loadSnapshot(serverId)
	if not serverId then
		return nil
	end

	local filePath = getCacheFilePath(serverId)
	if not filePath then
		return nil
	end

	local snapshot = nil
	local success, err = pcall(function()
		local reader = getFileReader(filePath, false)
		if not reader then
			-- File doesn't exist - normal for first run
			return
		end

		local content = {}
		local line = reader:readLine()
		while line do
			table.insert(content, line)
			line = reader:readLine()
		end
		reader:close()

		local fullContent = table.concat(content)
		if not fullContent or fullContent == "" then
			error("File is empty")
		end

		-- Parse manually (no loadstring available in Kahlua)
		local snapshot_data = {}

		-- Extract header: schema, revision, defaults, flags
		local schema = tonumber(string.match(fullContent, "schema=(%d+)"))
		local revision = tonumber(string.match(fullContent, "revision=(%d+)"))
		local defaultPrice = tonumber(string.match(fullContent, "price=(%d+)"))
		local defaultBroken = tonumber(string.match(fullContent, "broken=(%d+)"))
		local buyWhitelist = string.match(fullContent, "buyWhitelist=([^,}]+)") == "true"
		local sellWhitelist = string.match(fullContent, "sellWhitelist=([^,}]+)") == "true"

		snapshot_data.schema = schema
		snapshot_data.revision = revision
		snapshot_data.defaults = { price = defaultPrice, broken = defaultBroken }
		snapshot_data.flags = { buyWhitelist = buyWhitelist, sellWhitelist = sellWhitelist }

		-- Parse items array: {itemId, price, stock}
		snapshot_data.items = {}
		for itemId, price, stock in string.gmatch(fullContent, '{%s*"([^"]+)"%s*,%s*(%d+)%s*,%s*(-?%d+)%s*}') do
			table.insert(snapshot_data.items, { itemId, tonumber(price), tonumber(stock) })
		end

		-- Parse buy array: {itemId, price}
		snapshot_data.buy = {}
		local buyPattern = "buy={([^}]*)}"
		local buyContent = string.match(fullContent, buyPattern)
		if buyContent then
			for itemId, price in string.gmatch(buyContent, '{%s*"([^"]+)"%s*,%s*(%d+)%s*}') do
				table.insert(snapshot_data.buy, { itemId, tonumber(price) })
			end
		end

		-- Parse sell array: {itemId, price}
		snapshot_data.sell = {}
		local sellPattern = "sell={([^}]*)}"
		local sellContent = string.match(fullContent, sellPattern)
		if sellContent then
			for itemId, price in string.gmatch(sellContent, '{%s*"([^"]+)"%s*,%s*(%d+)%s*}') do
				table.insert(snapshot_data.sell, { itemId, tonumber(price) })
			end
		end

		if not snapshot_data.revision then
			error("Invalid cache format: missing revision")
		end

		snapshot = snapshot_data
	end)

	if not success and err then
		SharedLogger.log(
			"Shops",
			"[ListingCache.loadSnapshot] Failed to load from " .. filePath .. ": " .. tostring(err)
		)
		return nil
	end

	---@diagnostic disable-next-line: unnecessary-if
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
	return ListingCache.loadSnapshot(serverId) ~= nil
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
