-- FirstAid items registration
-- Deferred to avoid errors if Shop.RegisterItem not yet defined

local Tab = SHOPSB42.Tab
local Shop = SHOPSB42.Shop
if Shop and Shop.RegisterItem then
	Shop.RegisterItem("Base.SurvivalPack", {
		tab = Tab.FirstAid,
		price = 100,
		items = {
			{ item = "Base.Antibiotics" },
			{ item = "Base.PillsBeta" },
			{ item = "Base.Bandaid", quantity = 5 },
		},
	})

	Shop.RegisterItem("Base.Bandaid", {
		tab = Tab.FirstAid,
		price = 15,
	})
end
