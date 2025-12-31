-- ShopCommandHandlerServer.lua
-- Server-side command handler for shop-related client commands
-- Routes commands from client back to client or processes server-side

local SharedLogger = require("nshopsb42/utils/SharedLogger")

local Commands = {}

--- Clear the sprite drag cursor on client (when no more items available)
function Commands.ClearShopSpriteDrag(player, args)
	SharedLogger.log(
		"Shops",
		"[ShopCommandHandlerServer:ClearShopSpriteDrag] Sending server command to client for " .. player:getUsername()
	)

	-- SP lock
	if not isMultiplayer() then
		local cell = getWorld() and getWorld():getCell()
		if cell then
			cell:setDrag(nil, 0)
		end
	else
		sendServerCommand(player, "nshopsb42", "ClearShopSpriteDrag", {})
	end
end

--- Register command handler
Events.OnClientCommand.Add(function(module, command, player, args)
	if module ~= "nshopsb42" then
		return
	end
	if not Commands[command] then
		return
	end

	SharedLogger.log(
		"Shops",
		"[ShopCommandHandlerServer] Processing command: " .. command .. " for " .. player:getUsername()
	)
	Commands[command](player, args)
end)

SharedLogger.log("Shops", "[ShopCommandHandlerServer] Initialized")
