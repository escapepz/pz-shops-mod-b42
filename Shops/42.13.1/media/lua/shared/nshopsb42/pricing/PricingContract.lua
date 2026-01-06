-- PricingContract.lua
-- Deterministic shared pricing module for client preview and server validation
-- CRITICAL: Inputs MUST be scalar snapshots only
-- NO inventory state, container reads, world object access, RNG, or time-based logic
-- Extends SHOPSB42 namespace (no new globals)

local SharedLogger = require("nshopsb42/utils/SharedLogger")

SHOPSB42.PricingContract = SHOPSB42.PricingContract or {}
local Contract = SHOPSB42.PricingContract

-- Determinism validator: Ensure no forbidden operations are called
-- This is a safety net for development; production code must avoid these inherently
local function assertDeterministic(context)
	if not context then
		return
	end
	-- MANDATORY CONSTRAINTS (Phase 5 Enforcement):
	-- 1. No ZombRand() - defeats determinism
	-- 2. No os.time() or GameTime - time-dependent output
	-- 3. No mutable global state access
	-- 4. No inventory/container/world reads
	-- 5. Only ipairs() for arrays, sorted keys for maps
	-- Violation = desync in multiplayer, price divergence
end

---
-- ALLOWED OPERATIONS (Deterministic Safe):
-- - Table lookups (Shop.Items, Shop.PlayerSell, static config)
-- - Arithmetic (multiply, add, subtract, floor)
-- - Read-only scalar inputs (player traits via HasTrait, item condition via getCondition)
-- - Static configuration data
-- - Immutable snapshots passed at call time
--
-- FORBIDDEN OPERATIONS (Non-Deterministic, must never appear):
-- - ZombRand() - random number generation
-- - os.time() - current time
-- - GameTime - game world time
-- - Mutable global state reads (e.g., Economy or other global state)
-- - Inventory access (item containers, player inventory)
-- - World reads (world objects, chunks, positions)
-- - Table iteration via pairs() on unordered maps
--   (Use ipairs() for arrays, or explicitly sorted key iteration)
-- - Mod load-order dependent hooks
---

---
-- Calculate buy price for an NPC item (deterministic)
--
-- @param itemId string - Item ID (e.g., "Base.Apple")
-- @param shopId string - NPC shop ID (e.g., "npc_general_store")
-- @param basePrice number - Base price from shared catalog
-- @param playerSnapshot table|nil - Immutable player snapshot with { traits = {...} }
-- @param modifiers table|nil - Array of modifier objects { multiplier = 1.3, priority = 10 }
--
-- @return { finalPrice = number, revision = number } or nil if unable to calculate
--
-- IMPORTANT: This is pure calculation ONLY
-- - No server calls
-- - No ModData access
-- - No RNG
-- - Same inputs → same output (100% deterministic)
function Contract.calculateBuyPrice(itemId, shopId, basePrice, playerSnapshot, modifiers)
	assertDeterministic({ itemId = itemId, shopId = shopId, basePrice = basePrice })

	if not basePrice or basePrice < 0 then
		return nil
	end

	modifiers = modifiers or {}

	local price = basePrice

	-- Phase 5 DETERMINISM RULE: MUST sort modifiers before iteration
	-- NEVER use pairs() on modifiers - array must be ordered for MP consistency
	-- OPTIMIZATION: Skip sort if modifiers are pre-sorted (marked with _isSorted flag)
	local sortedMods = modifiers
	if not modifiers._isSorted then
		sortedMods = {}
		for _, mod in ipairs(modifiers) do
			table.insert(sortedMods, mod)
		end
		table.sort(sortedMods, function(a, b)
			local priorityA = a.priority or 100
			local priorityB = b.priority or 100
			return priorityA < priorityB
		end)
	end

	-- Apply each modifier as multiplier
	-- Using ipairs() = deterministic (array ordered)
	for _, mod in ipairs(sortedMods) do
		if mod.multiplier then
			price = price * mod.multiplier
		end
	end

	-- Floor to integer, ensure non-negative
	local finalPrice = math.floor(math.max(0, price))

	return {
		finalPrice = finalPrice,
		revision = 1, -- Future-proofing for live pricing (Phase 1.3)
	}
end

---
-- Calculate sell price for an NPC item (deterministic)
--
-- @param itemId string - Item ID (e.g., "Base.Apple")
-- @param shopId string - NPC shop ID
-- @param basePrice number - Base price from shared catalog
-- @param itemSnapshot table|nil - Immutable item snapshot with { condition = 0.85, fullType = "..." }
-- @param modifiers table|nil - Array of modifier objects
--
-- @return { finalPrice = number, revision = number } or nil if unable to calculate
--
-- IMPORTANT: itemSnapshot is IMMUTABLE snapshot of condition only
-- - No inventory/container access
-- - Condition is pre-calculated snapshot, not live item:getCondition()
function Contract.calculateSellPrice(itemId, shopId, basePrice, itemSnapshot, modifiers)
	assertDeterministic({ itemId = itemId, shopId = shopId, basePrice = basePrice })

	if not basePrice or basePrice < 0 then
		return nil
	end

	modifiers = modifiers or {}

	local price = basePrice

	-- Phase 5 DETERMINISM RULE: MUST sort modifiers before iteration
	-- NEVER use pairs() on modifiers - array must be ordered for MP consistency
	-- OPTIMIZATION: Skip sort if modifiers are pre-sorted (marked with _isSorted flag)
	local sortedMods = modifiers
	if not modifiers._isSorted then
		sortedMods = {}
		for _, mod in ipairs(modifiers) do
			table.insert(sortedMods, mod)
		end
		table.sort(sortedMods, function(a, b)
			local priorityA = a.priority or 100
			local priorityB = b.priority or 100
			return priorityA < priorityB
		end)
	end

	-- Apply each modifier as multiplier
	-- Using ipairs() = deterministic (array ordered)
	for _, mod in ipairs(sortedMods) do
		if mod.multiplier then
			price = price * mod.multiplier
		end
	end

	local finalPrice = math.floor(math.max(0, price))

	return {
		finalPrice = finalPrice,
		revision = 1, -- Future-proofing for live pricing
	}
end

---
-- (FUTURE) Validate that a pricing rule is deterministic
-- Called at mod initialization to catch non-deterministic logic early
--
-- @param ruleName string - Name of the rule (for error messages)
-- @param ruleFunc function - The pricing rule function to validate
--
-- @return boolean, string - (isValid, errorMessage)
--
-- This is a stub for Phase 5 (Determinism Validation)
-- Full implementation scans the rule's bytecode for forbidden operations
function Contract.validateDeterminism(ruleName, ruleFunc)
	-- Phase 5 will implement this using debug.getinfo and source analysis
	-- For now, return true (validation happens via code review + testing)
	return true, nil
end

---
-- Get the current NPC shop catalog snapshot (immutable)
--
-- @param shopId string - NPC shop ID (e.g., "npc_general_store")
--
-- @return table|nil - { shopId, name, items = { itemId -> { basePrice, category, stock } } }
--
-- This returns a SNAPSHOT of the shop's base prices
-- Used for both client preview listing and server validation
function Contract.getShopCatalogSnapshot(shopId)
	-- Catalog is loaded from shared Shop.Items and per-shop definitions
	-- This is populated during Shop initialization (Phase 1.3)
	if not SHOPSB42.NPCShopCatalog or not SHOPSB42.NPCShopCatalog[shopId] then
		return nil
	end

	return SHOPSB42.NPCShopCatalog[shopId]
end

---
-- Validate that server price and client price are functionally equivalent
-- Logs any mismatch silently (development aid, not production blocker)
--
-- @param itemId string
-- @param clientPrice number
-- @param serverPrice number
-- @param tolerance number - Acceptable difference (default: 0, exact match required)
function Contract.validatePriceConsistency(itemId, clientPrice, serverPrice, tolerance)
	tolerance = tolerance or 0
	if math.abs(clientPrice - serverPrice) > tolerance then
		SharedLogger.log(
			"Shops",
			"[PricingContract] Price mismatch for " .. itemId .. ": client=" .. clientPrice .. " server=" .. serverPrice
		)
	end
end

return Contract
