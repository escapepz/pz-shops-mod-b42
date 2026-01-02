local PlayerShop = SHOPSB42.PlayerShop
local PSClient = {}

function PSClient.ToggleBusy(args)
	PlayerShop.status[args[1]] = args[2]
end

function PSClient.SyncStatusData(args)
	PlayerShop.status = args[1]
end

local function SyncPlayerShopStatusData()
	sendClientCommand("PS", "SyncStatusData", {})
	Events.OnTick.Remove(SyncPlayerShopStatusData)
end

-- Event listener consolidated into ShopCommandDispatcherClient
-- Register event handlers (called by Init.lua)
function PSClient.Initialize()
	Events.OnTick.Add(SyncPlayerShopStatusData)
	-- OnServerCommand listener registered in dispatcher
end

return PSClient
