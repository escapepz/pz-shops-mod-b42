-- \lua\shared\ShopItems\CustomTab.lua
return function()
	Tab = Tab or {}
	Tab["CustomTab"] = "CustomTab"
	Shop.Tabs[Tab.CustomTab] = "Custom Tab"

	Shop.RegisterItem("Base.Bag_BigHikingBag", {
		tab = Tab.CustomTab,
		price = 6,
		specialCoin = true,
	})
end
