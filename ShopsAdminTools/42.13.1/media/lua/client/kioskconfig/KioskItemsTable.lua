-- KioskItemsTable: Global and Selected items table management
-- Mirrors vanilla ISItemsListTable pattern for filtering and rendering

KioskItemsTable = {}
KioskItemsTable.SMALL_FONT_HGT = getTextManager():getFontFromEnum(UIFont.Small):getLineHeight()

-- Draw global items row (Name | Icon | Display Name | Type)
-- Static function: listBox is the explicit first parameter
function KioskItemsTable.drawGlobalItemRow(listBox, y, _drawItem, alt, _selectedScriptItems, comboboxOpen)
	if not _drawItem then return y + listBox.itemheight end

	-- Skip if out of bounds
	if y + listBox.itemheight + listBox:getYScroll() <= 0 then
		return y + listBox.itemheight
	end
	if y + listBox:getYScroll() >= listBox.height then
		return y + listBox.itemheight
	end

	-- Check if item is already in SELECTED_SCRIPT_ITEMS (gray it out)
	local isSelected = false
	if _selectedScriptItems then
		for i = 1, #_selectedScriptItems do
			local selectedItem = _selectedScriptItems[i]
			if selectedItem and selectedItem.fullType == _drawItem.item.fullType then
				isSelected = true
				break
			end
		end
	end

	-- Draw border
	listBox:drawRectBorder(0, y, listBox:getWidth(), listBox.itemheight - 1, 0.9, 0.5, 0.5, 0.5)

	-- Only highlight if item is NOT already selected (grayed out items not interactive)
	if not isSelected then
		-- Highlight hover (light yellow: 1, 1, 0.5 - only if mouse is inside table bounds)
		-- Don't highlight if scrollbar is visible and mouse is on it (right edge)
		-- Don't highlight if combobox is open
		local scrollbarWidth = (#listBox.items > 15) and 17 or 0
		local maxContentX = listBox:getWidth() - scrollbarWidth
		if not comboboxOpen and listBox:getMouseY() >= y and listBox:getMouseY() < y + listBox.itemheight and
			listBox:getMouseX() >= 0 and listBox:getMouseX() < maxContentX then
			listBox:drawRect(0, y, listBox:getWidth(), listBox.itemheight - 1, 0.3, 1, 1, 0.5)
		end

		-- Highlight selection (compare by fullType, stable identifier)
		if listBox.selected and listBox.selected > 0 and listBox.selected <= #listBox.items then
			local selectedItem = listBox.items[listBox.selected]
			if selectedItem and selectedItem.item.fullType and _drawItem.item.fullType == selectedItem.item.fullType then
				listBox:drawRect(0, y, listBox:getWidth(), listBox.itemheight - 1, 0.5, 1, 1, 0.6)
			end
		end
	end

	-- Draw columns: Icon | Name | Display Name | Type
	local iconX = 5
	local nameX = 40
	local displayNameX = 205
	local typeX = 420

	-- Text color: gray if already selected, white otherwise
	local textColor = isSelected and 0.5 or 1
	local textAlpha = isSelected and 0.5 or 0.9

	-- Draw Icon (vanilla pattern from ISItemsListTable.lua, grayed out if selected)
	if _drawItem.item then
		local scriptItem = _drawItem.item.scriptItem
		local icon = scriptItem:getIcon()
		if scriptItem:getIconsForTexture() and not scriptItem:getIconsForTexture():isEmpty() then
			icon = scriptItem:getIconsForTexture():get(0)
		end
		if icon then
			local texture = tryGetTexture("Item_" .. icon)
			if texture then
				local iconAlpha = isSelected and 0.5 or 1
				listBox:drawTextureScaledAspect2(texture, iconX, y + 2, 18, 18, textColor, textColor, textColor,
					iconAlpha)
			end
		end

		-- Draw Name
		listBox:drawText(_drawItem.item.name or "Unknown", nameX, y + 5, textColor, textColor, textColor, textAlpha,
			UIFont.Small)

		-- Draw Display Name
		listBox:drawText(_drawItem.item.displayName or _drawItem.item.name or "Unknown", displayNameX, y + 5, textColor,
			textColor,
			textColor,
			textAlpha, UIFont.Small)

		-- Draw Type
		listBox:drawText(_drawItem.item.type or "Unknown", typeX, y + 5, textColor, textColor, textColor, textAlpha,
			UIFont.Small)
	end

	return y + listBox.itemheight
end

-- Draw selected items row (Icon | Name | Buy | Sell)
-- Static function: listBox is the explicit first parameter
-- Items displayed are already filtered (by applyRightFilters), so no filter checks needed
function KioskItemsTable.drawSelectedItemRow(listBox, y, _drawItem, alt, comboboxOpen)
	if not _drawItem then return y + listBox.itemheight end

	-- Skip if out of bounds
	if y + listBox.itemheight + listBox:getYScroll() <= 0 then
		return y + listBox.itemheight
	end
	if y + listBox:getYScroll() >= listBox.height then
		return y + listBox.itemheight
	end

	-- Draw border
	listBox:drawRectBorder(0, y, listBox:getWidth(), listBox.itemheight - 1, 0.9, 0.5, 0.5, 0.5)

	-- Highlight hover (light yellow: 1, 1, 0.5 - only if mouse is inside table bounds)
	-- Don't highlight if scrollbar is visible and mouse is on it (right edge)
	-- Don't highlight if combobox is in interaction state
	local scrollbarWidth = (#listBox.items > 15) and 17 or 0
	local maxContentX = listBox:getWidth() - scrollbarWidth
	if not comboboxOpen and listBox:getMouseY() >= y and listBox:getMouseY() < y + listBox.itemheight and
		listBox:getMouseX() >= 0 and listBox:getMouseX() < maxContentX then
		listBox:drawRect(0, y, listBox:getWidth(), listBox.itemheight - 1, 0.3, 1, 1, 0.5)
	end

	-- Highlight selection (compare by fullType, stable identifier)
	if listBox.selected and listBox.selected > 0 and listBox.selected <= #listBox.items then
		local selectedItem = listBox.items[listBox.selected]
		if selectedItem and selectedItem.item.fullType and _drawItem.item.fullType == selectedItem.item.fullType then
			listBox:drawRect(0, y, listBox:getWidth(), listBox.itemheight - 1, 0.5, 1, 1, 0.6)
		end
	end

	-- Draw columns: Icon | Name | IconBuy | Buy | IconSell | Sell
	local iconX = 5
	local nameX = 40
	local iconBuyX = 205
	local buyX = 230
	local iconSellX = 290
	local sellX = 315

	-- Draw Icon (vanilla pattern from ISItemsListTable.lua)
	if _drawItem.item then
		local scriptItem = _drawItem.item.scriptItem
		local icon = scriptItem:getIcon()
		if scriptItem:getIconsForTexture() and not scriptItem:getIconsForTexture():isEmpty() then
			icon = scriptItem:getIconsForTexture():get(0)
		end
		if icon then
			local texture = tryGetTexture("Item_" .. icon)
			if texture then
				listBox:drawTextureScaledAspect2(texture, iconX, y + 2, 18, 18, 1, 1, 1, 1)
			end
		end

		-- Draw Name
		listBox:drawText(_drawItem.item.name or "Unknown", nameX, y + 5, 1, 1, 1, 0.9, UIFont.Small)

		-- Draw Buy Icon (CopperCoin or EventCoin based on special status)
		local buyIconTexture = _drawItem.item.buyPriceSpecial and KioskShopConfigUI.eventCoinTexture or
			KioskShopConfigUI.copperCoinTexture
		if buyIconTexture then
			listBox:drawTextureScaledAspect2(buyIconTexture, iconBuyX, y + 2, 18, 18, 1, 1, 1, 1)
		else
			-- Fallback: draw placeholder if texture not found
			listBox:drawRect(iconBuyX, y + 2, 18, 18, 0.2, 0.2, 0.2, 0.5)
		end

		-- Draw Buy (buyPrice > 0 = Yes, buyPrice == 0 = No)
		listBox:drawText(tostring(_drawItem.item.buyPrice), buyX, y + 5, 1, 1, 1, 0.9, UIFont.Small)

		-- Draw Sell Icon (CopperCoin or EventCoin based on special status)
		local sellIconTexture = _drawItem.item.sellPriceSpecial and KioskShopConfigUI.eventCoinTexture or
			KioskShopConfigUI.copperCoinTexture
		if sellIconTexture then
			listBox:drawTextureScaledAspect2(sellIconTexture, iconSellX, y + 2, 18, 18, 1, 1, 1, 1)
		else
			-- Fallback: draw placeholder if texture not found
			listBox:drawRect(iconSellX, y + 2, 18, 18, 0.2, 0.2, 0.2, 0.5)
		end

		-- Draw Sell (sellPrice > 0 = Yes, sellPrice == 0 = No)
		listBox:drawText(tostring(_drawItem.item.sellPrice), sellX, y + 5, 1, 1, 1, 0.9, UIFont.Small)
	end

	return y + listBox.itemheight
end

-- Filter predicate: Type filter (substring match, case-insensitive)
function KioskItemsTable:filterByType(item, typeFilter)
	if typeFilter == "" or typeFilter == nil then return true end
	return string.find(item.type:lower(), typeFilter:lower()) ~= nil
end

-- Filter predicate: Name filter (substring match, case-insensitive)
function KioskItemsTable:filterByName(item, nameFilter)
	if nameFilter == "" or nameFilter == nil then return true end
	return string.find(item.name:lower(), nameFilter:lower()) ~= nil
end

-- Apply all active filters (vanilla ISItemsListTable pattern)
function KioskItemsTable:applyFilters(_scriptItems, typeFilter, nameFilter)
	local filtered = {}

	for i = 1, #_scriptItems do
		local item = _scriptItems[i]
		if self:filterByType(item, typeFilter) and self:filterByName(item, nameFilter) then
			table.insert(filtered, item)
		end
	end

	return filtered
end

-- Get paginated subset
function KioskItemsTable:getPaginatedItems(items, pageNumber, itemsPerPage)
	local startIndex = (pageNumber - 1) * itemsPerPage + 1
	local endIndex = math.min(startIndex + itemsPerPage - 1, #items)
	local result = {}

	for i = startIndex, endIndex do
		result[#result + 1] = items[i]
	end

	return result
end

-- Calculate max pages
function KioskItemsTable:getMaxPages(totalItems, itemsPerPage)
	return math.max(1, math.ceil(totalItems / itemsPerPage))
end
