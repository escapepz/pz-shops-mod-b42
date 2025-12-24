if not isServer() then return end

local PSServer = {}
local PlayerShopStatus = {}

function PSServer.ToggleBusy(player,args)
    PlayerShopStatus[args[1]] = args[2]
    sendServerCommand("PS", "ToggleBusy", args)
end

function PSServer.SyncStatusData(player,args)
    sendServerCommand(player,"PS", "SyncStatusData", {PlayerShopStatus})
end

local function getShopObject(coords)
    local square = getCell():getGridSquare(coords.x, coords.y, coords.z)
	if not square then return nil end
	for i=0,square:getSpecialObjects():size()-1 do
		local o = square:getSpecialObjects():get(i)
        local sprite = o:getSprite():getName()
        if string.find(sprite,PlayerShop.spritePrefix) then
            return o
        end
	end
	return nil
end

function PSServer.ChangeSprite(player,args)
    local sprite = args[1]
    local coords = args[2]
    local shop = getShopObject(coords)
    if shop then
        shop:setSprite(sprite)
        shop:sendObjectChange('sprite')
    end
end

function PSServer.PickupShop(player, args)
    local coords = args[1]
    local shop = getShopObject(coords)
    
    if not shop then return end
    
    -- Check if shop is empty
    local items = shop:getContainer():getItems()
    if items and items:size() > 0 then
        return
    end
    
    local income = shop:getModData().income
    if income and #income > 0 then
        return
    end
    
    -- Get item type
    local itemType = "Shops.PlayerShop"
    if shop:getContainer():getType() == "freezer" then
        itemType = "Shops.PlayerShopFreezer"
    end
    
    -- Remove shop from world
    shop:getSquare():transmitRemoveItemFromSquare(shop)
    
    -- Add item to player inventory
    local newItem = instanceItem(itemType)
    player:getInventory():AddItem(newItem)
    sendAddItemToContainer(player:getInventory(), newItem)
end

local function PS_OnClientCommand(module, command, player, args)
    if module == "PS" and PSServer[command] then
        PSServer[command](player, args)
    end
end

Events.OnClientCommand.Add(PS_OnClientCommand)