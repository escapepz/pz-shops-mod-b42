-- Phase 3: ClientShopListingService.lua
-- Client-side shop listing and preview pricing (ZERO NETWORK)
-- Loads static shop catalog from shared and provides preview prices deterministically
-- Part of hybrid model: Client Preview (Phase A) + Server Settlement (Phase B)

local SharedLogger = require("nshopsb42/utils/SharedLogger")
local PricingContract = require("nshopsb42/pricing/PricingContract")
local NPCShopCatalog = require("nshopsb42/pricing/NPCShopCatalog")

if not isClient() then
	SharedLogger.log("Shops", "[ClientShopListingService] Not on client, returning nil")
	return nil
end

SHOPSB42.ClientShopListingService = SHOPSB42.ClientShopListingService or {}
local Service = SHOPSB42.ClientShopListingService

---
-- Initialize the client listing service
-- Called during client module loading (after shared Shop data is available)
--
function Service.initialize()
	---@diagnostic disable-next-line: condition-is-always false
	if not SHOPSB42.Shop or not SHOPSB42.Shop.Items then
		SharedLogger.log("Shops", "[ClientShopListingService] WARNING: Shop.Items not initialized yet")
		return
	end

	-- Ensure catalog is built
	-- Note: Avoid next() in Kahlua; check if catalog is empty using pairs
	local catalogExists = false
	---@diagnostic disable-next-line: unnecessary-if
	if SHOPSB42.NPCShopCatalog then
		for _ in pairs(SHOPSB42.NPCShopCatalog) do
			catalogExists = true
			break
		end
	end

	if not catalogExists then
		NPCShopCatalog.initialize()
	end

	SharedLogger.log("Shops", "[ClientShopListingService] Initialized (catalog ready for client preview)")
end

---
-- Get all items available for purchase in an NPC shop
-- Returns PREVIEW prices computed deterministically client-side
--
-- @param shopId string - NPC shop ID (e.g., "npc_general_store")
-- @param player isa Player|nil - Current player (used for trait-based modifiers)
-- @return table - Array of items { itemId, basePrice, previewPrice, category, available }
--
function Service.getShopItems(shopId, player)
	if not player then
		player = getPlayer()
	end
	if not player then
		return {}
	end

	local catalog = NPCShopCatalog.getShopSnapshot(shopId)
	if not catalog or not catalog.items then
		return {}
	end

	local Shop = SHOPSB42.Shop
	if not Shop or not Shop.Items then
		return {}
	end

	local result = {}

	for itemId, catalogEntry in pairs(catalog.items) do
		local itemConfig = Shop.Items[itemId]
		---@diagnostic disable-next-line: unnecessary-if
		if itemConfig and catalogEntry.available then
			local basePrice = catalogEntry.basePrice or itemConfig.basePrice or itemConfig.price

			-- Calculate preview price using shared deterministic pricing
			local previewPrice = Service.calculatePreviewBuyPrice(itemId, shopId, basePrice, player)

			table.insert(result, {
				itemId = itemId,
				basePrice = basePrice,
				previewPrice = previewPrice,
				category = catalogEntry.category or "All",
				available = true,
				stock = catalogEntry.stock,
			})
		end
	end

	return result
end

---
-- Calculate preview buy price for an item (deterministic, client-side only)
-- Uses PricingContract for determinism guarantee
--
-- @param itemId string
-- @param shopId string
-- @param basePrice number
-- @param player isa Player|nil
-- @return number - Preview price (NOT authoritative, server will recompute)
--
function Service.calculatePreviewBuyPrice(itemId, shopId, basePrice, player)
	if not player then
		player = getPlayer()
	end

	-- Create immutable player snapshot (only traits, no inventory/state)
	local playerSnapshot = nil
	if player then
		playerSnapshot = {
			traits = {}, -- Future: extract trait info if needed for modifiers
		}
	end

	-- Get modifiers from shared config
	local modifiers = SHOPSB42.Shop.PriceModifiers or {}

	-- Use PricingContract for deterministic calculation
	-- This ensures client preview == server calculation (when conditions match)
	local result = PricingContract.calculateBuyPrice(itemId, shopId, basePrice, playerSnapshot, modifiers)

	if result then
		return result.finalPrice
	end

	-- Fallback to base if calculation fails
	return basePrice
end

---
-- Get base sell price for an item (deterministic preview)
-- This is the price player will receive if they sell the item to the shop
--
-- @param itemId string
-- @param shopId string
-- @param basePrice number
-- @param itemCondition number|nil - Item condition ratio (0.0-1.0)
-- @param player isa Player|nil
-- @return number - Preview sell price
--
function Service.calculatePreviewSellPrice(itemId, shopId, basePrice, itemCondition, player)
	if not player then
		player = getPlayer()
	end

	-- Create immutable item snapshot
	local itemSnapshot = nil
	if itemCondition then
		itemSnapshot = {
			condition = itemCondition,
		}
	end

	local modifiers = SHOPSB42.Shop.PriceModifiers or {}
	local result = PricingContract.calculateSellPrice(itemId, shopId, basePrice, itemSnapshot, modifiers)

	if result then
		return result.finalPrice
	end

	return basePrice
end

---
-- Get shop metadata (name, ID, description)
--
-- @param shopId string
-- @return table - { shopId, name, description }
--
function Service.getShopMetadata(shopId)
	local catalog = NPCShopCatalog.getShopSnapshot(shopId)
	if catalog then
		return {
			shopId = catalog.shopId,
			name = catalog.name,
			description = catalog.description or "",
		}
	end
	return nil
end

---
-- List all available NPC shops
--
-- @return table - Array of shop IDs
--
function Service.listAvailableShops()
	return NPCShopCatalog.listShops()
end

---
-- Validate that a price matches expected preview (for debugging/testing)
--
-- @param itemId string
-- @param clientPrice number - Price computed on client
-- @param serverPrice number - Price computed on server
-- @param tolerance number - Acceptable difference (default 0, exact match)
-- @return boolean - true if prices match within tolerance
--
function Service.validatePricePair(itemId, clientPrice, serverPrice, tolerance)
	tolerance = tolerance or 0
	local diff = math.abs(clientPrice - serverPrice)
	if diff > tolerance then
		SharedLogger.log(
			"Shops",
			"[ClientShopListingService] Price mismatch for "
				.. itemId
				.. ": client="
				.. clientPrice
				.. " server="
				.. serverPrice
		)
		return false
	end
	return true
end

SharedLogger.log("Shops", "[ClientShopListingService] Loaded")
return Service
