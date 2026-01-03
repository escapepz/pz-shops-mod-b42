-- listings/weapons.lua
-- Weapons: melee tools, blunt instruments, firearms
-- brokenPrice: reduced cost for damaged weapons (useful for worn tools)

return {
	buy = {
		{
			id = "Base.AxeSteel",
			tab = "Weapons",
			price = 25,
			brokenPrice = 5,
			stock = 10,
			notes = "Steel axe",
		},
		{
			id = "Base.Hammer",
			tab = "Weapons",
			price = 15,
			brokenPrice = 3,
			stock = 15,
			notes = "Claw hammer",
		},
		{
			id = "Base.Machete",
			tab = "Weapons",
			price = 20,
			brokenPrice = 4,
			stock = 12,
			notes = "Sharp machete",
		},
		{
			id = "Base.BaseballBat",
			tab = "Weapons",
			price = 10,
			brokenPrice = 2,
			stock = 20,
			notes = "Wooden baseball bat",
		},
		{
			id = "Base.Crowbar",
			tab = "Weapons",
			price = 12,
			brokenPrice = 2,
			stock = 18,
			notes = "Metal crowbar",
		},
	},

	sell = {
		{
			id = "Base.AxeSteel",
			price = 12,
		},
		{
			id = "Base.Hammer",
			price = 7,
		},
		{
			id = "Base.Machete",
			price = 10,
		},
		{
			id = "Base.BaseballBat",
			price = 5,
		},
		{
			id = "Base.Crowbar",
			price = 6,
		},
		{
			id = "Base.Bomb",
			blacklisted = true,
		},
	},
}
