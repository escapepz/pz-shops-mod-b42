-- ShopInitServer.lua
-- Server-side shop registry initialization

if not isServer() then return end

-- Load server-side patches
require "patches/ISTransferActionPatch"

Events.OnServerStarted.Add(Shop.FinalizeRegistry)
Events.OnServerStarted.Add(Shop.FinalizeSellRegistry)
