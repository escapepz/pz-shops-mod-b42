-- Currency.lua
-- Currency and wallet configuration
-- Extends SHOPSB42 namespace (no new globals)

SHOPSB42.Currency = SHOPSB42.Currency or {}
local Currency = SHOPSB42.Currency

Currency.Wallets = Currency.Wallets or {}
Currency.Wallets["Base.Wallet"] = true
Currency.Wallets["Base.Wallet_Female"] = true
Currency.Wallets["Base.Wallet_Male"] = true
Currency.Wallets["Base.Wallet_Hide"] = true

Currency.BaseCoin = "Shops.CopperCoin"
Currency.SpecialCoin = "Shops.EventCoin"
Currency.UseSpecialCoin = true

Currency.Coins = Currency.Coins or {}
Currency.Coins[Currency.SpecialCoin] = { value = 0, specialCoin = true }
Currency.Coins[Currency.BaseCoin] = { value = 1 }
Currency.Coins["Shops.SilverCoin"] = { value = 250 }
Currency.Coins["Shops.GoldCoin"] = { value = 500 }

Currency.CoinsTexture = {
	Coin = {
		texture = getTexture("media/textures/Item_CopperCoin.png"),
		scale = 15,
	},
	SpecialCoin = {
		texture = getTexture("media/textures/Item_EventCoin.png"),
		scale = 15,
	},
}

Currency.WalletTexture = {
	Account = {
		texture = getTexture("media/textures/Wallet_Account.png"),
		scale = 15,
	},
}

function Currency.format(quantity)
	-- Convert to string and ensure proper type
	quantity = tostring(quantity)

	-- Extract sign if negative
	local sign = ""
	if string.sub(quantity, 1, 1) == "-" then
		sign = "-"
		quantity = string.sub(quantity, 2)
	end

	-- Split integer and decimal parts
	local integerPart, decimalPart = string.match(quantity, "^(%d+)(.*)$")
	if not integerPart then
		integerPart = "0"
		decimalPart = ""
	end

	-- Add thousands separators (right to left)
	integerPart = integerPart:reverse()
	integerPart = integerPart:gsub("(%d%d%d)", "%1,")
	integerPart = integerPart:reverse()
	integerPart = integerPart:gsub("^,", "") -- Remove leading comma

	-- Ensure 2 decimal places
	if decimalPart == "" or decimalPart == "." then
		decimalPart = ".00"
	else
		decimalPart = string.format("%.2f", tonumber("0" .. decimalPart)):sub(2)
	end

	return sign .. integerPart .. decimalPart
end

return Currency
