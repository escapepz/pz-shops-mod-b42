-- Vehicles items registration (SERVER ONLY)
-- Deferred to avoid errors if Shop.RegisterItem not yet defined

if isMultiplayer() and not isServer() then
	return
end

local Tab = SHOPSB42.Tab
local Shop = SHOPSB42.Shop
if Shop and Shop.RegisterItem then
	Shop.RegisterItem("PinkSlip.CarNormal", {
		tab = Tab.Vehicles,
		price = 500,
	})
end
