-- Food items registration (SERVER ONLY)
-- Deferred to avoid errors if Shop.RegisterItem not yet defined

local Utilities = require("nshopsb42/utils/Utilities")

if Utilities.IsServerOrSinglePlayer() then
	local Tab = SHOPSB42.Tab
	local Shop = SHOPSB42.Shop
	if Shop and Shop.RegisterItem then
		Shop.RegisterItem("Base.Apple", {
			tab = Tab.Food,
			price = 15,
		})

		Shop.RegisterItem("Base.OatsRaw", {
			tab = Tab.Food,
			price = 20,
		})
	end
end
