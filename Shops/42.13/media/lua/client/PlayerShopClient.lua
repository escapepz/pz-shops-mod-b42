if not isClient() then return end

local PSClient = {}

function PSClient.ToggleBusy(args)
    PlayerShop.status[args[1]] = args[2]
end

function PSClient.SyncStatusData(args)
    PlayerShop.status = args[1]
end

function PSClient.SyncChangeSprite(args)
    local sprite = args[1]
    local coords = args[2]
    local square = getCell():getGridSquare(coords.x, coords.y, coords.z)
    if square then
        for i=0, square:getSpecialObjects():size()-1 do
            local obj = square:getSpecialObjects():get(i)
            if obj:getSprite():getName():find(PlayerShop.spritePrefix) then
                obj:setSprite(sprite)
                break
            end
        end
    end
end

local function PS_OnServerCommand(module, command, args)
    if module== "PS" and PSClient[command] then
        PSClient[command](args)
    end
end

local function SyncPlayerShopStatusData()
	sendClientCommand("PS", "SyncStatusData", {})
     Events.OnTick.Remove(SyncPlayerShopStatusData)
end

Events.OnTick.Add(SyncPlayerShopStatusData)