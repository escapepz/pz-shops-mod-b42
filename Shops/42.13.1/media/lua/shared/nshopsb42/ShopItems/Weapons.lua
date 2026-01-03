-- Weapons items (declarative list)
-- Returns a table of item definitions to be registered by ShopDefaultItems

local Tab = SHOPSB42.Tab

return {
	{
		id = "Base.Crowbar",
		config = {
			tab = Tab.Weapons,
			price = 250,
		},
	},
}
