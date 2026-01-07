-- ListingBootstrap.lua (Client-side)
-- Phase 3: Bootstrap listing from cache or shared default
-- Implements Tier 0/1/2 selection logic without network wait
-- UI initializes immediately with highest-revision listing available

local SharedLogger = require("nshopsb42/utils/SharedLogger")
local ListingCache = require("nshopsb42/listing/ListingCache")

local ListingBootstrap = {}

-- =============================================================================
-- BOOTSTRAP LOGIC
-- =============================================================================

-- Select the highest-revision listing from available tiers
-- Tier 0: shared/ShopCatalog (revision 0)
-- Tier 1/2: cached listing (from disk, higher revision)
-- Returns: selected listing table, revision number
local function selectBestListing()
	-- Tier 0: Shared default (always available)
	local ShopCatalog = require("nshopsb42/listing/ShopCatalog")
	local selectedListing = ShopCatalog
	local selectedRevision = 0
	local selectedSource = "shared"

	---@diagnostic disable-next-line: unnecessary-if
	-- Tier 1/2: Disk cache (if exists and valid)
	if SHOPSB42.cachedListing and ListingCache.isValidSnapshot(SHOPSB42.cachedListing) then
		local cachedRevision = SHOPSB42.cachedListing.revision or 0
		if cachedRevision > selectedRevision then
			selectedListing = SHOPSB42.cachedListing
			selectedRevision = cachedRevision
			selectedSource = "cache"
			SharedLogger.log(
				"Shops",
				"[ListingBootstrap.selectBestListing] Selected cached listing (revision " .. selectedRevision .. ")"
			)
		end
	else
		SharedLogger.log(
			"Shops",
			"[ListingBootstrap.selectBestListing] No valid cache, using shared default (revision 0)"
		)
	end

	return selectedListing, selectedRevision, selectedSource
end

-- Bootstrap Shop namespace from selected listing
-- Initializes Shop.* tables immediately without network wait
function ListingBootstrap.bootstrap()
	SharedLogger.log("Shops", "[ListingBootstrap.bootstrap] ENTRY")

	local selectedListing, selectedRevision, selectedSource = selectBestListing()

	-- Phase 3: Log which tier was selected (for debugging and audits)
	SharedLogger.log(
		"Shops",
		"[ListingBootstrap.bootstrap] Using catalog from: "
			.. selectedSource
			.. " (revision "
			.. selectedRevision
			.. ")"
	)

	-- Phase 3: Populate Shop namespace with highest-revision listing
	local Shop = SHOPSB42.Shop

	---@diagnostic disable-next-line: unnecessary-if
	-- Phase 3: Apply monotonicity check in memory
	-- Only accept listing if revision >= current
	if Shop.currentRevision and selectedRevision < Shop.currentRevision then
		SharedLogger.log(
			"Shops",
			"[ListingBootstrap.bootstrap] WARN: Rejecting downgrade (selected="
				.. selectedRevision
				.. " current="
				.. Shop.currentRevision
				.. ")"
		)
		return false
	end

	Shop.Items = selectedListing.Items or {}
	Shop.PlayerBuy = selectedListing.PlayerBuy or {}
	Shop.PlayerSell = selectedListing.PlayerSell or {}
	Shop.BuyIsWhitelist = selectedListing.BuyIsWhitelist or true
	Shop.SellIsWhitelist = selectedListing.SellIsWhitelist or false
	Shop.defaultPrice = selectedListing.defaultPrice or 100
	Shop.defaultPriceBroken = selectedListing.defaultPriceBroken or 50
	Shop.currentRevision = selectedRevision

	SharedLogger.log("Shops", "[ListingBootstrap.bootstrap] Bootstrapped Shop from revision " .. selectedRevision)

	-- Mark bootstrap complete for UI
	SHOPSB42.listingBootstrapComplete = true

	SharedLogger.log("Shops", "[ListingBootstrap.bootstrap] EXIT - UI can now initialize")
	return true
end

-- Initialize ClientShopListingService after bootstrap
-- Builds price cache from bootstrapped catalog
function ListingBootstrap.initializeUI()
	SharedLogger.log("Shops", "[ListingBootstrap.initializeUI] ENTRY")

	---@diagnostic disable-next-line: unnecessary-if
	if not SHOPSB42.listingBootstrapComplete then
		SharedLogger.log("Shops", "[ListingBootstrap.initializeUI] ERROR: Bootstrap not complete, aborting")
		return false
	end

	-- Initialize ClientShopListingService for deterministic preview pricing
	local ClientShopListingService = SHOPSB42.ClientShopListingService
	---@diagnostic disable-next-line: unnecessary-if
	if ClientShopListingService and ClientShopListingService.initialize then
		ClientShopListingService.initialize()
		SharedLogger.log("Shops", "[ListingBootstrap.initializeUI] ClientShopListingService initialized")
	else
		SharedLogger.log("Shops", "[ListingBootstrap.initializeUI] WARNING: ClientShopListingService not available")
		return false
	end

	SharedLogger.log("Shops", "[ListingBootstrap.initializeUI] EXIT - UI ready")
	return true
end

return ListingBootstrap
