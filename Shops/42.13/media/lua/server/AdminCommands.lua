-- Admin Commands (B42-safe)
-- All command registration via ServerCommands

if not isServer() then return end

------------------------------------------------------------
-- Register server command namespace
------------------------------------------------------------
ServerCommands = ServerCommands or {}
ServerCommands.shops = ServerCommands.shops or {}

------------------------------------------------------------
-- /servercmd shops help
------------------------------------------------------------
function ServerCommands.shops.help(player, args)
    if not player or not player:isAdmin() then return end
    
    print("[Shops] Admin help requested by: " .. player:getUsername())
end

print("[AdminCommands] Admin commands loaded (B42-safe)")
