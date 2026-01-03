-- listings/weapons.lua
-- Weapons: melee tools, blunt instruments, firearms

return {
	buy = {
		{
			id = "Base.AxeSteel",
			tab = "Weapons",
			price = 25,
			-- stock = 10, -- not implemented -- npc shop unlimited stock
			notes = "Steel axe", -- personal notes, not affected the gameplay
		},
		{
			id = "Base.Hammer",
			tab = "Weapons",
			price = 15,
			notes = "Claw hammer",
		},
		{
			id = "Base.Machete",
			tab = "Weapons",
			price = 20,
			notes = "Sharp machete",
		},
		{
			id = "Base.BaseballBat",
			tab = "Weapons",
			price = 10,
			notes = "Wooden baseball bat",
		},
		{
			id = "Base.Crowbar",
			tab = "Weapons",
			price = 12,
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
