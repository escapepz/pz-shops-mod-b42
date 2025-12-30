-- ForSell.lua (SERVER ONLY)
-- Default sell items registry - loaded only if no external sell hooks register items
-- Deferred to avoid errors if Shop.RegisterSellItem not yet defined

if not isServer() then
	return
end

local Shop = SHOPSB42.Shop
if Shop and Shop.RegisterSellItem then
	Shop.RegisterSellItem("Base.KeyRing", {
		blacklisted = true,
	})

	Shop.RegisterSellItem("Base.BaseballBat", {
		price = 50,
	})

	Shop.RegisterSellItem("Base.CreditCard", {
		price = 1,
		specialCoin = true,
	})

	Shop.RegisterSellItem("Base.PillsBeta", {
		price = 50,
	})
end
