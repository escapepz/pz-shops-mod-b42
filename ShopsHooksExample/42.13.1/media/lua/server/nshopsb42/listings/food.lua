-- listings/food.lua
-- Food items: fresh produce, canned goods, prepared meals
-- Format:
--   id: Base.ItemName (item type from game)
--   tab: UI tab name (must match SHOPSB42.Tab[])
--   price: shop buy price in currency units
--   stock: initial quantity available for purchase
--   brokenPrice: optional price for damaged/broken condition items
--   notes: optional description shown in shop UI
-- Sell section (optional):
--   blacklisted: true to prevent selling this item (blacklist mode only)

return {
	buy = {
		{
			id = "Base.Apple",
			tab = "Food",
			price = 2,
			stock = 100,
			notes = "Fresh apple",
		},
		{
			id = "Base.Banana",
			tab = "Food",
			price = 2,
			stock = 80,
			notes = "Ripe banana",
		},
		{
			id = "Base.CannedBolognese",
			tab = "Food",
			price = 8,
			stock = 50,
			notes = "Canned pasta meal",
		},
		{
			id = "Base.CannedBeans",
			tab = "Food",
			price = 6,
			stock = 60,
			notes = "Canned beans in sauce",
		},
		{
			id = "Base.CannedChili",
			tab = "Food",
			price = 8,
			stock = 40,
			notes = "Canned chili con carne",
		},
	},

	sell = {
		{
			id = "Base.Apple",
			price = 1,
		},
		{
			id = "Base.Banana",
			price = 1,
		},
		{
			id = "Base.CannedBolognese",
			price = 4,
		},
		{
			id = "Base.CannedBeans",
			price = 3,
		},
		{
			id = "Base.CannedChili",
			price = 4,
		},
	},
}
