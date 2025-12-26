-- ShopInitServer.lua
-- Server-side shop registry initialization

if not isServer() then return end

Events.OnServerStarted.Add(Shop.FinalizeRegistry)
Events.OnServerStarted.Add(Shop.FinalizeSellRegistry)
