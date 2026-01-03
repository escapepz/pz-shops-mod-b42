-- Food items (declarative list)
-- Returns a table of item definitions to be registered by ShopDefaultItems

local Tab = SHOPSB42.Tab

return {
	{
		id = "Base.Apple",
		config = {
			tab = Tab.Food,
			price = 15,
		},
	},
	{
		id = "Base.OatsRaw",
		config = {
			tab = Tab.Food,
			price = 20,
		},
	},
}
