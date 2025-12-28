-- ExampleShopServer.lua
-- Server-side logic for Example Shop mod
-- Handles reputation tracking and transaction logging

require("ExampleShop")

ExampleShopServer = ExampleShopServer or {}

-- ========== TRANSACTION LOGGING ==========

-- Log purchase transactions
function ExampleShopServer.onPlayerBuyFromShop(player, itemId, quantity, price)
	if not player then return end

	ExampleShop.log("Player " .. player:getUsername() .. " bought " .. quantity .. "x " .. itemId .. " for " .. price)

	-- Award reputation for any purchase
	if ExampleShop.CONFIG.enableVIPSystem then
		ExampleShop.addPlayerReputation(player, quantity * 1) -- 1 rep per item
	end
end

-- Log sell transactions
function ExampleShopServer.onPlayerSellToShop(player, itemId, quantity, totalPrice)
	if not player then return end

	ExampleShop.log("Player " .. player:getUsername() .. " sold " .. quantity .. "x " .. itemId .. " for " .. totalPrice)

	-- Award reputation for selling
	if ExampleShop.CONFIG.enableVIPSystem then
		ExampleShop.addPlayerReputation(player, quantity * 2) -- 2 rep per item sold
	end
end

-- ========== REPUTATION SYSTEM ==========

-- Get VIP tier name
function ExampleShopServer.getVIPTierName(reputation)
	if reputation >= 500 then
		return "Gold"
	elseif reputation >= 250 then
		return "Silver"
	elseif reputation >= 100 then
		return "Bronze"
	else
		return "Standard"
	end
end

-- Get player shop stats
function ExampleShopServer.getPlayerShopStats(player)
	if not player then return nil end

	local reputation = ExampleShop.getPlayerReputation(player)
	local tier = ExampleShopServer.getVIPTierName(reputation)

	return {
		username = player:getUsername(),
		reputation = reputation,
		vipTier = tier,
		buyDiscount = ExampleShopServer.getBuyDiscount(reputation),
		sellBonus = ExampleShopServer.getSellBonus(reputation),
	}
end

-- Get buy discount percentage for reputation level
function ExampleShopServer.getBuyDiscount(reputation)
	if reputation >= 500 then
		return 15 -- 15% discount
	elseif reputation >= 250 then
		return 10 -- 10% discount
	elseif reputation >= 100 then
		return 5 -- 5% discount
	else
		return 0 -- No discount
	end
end

-- Get sell bonus percentage for reputation level
function ExampleShopServer.getSellBonus(reputation)
	if reputation >= 500 then
		return 15 -- 15% bonus
	elseif reputation >= 250 then
		return 10 -- 10% bonus
	elseif reputation >= 100 then
		return 5 -- 5% bonus
	else
		return 0 -- No bonus
	end
end

-- Print player stats to console (admin command)
function ExampleShopServer.printPlayerStats(username)
	-- This would need to be called with actual player object
	-- Used for debugging/admin purposes
	ExampleShop.log("Player stats requested for: " .. username)
end

-- ========== INITIALIZATION ==========

ExampleShop.log("Server module loaded")

-- Force finalization since OnServerStarted may have already fired
ExampleShop.log("Finalizing registry now")
if not Shop._locked then
	Shop.FinalizeRegistry()
	ExampleShop.log("Buy registry finalized")
else
	ExampleShop.log("Buy registry already finalized")
end

if not Shop._sellLocked then
	Shop.FinalizeSellRegistry()
	ExampleShop.log("Sell registry finalized")
else
	ExampleShop.log("Sell registry already finalized")
end

-- Test price hooks after a short delay
-- Schedules test to run on next game update when player is definitely available
local priceHooksTested = false

function ExampleShopServer.testPriceHooksDelayed()
	if priceHooksTested then return end
	if not getPlayer() then return end

	ExampleShop.log("Testing price hooks with player available...")
	ExampleShop.testPriceHooks()
	priceHooksTested = true
end

if Events and Events.OnTick then
	Events.OnTick.Add(ExampleShopServer.testPriceHooksDelayed)
	ExampleShop.log("Registered OnTick for delayed price hook testing")
else
	ExampleShop.log("WARNING: Events.OnTick not available")
end

return ExampleShopServer
