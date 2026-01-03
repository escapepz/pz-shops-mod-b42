-- listings/misc/valuables.lua
-- Valuables: rare items, collectibles, high-value goods
-- No tab "Valuables" defined, it will nerver showing in NPC Shop UI

return {
	buy = {
		{
			id = "Base.Gold",
			tab = "Valuables",
			price = 100,
			notes = "Gold bar",
		},
		{
			id = "Base.Necklace",
			tab = "Valuables",
			price = 50,
			notes = "Gold necklace",
		},
		{
			id = "Base.Ring",
			tab = "Valuables",
			price = 40,
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
