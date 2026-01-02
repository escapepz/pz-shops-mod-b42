-- ShopCommandHandlerServer.lua
-- Server-side command handler for shop-related client commands
-- Routes commands from client back to client or processes server-side

local SharedLogger = require("nshopsb42/utils/SharedLogger")
local Utilities = require("nshopsb42/utils/Utilities")

local Commands = {}

--- Handle RequestShopData from client
function Commands.RequestShopData(player, args)
	local username = player and player:getUsername() or "unknown"
	SharedLogger.log("Shops", "[ShopCommandHandlerServer] RequestShopData from " .. username)

	local ShopFinalizeHandler = require("nshopsb42/transactions/ShopFinalizeHandlerServer")
	local success, err = pcall(function()
		ShopFinalizeHandler.sendShopDataToPlayer(player)
	end)

	if not success then
		SharedLogger.log("Shops", "[ShopCommandHandlerServer] ERROR in sendShopDataToPlayer: " .. tostring(err))
	else
		SharedLogger.log("Shops", "[ShopCommandHandlerServer] sendShopDataToPlayer completed successfully")
	end
end

--- Clear the sprite drag cursor on client (when no more items available)
function Commands.ClearShopSpriteDrag(player, args)
	SharedLogger.log(
		"Shops",
		"[ShopCommandHandlerServer:ClearShopSpriteDrag] Sending server command to client for " .. player:getUsername()
	)

	-- Use Utilities wrapper for SP/MP compatibility
	Utilities.SendServerCommandTo(player, "nshopsb42", "ClearShopSpriteDrag", {})
end

--- Remove shop (admin-only, server authority)
function Commands.RemoveShop(player, args)
	if not player then
		return
	end
	local username = player:getUsername()

	-- 1. CRITICAL: Admin permission check
	if not Utilities.IsPlayerAdmin(player) then
		SharedLogger.log(
			"Shops",
			"[ShopCommandHandlerServer:RemoveShop] DENIED - Non-admin " .. username .. " attempted shop removal"
		)
		player:setHaloNote("Admin permission required", 255, 0, 0, 400)
		return
	end

	-- 2. Resolve square safely
	local square = getWorld():getCell():getGridSquare(args.x, args.y, args.z)
	if not square then
		SharedLogger.log(
			"Shops",
			"[ShopCommandHandlerServer:RemoveShop] ERROR: Square not found at " .. args.x .. "," .. args.y
		)
		return
	end

	-- 3. Resolve object safely
	local obj = square:getObjects():get(args.index)
	if not obj then
		SharedLogger.log(
			"Shops",
			"[ShopCommandHandlerServer:RemoveShop] ERROR: Object not found at index " .. args.index .. " in square"
		)
		return
	end

	-- 4. Log successful removal
	SharedLogger.log(
		"Shops",
		"[ShopCommandHandlerServer:RemoveShop] REMOVING shop at " .. args.x .. "," .. args.y .. " by admin " .. username
	)

	-- 5. Remove object on server (atomic, syncs to all clients)
	square:transmitRemoveItemFromSquare(obj)

	-- 6. Notify player
	player:setHaloNote("Shop removed", 0, 255, 0, 300)
end

-- Event listeners consolidated into ShopCommandDispatcherServer
-- This module now only exports Commands for reference if needed
SharedLogger.log("Shops", "[ShopCommandHandlerServer] Loaded (dispatcher registered separately)")
