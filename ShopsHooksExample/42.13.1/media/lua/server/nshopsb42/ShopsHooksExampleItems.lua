-- ShopsHooksExampleItems.lua
-- Item registration for ShopsHooksExample (server-only reference example)
-- Demonstrates buy/sell item registration with whitelist/blacklist patterns
-- Extends SHOPSB42 namespace

local Utilities = require("nshopsb42/utils/Utilities")
local SharedLogger = require("nshopsb42/utils/SharedLogger")

SHOPSB42.ShopsHooksExampleItems = SHOPSB42.ShopsHooksExampleItems or {}
local Items = SHOPSB42.ShopsHooksExampleItems

-- Configuration: Control whether to enable whitelist mode
-- false = Blacklist mode (default) - all items sellable except blacklisted
-- true = Whitelist mode - only registered items sellable
local ENABLE_WHITELIST_MODE = false

-- Register items that players can BUY from the shop
-- Demonstrates:
--   - Safe hook API: ShopEvents.registerOnShopRegisterItems() calls this
--   - Food items with high stock
--   - Weapons with broken/damaged price variants
--   - Conditional registration based on game state
function Items.registerBuyItems()
	-- Guard: Only run on server
	if not Utilities.IsServerOrSinglePlayer() then
		return
	end

	-- Get Shop module (safe to access from hook)
	local Shop = SHOPSB42.Shop
	if not Shop or not Shop.RegisterItem then
		SharedLogger.log("Shops", "[ShopsHooksExample] ERROR: Shop.RegisterItem not available")
		return
	end

	-- =========================================================================
	-- EXAMPLE 1: Register Food Items
	-- =========================================================================
	-- Demonstrates basic item registration with stock limits
	-- API: Shop.RegisterItem(itemId, definition)
	-- Properties:
	--   tab = SHOPSB42.Tab.* (Food, Weapons, Vehicles, FirstAid, Event, etc.)
	--   price = base price in shop dollars
	--   items = stock quantity (0 or nil = unlimited)
	--   notes = optional description
	Shop.RegisterItem("Base.CannedBolognese", {
		tab = SHOPSB42.Tab.Food,
		price = 8,
		items = 50, -- Limited stock
		notes = "Canned pasta - shop example",
	})

	Shop.RegisterItem("Base.Apple", {
		tab = SHOPSB42.Tab.Food,
		price = 2,
		items = 100, -- High stock (common item)
	})

	SharedLogger.log("Shops", "[ShopsHooksExample] Registered BUY items: Food (CannedBolognese=8, Apple=2)")

	-- =========================================================================
	-- EXAMPLE 2: Register Weapons with Broken Price
	-- =========================================================================
	-- Demonstrates item damage variants
	-- Properties:
	--   brokenPrice = price for damaged/worn versions
	--   Used when item has damage but still functions
	Shop.RegisterItem("Base.AxeSteel", {
		tab = SHOPSB42.Tab.Weapons,
		price = 25,
		items = 10, -- Limited stock (valuable item)
		brokenPrice = 5, -- Damaged axes cost less
	})

	Shop.RegisterItem("Base.Hammer", {
		tab = SHOPSB42.Tab.Weapons,
		price = 15,
		items = 15,
		brokenPrice = 3,
	})

	SharedLogger.log(
		"Shops",
		"[ShopsHooksExample] Registered BUY items: Weapons (AxeSteel=25/5broken, Hammer=15/3broken)"
	)

	-- =========================================================================
	-- EXAMPLE 3: Conditional Registration (Game Difficulty)
	-- =========================================================================
	-- Demonstrates context-aware item availability
	-- Items only appear in shop if conditions are met
	local SandboxVars = SandboxVars or {}
	if SandboxVars and not SandboxVars.SurvivalMode then
		Shop.RegisterItem("Base.FirstAidKit", {
			tab = SHOPSB42.Tab.FirstAid,
			price = 45,
			items = 20,
		})

		SharedLogger.log(
			"Shops",
			"[ShopsHooksExample] Registered conditional BUY item: FirstAidKit (non-survival mode only)"
		)
	end

	SharedLogger.log("Shops", "[ShopsHooksExample] Buy item registration complete")
end

-- Configure whitelist/blacklist mode
-- Demonstrates:
--   - Setting global sell mode
--   - Modes affect which items can be sold to shop
function Items.configureListingMode()
	if not Utilities.IsServerOrSinglePlayer() then
		return
	end

	local Shop = SHOPSB42.Shop
	if not Shop then
		return
	end

	if ENABLE_WHITELIST_MODE then
		-- Whitelist mode: ONLY registered items can be sold
		Shop.SellisWhitelist = true
		SharedLogger.log("Shops", "[ShopsHooksExample] Enabled WHITELIST mode (only registered items sellable)")
	else
		-- Blacklist mode (default): All items sellable EXCEPT blacklisted
		Shop.SellisWhitelist = false
		SharedLogger.log("Shops", "[ShopsHooksExample] Enabled BLACKLIST mode (all items sellable except blacklisted)")
	end
end

-- Register items the shop will BUY from players (in blacklist mode)
-- Demonstrates:
--   - Safe hook API: ShopSellEvents.registerOnShopRegisterSellItems() calls this
--   - Registering items for sale to shop
--   - Blacklisting dangerous/quest items
--   - Different prices for different item types
function Items.registerSellItems()
	if not Utilities.IsServerOrSinglePlayer() then
		return
	end

	local Shop = SHOPSB42.Shop
	if not Shop or not Shop.RegisterSellItem then
		SharedLogger.log("Shops", "[ShopsHooksExample] ERROR: Shop.RegisterSellItem not available")
		return
	end

	-- =========================================================================
	-- EXAMPLE 1: Register Food Items Sell Price (Blacklist Mode)
	-- =========================================================================
	-- Demonstrates: Items players can sell to shop
	-- API: Shop.RegisterSellItem(itemId, definition)
	-- In blacklist mode:
	--   - Unregistered items use Shop.defaultPrice
	--   - Registered items use specified price
	--   - blacklisted=true prevents sale
	-- Properties:
	--   price = what shop pays player for this item
	--   blacklisted = true to prevent sale (blacklist mode only)
	Shop.RegisterSellItem("Base.CannedBolognese", {
		price = 4, -- Roughly half the buy price (8)
	})

	Shop.RegisterSellItem("Base.Apple", {
		price = 1, -- Roughly half the buy price (2)
	})

	SharedLogger.log("Shops", "[ShopsHooksExample] Registered SELL items: Food (CannedBolognese=4, Apple=1)")

	-- =========================================================================
	-- EXAMPLE 2: Register Weapon Items Sell Price
	-- =========================================================================
	-- Higher value weapons worth more when sold
	Shop.RegisterSellItem("Base.AxeSteel", {
		price = 12, -- Roughly half the buy price (25)
	})

	Shop.RegisterSellItem("Base.Hammer", {
		price = 7, -- Roughly half the buy price (15)
	})

	SharedLogger.log("Shops", "[ShopsHooksExample] Registered SELL items: Weapons (AxeSteel=12, Hammer=7)")

	-- =========================================================================
	-- EXAMPLE 3: Blacklist Dangerous Items
	-- =========================================================================
	-- In blacklist mode (default), shop refuses to buy blacklisted items
	-- In whitelist mode, unregistered items are implicitly blacklisted
	-- Demonstrates: Preventing sale of explosive/quest items
	Shop.RegisterSellItem("Base.Bomb", {
		blacklisted = true,
	})

	Shop.RegisterSellItem("Base.C4", {
		blacklisted = true,
	})

	Shop.RegisterSellItem("Base.Explosives", {
		blacklisted = true,
	})

	SharedLogger.log("Shops", "[ShopsHooksExample] Blacklisted items: Bomb, C4, Explosives (players cannot sell these)")

	SharedLogger.log("Shops", "[ShopsHooksExample] Sell item registration complete (blacklist mode)")
end

-- Register items ONLY in whitelist mode
-- When whitelist is enabled, ONLY these specific items can be sold
-- Demonstrates:
--   - Curated/restricted item list for specific shop types
--   - Per-item sell price configuration
--   - Conditional hook execution based on Shop.SellIsWhitelist
function Items.registerWhitelistSellItems()
	if not Utilities.IsServerOrSinglePlayer() then
		return
	end

	-- Skip if not in whitelist mode
	if not ENABLE_WHITELIST_MODE then
		return
	end

	local Shop = SHOPSB42.Shop
	if not Shop or not Shop.RegisterSellItem then
		return
	end

	-- =========================================================================
	-- EXAMPLE: Whitelist Mode Registration
	-- =========================================================================
	-- When Shop.SellIsWhitelist = true, ONLY explicitly registered items can be sold
	-- This example registers a curated list of safe, store-appropriate items
	-- Demonstrates: Restricted economy mod or specialty shops
	local whitelistItems = {
		{ itemId = "Base.CannedBolognese", price = 4 },
		{ itemId = "Base.Apple", price = 1 },
		{ itemId = "Base.AxeSteel", price = 12 },
		{ itemId = "Base.Hammer", price = 7 },
	}

	for _, item in ipairs(whitelistItems) do
		Shop.RegisterSellItem(item.itemId, {
			price = item.price,
		})
	end

	SharedLogger.log(
		"Shops",
		"[ShopsHooksExample] Registered " .. #whitelistItems .. " whitelisted sell items (WHITELIST MODE)"
	)
end

-- Helper: Display current listing mode
-- Useful for logging or conditional behavior in other hooks
function Items.printListingModeInfo()
	local Shop = SHOPSB42.Shop
	if Shop then
		local mode = Shop.SellisWhitelist and "WHITELIST (restrictive)" or "BLACKLIST (permissive)"
		SharedLogger.log(
			"Shops",
			"[ShopsHooksExample] Sell listing mode: "
				.. mode
				.. " | Can sell unregistered items: "
				.. tostring(not Shop.SellisWhitelist)
		)
	end
end

return Items
