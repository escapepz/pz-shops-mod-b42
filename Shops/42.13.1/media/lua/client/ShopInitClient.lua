-- ShopInitClient.lua
-- Client-side shop registry initialization

if not isClient() then return end

Events.OnGameBoot.Add(Shop.FinalizeRegistry)
Events.OnGameBoot.Add(Shop.FinalizeSellRegistry)
