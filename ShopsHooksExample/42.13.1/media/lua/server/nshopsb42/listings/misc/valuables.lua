-- listings/misc/valuables.lua
-- Valuables: rare items, collectibles, high-value goods

return {
	buy = {
		{
			id = "Base.Gold",
			tab = "Valuables",
			price = 100,
			stock = 5,
			notes = "Gold bar",
		},
		{
			id = "Base.Necklace",
			tab = "Valuables",
			price = 50,
			stock = 10,
			notes = "Gold necklace",
		},
		{
			id = "Base.Ring",
			tab = "Valuables",
			price = 40,
			stock = 15,
			notes = "Gold ring",
		},
	},

	sell = {
		{
			id = "Base.Gold",
			price = 50,
		},
		{
			id = "Base.Necklace",
			price = 25,
		},
		{
			id = "Base.Ring",
			price = 20,
		},
	},
}
