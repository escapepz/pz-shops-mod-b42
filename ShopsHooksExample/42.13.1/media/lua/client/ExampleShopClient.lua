-- ExampleShopClient.lua
-- Client-side logic for Example Shop mod
-- Handles UI displays and client-side features

require("ExampleShop")

ExampleShopClient = ExampleShopClient or {}

-- ========== UI INFORMATION DISPLAY ==========

-- Get player VIP tier with color coding
function ExampleShopClient.getVIPTierDisplay(reputation)
	local tier = "Standard"
	local color = { r = 0.7, g = 0.7, b = 0.7 } -- Gray

	if reputation >= 500 then
		tier = "Gold"
		color = { r = 1.0, g = 0.84, b = 0.0 } -- Gold
	elseif reputation >= 250 then
		tier = "Silver"
		color = { r = 0.75, g = 0.75, b = 0.75 } -- Silver
	elseif reputation >= 100 then
		tier = "Bronze"
		color = { r = 0.80, g = 0.50, b = 0.20 } -- Bronze
	end

	return { tier = tier, color = color }
end

-- Format price with currency symbol
function ExampleShopClient.formatPrice(price)
	return "$" .. tostring(math.floor(price))
end

-- Get discount display text
function ExampleShopClient.getDiscountText(reputation)
	local discount = 0
	if reputation >= 500 then
		discount = 15
	elseif reputation >= 250 then
		discount = 10
	elseif reputation >= 100 then
		discount = 5
	end

	if discount > 0 then
		return discount .. "% VIP Discount"
	else
		return "No discount"
	end
end

-- ========== SHOP UI ENHANCEMENTS ==========

-- Create a tooltip for shop items showing details
function ExampleShopClient.createItemTooltip(itemId, price)
	local tooltip = ""

	-- Category information
	if string.find(itemId, "Pistol") or string.find(itemId, "Rifle") then
		tooltip = tooltip .. "Category: Weapon\n"
		tooltip = tooltip .. "Markup: +30%\n"
	elseif string.find(itemId, "Rounds") then
		tooltip = tooltip .. "Category: Ammunition\n"
		tooltip = tooltip .. "Markup: +20%\n"
	elseif string.find(itemId, "Apple") or string.find(itemId, "Bread") then
		tooltip = tooltip .. "Category: Food\n"
		tooltip = tooltip .. "Discount: -10%\n"
	end

	tooltip = tooltip .. "Price: " .. ExampleShopClient.formatPrice(price)

	return tooltip
end

-- Display VIP benefits to player
function ExampleShopClient.showVIPBenefits(player)
	if not player then return end

	local reputation = ExampleShop.getPlayerReputation(player)
	local tierInfo = ExampleShopClient.getVIPTierDisplay(reputation)

	local message = "=== VIP Status ===\n"
	message = message .. "Tier: " .. tierInfo.tier .. "\n"
	message = message .. "Reputation: " .. reputation .. "\n"
	message = message .. "Buy Discount: " .. ExampleShopClient.getDiscountText(reputation)

	ExampleShop.log(message)
end

-- ========== TIME-BASED DISPLAY ==========

-- Get current time period name
function ExampleShopClient.getTimePeriod()
	local hour = getGameTime():getHour()

	if hour >= 6 and hour < 10 then
		return "Morning (6 AM - 10 AM): Prices -5%"
	elseif hour >= 18 and hour < 23 then
		return "Evening (6 PM - 11 PM): Prices +10%"
	elseif hour >= 23 or hour < 6 then
		return "Night (11 PM - 6 AM): Prices +15%"
	else
		return "Standard prices"
	end
end

-- ========== ITEM BROWSER ==========

-- Get all available items in shop
function ExampleShopClient.getBuyItems()
	return {
		fruits = { "Base.Apple", "Base.Banana", "Base.Orange" },
		bread = { "Base.Bread" },
		drinks = { "Base.Pop", "Base.Water" },
		canned = { "Base.CannedApple", "Base.CannedBellPeppers", "Base.CannedCarrot", "Base.CannedChili" },
		firstaid = { "Base.Bandage", "Base.Painkiller", "Base.Antibiotic", "Base.Disinfectant" },
		tools = { "Base.Flashlight", "Base.Rope", "Base.Hammer", "Base.Screwdriver" },
		weapons = { "Base.Handgun", "Base.Pistol", "Base.Revolver", "Base.AssaultRifle", "Base.HuntingRifle" },
		ammo = { "Base.223Rounds", "Base.762mmRounds", "Base.9mmRounds", "Base.ShotgunShells" },
	}
end

-- Get category name for display
function ExampleShopClient.getCategoryName(category)
	local names = {
		fruits = "Fresh Fruits",
		bread = "Bread",
		drinks = "Beverages",
		canned = "Canned Goods",
		firstaid = "First Aid",
		tools = "Tools & Equipment",
		weapons = "Weapons",
		ammo = "Ammunition",
	}
	return names[category] or category
end

-- ========== INITIALIZATION ==========

ExampleShop.log("Client module loaded")

return ExampleShopClient
