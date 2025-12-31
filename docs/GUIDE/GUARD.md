-- Server-side code (create, tryBuild)
if isServer() or not isMultiplayer() then
-- Runs on server in MP, or anywhere in SP
end

-- Client-side code (render, key events)
if isClient() or not isMultiplayer() then
-- Runs on client in MP, or anywhere in SP
end
