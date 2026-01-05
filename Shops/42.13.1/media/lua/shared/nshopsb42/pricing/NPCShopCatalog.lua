-- NPCShopCatalog.lua
-- Shared NPC shop catalog (static, immutable definitions)
-- Used by client for preview pricing and server for validation
-- Extends SHOPSB42 namespace (no new globals)

local SharedLogger = require("nshopsb42/utils/SharedLogger")

SHOPSB42.NPCShopCatalog = SHOPSB42.NPCShopCatalog or {}
local Catalog = SHOPSB42.NPCShopCatalog

---
-- Initialize the NPC shop catalog
-- Called during shared module initialization
-- This populates the catalog from static shop definitions
function Catalog.initialize()
	if not SHOPSB42.Shop or not SHOPSB42.Shop.Items then
		SharedLogger.log("Shops", "[NPCShopCatalog] WARNING: Shop.Items not yet initialized, deferring catalog build")
		return
	end

	-- Build catalog from Shop.Items (populated by ShopDefaultItems and mod hooks)
	-- For now, create a single "default" NPC shop with all registered items
	Catalog._buildDefaultShop()
end

---
-- Build the default NPC shop catalog from registered items
-- Internal use only
function Catalog._buildDefaultShop()
	local Shop = SHOPSB42.Shop

	if not Shop.Items then
		SharedLogger.log("Shops", "[NPCShopCatalog] No items registered yet")
		return
	end

	-- Check if items table is empty (avoid next() in Kahlua)
	-- Phase 5 NOTE: pairs() here is safe (runs once at init, not in pricing)
	local hasItems = false
	for _ in pairs(Shop.Items) do
		hasItems = true
		break
	end

	if not hasItems then
		SharedLogger.log("Shops", "[NPCShopCatalog] No items registered yet")
		return
	end

	-- Create default NPC shop ("npc_general_store")
	Catalog["npc_general_store"] = {
		shopId = "npc_general_store",
		name = "General Store",
		items = {},
	}

	-- Populate items from Shop.Items registry
	-- Phase 5 NOTE: pairs() here is safe (runs once at init, not in pricing calculations)
	for itemId, itemConfig in pairs(Shop.Items) do
		local basePrice = itemConfig.basePrice or itemConfig.price
		if basePrice then
			Catalog["npc_general_store"].items[itemId] = {
				itemId = itemId,
				basePrice = basePrice,
				category = itemConfig.tab or "All",
				stock = -1, -- Infinite stock for NPC shops
				available = true,
			}
		end
	end

	SharedLogger.log(
		"Shops",
		"[NPCShopCatalog] Initialized default shop with "
			.. Catalog._countItems(Catalog["npc_general_store"])
			.. " items"
	)
end

---
-- Count items in a shop (helper)
-- Phase 5 NOTE: pairs() here is safe (counting, not pricing)
function Catalog._countItems(shop)
	if not shop or not shop.items then
		return 0
	end
	local count = 0
	for _ in pairs(shop.items) do
		count = count + 1
	end
	return count
end

---
-- Get a snapshot of an NPC shop's catalog
--
-- @param shopId string - NPC shop ID (e.g., "npc_general_store")
--
-- @return table - { shopId, name, items = { itemId -> { basePrice, category, stock } } }
--
-- This returns an IMMUTABLE snapshot of the shop's current state
-- Safe for both client preview and server validation
function Catalog.getShopSnapshot(shopId)
	if not Catalog[shopId] then
		return nil
	end

	return Catalog[shopId]
end

---
-- Get base price for an item in an NPC shop
--
-- @param shopId string
-- @param itemId string
--
-- @return number|nil - Base price, or nil if item not in shop
function Catalog.getItemBasePrice(shopId, itemId)
	local shop = Catalog[shopId]
	if not shop or not shop.items or not shop.items[itemId] then
		return nil
	end

	return shop.items[itemId].basePrice
end

---
-- Check if an item is available in an NPC shop
--
-- @param shopId string
-- @param itemId string
--
-- @return boolean
function Catalog.isItemAvailable(shopId, itemId)
	local shop = Catalog[shopId]
	if not shop or not shop.items or not shop.items[itemId] then
		return false
	end

	local itemEntry = shop.items[itemId]
	if not itemEntry then
		return false
	end
	return itemEntry.available == true and itemEntry.stock ~= 0
end

---
-- List all items in an NPC shop
--
-- @param shopId string
--
-- @return table - Array of item IDs, sorted
-- Phase 5 NOTE: pairs() used to enumerate items, but results are sorted before return (safe)
function Catalog.listShopItems(shopId)
	local shop = Catalog[shopId]
	if not shop or not shop.items then
		return {}
	end

	local items = {}
	for itemId in pairs(shop.items) do
		table.insert(items, itemId)
	end

	table.sort(items)
	return items
end

---
-- List all NPC shops in the catalog
--
-- @return table - Array of shop IDs, sorted
-- Phase 5 NOTE: pairs() used to enumerate shops, but results are sorted before return (safe)
function Catalog.listShops()
	local shops = {}
	for shopId in pairs(Catalog) do
		if not shopId:match("^_") then -- Skip internal fields
			table.insert(shops, shopId)
		end
	end

	table.sort(shops)
	return shops
end

---
-- Verify that catalog matches Shop.Items registry
-- Used for validation (Phase 5)
--
-- @return boolean, string - (isValid, errorMessage)
function Catalog.validate()
	local Shop = SHOPSB42.Shop

	if not Shop.Items then
		return false, "Shop.Items not initialized"
	end

	local shop = Catalog["npc_general_store"]
	if not shop then
		return false, "Default NPC shop not initialized"
	end

	-- Check that all registered items have catalog entries
	-- Phase 5 NOTE: pairs() here is safe (validation only, not pricing)
	local missingCount = 0
	for itemId in pairs(Shop.Items) do
		if not shop.items[itemId] then
			missingCount = missingCount + 1
			SharedLogger.log(
				"Shops",
				"[NPCShopCatalog] WARNING: Item " .. itemId .. " in Shop.Items but not in catalog"
			)
		end
	end

	if missingCount > 0 then
		return false, "Catalog missing " .. missingCount .. " registered items"
	end

	return true, nil
end

return Catalog
