return function()
	Shop.RegisterItem("Base.SurvivalPack", {
		tab = Tab.FirstAid,
		price = 100,
		items = {
			{ item = "Base.Antibiotics" },
			{ item = "Base.PillsBeta" },
			{ item = "Base.Bandaid",    quantity = 5 },
		}
	})

	Shop.RegisterItem("Base.Bandaid", {
		tab = Tab.FirstAid,
		price = 15,
	})
end
