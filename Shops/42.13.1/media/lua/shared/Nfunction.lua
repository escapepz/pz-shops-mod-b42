local Nfunction = {}

local isDebug = getCore():getDebug() -- Enable debug logs when running with -debug flag

function Nfunction.trimString(str, limit)
	local len = string.len(str)
	if len > limit then
		str = string.sub(str, 1, limit - 3) .. "..."
	end
	return str
end

function Nfunction.drainablePrice(item, price)
	if instanceof(item, "DrainableComboItem") then
		price = math.floor(price * item:getUseDelta())
		if price <= 0 then
			price = 1
		end
	end
	return price
end

local shopItems = {}
function Nfunction.logShop(coords, action)
	-- Sandbox vars control cosmetic/UI logs only. Audit logs are always enabled.
	local username = getPlayer():getUsername()
	if not action then
		action = "Purchase"
	end

	-- Check sandbox var for action type
	local sandboxVarKey = action == "Sell" and "SellLog" or "PurchaseLog"
	local isEnabled = SandboxVars.Shops[sandboxVarKey]
	if isDebug then
		writeLog("Shops", "[logShop] called - action=" ..
			action .. ", sandboxVar=" .. sandboxVarKey .. ", enabled=" .. tostring(isEnabled))
	end
	if not isEnabled then
		if isDebug then 
			writeLog("Shops", "[logShop] Logging suppressed for " .. action)
		end
		return -- Exit early if logging is disabled for this action type
	end

	local log = username .. " " .. coords.x .. "," .. coords.y .. "," .. coords.z .. " " .. action .. " ["
	local first = true
	for k, v in pairs(shopItems) do
		if first then
			first = false
			log = log .. k .. "=" .. v
		else
			log = log .. "," .. k .. "=" .. v
		end
	end
	log = log .. "]"
	if isDebug then 
		writeLog("Shops", "[logShop] Sending log: " .. log)
	end
	shopItems = {}
	sendClientCommand("LS", "TransactionShopLog", { log })
end

function Nfunction.buildLogShop(type, quantity)
	-- Sandbox vars control cosmetic/UI logs. This function builds the log payload.
	-- The actual sandbox check happens in logShop() when the log is sent.
	if not shopItems[type] then
		local count = 1
		if quantity then count = quantity end
		shopItems[type] = count
	else
		shopItems[type] = shopItems[type] + 1
	end
end

return Nfunction
