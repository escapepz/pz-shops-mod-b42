-- Weapons items registration
-- Deferred to avoid errors if Shop.RegisterItem not yet defined

local Tab = SHOPSB42.Tab
local Shop = SHOPSB42.Shop
if Shop and Shop.RegisterItem then
	Shop.RegisterItem("Base.Crowbar", {
		tab = Tab.Weapons,
		price = 250,
	})
end
