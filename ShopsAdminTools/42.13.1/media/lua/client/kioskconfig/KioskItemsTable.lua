-- KioskItemsTable: Global and Selected items table management
-- Mirrors vanilla ISItemsListTable pattern for filtering and rendering

KioskItemsTable = {}
KioskItemsTable.SMALL_FONT_HGT = getTextManager():getFontFromEnum(UIFont.Small):getLineHeight()

-- Draw global items row (Name | Icon | Display Name | Type)
-- Static function: listBox is the explicit first parameter
function KioskItemsTable.drawGlobalItemRow(listBox, y, item, alt)
	if not item then return y + listBox.itemheight end

	-- Skip if out of bounds
	if y + listBox.itemheight + listBox:getYScroll() <= 0 then
		return y + listBox.itemheight
	end
	if y + listBox:getYScroll() >= listBox.height then
		return y + listBox.itemheight
	end

	-- Draw border
	listBox:drawRectBorder(0, y, listBox:getWidth(), listBox.itemheight - 1, 0.9, 0.5, 0.5, 0.5)

	-- Highlight hover
	if listBox:getMouseY() >= y and listBox:getMouseY() < y + listBox.itemheight then
		listBox:drawRect(0, y, listBox:getWidth(), listBox.itemheight - 1, 0.2, 0.2, 0.2, 0.2)
	end

	-- Highlight selection
	if listBox.selected == item.index then
		listBox:drawRect(0, y, listBox:getWidth(), listBox.itemheight - 1, 0.3, 0.3, 0.3, 0.3)
	end

	-- Draw columns: Name | Icon | Display Name | Type
	local col1Width = 185 -- Name
	local iconWidth = 30 -- Icon
	local col2Width = 200 -- Display Name

	-- Draw Name
	listBox:drawText(item.name or "Unknown", 10, y + 5, 1, 1, 1, 0.9, UIFont.Small)

	-- Draw Icon (vanilla pattern from ISItemsListTable.lua)
	if item.item then
		local icon = item.item:getIcon()
		if item.item:getIconsForTexture() and not item.item:getIconsForTexture():isEmpty() then
			icon = item.item:getIconsForTexture():get(0)
		end
		if icon then
			local texture = tryGetTexture("Item_" .. icon)
			if texture then
				listBox:drawTextureScaledAspect2(texture, 175, y + 2, 18, 18, 1, 1, 1, 1)
			end
		end
	end

	-- Draw Display Name
	listBox:drawText(item.displayName or item.name or "Unknown", 205, y + 5, 1, 1, 1, 0.9, UIFont.Small)

	-- Draw Type
	listBox:drawText(item.type or "Unknown", 420, y + 5, 1, 1, 1, 0.9, UIFont.Small)

	return y + listBox.itemheight
end

-- Draw selected items row (Type | Name | Buy | Sell | Price)
-- Static function: listBox is the explicit first parameter
function KioskItemsTable.drawSelectedItemRow(listBox, y, item, alt)
	if not item then return y + listBox.itemheight end

	-- Skip if out of bounds
	if y + listBox.itemheight + listBox:getYScroll() <= 0 then
		return y + listBox.itemheight
	end
	if y + listBox:getYScroll() >= listBox.height then
		return y + listBox.itemheight
	end

	-- Draw border
	listBox:drawRectBorder(0, y, listBox:getWidth(), listBox.itemheight - 1, 0.9, 0.5, 0.5, 0.5)

	-- Highlight hover
	if listBox:getMouseY() >= y and listBox:getMouseY() < y + listBox.itemheight then
		listBox:drawRect(0, y, listBox:getWidth(), listBox.itemheight - 1, 0.2, 0.2, 0.2, 0.2)
	end

	-- Highlight selection
	if listBox.selected == item.index then
		listBox:drawRect(0, y, listBox:getWidth(), listBox.itemheight - 1, 0.3, 0.3, 0.3, 0.3)
	end

	-- Draw columns: Type | Name | Buy | Sell | Price
	local col1Width = 80
	local col2Width = 100
	local col3Width = 40
	local col4Width = 40

	listBox:drawText(item.type or "Unknown", 10, y + 5, 1, 1, 1, 0.9, UIFont.Small)
	listBox:drawText(item.name or "Unknown", col1Width + 10, y + 5, 1, 1, 1, 0.9, UIFont.Small)
	listBox:drawText(item.buy and "Yes" or "No", col1Width + col2Width + 10, y + 5, 1, 1, 1, 0.9, UIFont.Small)
	listBox:drawText(item.sell and "Yes" or "No", col1Width + col2Width + col3Width + 10, y + 5, 1, 1, 1, 0.9,
		UIFont.Small)
	listBox:drawText(tostring(item.price or 0), col1Width + col2Width + col3Width + col4Width + 10, y + 5, 1, 1, 1, 0.9,
		UIFont.Small)

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
function KioskItemsTable:applyFilters(allItems, typeFilter, nameFilter)
	local filtered = {}

	for i = 1, #allItems do
		local item = allItems[i]
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
