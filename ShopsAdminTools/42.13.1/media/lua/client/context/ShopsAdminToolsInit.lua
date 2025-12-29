-- ShopsAdminTools Initialization
-- Loads admin tool components

require "admin/AdminToolsUI"

-- Initialize admin tools
ShopsAdminTools = ShopsAdminTools or {}

-- Show the Kiosk Shop Config window
function ShopsAdminTools.showKioskConfigurator(player)
	if not player then return end
	AdminToolsUI:showKioskConfig(player)
end

-- Close all admin windows
function ShopsAdminTools.closeAdminTools()
	AdminToolsUI:closeAll()
end

-- Hook to expose admin tools to context menu or commands
Events.OnGameStart.Add(function()
	print("[ShopsAdminTools] Admin tools initialized")
	ShopsAdminTools.showKioskConfigurator(getPlayer())
end)
