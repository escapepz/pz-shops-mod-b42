-- ShopPriceEvents.lua
-- Price hook event dispatchers (B42-compliant custom events)
-- 
-- These are Lua callback dispatchers, not engine events.
-- Mods register callbacks here during load, they are called during Shop price calculations

ShopPriceEvents = ShopPriceEvents or {}

-- Buy price modification hooks
ShopPriceEvents.OnShopModifyBuyPrice = {}

-- Register a callback to modify buy prices
function ShopPriceEvents.registerOnShopModifyBuyPrice(callback)
	if type(callback) ~= "function" then
		error("[ShopPriceEvents] registerOnShopModifyBuyPrice requires a function")
	end
	table.insert(ShopPriceEvents.OnShopModifyBuyPrice, callback)
end

-- Execute all buy price modification callbacks
function ShopPriceEvents.triggerOnShopModifyBuyPrice(player, itemId, base, context, modifiers)
	if #ShopPriceEvents.OnShopModifyBuyPrice == 0 then
		writeLog("Shops", "[ShopPriceEvents] WARNING: No OnShopModifyBuyPrice hooks registered!")
	end
	for _, callback in ipairs(ShopPriceEvents.OnShopModifyBuyPrice) do
		callback(player, itemId, base, context, modifiers)
	end
end

-- Buy price override hooks
ShopPriceEvents.OnShopOverrideBuyPrice = {}

-- Register a callback to override buy prices
function ShopPriceEvents.registerOnShopOverrideBuyPrice(callback)
	if type(callback) ~= "function" then
		error("[ShopPriceEvents] registerOnShopOverrideBuyPrice requires a function")
	end
	table.insert(ShopPriceEvents.OnShopOverrideBuyPrice, callback)
end

-- Execute all buy price override callbacks
-- Returns the first non-nil override, or nil to use calculated price
function ShopPriceEvents.triggerOnShopOverrideBuyPrice(player, itemId, price, context)
	if #ShopPriceEvents.OnShopOverrideBuyPrice == 0 then
		writeLog("Shops", "[ShopPriceEvents] WARNING: No OnShopOverrideBuyPrice hooks registered!")
	end
	for _, callback in ipairs(ShopPriceEvents.OnShopOverrideBuyPrice) do
		local override = callback(player, itemId, price, context)
		if override ~= nil then
			return override
		end
	end
	return nil
end

-- Sell price modification hooks
ShopPriceEvents.OnShopModifySellPrice = {}

-- Register a callback to modify sell prices
function ShopPriceEvents.registerOnShopModifySellPrice(callback)
	if type(callback) ~= "function" then
		error("[ShopPriceEvents] registerOnShopModifySellPrice requires a function")
	end
	table.insert(ShopPriceEvents.OnShopModifySellPrice, callback)
end

-- Execute all sell price modification callbacks
function ShopPriceEvents.triggerOnShopModifySellPrice(player, item, base, context, modifiers)
	for _, callback in ipairs(ShopPriceEvents.OnShopModifySellPrice) do
		callback(player, item, base, context, modifiers)
	end
end

-- Sell price override hooks
ShopPriceEvents.OnShopOverrideSellPrice = {}

-- Register a callback to override sell prices
function ShopPriceEvents.registerOnShopOverrideSellPrice(callback)
	if type(callback) ~= "function" then
		error("[ShopPriceEvents] registerOnShopOverrideSellPrice requires a function")
	end
	table.insert(ShopPriceEvents.OnShopOverrideSellPrice, callback)
end

-- Execute all sell price override callbacks
-- Returns the first non-nil override, or nil to use calculated price
function ShopPriceEvents.triggerOnShopOverrideSellPrice(player, item, price, context)
	for _, callback in ipairs(ShopPriceEvents.OnShopOverrideSellPrice) do
		local override = callback(player, item, price, context)
		if override ~= nil then
			return override
		end
	end
	return nil
end
