-- ShopListingNPC.lua
-- Client-side NPC shop listing helper (deterministic, zero network)
-- Loads catalog and calculates preview prices locally
-- Extends SHOPSB42 namespace (no new globals)

local SharedLogger = require("nshopsb42/utils/SharedLogger")
local PricingContract = require("nshopsb42/pricing/PricingContract")
local NPCShopCatalog = require("nshopsb42/pricing/NPCShopCatalog")

SHOPSB42.ShopListingNPC = SHOPSB42.ShopListingNPC or {}
local ShopListingNPC = SHOPSB42.ShopListingNPC

---
-- Load a shop catalog snapshot for NPC shop display
-- Call this once when the shop UI opens (no network traffic)
--
-- @param shopId string - NPC shop ID (e.g., "npc_general_store")
--
-- @return table - { shopId, name, items = { itemId -> { basePrice, category, stock, available } } }
-- @return string - Error message if shop not found, nil on success
function ShopListingNPC.loadShop(shopId)
	if not shopId then
		return nil, "[ShopListingNPC] shopId is required"
	end

	local catalog = NPCShopCatalog.getShopSnapshot(shopId)
	if not catalog then
		SharedLogger.log("Shops", "[ShopListingNPC] WARNING: NPC shop not found: " .. shopId)
		return nil, "Shop not found: " .. shopId
	end

	SharedLogger.log(
		"Shops",
		"[ShopListingNPC] Loaded catalog for " .. shopId .. " with " .. ShopListingNPC._countItems(catalog) .. " items"
	)

	return catalog, nil
end

---
-- Count items in a catalog (helper)
function ShopListingNPC._countItems(catalog)
	if not catalog or not catalog.items then
		return 0
	end
	local count = 0
	for _ in pairs(catalog.items) do
		count = count + 1
	end
	return count
end

---
-- Calculate a preview buy price for an NPC shop item
-- This is DETERMINISTIC and SAFE for client-side preview display
-- The server will recompute and validate on actual transaction
--
-- IMPORTANT: Preview price is NON-AUTHORITATIVE
-- Label internally as "preview" or "estimated" in UI
-- Server final price is always the source of truth
--
-- @param itemId string - Item ID (e.g., "Base.Apple")
-- @param basePrice number - Base price from catalog
-- @param playerSnapshot table|nil - Immutable player snapshot { traits = {...} }
-- @param modifiers table|nil - Array of { multiplier, label } objects
--
-- @return number - Preview price (may differ from server on transaction)
-- @return string - "preview" (label for UI)
function ShopListingNPC.getPreviewBuyPrice(itemId, basePrice, playerSnapshot, modifiers)
	if not basePrice or basePrice < 0 then
		return nil, "invalid basePrice"
	end

	modifiers = modifiers or {}

	-- Use PricingContract for deterministic calculation
	local result = PricingContract.calculateBuyPrice(itemId, "npc_general_store", basePrice, playerSnapshot, modifiers)

	if not result then
		return nil, "calculation failed"
	end

	return result.finalPrice, "preview"
end

---
-- Calculate a preview sell price for an NPC shop item
-- This is DETERMINISTIC and SAFE for client-side preview display
--
-- IMPORTANT: Preview price is NON-AUTHORITATIVE
-- Server will recompute from actual item state on transaction
--
-- @param itemId string - Item ID
-- @param basePrice number - Base price from catalog
-- @param itemSnapshot table|nil - Immutable item snapshot { condition = 0.85 }
-- @param modifiers table|nil - Array of { multiplier, label } objects
--
-- @return number - Preview price
-- @return string - "preview"
function ShopListingNPC.getPreviewSellPrice(itemId, basePrice, itemSnapshot, modifiers)
	if not basePrice or basePrice < 0 then
		return nil, "invalid basePrice"
	end

	modifiers = modifiers or {}

	-- Use PricingContract for deterministic calculation
	local result = PricingContract.calculateSellPrice(itemId, "npc_general_store", basePrice, itemSnapshot, modifiers)

	if not result then
		return nil, "calculation failed"
	end

	return result.finalPrice, "preview"
end

---
-- Validate and report price mismatch between client preview and server actual
-- Used as a development aid to catch non-determinism or mod conflicts
-- Does NOT prevent transactions, just logs silently
--
-- @param itemId string
-- @param previewPrice number - Client preview price
-- @param serverPrice number - Server final price
-- @param tolerance number - Acceptable difference (default: 0, exact match)
--
-- @return boolean - true if within tolerance, false if mismatch
function ShopListingNPC.validatePriceMismatch(itemId, previewPrice, serverPrice, tolerance)
	tolerance = tolerance or 0

	if not previewPrice or not serverPrice then
		return false
	end

	local diff = math.abs(previewPrice - serverPrice)
	if diff > tolerance then
		SharedLogger.log(
			"Shops",
			"[ShopListingNPC] MISMATCH: "
				.. itemId
				.. " preview="
				.. previewPrice
				.. " server="
				.. serverPrice
				.. " diff="
				.. diff
		)
		return false
	end

	return true
end

---
-- Check if an item is available in the NPC shop for purchase
--
-- @param shopId string
-- @param itemId string
--
-- @return boolean
function ShopListingNPC.isItemAvailable(shopId, itemId)
	return NPCShopCatalog.isItemAvailable(shopId, itemId)
end

---
-- List all items available in an NPC shop
--
-- @param shopId string
--
-- @return table - Array of item IDs, sorted alphabetically
function ShopListingNPC.listShopItems(shopId)
	return NPCShopCatalog.listShopItems(shopId)
end

---
-- Get base price for an item in NPC shop catalog
--
-- @param shopId string
-- @param itemId string
--
-- @return number|nil - Base price, or nil if item not in shop
function ShopListingNPC.getItemBasePrice(shopId, itemId)
	return NPCShopCatalog.getItemBasePrice(shopId, itemId)
end

---
-- Create an immutable player snapshot for deterministic pricing
-- This captures only the data safe for client-side calculation
-- No inventory or world state (those are re-checked on server at transaction time)
--
-- @param player Player object|nil
--
-- @return table - { traits = {...} } immutable snapshot
function ShopListingNPC.createPlayerSnapshot(player)
	if not player then
		return { traits = {} }
	end

	-- Snapshot only traits (immutable, safe for deterministic pricing)
	-- Do NOT include inventory, items, or world state
	local traits = {}

	-- List of trait names that are safe for pricing (read-only, static)
	local safeTraits = {
		"Desensitized",
		"VeryVeryUnhappy",
		"VeryUnhappy",
		"Unhappy",
		"Lucky",
		"VeryLucky",
		"ExtraPicky",
		"Picky",
		"PacketThief",
	}

	for _, traitName in ipairs(safeTraits) do
		if player:HasTrait(traitName) then
			table.insert(traits, traitName)
		end
	end

	return { traits = traits }
end

---
-- Create an immutable item snapshot for deterministic pricing
-- Captures only the data safe for client-side calculation
-- Called BEFORE transaction (seller doesn't have item yet for preview)
-- Called on server with actual item for validation
--
-- @param item Item object|nil
--
-- @return table - { condition = 0.85, fullType = "..." } immutable snapshot
function ShopListingNPC.createItemSnapshot(item)
	if not item then
		return { condition = 1.0, fullType = "unknown" }
	end

	-- Snapshot only immutable properties safe for pricing
	return {
		condition = item:getCondition() / item:getMaxCondition(), -- 0-1 ratio
		fullType = item:getFullType(),
		category = item:getType(), -- For potential future use
	}
end

return ShopListingNPC
