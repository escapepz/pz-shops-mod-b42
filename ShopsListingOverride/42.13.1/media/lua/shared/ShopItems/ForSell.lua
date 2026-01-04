-- ForSell.lua
-- Default sell items registry - loaded only if no external sell hooks register items

Shop.RegisterSellItem("Base.KeyRing", {
	blacklisted = true
})

Shop.RegisterSellItem("Base.BaseballBat", {
	price = 50
})

Shop.RegisterSellItem("Base.CreditCard", {
	price = 1,
	specialCoin = true
})

Shop.RegisterSellItem("Base.PillsBeta", {
	price = 50
})
