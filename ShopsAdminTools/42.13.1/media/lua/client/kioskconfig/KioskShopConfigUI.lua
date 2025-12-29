-- KioskShopConfigUI: Two-panel kiosk shop configuration window
-- Reference: docs/ShopsAdminTools/UI_Update.md
---@class KioskShopConfigUI : ISPanel
KioskShopConfigUI = ISPanel:derive("KioskShopConfigUI")

KioskShopConfigUI.SMALL_FONT_HGT = getTextManager():getFontFromEnum(UIFont.Small):getLineHeight()
KioskShopConfigUI.MEDIUM_FONT_HGT = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight()

-- ========== UTILITY FUNCTIONS ==========

function KioskShopConfigUI.log(message)
	if true then -- Set to false to disable debug logging
		writeLog("ShopsAdminTools", "[KioskShopConfigUI] " .. tostring(message))
	end
end

local function getWindowDimensions()
	local fontSizeMultiplier = getCore():getOptionFontSizeReal()
	local width = 1150 + (fontSizeMultiplier * 50)
	local height = 650 + (fontSizeMultiplier * 50)
	return width, height
end

-- Update lifecycle (vanilla ISItemsListTable pattern)
function KioskShopConfigUI:update()
	if self.needsInitList then
		self:initList()
		self.needsInitList = false
	end

	-- Handle filter debounce (50ms delay for text input performance)
	-- if self.filterDebounceTimer > 0 then
	-- 	self.filterDebounceTimer = self.filterDebounceTimer - 1 / 60 -- 60 FPS
	-- 	if self.filterDebounceTimer <= 0 then
	-- 		self:applyFilters()
	-- 	end
	-- end
end

-- Render the UI
function KioskShopConfigUI:render()
	ISPanel.render(self)
	-- Draw title bar
	local titleBarHeight = 30
	self:drawRect(0, 0, self.width, titleBarHeight, 0.4, 0.2, 0.2, 0.2)
	self:drawText(self.title, 10, 8, 1, 1, 1, 1, UIFont.Small)
end

-- Declare which keys this panel handles (ESC key consumed)
function KioskShopConfigUI:isKeyConsumed(key)
	return key == Keyboard.KEY_ESCAPE
end

-- Handle key release on panel (ESC closes)
function KioskShopConfigUI:onKeyRelease(key)
	if not self:isVisible() then return false end
	if key == Keyboard.KEY_ESCAPE then
		self:close()
		self:removeFromUIManager()
		return true
	end
	return false
end

-- Create UI children (two-panel layout)
function KioskShopConfigUI:createChildren()
	ISPanel.createChildren(self)

	-- Add close button to title bar
	local closeBtn = ISButton:new(self.width - 30, 5, 25, 25, "X", self, KioskShopConfigUI.onClose)
	closeBtn:initialise()
	self:addChild(closeBtn)

	local titleBarHeight = 30
	local padding = 10
	local headerHeight = 20
	local filterHeight = 125 -- Increased for 3 filters (Type, Name, Display Name)
	local paginationHeight = 35

	-- Calculate available heights
	local totalFixedHeight = titleBarHeight + padding + headerHeight + padding + filterHeight + padding +
		paginationHeight
	local itemsTableHeight = self.height - totalFixedHeight - (padding * 2)

	-- LEFT PANEL: Global Items
	local leftPanelWidth = (self.width - padding * 3) / 2
	self.leftPanel = ISPanel:new(padding, titleBarHeight + padding, leftPanelWidth,
		self.height - titleBarHeight - padding - 5)
	self.leftPanel:initialise()
	self.leftPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
	self.leftPanel.borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 0.5 }
	self:addChild(self.leftPanel)

	-- LEFT: Title label
	local titleLabel = ISLabel:new(5, 5, KioskShopConfigUI.SMALL_FONT_HGT, "GLOBAL ITEMS", 1, 1, 1, 1, UIFont.Small, true)
	self.leftPanel:addChild(titleLabel)

	-- LEFT: Column headers
	local headerPanel = ISPanel:new(5, 25, leftPanelWidth - 10, headerHeight)
	headerPanel:initialise()
	headerPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.2 }
	self.leftPanel:addChild(headerPanel)

	local nameHeader = ISLabel:new(10, 3, KioskShopConfigUI.SMALL_FONT_HGT, "Name", 0.9, 0.9, 0.9, 1, UIFont.Small, true)
	headerPanel:addChild(nameHeader)

	-- Icon column has no header, positioned near Display Name
	local displayNameHeader = ISLabel:new(205, 3, KioskShopConfigUI.SMALL_FONT_HGT, "Display Name", 0.9, 0.9, 0.9, 1,
		UIFont.Small, true)
	headerPanel:addChild(displayNameHeader)

	local typeHeader = ISLabel:new(420, 3, KioskShopConfigUI.SMALL_FONT_HGT, "Type", 0.9, 0.9, 0.9, 1, UIFont.Small, true)
	headerPanel:addChild(typeHeader)

	-- LEFT: Items table (ISScrollingListBox with columns)
	self.globalItemsList = ISScrollingListBox:new(5, 48, leftPanelWidth - 10, itemsTableHeight)
	self.globalItemsList:initialise()
	self.globalItemsList:instantiate()
	self.globalItemsList.itemheight = 22
	self.globalItemsList.font = UIFont.Small
	-- Callback receives self (listBox) as first parameter when called as method
	self.globalItemsList.doDrawItem = function(listBox, y, item, alt)
		-- ISScrollingListBox wraps items, unwrap if necessary
		if item and item.item and not item.name then
			item = item.item
		end
		return KioskItemsTable.drawGlobalItemRow(listBox, y, item, alt)
	end
	self.globalItemsList.onMouseDown = function()
		self:onGlobalItemSelected()
	end
	self.globalItemsList.onDoubleClick = function()
		self:onAddItemToSelected()
	end
	self.globalItemsList.joypadParent = self
	self.globalItemsList.drawBorder = true
	self.leftPanel:addChild(self.globalItemsList)

	-- LEFT: Filters
	local filterY = titleBarHeight + padding + 20 + headerHeight + padding + itemsTableHeight
	self.leftFiltersPanel = ISPanel:new(padding, filterY, leftPanelWidth, filterHeight)
	self.leftFiltersPanel:initialise()
	self.leftFiltersPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.1 }
	self:addChild(self.leftFiltersPanel)

	-- Initialize filter widgets array (vanilla pattern)
	self.filterWidgets = {}

	-- Initialize debounce for text filtering
	-- self.filterDebounceTimer = 0
	-- self.filterDebounceDelay = 0.10 -- 100ms delay

	-- Filters Label (big font like GLOBAL ITEMS)
	local filtersLabel = ISLabel:new(5, 5, KioskShopConfigUI.SMALL_FONT_HGT, "FILTERS", 1, 1, 1, 1, UIFont.Small, true)
	self.leftFiltersPanel:addChild(filtersLabel)

	-- Filter: Name (aligned with Name column: width reduced by 20)
	self.nameFilterBox = ISTextEntryBox:new("", 15, 25, 140, 22)
	self.nameFilterBox:initialise()
	self.nameFilterBox:instantiate()
	self.nameFilterBox.parent = self
	self.nameFilterBox.itemsListFilter = function(widget, item)
		return self:filterName(widget, item)
	end
	-- self.nameFilterBox.onTextChange = function()
	-- 	self.filterDebounceTimer = self.filterDebounceDelay
	-- end
	self.nameFilterBox.onOtherKey = function(widget, key)
		if key == Keyboard.KEY_ESCAPE then
			self.nameFilterBox:unfocus()
		end
	end
	self.nameFilterBox.onCommandEntered = function()
		self:applyFilters()
	end
	self.leftFiltersPanel:addChild(self.nameFilterBox)
	table.insert(self.filterWidgets, self.nameFilterBox)

	-- Filter: Display Name (moved right +10)
	self.displayNameFilterBox = ISTextEntryBox:new("", 210, 25, 190, 22)
	self.displayNameFilterBox:initialise()
	self.displayNameFilterBox:instantiate()
	self.displayNameFilterBox.parent = self
	self.displayNameFilterBox.itemsListFilter = function(widget, item)
		return self:filterDisplayName(widget, item)
	end
	-- self.displayNameFilterBox.onTextChange = function()
	-- 	self.filterDebounceTimer = self.filterDebounceDelay
	-- end
	self.displayNameFilterBox.onOtherKey = function(widget, key)
		if key == Keyboard.KEY_ESCAPE then
			self.displayNameFilterBox:unfocus()
		end
	end
	self.displayNameFilterBox.onCommandEntered = function()
		self:applyFilters()
	end
	self.leftFiltersPanel:addChild(self.displayNameFilterBox)
	table.insert(self.filterWidgets, self.displayNameFilterBox)

	-- Filter: Type (Combo box - moved right +10, width 125)
	self.typeFilterCombo = ISComboBox:new(420, 25, 125, 22)
	self.typeFilterCombo:initialise()
	self.typeFilterCombo:instantiate()
	self.typeFilterCombo.parent = self
	self.typeFilterCombo.itemsListFilter = function(widget, item)
		return self:filterTypeCombo(widget, item)
	end
	self.typeFilterCombo.onChange = function()
		self:onTypeFilterChange()
	end
	self.leftFiltersPanel:addChild(self.typeFilterCombo)
	table.insert(self.filterWidgets, self.typeFilterCombo)

	-- LEFT: Pagination
	local paginationY = filterY + filterHeight + 5
	self.leftPaginationPanel = ISPanel:new(padding, paginationY, leftPanelWidth, paginationHeight)
	self.leftPaginationPanel:initialise()
	self.leftPaginationPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.1 }
	self:addChild(self.leftPaginationPanel)

	self.prevPageBtn = ISButton:new(5, 5, 50, 22, "< Prev", self, KioskShopConfigUI.onPrevPage)
	self.prevPageBtn:initialise()
	self.leftPaginationPanel:addChild(self.prevPageBtn)

	self.pageLabel = ISLabel:new(65, 8, KioskShopConfigUI.SMALL_FONT_HGT, "Page 1 / 1", 1, 1, 1, 1, UIFont.Small, true)
	self.leftPaginationPanel:addChild(self.pageLabel)

	self.totalLabel = ISLabel:new(160, 8, KioskShopConfigUI.SMALL_FONT_HGT, "Total: 0", 0.7, 0.7, 0.7, 1, UIFont.Small,
		true)
	self.leftPaginationPanel:addChild(self.totalLabel)

	-- Go to page input (near Next button)
	-- local gotoLabel = ISLabel:new(leftPanelWidth - 165, 8, KioskShopConfigUI.SMALL_FONT_HGT, "Go:", 0.8, 0.8, 0.8, 1,
	-- 	UIFont.Small, true)
	-- self.leftPaginationPanel:addChild(gotoLabel)

	-- self.gotoPageBox = ISTextEntryBox:new("", leftPanelWidth - 135, 5, 35, 22)
	-- self.gotoPageBox:initialise()
	-- self.gotoPageBox:instantiate()
	-- self.gotoPageBox.onKeyPress = function(key)
	-- 	if key == Keyboard.KEY_RETURN then
	-- 		self:onGotoPage()
	-- 	end
	-- end
	-- self.leftPaginationPanel:addChild(self.gotoPageBox)

	self.nextPageBtn = ISButton:new(leftPanelWidth - 60, 5, 50, 22, "Next >", self, KioskShopConfigUI.onNextPage)
	self.nextPageBtn:initialise()
	self.leftPaginationPanel:addChild(self.nextPageBtn)

	-- RIGHT PANEL: Selected Items
	local rightPanelX = padding + leftPanelWidth + padding
	local rightPanelWidth = leftPanelWidth
	self.rightPanel = ISPanel:new(rightPanelX, titleBarHeight + padding, rightPanelWidth,
		self.height - titleBarHeight - padding - 5)
	self.rightPanel:initialise()
	self.rightPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
	self.rightPanel.borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 0.5 }
	self:addChild(self.rightPanel)

	-- RIGHT: Title label
	local rightTitleLabel = ISLabel:new(5, 5, KioskShopConfigUI.SMALL_FONT_HGT, "SELECTED ITEMS", 1, 1, 1, 1,
		UIFont.Small, true)
	self.rightPanel:addChild(rightTitleLabel)

	-- RIGHT: Column headers
	local rightHeaderPanel = ISPanel:new(5, 25, rightPanelWidth - 10, 20)
	rightHeaderPanel:initialise()
	rightHeaderPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.2 }
	self.rightPanel:addChild(rightHeaderPanel)

	local rightTypeHeader = ISLabel:new(5, 3, KioskShopConfigUI.SMALL_FONT_HGT, "Type", 0.9, 0.9, 0.9, 1, UIFont.Small,
		true)
	rightHeaderPanel:addChild(rightTypeHeader)

	local rightNameHeader = ISLabel:new(85, 3, KioskShopConfigUI.SMALL_FONT_HGT, "Name", 0.9, 0.9, 0.9, 1, UIFont.Small,
		true)
	rightHeaderPanel:addChild(rightNameHeader)

	local buyHeader = ISLabel:new(195, 3, KioskShopConfigUI.SMALL_FONT_HGT, "Buy", 0.9, 0.9, 0.9, 1, UIFont.Small, true)
	rightHeaderPanel:addChild(buyHeader)

	local sellHeader = ISLabel:new(245, 3, KioskShopConfigUI.SMALL_FONT_HGT, "Sell", 0.9, 0.9, 0.9, 1, UIFont.Small, true)
	rightHeaderPanel:addChild(sellHeader)

	local priceHeader = ISLabel:new(295, 3, KioskShopConfigUI.SMALL_FONT_HGT, "Price", 0.9, 0.9, 0.9, 1, UIFont.Small,
		true)
	rightHeaderPanel:addChild(priceHeader)

	-- RIGHT: Selected items table
	self.selectedItemsList = ISScrollingListBox:new(5, 48, rightPanelWidth - 10, itemsTableHeight)
	self.selectedItemsList:initialise()
	self.selectedItemsList:instantiate()
	self.selectedItemsList.itemheight = 22
	self.selectedItemsList.font = UIFont.Small
	-- Callback receives self (listBox) as first parameter when called as method
	self.selectedItemsList.doDrawItem = function(listBox, y, item, alt)
		-- ISScrollingListBox wraps items, unwrap if necessary
		if item and item.item and not item.name then
			item = item.item
		end
		return KioskItemsTable.drawSelectedItemRow(listBox, y, item, alt)
	end
	self.selectedItemsList.onMouseDown = function()
		self:onSelectedItemClicked()
	end
	self.selectedItemsList.joypadParent = self
	self.selectedItemsList.drawBorder = true
	self.rightPanel:addChild(self.selectedItemsList)

	-- RIGHT: Item Config Panel
	local configPanelY = filterY
	self.configPanel = KioskItemConfigPanel:create(self, rightPanelX, configPanelY, rightPanelWidth,
		filterHeight + paginationHeight)

	-- Initialize state
	self.currentPage = 1
	self.itemsPerPage = 100
	self.selectedItem = nil
	self.needsInitList = true
	self.allItems = {}
	self.filteredItems = {} -- Cache for filtered results
end

-- Global item selection
function KioskShopConfigUI:onGlobalItemSelected()
	if self.globalItemsList.selected then
		self:updateConfigPanel()
	end
end

-- Add selected global item to selected items
function KioskShopConfigUI:onAddItemToSelected()
	local item = self.globalItemsList.items[self.globalItemsList.selected]
	if not item then return end

	-- Check if already in selected items
	for i = 1, #self.selectedItemsList.items do
		if self.selectedItemsList.items[i].id == item.id then
			return -- Already added
		end
	end

	-- Add to selected items with default config
	local newItem = {
		item = item.item, -- Store full scriptItem object (vanilla pattern)
		id = item.id,
		type = item.type,
		name = item.name,
		displayName = item.displayName,
		buy = false,
		sell = false,
		buyPrice = 0,
		sellPrice = 0,
		index = #self.selectedItemsList.items + 1
	}
	self.selectedItemsList:addItem(item.name, newItem)
end

-- Selected item clicked
function KioskShopConfigUI:onSelectedItemClicked()
	if self.selectedItemsList.selected then
		self:updateConfigPanel()
	end
end

-- Update config panel for selected item
function KioskShopConfigUI:updateConfigPanel()
	local item = self.selectedItemsList.items[self.selectedItemsList.selected]
	if not item then
		self.configPanel:setVisible(false)
		return
	end

	self.selectedItem = item
	KioskItemConfigPanel:loadItem(self.configPanel, item)
end

-- Config changed callback
function KioskShopConfigUI:onConfigChanged()
	if not self.selectedItem then return end
	KioskItemConfigPanel:applyToItem(self.configPanel, self.selectedItem)
	self.selectedItemsList:invalidate()
end

-- Filter functions (vanilla ISItemsListTable pattern)
function KioskShopConfigUI:filterTypeCombo(widget, item)
	if widget.selected == 1 then return true end -- "<Any>" option = pass all
	local selectedType = widget:getOptionText(widget.selected)
	if not selectedType or selectedType == "" then return true end
	return (item.type or "") == selectedType
end

function KioskShopConfigUI:filterName(widget, item)
	local filterText = string.lower(widget:getInternalText() or "")
	if filterText == "" then return true end -- Empty filter = pass all
	local itemName = string.lower(item.name or "")
	return checkStringPattern(filterText) and string.match(itemName, filterText) ~= nil
end

function KioskShopConfigUI:filterDisplayName(widget, item)
	local filterText = string.lower(widget:getInternalText() or "")
	if filterText == "" then return true end -- Empty filter = pass all
	local displayName = string.lower(item.displayName or "")
	return checkStringPattern(filterText) and string.match(displayName, filterText) ~= nil
end

-- Type filter changed (apply immediately)
function KioskShopConfigUI:onTypeFilterChange()
	self.currentPage = 1
	self:applyFilters()
end

-- Apply all active filters to items (vanilla core loop pattern)
function KioskShopConfigUI:applyFilters()
	self.globalItemsList:clear()

	-- Cache original items if not already cached
	if not self.fullItemList then
		self.fullItemList = {}
		for i = 1, #self.allItems do
			table.insert(self.fullItemList, self.allItems[i])
		end
		KioskShopConfigUI.log("applyFilters() - created fullItemList with " .. #self.fullItemList .. " items")
	end

	-- Reset filtered list
	self.filteredItems = {}

	-- Loop every item in full list
	for i = 1, #self.fullItemList do
		local item = self.fullItemList[i]
		local add = true

		-- Loop every filter widget (AND logic)
		for j = 1, #self.filterWidgets do
			local widget = self.filterWidgets[j]
			if widget and widget.itemsListFilter then
				if not widget.itemsListFilter(widget, item) then
					add = false
					break
				end
			end
		end

		if add then
			table.insert(self.filteredItems, item)
		end
	end

	KioskShopConfigUI.log("applyFilters() - fullItemList size: " ..
		#self.fullItemList .. ", filtered down to " .. #self.filteredItems .. " items")

	-- Debug: check filter results
	if #self.filteredItems == 0 and #self.fullItemList > 0 then
		KioskShopConfigUI.log("  WARNING: Filtered list empty but fullItemList has items!")
	end

	-- Debug: check first few filtered items
	for i = 1, math.min(3, #self.filteredItems) do
		local item = self.filteredItems[i]
		KioskShopConfigUI.log("  filteredItems[" ..
			i .. "]: name='" .. tostring(item.name) .. "', type='" .. tostring(item.type) .. "'")
	end

	-- Paginate filtered results
	local maxPages = KioskItemsTable:getMaxPages(#self.filteredItems, self.itemsPerPage)
	local paginated = KioskItemsTable:getPaginatedItems(self.filteredItems, self.currentPage, self.itemsPerPage)

	KioskShopConfigUI.log("applyFilters() - page " ..
		self.currentPage .. " of " .. maxPages .. " has " .. #paginated .. " paginated items")

	-- Add paginated items to listbox
	for i = 1, #paginated do
		local item = paginated[i]
		if not item or not item.name then
			KioskShopConfigUI.log("applyFilters() - paginated[" .. i .. "] missing name: " .. tostring(item))
			if item then
				KioskShopConfigUI.log("  item keys: " .. table.concat(KioskItemsTable:getTableKeys(item) or {}, ", "))
			end
		end
		self.globalItemsList:addItem(item.name, item)
	end

	-- Update pagination labels
	self.pageLabel:setName("Page " .. self.currentPage .. " / " .. math.max(1, maxPages))
	self.totalLabel:setName("Total: " .. #self.filteredItems)
end

-- Pagination (bypass debounce, repaginate existing filtered items)
function KioskShopConfigUI:onPrevPage()
	if self.currentPage > 1 then
		self.currentPage = self.currentPage - 1
		self:rebuildPagination()
	end
end

function KioskShopConfigUI:onNextPage()
	local maxPages = KioskItemsTable:getMaxPages(#self.filteredItems, self.itemsPerPage)
	if self.currentPage < maxPages then
		self.currentPage = self.currentPage + 1
		self:rebuildPagination()
	end
end

function KioskShopConfigUI:onGotoPage()
	local pageText = self.gotoPageBox:getText() or ""
	local pageNum = tonumber(pageText)

	if not pageNum then return end

	local maxPages = KioskItemsTable:getMaxPages(#self.filteredItems, self.itemsPerPage)
	pageNum = math.max(1, math.min(pageNum, maxPages))

	self.currentPage = pageNum
	self:rebuildPagination()
	self.gotoPageBox:setText("")
end

-- Rebuild pagination without re-filtering (fast pagination)
function KioskShopConfigUI:rebuildPagination()
	self.globalItemsList:clear()

	local maxPages = KioskItemsTable:getMaxPages(#self.filteredItems, self.itemsPerPage)
	local paginated = KioskItemsTable:getPaginatedItems(self.filteredItems, self.currentPage, self.itemsPerPage)

	for i = 1, #paginated do
		local item = paginated[i]
		self.globalItemsList:addItem(item.name, item)
	end

	self.pageLabel:setName("Page " .. self.currentPage .. " / " .. math.max(1, maxPages))
end

-- Initialize list from game item registry (vanilla ISItemsListTable pattern)
function KioskShopConfigUI:initList()
	self.allItems = {}
	self.filteredItems = {}
	self.fullItemList = nil -- Reset cache to rebuild from scratch

	local allItems = getAllItems()
	if not allItems then
		KioskShopConfigUI.log("initList() - getAllItems() returned nil")
		return
	end

	KioskShopConfigUI.log("initList() - getAllItems() returned " .. allItems:size() .. " items")

	for i = 0, allItems:size() - 1 do
		local scriptItem = allItems:get(i)
		if scriptItem then
			-- Try to get type
			local itemType = scriptItem:getItemType():toString()
			if not itemType or itemType == "" then
				itemType = "Unknown"
			end

			-- Try to get name
			local name = scriptItem:getName()
			if not name or name == "" then
				name = "Unknown"
			end

			-- Try to get display name
			local displayName = scriptItem:getDisplayName()
			if not displayName or displayName == "" then
				displayName = scriptItem:getName()
			end
			if not displayName or displayName == "" then
				displayName = "Unknown"
			end

			-- Try to get module name
			local moduleName = scriptItem:getModuleName()
			if not moduleName or moduleName == "" then
				moduleName = "Base"
			end

			table.insert(self.allItems, {
				item = scriptItem, -- Store full scriptItem object (vanilla pattern)
				id = i,
				type = itemType,
				name = name,
				displayName = displayName,
				module = moduleName,
				buy = false,
				sell = false,
				buyPrice = 0,
				sellPrice = 0,
				index = #self.allItems + 1
			})
		end
	end

	KioskShopConfigUI.log("initList() - self.allItems has " .. #self.allItems .. " items")

	-- Populate Type combo box with unique types
	local uniqueTypes = {}
	local typeMap = {}
	for i = 1, #self.allItems do
		local itemType = self.allItems[i].type
		if not typeMap[itemType] then
			typeMap[itemType] = true
			table.insert(uniqueTypes, itemType)
		end
	end
	table.sort(uniqueTypes)

	self.typeFilterCombo:clear()
	self.typeFilterCombo:addOption("<Any>") -- Always first option for "no filter"
	for _, typeValue in ipairs(uniqueTypes) do
		self.typeFilterCombo:addOption(typeValue)
	end
	self.typeFilterCombo.selected = 1 -- Default to "<Any>"

	self.currentPage = 1
	self.nameFilterBox:setText("")
	self.displayNameFilterBox:setText("")
	self:applyFilters()

	KioskShopConfigUI.log("initList() - after applyFilters, globalItemsList has " ..
		#self.globalItemsList.items .. " items")
end

-- Close button callback
function KioskShopConfigUI:onClose()
	self:close()
end

-- Cleanup
function KioskShopConfigUI:close()
	ISPanel.close(self)
	self.character = nil
	self.globalItemsList = nil
	self.selectedItemsList = nil
	self.configPanel = nil
	self.typeFilterCombo = nil
	self.nameFilterBox = nil
	self.displayNameFilterBox = nil
	self.filterWidgets = nil
	self.allItems = nil
	self.filteredItems = nil
	self.fullItemList = nil
	self:removeFromUIManager()
end

-- Constructor
function KioskShopConfigUI:new(player)
	local width, height = getWindowDimensions()
	local x = (getCore():getScreenWidth() / 2) - (width / 2)
	local y = (getCore():getScreenHeight() / 2) - (height / 2)

	local o = ISPanel:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self
	o.title = "Kiosk Shop Config"
	o.character = player
	o.player = player
	o.resizable = false
	o.moveablePanel = false
	o:setWantKeyEvents(true) -- (method call, not property)
	o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.7 }
	o.borderColor = { r = 0.5, g = 0.5, b = 0.5, a = 0.8 }
	return o
end
