-- Event items (declarative list)
-- Returns a table of item definitions to be registered by ShopDefaultItems

local Tab = SHOPSB42.Tab

return {
	{
		id = "Base.HairDyeBlonde",
		config = {
			tab = Tab.Event,
			price = 5,
			specialCoin = true,
		},
	},
	{
		id = "Base.Bag_BigHikingBag",
		config = {
			tab = Tab.Event,
			price = 5,
			specialCoin = true,
		},
	},
	{
		id = "Base.Chocolate_HeartBox",
		config = {
			tab = Tab.Event,
			price = 5,
			specialCoin = true,
		},
	},
}
