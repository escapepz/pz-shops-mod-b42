-- FirstAid items registration (SERVER ONLY)
-- Deferred to avoid errors if Shop.RegisterItem not yet defined

local Utilities = require("nshopsb42/utils/Utilities")

if Utilities.IsServerOrSinglePlayer() then
	local Tab = SHOPSB42.Tab
	local Shop = SHOPSB42.Shop
	if Shop and Shop.RegisterItem then
		Shop.RegisterItem("Shops.SurvivalPack", {
			tab = Tab.FirstAid,
			price = 100,
			isVirtualBundle = true,
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
end
