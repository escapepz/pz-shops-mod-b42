-- listings/medical.lua
-- Medical supplies: first aid, bandages, medicine

return {
	buy = {
		{
			id = "Base.Bandage",
			tab = "FirstAid",
			price = 3,
			notes = "Sterile bandage",
		},
		{
			id = "Base.Gauze",
			tab = "FirstAid",
			price = 2,
			notes = "Gauze roll",
		},
		{
			id = "Base.Tweezers",
			tab = "FirstAid",
			price = 5,
			stock = 20,
			notes = "Medical tweezers",
		},
		{
			id = "Base.Antiseptic",
			tab = "FirstAid",
			price = 8,
			stock = 30,
			notes = "Antiseptic solution",
		},
		{
			id = "Base.Pills",
			tab = "FirstAid",
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
