Currency = Currency or {}

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
		scale = 15
	},
	SpecialCoin = {
		texture = getTexture("media/textures/Item_EventCoin.png"),
		scale = 15
	},
}

Currency.WalletTexture = {
	Account = {
		texture = getTexture("media/textures/Wallet_Account.png"),
		scale = 15
	},
}

function Currency.format(quantity)
	_, found = string.find(quantity, '%.')
	if found then
		quantity = string.format("%.2f", quantity)
	end
	while true do
		quantity, k = string.gsub(quantity, "^(-?%d+)(%d%d%d)", '%1,%2')
		if (k == 0) then break end
	end
	return quantity
end
