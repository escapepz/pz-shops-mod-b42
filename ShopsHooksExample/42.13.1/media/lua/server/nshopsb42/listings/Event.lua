-- Event items registration (SERVER ONLY)
-- Deferred to avoid errors if Shop.RegisterItem not yet defined

return {
	buy = {
		{
			id = "Base.Chocolate_HeartBox",
			tab = "Event",
			price = 5,
			specialCoin = true,
		},
		{
			id = "Shops.SurvivalPack",
			tab = "Event",
			price = 100,
			specialCoin = true,
			isVirtualBundle = true, -- Mark as bundle
			items = { -- Contents
				{ item = "Base.Antibiotics" },
				{ item = "Base.PillsBeta" },
				{ item = "Base.Bandaid", quantity = 50 },
			},
		},
	},
	sell = {},
}
