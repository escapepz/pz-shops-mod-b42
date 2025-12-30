-- Vehicles items registration
-- Deferred to avoid errors if Shop.RegisterItem not yet defined

local Tab = SHOPSB42.Tab
local Shop = SHOPSB42.Shop
if Shop and Shop.RegisterItem then
	Shop.RegisterItem("PinkSlip.CarNormal", {
		tab = Tab.Vehicles,
		price = 500,
	})
end
