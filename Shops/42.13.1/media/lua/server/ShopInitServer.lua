-- ShopInitServer.lua
-- Server-side shop registry initialization
-- Finalization is handled by ShopFinalizeHandler in shared code

if not isServer() then return end

-- Load server-side patches
require "patches/ISTransferActionPatch"
