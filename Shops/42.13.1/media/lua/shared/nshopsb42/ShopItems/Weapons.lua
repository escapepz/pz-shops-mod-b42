-- Weapons items registration (SERVER ONLY)
-- Deferred to avoid errors if Shop.RegisterItem not yet defined

local Utilities = require("nshopsb42/utils/Utilities")

if Utilities.IsServerOrSinglePlayer() then
	local Tab = SHOPSB42.Tab
	local Shop = SHOPSB42.Shop
	if Shop and Shop.RegisterItem then
		Shop.RegisterItem("Base.Crowbar", {
			tab = Tab.Weapons,
			price = 250,
		})
	end
end
