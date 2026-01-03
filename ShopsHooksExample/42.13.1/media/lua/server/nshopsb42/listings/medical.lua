-- listings/medical.lua
-- Medical supplies: first aid, bandages, medicine

return {
	buy = {
		{
			id = "Base.Bandage",
			tab = "Medical",
			price = 3,
			stock = 100,
			notes = "Sterile bandage",
		},
		{
			id = "Base.Gauze",
			tab = "Medical",
			price = 2,
			stock = 80,
			notes = "Gauze roll",
		},
		{
			id = "Base.Tweezers",
			tab = "Medical",
			price = 5,
			stock = 20,
			notes = "Medical tweezers",
		},
		{
			id = "Base.Antiseptic",
			tab = "Medical",
			price = 8,
			stock = 30,
			notes = "Antiseptic solution",
		},
		{
			id = "Base.Pills",
			tab = "Medical",
			price = 15,
			stock = 25,
			notes = "Pain relief pills",
		},
	},

	sell = {
		{
			id = "Base.Bandage",
			price = 1,
		},
		{
			id = "Base.Gauze",
			price = 1,
		},
		{
			id = "Base.Tweezers",
			price = 2,
		},
		{
			id = "Base.Antiseptic",
			price = 4,
		},
		{
			id = "Base.Pills",
			price = 7,
		},
	},
}
