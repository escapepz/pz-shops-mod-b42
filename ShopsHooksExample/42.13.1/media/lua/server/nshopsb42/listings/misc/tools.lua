-- listings/misc/tools.lua
-- Tools: building, crafting, utility items
-- No tab "Tools" defined, it will nerver showing in NPC Shop UI till defined

return {
	buy = {
		{
			id = "Base.Hammer",
			tab = "Tools",
			price = 15,
			notes = "Claw hammer",
		},
		{
			id = "Base.Screwdriver",
			tab = "Tools",
			price = 4,
			notes = "Flathead screwdriver",
		},
		{
			id = "Base.Wrench",
			tab = "Tools",
			price = 8,
			notes = "Adjustable wrench",
		},
		{
			id = "Base.Saw",
			tab = "Tools",
			price = 12,
			notes = "Hand saw",
		},
		{
			id = "Base.PlankNail",
			tab = "Tools",
			price = 1,
			notes = "Nails (bundle)",
		},
		{
			id = "Base.WoodPlank",
			tab = "Tools",
			price = 5,
			notes = "Wood plank",
		},
	},

	sell = {
		{
			id = "Base.Hammer",
			price = 7,
		},
		{
			id = "Base.Screwdriver",
			price = 2,
		},
		{
			id = "Base.Wrench",
			price = 4,
		},
		{
			id = "Base.Saw",
			price = 6,
		},
		{
			id = "Base.PlankNail",
			price = 0,
		},
		{
			id = "Base.WoodPlank",
			price = 2,
		},
	},
}
