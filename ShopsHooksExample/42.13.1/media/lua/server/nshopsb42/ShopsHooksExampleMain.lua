-- ShopsHooksExampleMain.lua
-- Central loader + serializer for declarative item listings
-- Loads all item definitions from listings/ folder and registers them with Shops
-- Provides unified registration for buy/sell items and whitelist/blacklist control

local Utilities = require("nshopsb42/utils/Utilities")
local SharedLogger = require("nshopsb42/utils/SharedLogger")
local ShopsHooksExampleState = require("nshopsb42/ShopsHooksExampleState")

SHOPSB42.ShopsHooksExampleMain = SHOPSB42.ShopsHooksExampleMain or {}
local Main = SHOPSB42.ShopsHooksExampleMain

local LISTING_ROOT = "nshopsb42/listings/"

-- ============================================================================
-- Utilities
-- ============================================================================

local function loadModule(path)
	return require(LISTING_ROOT .. path)
end

-- ============================================================================
-- Load All Listings
-- ============================================================================

function Main.loadAllListings()
	local index = loadModule("_index")
	local result = { buy = {}, sell = {} }

	for _, name in ipairs(index) do
		local data = loadModule(name)
		if data.buy then
			for _, item in ipairs(data.buy) do
				table.insert(result.buy, item)
			end
		end
		if data.sell then
			for _, item in ipairs(data.sell) do
				table.insert(result.sell, item)
			end
		end
	end

	return result
end

-- ============================================================================
-- Register Buy Items
-- ============================================================================
-- Called during shop initialization hook
-- Registers all items in listings/*/buy sections
--
-- Tab values must match SHOPSB42.Tab constants:
--   "Favorite", "Sell", "All", "Food", "Weapons", "Vehicles", "FirstAid", "Event"
-- To use custom tabs, extend SHOPSB42.Shop.Tab before registration

function Main.registerBuyItems()
	if not Utilities.IsServerOrSinglePlayer() then
		return
	end

	local Shop = SHOPSB42.Shop
	local listings = Main.loadAllListings()

	for _, def in ipairs(listings.buy) do
		-- Build config table, passing through all optional properties
		local config = {
			tab = def.tab,
			price = def.price,
		}

		-- Pass through optional properties if defined in listing
		if def.items then
			config.items = def.items
		end
		-- if def.brokenPrice then
		-- 	config.brokenPrice = def.brokenPrice
		-- end
		-- if def.notes then
		-- 	config.notes = def.notes
		-- end
		-- if def.basePrice then
		-- 	config.basePrice = def.basePrice
		-- end
		if def.specialCoin then
			config.specialCoin = def.specialCoin
		end
		if def.isVirtualBundle then
			config.isVirtualBundle = def.isVirtualBundle
		end

		Shop.RegisterItem(def.id, config)
	end

	SharedLogger.log("Shops", "[ShopsHooksExample] Buy listings registered: " .. #listings.buy .. " items")
end

-- ============================================================================
-- Register Sell Items (Whitelist/Blacklist)
-- ============================================================================
-- Called during sell items hook
-- Applies whitelist/blacklist rules from listings/*/sell sections

function Main.registerSellItems()
	if not Utilities.IsServerOrSinglePlayer() then
		return
	end

	local Shop = SHOPSB42.Shop
	local listings = Main.loadAllListings()

	for _, def in ipairs(listings.sell) do
		-- Build config table, passing through all optional properties
		local config = {
			price = def.price,
			blacklisted = def.blacklisted,
		}

		-- Pass through optional properties if defined in listing
		if def.specialCoin then
			config.specialCoin = def.specialCoin
		end

		Shop.RegisterSellItem(def.id, config)
	end

	SharedLogger.log("Shops", "[ShopsHooksExample] Sell listings registered: " .. #listings.sell .. " items")
end

-- ============================================================================
-- Configure Listing Mode
-- ============================================================================
-- Must be called before item registration hooks
-- Sets whether shop operates in whitelist or blacklist mode

function Main.configureListingMode()
	-- true  = whitelist (only registered items sellable)
	-- false = blacklist (all items sellable by default, except blacklisted)
	-- Uses config value from ShopsHooksExampleState
	local isWhitelist = ShopsHooksExampleState.SellIsWhitelist or false

	if SHOPSB42.Shop then
		SHOPSB42.Shop.SellIsWhitelist = isWhitelist
		SharedLogger.log("Shops", "[ShopsHooksExample] Listing mode: " .. (isWhitelist and "WHITELIST" or "BLACKLIST"))
	end
end

return Main
