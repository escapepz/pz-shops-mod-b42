---@diagnostic disable: duplicate-set-field
local InventoryTransferValidation = require("nshopsb42/validation/InventoryTransferValidation")
local SharedLogger = SHOPSB42.SharedLogger

local oldStart = ISInventoryTransferAction.start

function ISInventoryTransferAction:start()
	-- Validate shop ownership BEFORE action starts
	if not InventoryTransferValidation.validateShopOwnership(self.character, self.srcContainer, self.destContainer) then
		SharedLogger.log("Shops", "[ISInventoryTransferActionPatch] Transfer denied - player does not own container")
		self:forceStop()
		return
	end

	-- Proceed with original start
	oldStart(self)
end
