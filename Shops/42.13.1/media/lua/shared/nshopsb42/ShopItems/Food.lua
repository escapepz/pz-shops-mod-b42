-- Food items registration (SERVER ONLY)
-- Deferred to avoid errors if Shop.RegisterItem not yet defined

if not isServer() then
	return
end

local Tab = SHOPSB42.Tab
local Shop = SHOPSB42.Shop
if Shop and Shop.RegisterItem then
	Shop.RegisterItem("Base.OatsRaw", {
		tab = Tab.Food,
		price = 20,
	})
end
