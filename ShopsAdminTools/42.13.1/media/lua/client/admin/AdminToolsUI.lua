-- AdminToolsUI: Main entry point for admin tools UI
-- Manages initialization and window lifecycle for all admin panels

AdminToolsUI = AdminToolsUI or {}

-- Load components (order matters: dependencies first)
require "admin/KioskItemsTable"
require "admin/KioskItemConfigPanel"
require "admin/KioskShopConfigUI"

-- Window instance
AdminToolsUI.kioskConfigWindow = nil

-- Initialize and show Kiosk Shop Config window
function AdminToolsUI:showKioskConfig(player)
	if not player then return end
	-- Always create fresh window to reload item list
	if self.kioskConfigWindow then
		self.kioskConfigWindow:close()
	end
	self.kioskConfigWindow = KioskShopConfigUI:new(player)
	self.kioskConfigWindow:initialise()
	self.kioskConfigWindow:instantiate()
	self.kioskConfigWindow:addToUIManager()
	self.kioskConfigWindow:setVisible(true)
	return self.kioskConfigWindow
end

-- Close all admin windows
function AdminToolsUI:closeAll()
	if self.kioskConfigWindow then
		self.kioskConfigWindow:setVisible(false)
		self.kioskConfigWindow:close()
		self.kioskConfigWindow = nil
	end
end
