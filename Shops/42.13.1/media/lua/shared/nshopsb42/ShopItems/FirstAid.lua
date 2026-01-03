-- FirstAid items (declarative list)
-- Returns a table of item definitions to be registered by ShopDefaultItems

local Tab = SHOPSB42.Tab

return {
	{
		id = "Shops.SurvivalPack",
		config = {
			tab = Tab.FirstAid,
			price = 100,
			isVirtualBundle = true,
			items = {
				{ item = "Base.Antibiotics" },
				{ item = "Base.PillsBeta" },
				{ item = "Base.Bandaid", quantity = 5 },
			},
		},
	},
	{
		id = "Base.Bandaid",
		config = {
			tab = Tab.FirstAid,
			price = 15,
		},
	},
}
