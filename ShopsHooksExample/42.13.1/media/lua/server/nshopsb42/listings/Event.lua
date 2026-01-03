-- Event items registration (SERVER ONLY)
-- Deferred to avoid errors if Shop.RegisterItem not yet defined

return {
	buy = {
		{
			id = "Base.Chocolate_HeartBox",
			tab = "Event",
			price = 5,
			specialCoin = true,
		},
	},
}
