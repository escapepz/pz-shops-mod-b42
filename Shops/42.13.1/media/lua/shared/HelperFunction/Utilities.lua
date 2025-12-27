---@class Utilities
local Utilities = {};

--- [SHARED]
--- Return a IsoPlayer from its username if found
function Utilities.GetPlayerFromUsername(username)
    if isServer() then
        local players = getOnlinePlayers();
        for i = 0, players:size() - 1 do
            local player = players:get(i);
            if player:getUsername() == username then
                return player;
            end
        end
    elseif isClient() then
        return getPlayerFromUsername(username);
    end
end

--- [SHARED]
--- Return true if game is single player
---@return boolean
function Utilities.IsSinglePlayer()
    return not isClient() and not isServer();
end

--- [SHARED]
--- Return true if game is single player with debug enabled
---@return boolean
function Utilities.IsSinglePlayerDebug()
    return Utilities.IsSinglePlayer() and isDebugEnabled();
end

--- [CLIENT]
--- Return true if the game is client or single player
function Utilities.IsClientOrSinglePlayer()
    return isClient() or Utilities.IsSinglePlayer();
end

--- [SERVER]
--- Return true if the game is server or single player
function Utilities.IsServerOrSinglePlayer()
    return isServer() or Utilities.IsSinglePlayer();
end

--- [CLIENT]
--- Return true if client is admin or single player
---@return boolean
function Utilities.IsClientAdmin()
    local playerObj = getPlayer();
    return (instanceof(playerObj, "IsoPlayer") and playerObj:isAccessLevel("Admin")) or Utilities.IsSinglePlayer();
end

--- [CLIENT]
--- Return true if the client is admin or moderator
---@return boolean
function Utilities.IsClientStaff()
    local playerObj = getPlayer();
    return Utilities.IsClientAdmin() or (instanceof(playerObj, "IsoPlayer") and playerObj:isAccessLevel("Moderator"));
end

--- [SERVER]
--- Return true if the IsoPlayer is admin or single player + debug mode
---@param playerObjOrUsername IsoPlayer|string
---@return boolean
function Utilities.IsPlayerAdmin(playerObjOrUsername)
    if type(playerObjOrUsername) == "string" then
        playerObjOrUsername = Utilities.GetPlayerFromUsername(playerObjOrUsername);
    end
    return (instanceof(playerObjOrUsername, "IsoPlayer") and playerObjOrUsername:isAccessLevel("Admin")) or Utilities.IsSinglePlayerDebug();
end

--- [SERVER]
--- Return true if the IsoPlayer is admin or moderator
---@param playerObjOrUsername IsoPlayer|string
---@return boolean
function Utilities.IsPlayerStaff(playerObjOrUsername)
    if type(playerObjOrUsername) == "string" then
        playerObjOrUsername = Utilities.GetPlayerFromUsername(playerObjOrUsername);
    end
    return (instanceof(playerObjOrUsername, "IsoPlayer") and (playerObjOrUsername:isAccessLevel("Admin") or playerObjOrUsername:isAccessLevel("Moderator"))) or Utilities.IsSinglePlayerDebug();
end

--- [CLIENT]
--- Send a command from the client to the server
---@param _module string
---@param _command string
---@param _data table
function Utilities.SendClientCommand(_module, _command, _data)
    if Utilities.IsClientOrSinglePlayer() then
        sendClientCommand(_module, _command, _data);
    end
end

--- [SERVER]
--- Send a command from the server to a specific client
---@param _targetPlayerObj IsoPlayer
---@param _module string
---@param _command string
---@param _data table
function Utilities.SendServerCommandTo(_targetPlayerObj, _module, _command, _data)
    if Utilities.IsServerOrSinglePlayer() then
        if Utilities.IsSinglePlayer() then
            triggerEvent("OnServerCommand", _module, _command, _data);
        else
            sendServerCommand(_targetPlayerObj, _module, _command, _data);
        end
    end
end

--- [SERVER]
--- Send a command from the server to all clients
---@param _module string
---@param _command string
---@param _data table
function Utilities.SendServerCommandToAll(_module, _command, _data)
    if Utilities.IsServerOrSinglePlayer() then
        if Utilities.IsSinglePlayer() then
            triggerEvent("OnServerCommand", _module, _command, _data);
        else
            sendServerCommand(_module, _command, _data);
        end
    end
end

--- [SERVER]
--- Send a command from the server to all clients in range
---@param _x number
---@param _y number
---@param _z number
---@param _distanceMin number
---@param _distanceMax number
---@param _module string
---@param _command string
---@param _data table
function Utilities.SendServerCommandToAllInRange(_x, _y, _z, _distanceMin, _distanceMax, _module, _command, _data)
    if Utilities.IsServerOrSinglePlayer() then
        if Utilities.IsSinglePlayer() then
            if Utilities.IsPlayerInRange(getPlayer(), _x, _y, _z, _distanceMin, _distanceMax) then
                triggerEvent("OnServerCommand", _module, _command, _data);
            end
        else
            local players = getOnlinePlayers();
            if players then
                for i = 0, players:size() - 1 do
                    local targetPlayer = players:get(i);
                    if Utilities.IsPlayerInRange(targetPlayer, _x, _y, _z, _distanceMin, _distanceMax) then
                        sendServerCommand(targetPlayer, _module, _command, _data);
                    end
                end
            end
        end
    end
end

--- [SHARED]
--- Return true if the IsoPlayer is in range
---@param _x number
---@param _y number
---@param _z number
---@param _distanceMin number
---@param _distanceMax number
---@return boolean
function Utilities.IsPlayerInRange(_playerObj, _x, _y, _z, _distanceMin, _distanceMax)
    if not _playerObj then return false; end
    local x2, y2, z2 = _playerObj:getX(), _playerObj:getY(), _playerObj:getZ();
    local currentDistance = IsoUtils.DistanceTo(_x, _y, _z, x2, y2, z2);
    return (currentDistance >= _distanceMin and currentDistance <= _distanceMax);
end

--- Check if a square is powerred
function Utilities.SquareHasElectricity(square)
    return (SandboxVars.AllowExteriorGenerator and square and square:haveElectricity()) or (SandboxVars.ElecShutModifier > -1 and GameTime:getInstance():getNightsSurvived() < SandboxVars.ElecShutModifier);
end

--- Get the server name or the save file name in single player
function Utilities.GetServerName()
    if Utilities.IsSinglePlayer() then
        local world = getWorld():getWorld();
        if type(world) == "string" and world ~= "" then
            local saveInfo = getSaveInfo(world)
            if saveInfo and saveInfo.gameMode then
                return saveInfo.saveName;
            end
        end
        return "SinglePlayerGame";
    else
        return getServerOptions():getOptionByName("PublicName"):getValue();
    end
    return "Unknown";
end

function Utilities.SplitString(str, delimiter)
    local result = {}
    for match in (str..delimiter):gmatch("(.-)%"..delimiter) do
        table.insert(result, match)
    end
    return result
end

function Utilities.SquareToString(square)
    if square then
        return square:getX() .. "|" .. square:getY() .. "|" .. square:getZ();
    end
end

function Utilities.StringToSquare(string)
    local split = Utilities.SplitString(string, "|");
    if #split >= 3 then
        local x, y, z = tonumber(split[1]), tonumber(split[2]), tonumber(split[3]);
        local square = getCell():getGridSquare(x, y, z);
        if square then
            return square;
        end
    end
end

function Utilities.FindAllItemInInventoryByTag(inventory, tag)
    local foundItems = ArrayList.new()
    local validItems = getScriptManager():getItemsTag(tag)
    if validItems then
        for i=0, validItems:size()-1 do
            foundItems:addAll(inventory:getItemsFromFullType(validItems:get(i):getFullName()))
        end
    end
    return foundItems
end

function Utilities.GetMoveableDisplayName(obj)
	if not obj then return nil end
	if not obj:getSprite() then return nil end
	local props = obj:getSprite():getProperties();
	if props:Is("CustomName") then
		local name = props:Val("CustomName");
		if props:Is("GroupName") then
			name = props:Val("GroupName") .. " " .. name;
		end
		return Translator.getMoveableDisplayName(name);
	end
	return nil;
end

return Utilities;
