-- Server-side Item Transfer Hook for Shop Ownership Validation
-- Method 2: Override ISTransferAction:transferItem() with shop ownership checks

local InventoryTransferValidation = require("nshopsb42/validation/InventoryTransferValidation")
local SharedLogger = SHOPSB42.SharedLogger

-- Store original function
local OriginalTransferItem = ISTransferAction.transferItem

-- Override transferItem to validate shop ownership BEFORE transfer
---@diagnostic disable-next-line: duplicate-set-field
function ISTransferAction:transferItem(character, item, srcContainer, destContainer, dropSquare)
	local username = character and character:getUsername() or "Unknown"

	SharedLogger.log(
		"Shops",
		"[ISTransferActionPatch] Transfer attempt - username="
			.. username
			.. ", item="
			.. (item and item:getDisplayName() or "Unknown")
			.. ", srcContainer="
			.. (srcContainer and srcContainer:getType() or "Unknown")
			.. ", destContainer="
			.. (destContainer and destContainer:getType() or "Unknown")
	)

	-- Validate shop ownership using same conditions as client-side validation
	if not InventoryTransferValidation.validateShopOwnership(character, srcContainer, destContainer) then
		SharedLogger.log(
			"Shops",
			"[ISTransferActionPatch] Transfer REJECTED - Player does not own source/destination container"
		)
		return nil -- Return nil to indicate failure
	end

	SharedLogger.log("Shops", "[ISTransferActionPatch] Transfer ALLOWED - Proceeding with original transfer")

	-- Call the original transfer function
	return OriginalTransferItem(self, character, item, srcContainer, destContainer, dropSquare)
end
