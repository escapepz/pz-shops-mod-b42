-- ShopsAdminTools Initialization
-- Loads admin tool components

require "kioskconfig/ISKioskConfigPanel"

-- Initialize admin tools
ShopsAdminTools = ShopsAdminTools or {}

-- Show the Kiosk Configurator UI
function ShopsAdminTools.showKioskConfigurator(player)
	if not player then return end
	ISKioskConfigPanel:show(player)
end

-- Hook to expose admin tools to context menu or commands
Events.OnGameStart.Add(function()
	print("[ShopsAdminTools] Admin tools initialized")
end)
