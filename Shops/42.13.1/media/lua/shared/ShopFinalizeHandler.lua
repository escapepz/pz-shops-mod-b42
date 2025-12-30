-- ShopFinalizeHandler.lua
-- Unified finalization handler for both single-player and multiplayer
-- Ensures registry is finalized whether events fire or not

ShopFinalizeHandler = ShopFinalizeHandler or {}
ShopFinalizeHandler._finalizationAttempted = false

function ShopFinalizeHandler.finalizeNow()
	if ShopFinalizeHandler._finalizationAttempted then return end
	ShopFinalizeHandler._finalizationAttempted = true

	if not Shop._locked then
		writeLog("Shops", "[ShopFinalizeHandler] Finalizing buy registry...")
		Shop.FinalizeRegistry()
	end

	if not Shop._sellLocked then
		writeLog("Shops", "[ShopFinalizeHandler] Finalizing sell registry...")
		Shop.FinalizeSellRegistry()
	end
end

-- Register event handlers - whichever fires first will trigger finalization
if isClient() then
	Events.OnGameBoot.Add(ShopFinalizeHandler.finalizeNow)
end

if isServer() then
	Events.OnServerStarted.Add(ShopFinalizeHandler.finalizeNow)
end

-- Fallback: If event already fired, finalize on next tick
local function checkFinalizationFallback()
	ShopFinalizeHandler.finalizeNow()
end

if Events and Events.OnTick then
	Events.OnTick.Add(checkFinalizationFallback)
end

return ShopFinalizeHandler
