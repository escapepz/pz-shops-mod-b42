-- Event items registration
-- Deferred to avoid errors if Shop.RegisterItem not yet defined

local Tab = SHOPSB42.Tab
local Shop = SHOPSB42.Shop
if Shop and Shop.RegisterItem then
	Shop.RegisterItem("Base.HairDyeBlonde", {
		tab = Tab.Event,
		price = 5,
		specialCoin = true,
	})

	Shop.RegisterItem("Base.Bag_BigHikingBag", {
		tab = Tab.Event,
		price = 5,
		specialCoin = true,
	})
end
