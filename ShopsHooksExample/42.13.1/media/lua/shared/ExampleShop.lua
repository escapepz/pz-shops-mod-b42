-- ExampleShop.lua
-- Complete example mod demonstrating Shop hook system
-- Features: Custom items, dynamic pricing, VIP system, time-based sales

-- Ensure shop modules are loaded
require("ShopEvents")
require("ShopSellEvents")
require("ShopPriceEvents")
require("ShopRegistry")
require("ShopSellRegistry")

ExampleShop = ExampleShop or {}
ExampleShop.VERSION = "1.0"
ExampleShop.CONFIG = {
	enableVIPSystem = true,
	enableTimedSales = true,
	enableBulkDiscounts = true,
	debugLogging = true,
}

-- ========== UTILITY FUNCTIONS ==========

function ExampleShop.log(message)
	if ExampleShop.CONFIG.debugLogging then
		writeLog("ShopsHooksExample", "[ExampleShop] " .. message)
	end
end

function ExampleShop.getPlayerReputation(player)
	if not player then return 0 end
	return player:getProperty("exampleshop_reputation") or 0
end

function ExampleShop.setPlayerReputation(player, value)
	if player then
		player:setProperty("exampleshop_reputation", value)
	end
end

function ExampleShop.addPlayerReputation(player, amount)
	if player then
		local current = ExampleShop.getPlayerReputation(player)
		ExampleShop.setPlayerReputation(player, current + amount)
	end
end

-- ========== ITEM REGISTRATION ==========

-- Register buy items
function ExampleShop.registerBuyItems()
	ExampleShop.log("Registering buy items...")

	-- Food and Supplies (Tier 1)
	Shop.RegisterItem("Base.Apple", { tab = Tab.Food, price = 12 })
	Shop.RegisterItem("Base.Banana", { tab = Tab.Food, price = 15 })
	Shop.RegisterItem("Base.Orange", { tab = Tab.Food, price = 18 })
	Shop.RegisterItem("Base.Bread", { tab = Tab.Food, price = 35 })
	Shop.RegisterItem("Base.Pop", { tab = Tab.Food, price = 20 })
	Shop.RegisterItem("Base.Water", { tab = Tab.Food, price = 15 })

	-- Canned Goods (Tier 1)
	Shop.RegisterItem("Base.CannedApple", { tab = Tab.Food, price = 40 })
	Shop.RegisterItem("Base.CannedBellPeppers", { tab = Tab.Food, price = 45 })
	Shop.RegisterItem("Base.CannedCarrot", { tab = Tab.Food, price = 40 })
	Shop.RegisterItem("Base.CannedChili", { tab = Tab.Food, price = 55 })

	-- First Aid (Tier 2)
	Shop.RegisterItem("Base.Bandage", { tab = Tab.FirstAid, price = 25 })
	Shop.RegisterItem("Base.Painkiller", { tab = Tab.FirstAid, price = 35 })
	Shop.RegisterItem("Base.Antibiotic", { tab = Tab.FirstAid, price = 55 })
	Shop.RegisterItem("Base.Disinfectant", { tab = Tab.FirstAid, price = 30 })

	-- Tools and Equipment (Tier 2)
	Shop.RegisterItem("Base.Flashlight", { tab = Tab.All, price = 45 })
	Shop.RegisterItem("Base.Rope", { tab = Tab.All, price = 50 })
	Shop.RegisterItem("Base.Hammer", { tab = Tab.All, price = 60 })
	Shop.RegisterItem("Base.Screwdriver", { tab = Tab.All, price = 40 })

	-- Weapons (Tier 3)
	Shop.RegisterItem("Base.Handgun", { tab = Tab.Weapons, price = 400 })
	Shop.RegisterItem("Base.Pistol", { tab = Tab.Weapons, price = 450 })
	Shop.RegisterItem("Base.Revolver", { tab = Tab.Weapons, price = 500 })
	Shop.RegisterItem("Base.AssaultRifle", { tab = Tab.Weapons, price = 800 })
	Shop.RegisterItem("Base.HuntingRifle", { tab = Tab.Weapons, price = 600 })

	-- Ammunition (Tier 3)
	Shop.RegisterItem("Base.223Rounds", { tab = Tab.Weapons, price = 100 })
	Shop.RegisterItem("Base.762mmRounds", { tab = Tab.Weapons, price = 120 })
	Shop.RegisterItem("Base.9mmRounds", { tab = Tab.Weapons, price = 80 })
	Shop.RegisterItem("Base.ShotgunShells", { tab = Tab.Weapons, price = 150 })

	ExampleShop.log("Registered " .. "25" .. " buy items")
end

-- Register sell items (items players can sell to the shop)
function ExampleShop.registerSellItems()
	ExampleShop.log("Registering sell items...")

	-- Enable whitelist mode: ONLY registered items can be sold (all others are blacklisted)
	Shop.SellisWhitelist = true
	ExampleShop.log("Whitelist mode enabled - only registered items can be sold")

	-- Food and Supplies (50% of buy price)
	Shop.RegisterSellItem("Base.Apple", { price = 6 })
	Shop.RegisterSellItem("Base.Banana", { price = 8 })
	Shop.RegisterSellItem("Base.Orange", { price = 9 })
	Shop.RegisterSellItem("Base.Bread", { price = 18 })
	Shop.RegisterSellItem("Base.Pop", { price = 10 })
	Shop.RegisterSellItem("Base.Water", { price = 8 })

	-- Canned Goods (50% of buy price)
	Shop.RegisterSellItem("Base.CannedApple", { price = 20 })
	Shop.RegisterSellItem("Base.CannedBellPeppers", { price = 22 })
	Shop.RegisterSellItem("Base.CannedCarrot", { price = 20 })
	Shop.RegisterSellItem("Base.CannedChili", { price = 28 })

	-- First Aid (40% of buy price)
	Shop.RegisterSellItem("Base.Bandage", { price = 10 })
	Shop.RegisterSellItem("Base.Painkiller", { price = 14 })
	Shop.RegisterSellItem("Base.Antibiotic", { price = 22 })
	Shop.RegisterSellItem("Base.Disinfectant", { price = 12 })

	-- Tools and Equipment (30% of buy price)
	Shop.RegisterSellItem("Base.Flashlight", { price = 14 })
	Shop.RegisterSellItem("Base.Rope", { price = 15 })
	Shop.RegisterSellItem("Base.Hammer", { price = 18 })
	Shop.RegisterSellItem("Base.Screwdriver", { price = 12 })

	-- Weapons (25% of buy price)
	Shop.RegisterSellItem("Base.Handgun", { price = 100 })
	Shop.RegisterSellItem("Base.Pistol", { price = 112 })
	Shop.RegisterSellItem("Base.Revolver", { price = 125 })
	Shop.RegisterSellItem("Base.AssaultRifle", { price = 200 })
	Shop.RegisterSellItem("Base.HuntingRifle", { price = 150 })

	-- Blacklist (items that cannot be sold)
	Shop.RegisterSellItem("Base.KeyRing", { blacklisted = true })

	ExampleShop.log("Registered 25 sell items + 1 blacklisted item")
end

-- ========== BUY PRICE MODIFICATIONS ==========

-- Apply category-based markup
function ExampleShop.modifyBuyPriceByCategory(player, itemId, base, context, modifiers)
	writeLog("ShopsHooksExample", "[Hook] modifyBuyPriceByCategory called: " .. itemId .. " (base: " .. base .. ")")
	ExampleShop.log("modifyBuyPriceByCategory: " .. itemId .. " (base: " .. base .. ")")

	-- Weapon category: +30% markup
	if string.find(itemId, "Handgun") or string.find(itemId, "Pistol") or
		string.find(itemId, "Revolver") or string.find(itemId, "Rifle") then
		table.insert(modifiers, { multiplier = 1.3, label = "weaponMarkup" })
		ExampleShop.log("  -> Weapon markup 1.3x applied")
	end

	-- Ammunition category: +20% markup
	if string.find(itemId, "Rounds") or string.find(itemId, "Shells") then
		table.insert(modifiers, { multiplier = 1.2, label = "ammoMarkup" })
		ExampleShop.log("  -> Ammo markup 1.2x applied")
	end

	-- Food category: -10% discount
	if string.find(itemId, "Apple") or string.find(itemId, "Banana") or
		string.find(itemId, "Orange") or string.find(itemId, "Bread") or
		string.find(itemId, "Canned") then
		table.insert(modifiers, { multiplier = 0.9, label = "foodDiscount" })
		ExampleShop.log("  -> Food discount 0.9x applied")
	end

	-- First Aid category: +15% markup
	if string.find(itemId, "Bandage") or string.find(itemId, "Painkiller") or
		string.find(itemId, "Antibiotic") or string.find(itemId, "Disinfectant") then
		table.insert(modifiers, { multiplier = 1.15, label = "medicalMarkup" })
		ExampleShop.log("  -> Medical markup 1.15x applied")
	end
end

-- Apply time-based pricing
function ExampleShop.modifyBuyPriceByTime(player, itemId, base, context, modifiers)
	if not ExampleShop.CONFIG.enableTimedSales then return end

	writeLog("ShopsHooksExample", "[Hook] modifyBuyPriceByTime called: " .. itemId)
	local currentHour = getGameTime():getHour()

	-- Morning discount (6 AM - 10 AM): -5%
	if currentHour >= 6 and currentHour < 10 then
		table.insert(modifiers, { multiplier = 0.95, label = "morningDiscount" })
		ExampleShop.log("Morning discount applied")
	end

	-- Evening premium (6 PM - 11 PM): +10%
	if currentHour >= 18 and currentHour < 23 then
		table.insert(modifiers, { multiplier = 1.1, label = "eveningPremium" })
		ExampleShop.log("Evening premium applied")
	end

	-- Night premium (11 PM - 6 AM): +15%
	if currentHour >= 23 or currentHour < 6 then
		table.insert(modifiers, { multiplier = 1.15, label = "nightPremium" })
		ExampleShop.log("Night premium applied")
	end
end

-- Apply VIP discounts
function ExampleShop.modifyBuyPriceVIP(player, itemId, base, context, modifiers)
	if not ExampleShop.CONFIG.enableVIPSystem or not player then return end

	local reputation = ExampleShop.getPlayerReputation(player)

	-- Bronze VIP (100+ reputation): -5%
	if reputation >= 100 and reputation < 250 then
		table.insert(modifiers, { multiplier = 0.95, label = "vipBronze" })
		ExampleShop.log("VIP Bronze discount applied (reputation: " .. reputation .. ")")
	end

	-- Silver VIP (250+ reputation): -10%
	if reputation >= 250 and reputation < 500 then
		table.insert(modifiers, { multiplier = 0.9, label = "vipSilver" })
		ExampleShop.log("VIP Silver discount applied (reputation: " .. reputation .. ")")
	end

	-- Gold VIP (500+ reputation): -15%
	if reputation >= 500 then
		table.insert(modifiers, { multiplier = 0.85, label = "vipGold" })
		ExampleShop.log("VIP Gold discount applied (reputation: " .. reputation .. ")")
	end
end

-- Apply bulk discount
function ExampleShop.modifyBuyPriceByBulk(player, itemId, base, context, modifiers)
	if not ExampleShop.CONFIG.enableBulkDiscounts or not player then return end

	-- Check if player already has this item
	if player:getInventory() then
		local count = player:getInventory():getItemCount(itemId)

		if count >= 10 then
			table.insert(modifiers, { multiplier = 0.85, label = "bulkDiscount" })
			ExampleShop.log("Bulk discount applied (count: " .. count .. ")")
		elseif count >= 5 then
			table.insert(modifiers, { multiplier = 0.9, label = "bulkDiscount" })
		end
	end
end

-- ========== BUY PRICE OVERRIDES ==========

-- Fixed prices for special items
function ExampleShop.overrideBuyPriceSpecialItems(player, itemId, price, context)
	local specialPrices = {
		["Base.Water"] = 10, -- Always cheap
		["Base.Pop"] = 15, -- Always fixed
	}

	if specialPrices[itemId] then
		ExampleShop.log("Override: " .. itemId .. " -> " .. specialPrices[itemId])
		return specialPrices[itemId]
	end

	return nil -- Use calculated price
end

-- Admin free items
function ExampleShop.overrideBuyPriceAdmin(player, itemId, price, context)
	-- Admin check disabled in example - uncomment if you implement proper admin system
	-- if player and player:isAccessLevel("admin") then
	-- 	ExampleShop.log("Admin override: " .. itemId .. " is free")
	-- 	return 0 -- Free for admins
	-- end
	return nil
end

-- ========== SELL PRICE MODIFICATIONS ==========

-- Modify sell price by item condition
function ExampleShop.modifySellPriceByCondition(player, item, base, context, modifiers)
	if not item then return end

	local condition = item:getCondition()
	ExampleShop.log("modifySellPriceByCondition: " .. item:getID() .. " condition=" .. condition .. " base=" .. base)

	if condition < 25 then
		table.insert(modifiers, { multiplier = 0.2, label = "conditionBad" })
		ExampleShop.log("  -> Poor condition (0.2x multiplier)")
	elseif condition < 50 then
		table.insert(modifiers, { multiplier = 0.5, label = "conditionFair" })
		ExampleShop.log("  -> Fair condition (0.5x multiplier)")
	elseif condition < 75 then
		table.insert(modifiers, { multiplier = 0.85, label = "conditionGood" })
		ExampleShop.log("  -> Good condition (0.85x multiplier)")
	else
		table.insert(modifiers, { multiplier = 1.0, label = "conditionExcellent" })
		ExampleShop.log("  -> Excellent condition (1.0x multiplier)")
	end
end

-- Modify sell price by quantity (bulk seller bonus)
function ExampleShop.modifySellPriceByQuantity(player, item, base, context, modifiers)
	if not player or not player:getInventory() then return end

	local count = player:getInventory():getItemCount(item:getID())

	if count > 20 then
		table.insert(modifiers, { multiplier = 1.1, label = "bulkSeller" })
		ExampleShop.log("Bulk seller bonus applied (count: " .. count .. ")")
	elseif count > 10 then
		table.insert(modifiers, { multiplier = 1.05, label = "bulkSeller" })
	end
end

-- Modify sell price by reputation
function ExampleShop.modifySellPriceByReputation(player, item, base, context, modifiers)
	if not ExampleShop.CONFIG.enableVIPSystem or not player then return end

	local reputation = ExampleShop.getPlayerReputation(player)

	if reputation > 500 then
		table.insert(modifiers, { multiplier = 1.15, label = "loyaltyGold" })
		ExampleShop.log("Gold loyalty bonus applied")
	elseif reputation > 250 then
		table.insert(modifiers, { multiplier = 1.1, label = "loyaltysilver" })
		ExampleShop.log("Silver loyalty bonus applied")
	elseif reputation > 100 then
		table.insert(modifiers, { multiplier = 1.05, label = "loyaltyBronze" })
		ExampleShop.log("Bronze loyalty bonus applied")
	end
end

-- ========== SELL ITEM REGISTRATION HOOKS ==========

-- Allow mods to modify what items can be sold
function ExampleShop.onRegisterSellItems()
	ExampleShop.log("Hook: onRegisterSellItems called")
	-- This is called when sell items are being registered
	-- Can be used to dynamically add/remove sellable items
end

-- ========== PRICE HOOK VERIFICATION ==========

-- Test function to verify price hooks are working
function ExampleShop.testPriceHooks()
	ExampleShop.log("=== Testing Buy Price Hooks ===")

	-- Get a test player
	local testPlayer = getPlayer()
	if not testPlayer then
		ExampleShop.log("WARNING: No player available for testing")
		return
	end

	-- Test context
	local context = {
		shopId = "ExampleShop",
		quantity = 1,
		isSpecialCoin = false,
		isBroken = false,
	}

	-- Test items with different categories to verify each hook
	local testItems = {
		{
			id = "Base.Apple",
			name = "Food (foodDiscount: -10%)",
		},
		{
			id = "Base.Handgun",
			name = "Weapon (weaponMarkup: +30%)",
		},
		{
			id = "Base.Bandage",
			name = "Medical (medicalMarkup: +15%)",
		},
		{
			id = "Base.223Rounds",
			name = "Ammo (ammoMarkup: +20%)",
		},
	}

	ExampleShop.log("Registered price hooks: " .. #ShopPriceEvents.OnShopModifyBuyPrice .. " modify + " ..
		#ShopPriceEvents.OnShopOverrideBuyPrice .. " override")
	ExampleShop.log("Testing " .. #testItems .. " items:")

	for _, testItem in ipairs(testItems) do
		local item = Shop.Items[testItem.id]
		if item then
			local basePrice = item.price
			ExampleShop.log("DEBUG: Calling Shop.resolvePlayerBuyPrice for " .. testItem.id)
			local finalPrice = Shop.resolvePlayerBuyPrice(testPlayer, testItem.id, context)
			ExampleShop.log("DEBUG: Result = " .. tostring(finalPrice))
			if not finalPrice then finalPrice = basePrice end

			local priceDiff = finalPrice - basePrice
			local pct = 0
			if basePrice > 0 then
				pct = math.floor((priceDiff / basePrice) * 100)
			end

			local direction = priceDiff > 0 and "+" or ""
			ExampleShop.log(string.format("  [%s] %s: %d -> %d (%s%d%%) - %s",
				item.tab or "?", testItem.id, basePrice, finalPrice, direction, pct, testItem.name))
		else
			ExampleShop.log("  [!] " .. testItem.id .. " NOT FOUND")
		end
	end

	ExampleShop.log("=== Test Complete ===")
end

-- ========== SELL PRICE OVERRIDES ==========

-- Don't buy damaged weapons
function ExampleShop.overrideSellPriceDamaged(player, item, price, context)
	if not item then return nil end

	local itemId = item:getID()
	local condition = item:getCondition()

	-- Weapons must be in decent condition
	if (string.find(itemId, "Pistol") or string.find(itemId, "Rifle") or
			string.find(itemId, "Handgun")) and condition < 30 then
		ExampleShop.log("Rejecting damaged weapon: " .. itemId)
		return 0 -- Won't buy
	end

	return nil -- Use calculated price
end

-- Premium weapons get fixed prices
function ExampleShop.overrideSellPricePremium(player, item, price, context)
	if not item then return nil end

	local itemId = item:getID()
	local premiumPrices = {
		["Base.AssaultRifle"] = 150,
		["Base.HuntingRifle"] = 120,
		["Base.Pistol"] = 75,
	}

	if premiumPrices[itemId] then
		ExampleShop.log("Premium override: " .. itemId .. " -> " .. premiumPrices[itemId])
		return premiumPrices[itemId]
	end

	return nil
end

-- ========== HOOK REGISTRATION ==========

function ExampleShop.registerHooks()
	ExampleShop.log("Registering hooks...")
	ExampleShop.log("ShopEvents available: " .. tostring(ShopEvents ~= nil))
	ExampleShop.log("ShopPriceEvents available: " .. tostring(ShopPriceEvents ~= nil))

	-- Register item registration hook
	if ShopEvents and ShopEvents.registerOnShopRegisterItems then
		ShopEvents.registerOnShopRegisterItems(ExampleShop.registerBuyItems)
		ExampleShop.log("Registered OnShopRegisterItems")
	else
		ExampleShop.log("WARNING: ShopEvents.registerOnShopRegisterItems not found!")
	end

	-- Register sell item registration hook
	if ShopSellEvents and ShopSellEvents.registerOnShopRegisterSellItems then
		ShopSellEvents.registerOnShopRegisterSellItems(ExampleShop.registerSellItems)
		ExampleShop.log("Registered OnShopRegisterSellItems")
	end

	-- Register buy price modification hooks
	if ShopPriceEvents and ShopPriceEvents.registerOnShopModifyBuyPrice then
		ShopPriceEvents.registerOnShopModifyBuyPrice(ExampleShop.modifyBuyPriceByCategory)
		ShopPriceEvents.registerOnShopModifyBuyPrice(ExampleShop.modifyBuyPriceByTime)
		ShopPriceEvents.registerOnShopModifyBuyPrice(ExampleShop.modifyBuyPriceVIP)
		ShopPriceEvents.registerOnShopModifyBuyPrice(ExampleShop.modifyBuyPriceByBulk)
		ExampleShop.log("Registered OnShopModifyBuyPrice hooks (4x)")
		ExampleShop.log("Total buy modify hooks: " .. #ShopPriceEvents.OnShopModifyBuyPrice)
	else
		ExampleShop.log("WARNING: ShopPriceEvents.registerOnShopModifyBuyPrice not found!")
	end

	-- Register buy price override hooks
	if ShopPriceEvents and ShopPriceEvents.registerOnShopOverrideBuyPrice then
		ShopPriceEvents.registerOnShopOverrideBuyPrice(ExampleShop.overrideBuyPriceSpecialItems)
		ShopPriceEvents.registerOnShopOverrideBuyPrice(ExampleShop.overrideBuyPriceAdmin)
		ExampleShop.log("Registered OnShopOverrideBuyPrice hooks (2x)")
		ExampleShop.log("Total buy override hooks: " .. #ShopPriceEvents.OnShopOverrideBuyPrice)
	else
		ExampleShop.log("WARNING: ShopPriceEvents.registerOnShopOverrideBuyPrice not found!")
	end

	-- Register sell price modification hooks
	if ShopPriceEvents and ShopPriceEvents.registerOnShopModifySellPrice then
		ShopPriceEvents.registerOnShopModifySellPrice(ExampleShop.modifySellPriceByCondition)
		ShopPriceEvents.registerOnShopModifySellPrice(ExampleShop.modifySellPriceByQuantity)
		ShopPriceEvents.registerOnShopModifySellPrice(ExampleShop.modifySellPriceByReputation)
		ExampleShop.log("Registered OnShopModifySellPrice hooks (3x)")
		ExampleShop.log("Total sell modify hooks: " .. #ShopPriceEvents.OnShopModifySellPrice)
	else
		ExampleShop.log("WARNING: ShopPriceEvents.registerOnShopModifySellPrice not found!")
	end

	-- Register sell price override hooks
	if ShopPriceEvents and ShopPriceEvents.registerOnShopOverrideSellPrice then
		ShopPriceEvents.registerOnShopOverrideSellPrice(ExampleShop.overrideSellPriceDamaged)
		ShopPriceEvents.registerOnShopOverrideSellPrice(ExampleShop.overrideSellPricePremium)
		ExampleShop.log("Registered OnShopOverrideSellPrice hooks (2x)")
		ExampleShop.log("Total sell override hooks: " .. #ShopPriceEvents.OnShopOverrideSellPrice)
	else
		ExampleShop.log("WARNING: ShopPriceEvents.registerOnShopOverrideSellPrice not found!")
	end

	-- Register sell item registration hook
	if ShopSellEvents and ShopSellEvents.registerOnShopRegisterSellItems then
		ShopSellEvents.registerOnShopRegisterSellItems(ExampleShop.onRegisterSellItems)
		ExampleShop.log("Registered OnShopRegisterSellItems hook")
	end

	ExampleShop.log("All hooks registered successfully!")
end

-- ========== INITIALIZATION ==========

-- Auto-initialize on load
ExampleShop.registerHooks()

-- Force immediate finalization if shop is already locked (means it wasn't finalized with hooks)
if Shop._locked then
	ExampleShop.log("WARNING: Shop already finalized without hooks! Items won't show.")
else
	ExampleShop.log("Shop not yet finalized, hooks will be called on OnServerStarted")
end

return ExampleShop
