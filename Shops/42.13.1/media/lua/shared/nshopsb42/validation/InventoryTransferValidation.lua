-- Shared inventory transfer validation for player shops
-- Used by both client and server to validate shop ownership

local InventoryTransferValidation = {}
local SharedLogger = require("nshopsb42/utils/SharedLogger")

--- Validates if a character can transfer items from/to a container
--- Checks both source and destination containers for shop ownership
--- @param character IsoPlayer The character attempting the transfer
--- @param srcContainer table The source container
--- @param destContainer table The destination container
--- @return boolean true if transfer is allowed, false otherwise
function InventoryTransferValidation.validateShopOwnership(character, srcContainer, destContainer)
	local username = character and character:getUsername() or "Unknown"
	local charType = character and tostring(character:getClass()) or "Unknown"
	SharedLogger.log(
		"Shops",
		"[InventoryTransferValidation] validateShopOwnership() - username=" .. username .. ", charType=" .. charType
	)

	-- Helper function to validate container ownership
	local function validateContainerOwnership(container, containerName)
		if not container then
			SharedLogger.log("Shops", "[InventoryTransferValidation] " .. containerName .. " is nil")
			return true
		end

		local containerType = tostring(container:getClass())
		SharedLogger.log("Shops", "[InventoryTransferValidation] " .. containerName .. " type=" .. containerType)

		local parent = container:getParent()
		if not parent then
			SharedLogger.log("Shops", "[InventoryTransferValidation] " .. containerName .. " has no parent")
			return true
		end

		local parentType = tostring(parent:getClass())
		SharedLogger.log("Shops", "[InventoryTransferValidation] " .. containerName .. " parent type=" .. parentType)

		-- If container has owner modData, validate ownership
		local parentModData = parent:getModData()
		local modDataStr = ""
		if parentModData then
			for k, v in pairs(parentModData) do
				modDataStr = modDataStr .. k .. "=" .. tostring(v) .. ", "
			end
		end
		SharedLogger.log(
			"Shops",
			"[InventoryTransferValidation] " .. containerName .. " parentModData={" .. modDataStr .. "}"
		)

		if parentModData and parentModData.owner then
			SharedLogger.log(
				"Shops",
				"[InventoryTransferValidation] "
					.. containerName
					.. " found owner - owner="
					.. parentModData.owner
					.. ", username="
					.. username
			)

			local isOwner = (username == parentModData.owner)
			SharedLogger.log(
				"Shops",
				"[InventoryTransferValidation] " .. containerName .. " ownership check - isOwner=" .. tostring(isOwner)
			)

			-- Allow admin override
			if character:isAccessLevel("Admin") then
				SharedLogger.log("Shops", "[InventoryTransferValidation] Admin override for " .. containerName)
				isOwner = true
			end

			return isOwner
		end

		return true
	end

	-- Validate source container
	local srcValid = validateContainerOwnership(srcContainer, "srcContainer")
	if not srcValid then
		SharedLogger.log(
			"Shops",
			"[InventoryTransferValidation] Transfer rejected - player does not own source container"
		)
		return false
	end

	-- Validate destination container
	local destValid = validateContainerOwnership(destContainer, "destContainer")
	if not destValid then
		SharedLogger.log(
			"Shops",
			"[InventoryTransferValidation] Transfer rejected - player does not own destination container"
		)
		return false
	end

	SharedLogger.log("Shops", "[InventoryTransferValidation] Transfer allowed")
	return true
end

return InventoryTransferValidation
