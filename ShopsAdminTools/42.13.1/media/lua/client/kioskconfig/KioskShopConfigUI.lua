-- KioskShopConfigUI: Two-panel kiosk shop configuration window
-- Reference: docs/ShopsAdminTools/UI_Update.md
---@class KioskShopConfigUI : ISPanel
KioskShopConfigUI = ISPanel:derive("KioskShopConfigUI")

KioskShopConfigUI.SMALL_FONT_HGT = getTextManager():getFontFromEnum(UIFont.Small):getLineHeight()
KioskShopConfigUI.MEDIUM_FONT_HGT = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight()

-- Load coin textures once at class level
KioskShopConfigUI.copperCoinTexture = tryGetTexture("Item_CopperCoin")
KioskShopConfigUI.eventCoinTexture = tryGetTexture("Item_EventCoin")

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
	-- 		self:applyLeftFilters()
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

	local fontSizeMultiplier = getCore():getOptionFontSizeReal()
	local titleBarHeight = 30
	local padding = 10
	local tinyPadding = 3
	local titleHeight = 20 + (fontSizeMultiplier * 5)
	local headerHeight = 20 + (fontSizeMultiplier * 5)
	local filterHeight = 30                             -- Fixed filter row height
	local headerFilterHeight = headerHeight + filterHeight -- Combined headers + filters panel
	local paginationHeight = 35                         -- Fixed pagination height

	-- Calculate fixed sections BEFORE table (title and combined headers+filters are fixed)
	local fixedHeightBeforeTable = titleBarHeight + padding + titleHeight + padding + headerFilterHeight + tinyPadding

	-- Remaining height for table + pagination + WIP
	local remainingHeight = self.height - fixedHeightBeforeTable - padding

	-- Give table the remaining space minus pagination and WIP bottom padding
	local itemsTableHeight = 330 -- 15 rows × 22px

	-- WIP gets what's left after table and pagination, but constrained to not overflow panel
	local maxWipHeight = self.height - fixedHeightBeforeTable - tinyPadding - itemsTableHeight - tinyPadding -
		paginationHeight - padding
	local wipHeight = math.max(0, maxWipHeight)

	-- LEFT PANEL: Global Items
	local leftPanelWidth = (self.width - padding * 3) / 2
	local leftPanelY = titleBarHeight + padding
	local leftPanelHeight = self.height - titleBarHeight - padding - 5
	self.leftPanel = ISPanel:new(padding, leftPanelY, leftPanelWidth, leftPanelHeight)
	self.leftPanel:initialise()
	self.leftPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
	self.leftPanel.borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 0.5 }
	self:addChild(self.leftPanel)

	-- LEFT: Title label
	local titleLabel = ISLabel:new(5, 5, KioskShopConfigUI.SMALL_FONT_HGT, "GLOBAL ITEMS", 1, 1, 1, 1, UIFont.Small, true)
	self.leftPanel:addChild(titleLabel)

	-- LEFT: Combined Headers + Filters Panel
	local headerFilterY = titleHeight + padding
	self.leftHeaderFilterPanel = ISPanel:new(5, headerFilterY, leftPanelWidth - 10, headerFilterHeight)
	self.leftHeaderFilterPanel:initialise()
	self.leftHeaderFilterPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.1 }
	self.leftPanel:addChild(self.leftHeaderFilterPanel)

	-- Column headers (at top of combined panel)
	local headerPanel = ISPanel:new(0, 0, leftPanelWidth - 10, headerHeight)
	headerPanel:initialise()
	headerPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.2 }
	self.leftHeaderFilterPanel:addChild(headerPanel)

	local nameHeader = ISLabel:new(40, 3, KioskShopConfigUI.SMALL_FONT_HGT, "Name", 0.9, 0.9, 0.9, 1, UIFont.Small, true)
	headerPanel:addChild(nameHeader)

	local displayNameHeader = ISLabel:new(205, 3, KioskShopConfigUI.SMALL_FONT_HGT, "Display Name", 0.9, 0.9, 0.9, 1,
		UIFont.Small, true)
	headerPanel:addChild(displayNameHeader)

	local typeHeader = ISLabel:new(420, 3, KioskShopConfigUI.SMALL_FONT_HGT, "Type", 0.9, 0.9, 0.9, 1, UIFont.Small, true)
	headerPanel:addChild(typeHeader)

	-- Filters (below headers, within same panel)
	self.leftFiltersPanel = ISPanel:new(0, headerHeight, leftPanelWidth - 10, filterHeight)
	self.leftFiltersPanel:initialise()
	self.leftFiltersPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
	self.leftHeaderFilterPanel:addChild(self.leftFiltersPanel)

	-- Initialize filter widgets array (vanilla pattern)
	self.filterWidgets = {}

	-- Filter: Name (X=40 like header, width = 160 to match row content)
	self.leftNameFilterBox = ISTextEntryBox:new("", 40, 5, 160, 22)
	self.leftNameFilterBox:initialise()
	self.leftNameFilterBox:instantiate()
	self.leftNameFilterBox.parent = self
	self.leftNameFilterBox.itemsListFilter = function(widget, item)
		return self:filterName(widget, item)
	end
	self.leftNameFilterBox.onOtherKey = function(widget, key)
		if key == Keyboard.KEY_ESCAPE then
			self.leftNameFilterBox:unfocus()
		end
	end
	self.leftNameFilterBox.onCommandEntered = function()
		self:applyLeftTableFilters()
	end
	self.leftFiltersPanel:addChild(self.leftNameFilterBox)
	table.insert(self.filterWidgets, self.leftNameFilterBox)

	-- Filter: Display Name (X=205 like header, width = 205 - 15 = 190)
	self.displayNameFilterBox = ISTextEntryBox:new("", 205, 5, 190, 22)
	self.displayNameFilterBox:initialise()
	self.displayNameFilterBox:instantiate()
	self.displayNameFilterBox.parent = self
	self.displayNameFilterBox.itemsListFilter = function(widget, item)
		return self:filterDisplayName(widget, item)
	end
	self.displayNameFilterBox.onOtherKey = function(widget, key)
		if key == Keyboard.KEY_ESCAPE then
			self.displayNameFilterBox:unfocus()
		end
	end
	self.displayNameFilterBox.onCommandEntered = function()
		self:applyLeftTableFilters()
	end
	self.leftFiltersPanel:addChild(self.displayNameFilterBox)
	table.insert(self.filterWidgets, self.displayNameFilterBox)

	-- Filter: Type (X=420 like header, width = remaining-45 to leave room for clear button)
	self.typeFilterCombo = ISComboBox:new(420, 5, leftPanelWidth - 10 - 420 - 45, 22)
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

	-- Clear Filters Button (X before Name input)
	self.clearFiltersBtn = ISButton:new(5, 5, 25, 22, "X", self, KioskShopConfigUI.onClearLeftFilters)
	self.clearFiltersBtn:initialise()
	self.leftFiltersPanel:addChild(self.clearFiltersBtn)

	-- LEFT: Items table (below combined headers+filters panel)
	local tableY = headerFilterY + headerFilterHeight + tinyPadding
	self.globalItemsList = ISScrollingListBox:new(5, tableY, leftPanelWidth - 10, itemsTableHeight)
	self.globalItemsList:initialise()
	self.globalItemsList:instantiate()
	self.globalItemsList.itemheight = 22
	self.globalItemsList.font = UIFont.Small
	-- Callback receives self (listBox) as first parameter when called as method
	self.globalItemsList.doDrawItem = function(listBox, y, _drawItem, alt)
		-- Check if typeFilterCombo is in interaction state (expanded, focused, or mouse over)
		local comboboxOpen = self.typeFilterCombo and
			(self.typeFilterCombo.expanded or self.typeFilterCombo.joypadFocused or self.typeFilterCombo:isMouseOver()) or
			false
		return KioskItemsTable.drawGlobalItemRow(listBox, y, _drawItem, alt, self.SELECTED_SCRIPT_ITEMS, comboboxOpen)
	end
	-- Handle single left click on Global Items (vanilla pattern)
	self.globalItemsList.onMouseDown = function(listBox, x, y)
		if #listBox.items == 0 then return end
		local row = listBox:rowAt(x, y + 3)
		if row < 1 then return end

		-- Check if item is already in SELECTED_SCRIPT_ITEMS (prevent selecting duplicates)
		local clickedItem = listBox.items[row]
		for i = 1, #self.SELECTED_SCRIPT_ITEMS do
			local selectedItem = self.SELECTED_SCRIPT_ITEMS[i]
			if selectedItem and selectedItem.fullType == clickedItem.fullType then
				return -- Item already selected, ignore click
			end
		end

		listBox.selected = row
		getSoundManager():playUISound("UISelectListItem")
		self:onGlobalItemSelected()
	end

	-- Handle double click on Global Items (vanilla pattern - adds to selected items)
	self.globalItemsList:setOnMouseDoubleClick(self, self.onGlobalItemDoubleClick)
	self.globalItemsList.joypadParent = self
	self.globalItemsList.drawBorder = true
	self.leftPanel:addChild(self.globalItemsList)

	-- LEFT: Pagination Section (below table)
	local paginationY = tableY + itemsTableHeight + tinyPadding
	self.leftPaginationPanel = ISPanel:new(5, paginationY, leftPanelWidth - 10, paginationHeight)
	self.leftPaginationPanel:initialise()
	self.leftPaginationPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.1 }
	self.leftPanel:addChild(self.leftPaginationPanel)

	self.prevPageBtn = ISButton:new(5, 5, 50, 22, "< Prev", self, KioskShopConfigUI.onPrevPage)
	self.prevPageBtn:initialise()
	self.leftPaginationPanel:addChild(self.prevPageBtn)

	self.pageLabel = ISLabel:new(65, 8, KioskShopConfigUI.SMALL_FONT_HGT, "Page 1 / 1", 1, 1, 1, 1, UIFont.Small, true)
	self.leftPaginationPanel:addChild(self.pageLabel)

	self.nextPageBtn = ISButton:new(150, 5, 50, 22, "Next >", self, KioskShopConfigUI.onNextPage)
	self.nextPageBtn:initialise()
	self.leftPaginationPanel:addChild(self.nextPageBtn)

	-- Total label centered
	local totalLabelX = (leftPanelWidth - 10) / 2 - 20
	self.totalLabel = ISLabel:new(totalLabelX, 8, KioskShopConfigUI.SMALL_FONT_HGT, "Total: 0", 0.7, 0.7, 0.7, 1,
		UIFont.Small, true)
	self.leftPaginationPanel:addChild(self.totalLabel)

	-- Select All button (right side of pagination)
	self.selectAllBtn = ISButton:new(leftPanelWidth - 10 - 100, 5, 95, 22, "Select All ->", self,
		KioskShopConfigUI.onSelectAllPage)
	self.selectAllBtn:initialise()
	self.leftPaginationPanel:addChild(self.selectAllBtn)

	-- LEFT: WIP Section (future features)
	local wipY = paginationY + paginationHeight + padding
	-- Constrain WIP height to not overflow panel and stay 3px within bounds
	local maxWipPanelHeight = leftPanelHeight - wipY - 3
	local constrainedWipHeight = math.min(wipHeight, math.max(0, maxWipPanelHeight))
	self.leftWIPPanel = ISPanel:new(5, wipY, leftPanelWidth - 10, constrainedWipHeight)
	self.leftWIPPanel:initialise()
	self.leftWIPPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.1 }
	self.leftPanel:addChild(self.leftWIPPanel)

	-- RIGHT PANEL: Selected Items
	local rightPanelX = padding + leftPanelWidth + padding
	local rightPanelWidth = leftPanelWidth
	local rightPanelY = titleBarHeight + padding
	local rightPanelHeight = self.height - titleBarHeight - padding - 5
	self.rightPanel = ISPanel:new(rightPanelX, rightPanelY, rightPanelWidth, rightPanelHeight)
	self.rightPanel:initialise()
	self.rightPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
	self.rightPanel.borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 0.5 }
	self:addChild(self.rightPanel)

	-- RIGHT: Title label
	local rightTitleLabel = ISLabel:new(5, 5, KioskShopConfigUI.SMALL_FONT_HGT, "SELECTED ITEMS", 1, 1, 1, 1,
		UIFont.Small, true)
	self.rightPanel:addChild(rightTitleLabel)

	-- RIGHT: Combined Headers + Filters Panel
	local rightHeaderFilterY = titleHeight + padding
	self.rightHeaderFilterPanel = ISPanel:new(5, rightHeaderFilterY, rightPanelWidth - 10, headerFilterHeight)
	self.rightHeaderFilterPanel:initialise()
	self.rightHeaderFilterPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.1 }
	self.rightPanel:addChild(self.rightHeaderFilterPanel)

	-- Column headers (at top of combined panel)
	local rightHeaderPanel = ISPanel:new(0, 0, rightPanelWidth - 10, headerHeight)
	rightHeaderPanel:initialise()
	rightHeaderPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.2 }
	self.rightHeaderFilterPanel:addChild(rightHeaderPanel)

	local rightNameHeader = ISLabel:new(40, 3, KioskShopConfigUI.SMALL_FONT_HGT, "Name", 0.9, 0.9, 0.9, 1, UIFont.Small,
		true)
	rightHeaderPanel:addChild(rightNameHeader)

	local buyHeader = ISLabel:new(205, 3, KioskShopConfigUI.SMALL_FONT_HGT, "Buy", 0.9, 0.9, 0.9, 1, UIFont.Small, true)
	rightHeaderPanel:addChild(buyHeader)

	local sellHeader = ISLabel:new(290, 3, KioskShopConfigUI.SMALL_FONT_HGT, "Sell", 0.9, 0.9, 0.9, 1, UIFont.Small, true)
	rightHeaderPanel:addChild(sellHeader)

	-- Filters (below headers, within same panel)
	self.rightFiltersPanel = ISPanel:new(0, headerHeight, rightPanelWidth - 10, filterHeight)
	self.rightFiltersPanel:initialise()
	self.rightFiltersPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
	self.rightHeaderFilterPanel:addChild(self.rightFiltersPanel)

	-- Initialize filter widgets array for right table
	self.rightFilterWidgets = {}

	-- Filter: Name (X=40 like header, width = 160 to match left side)
	self.rightNameFilterBox = ISTextEntryBox:new("", 40, 5, 160, 22)
	self.rightNameFilterBox:initialise()
	self.rightNameFilterBox:instantiate()
	self.rightNameFilterBox.parent = self
	self.rightNameFilterBox.onOtherKey = function(widget, key)
		if key == Keyboard.KEY_ESCAPE then
			self.rightNameFilterBox:unfocus()
		end
	end
	self.rightNameFilterBox.onCommandEntered = function()
		self:applyRightFilters()
	end
	self.rightFiltersPanel:addChild(self.rightNameFilterBox)

	-- Filter: Buy (X=205 like header, width = 80 for "100,000")
	self.rightBuyFilterCombo = ISComboBox:new(205, 5, 80, 22)
	self.rightBuyFilterCombo:initialise()
	self.rightBuyFilterCombo:instantiate()
	self.rightBuyFilterCombo:addOption("<Any>")
	self.rightBuyFilterCombo:addOption("Yes")
	self.rightBuyFilterCombo:addOption("No")
	self.rightBuyFilterCombo.selected = 1
	self.rightBuyFilterCombo.parent = self
	self.rightBuyFilterCombo.onChange = function()
		self:applyRightFilters()
	end
	self.rightFiltersPanel:addChild(self.rightBuyFilterCombo)
	table.insert(self.rightFilterWidgets, self.rightBuyFilterCombo)

	-- Filter: Sell (X=290 like header, width = 80 for "100,000")
	self.rightSellFilterCombo = ISComboBox:new(290, 5, 80, 22)
	self.rightSellFilterCombo:initialise()
	self.rightSellFilterCombo:instantiate()
	self.rightSellFilterCombo:addOption("<Any>")
	self.rightSellFilterCombo:addOption("Yes")
	self.rightSellFilterCombo:addOption("No")
	self.rightSellFilterCombo.selected = 1
	self.rightSellFilterCombo.parent = self
	self.rightSellFilterCombo.onChange = function()
		self:applyRightFilters()
	end
	self.rightFiltersPanel:addChild(self.rightSellFilterCombo)
	table.insert(self.rightFilterWidgets, self.rightSellFilterCombo)

	-- RIGHT: Selected items table (below combined headers+filters panel)
	local rightTableY = rightHeaderFilterY + headerFilterHeight + tinyPadding
	self.selectedItemsList = ISScrollingListBox:new(5, rightTableY, rightPanelWidth - 10, itemsTableHeight)
	self.selectedItemsList:initialise()
	self.selectedItemsList:instantiate()
	self.selectedItemsList.itemheight = 22
	self.selectedItemsList.font = UIFont.Small
	-- Callback receives self (listBox) as first parameter when called as method
	self.selectedItemsList.doDrawItem = function(listBox, y, drawItem, alt)
		-- Check if any right-side combobox is in interaction state
		local comboboxOpen = (self.rightBuyFilterCombo and (self.rightBuyFilterCombo.expanded or self.rightBuyFilterCombo.joypadFocused or self.rightBuyFilterCombo:isMouseOver())) or
			(self.rightSellFilterCombo and (self.rightSellFilterCombo.expanded or self.rightSellFilterCombo.joypadFocused or self.rightSellFilterCombo:isMouseOver())) or
			false
		return KioskItemsTable.drawSelectedItemRow(listBox, y, drawItem, alt, comboboxOpen)
	end
	-- Single click handler to select and update editor panel
	self.selectedItemsList.onMouseDown = function(listBox, x, y)
		KioskShopConfigUI.log("Right onMouseDown called with: listBox=" ..
			tostring(listBox ~= nil) .. ", x=" .. tostring(x) .. ", y=" .. tostring(y))
		if #listBox.items == 0 then return end
		local row = listBox:rowAt(x, y + 3)
		KioskShopConfigUI.log("Right table click: x=" .. x .. ", y=" .. y .. ", row=" .. tostring(row))
		if not row or row < 1 then return end

		listBox.selected = row
		getSoundManager():playUISound("UISelectListItem")
		local listBoxItem = listBox.items[row]
		self:onSelectedItemRightTable(listBoxItem)
		self:onSelectedItemEditorUpdate(listBoxItem)
	end
	-- Double click handler to remove from selected items
	self.selectedItemsList:setOnMouseDoubleClick(self, self.onRemoveItemFromSelectedScriptItems)
	self.selectedItemsList.joypadParent = self
	self.selectedItemsList.drawBorder = true
	self.rightPanel:addChild(self.selectedItemsList)

	-- RIGHT: Pagination Section (below table)
	local rightPaginationY = rightTableY + itemsTableHeight + tinyPadding
	self.rightPaginationPanel = ISPanel:new(5, rightPaginationY, rightPanelWidth - 10, paginationHeight)
	self.rightPaginationPanel:initialise()
	self.rightPaginationPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.1 }
	self.rightPanel:addChild(self.rightPaginationPanel)

	self.rightPrevPageBtn = ISButton:new(5, 5, 50, 22, "< Prev", self, KioskShopConfigUI.onRightPrevPage)
	self.rightPrevPageBtn:initialise()
	self.rightPaginationPanel:addChild(self.rightPrevPageBtn)

	self.rightPageLabel = ISLabel:new(65, 8, KioskShopConfigUI.SMALL_FONT_HGT, "Page 1 / 1", 1, 1, 1, 1, UIFont.Small,
		true)
	self.rightPaginationPanel:addChild(self.rightPageLabel)

	self.rightNextPageBtn = ISButton:new(150, 5, 50, 22, "Next >", self, KioskShopConfigUI.onRightNextPage)
	self.rightNextPageBtn:initialise()
	self.rightPaginationPanel:addChild(self.rightNextPageBtn)

	-- Total label centered
	local rightTotalLabelX = (rightPanelWidth - 10) / 2 - 20
	self.rightTotalLabel = ISLabel:new(rightTotalLabelX, 8, KioskShopConfigUI.SMALL_FONT_HGT, "Total: 0", 0.7, 0.7, 0.7,
		1, UIFont.Small, true)
	self.rightPaginationPanel:addChild(self.rightTotalLabel)

	-- Deselect All button (right side of pagination)
	self.deselectAllBtn = ISButton:new(rightPanelWidth - 10 - 115, 5, 110, 22, "<- Deselect All", self,
		KioskShopConfigUI.onDeselectAllPage)
	self.deselectAllBtn:initialise()
	self.rightPaginationPanel:addChild(self.deselectAllBtn)

	-- RIGHT: WIP Section (item editor panel)
	local rightWipY = rightPaginationY + paginationHeight + padding
	-- Constrain WIP height to not overflow panel and stay 3px within bounds
	local maxRightWipPanelHeight = rightPanelHeight - rightWipY - 3
	local constrainedRightWipHeight = math.min(wipHeight, math.max(0, maxRightWipPanelHeight))
	self.rightWIPPanel = ISPanel:new(5, rightWipY, rightPanelWidth - 10, constrainedRightWipHeight)
	self.rightWIPPanel:initialise()
	self.rightWIPPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.1 }
	self.rightPanel:addChild(self.rightWIPPanel)

	-- Item fullType label
	local wipPadding = 5
	local lineSpacing = 8
	self.itemFullTypeLabel = ISLabel:new(wipPadding, wipPadding, KioskShopConfigUI.SMALL_FONT_HGT, '["_____"]', 1, 1, 1,
		1, UIFont
		.Small, true)
	self.rightWIPPanel:addChild(self.itemFullTypeLabel)

	-- Buy Price section (compact, single line)
	local buyY = wipPadding + KioskShopConfigUI.SMALL_FONT_HGT + lineSpacing
	local buyLabel = ISLabel:new(wipPadding, buyY, KioskShopConfigUI.SMALL_FONT_HGT, "Player Spend (Buy Price):", 0.8,
		0.8, 0.8, 1,
		UIFont.Small,
		true)
	self.rightWIPPanel:addChild(buyLabel)

	local labelWidth = 160
	local inputWidth = 60
	local iconSize = 20
	local spacing = 5
	local checkboxWidth = 100

	local buyInputX = wipPadding + labelWidth + spacing
	local buyIconX = buyInputX + inputWidth + spacing
	local buyCheckboxX = buyIconX + iconSize + spacing

	self.buyPriceInput = ISTextEntryBox:new("", buyInputX, buyY, inputWidth, 20)
	self.buyPriceInput:initialise()
	self.buyPriceInput:instantiate()
	self.buyPriceInput:setOnlyNumbers(true)
	self.buyPriceInput.parent = self
	self.buyPriceInput.onOtherKey = function(widget, key)
		if key == Keyboard.KEY_ESCAPE then
			self.buyPriceInput:unfocus()
		end
	end

	self.rightWIPPanel:addChild(self.buyPriceInput)

	-- Item icon placeholder (Buy)
	self.buyIconPlaceholder = ISPanel:new(buyIconX, buyY, iconSize, 20)
	self.buyIconPlaceholder:initialise()
	self.buyIconPlaceholder.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
	self.buyIconPlaceholder.borderColor = { r = 0, g = 0, b = 0, a = 0 }
	self.buyIconPlaceholder.texture = KioskShopConfigUI.copperCoinTexture
	self.buyIconPlaceholder.render = function(panel)
		ISPanel.render(panel)
		if panel.texture then
			panel:drawTextureScaled(panel.texture, 0, 0, panel.width, panel.height, 1, 1, 1, 1)
		end
	end
	self.rightWIPPanel:addChild(self.buyIconPlaceholder)

	self.buyPriceSpecialCheckbox = ISTickBox:new(buyCheckboxX, buyY, checkboxWidth, 20, "Special", self, nil)
	self.buyPriceSpecialCheckbox:initialise()
	self.buyPriceSpecialCheckbox:addOption("Special ?", false)
	-- Set callback with proper closure binding
	self.buyPriceSpecialCheckbox.changeOptionMethod = function(tickbox, index, isChecked)
		self:onBuySpecialChanged(index, isChecked)
	end
	self.rightWIPPanel:addChild(self.buyPriceSpecialCheckbox)

	-- Sell Price section (compact, single line)
	local sellY = buyY + KioskShopConfigUI.SMALL_FONT_HGT + lineSpacing
	local sellLabel = ISLabel:new(wipPadding, sellY, KioskShopConfigUI.SMALL_FONT_HGT, "Player Earn    (Sell Price):",
		0.8,
		0.8, 0.8, 1,
		UIFont.Small,
		true)
	self.rightWIPPanel:addChild(sellLabel)

	local sellInputX = buyInputX
	local sellIconX = buyIconX
	local sellCheckboxX = buyCheckboxX

	self.sellPriceInput = ISTextEntryBox:new("", sellInputX, sellY, inputWidth, 20)
	self.sellPriceInput:initialise()
	self.sellPriceInput:instantiate()
	self.sellPriceInput:setOnlyNumbers(true)
	self.sellPriceInput.parent = self
	self.sellPriceInput.onOtherKey = function(widget, key)
		if key == Keyboard.KEY_ESCAPE then
			self.sellPriceInput:unfocus()
		end
	end
	-- Then:
	self.sellPriceInput.onTextChangeFunction = function(target, entry)
		self:onSellPriceChanged(target, entry)
	end
	self.rightWIPPanel:addChild(self.sellPriceInput)

	-- Item icon placeholder (Sell)
	self.sellIconPlaceholder = ISPanel:new(sellIconX, sellY, iconSize, 20)
	self.sellIconPlaceholder:initialise()
	self.sellIconPlaceholder.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
	self.sellIconPlaceholder.borderColor = { r = 0, g = 0, b = 0, a = 0 }
	self.sellIconPlaceholder.texture = KioskShopConfigUI.copperCoinTexture
	self.sellIconPlaceholder.render = function(panel)
		ISPanel.render(panel)
		if panel.texture then
			panel:drawTextureScaled(panel.texture, 0, 0, panel.width, panel.height, 1, 1, 1, 1)
		end
	end
	self.rightWIPPanel:addChild(self.sellIconPlaceholder)

	self.sellPriceSpecialCheckbox = ISTickBox:new(sellCheckboxX, sellY, checkboxWidth, 20, "Special", self, nil)
	self.sellPriceSpecialCheckbox:initialise()
	self.sellPriceSpecialCheckbox:addOption("Special ?", false)
	-- Set callback with proper closure binding
	self.sellPriceSpecialCheckbox.changeOptionMethod = function(tickbox, index, isChecked)
		self:onSellSpecialChanged(index, isChecked)
	end
	self.rightWIPPanel:addChild(self.sellPriceSpecialCheckbox)

	-- Initialize state
	self.currentPage = 1
	self.rightCurrentPage = 1
	self.itemsPerPage = 100
	self.selectedItem = nil
	self.needsInitList = true
	self.scriptItems = {}
	self.filteredScriptItems = {} -- Cache for filtered results

	-- SELECTED_SCRIPT_ITEMS: Source of truth for selected items (persists across filters)
	-- selectedItemsList (UIList): Filtered view of SELECTED_SCRIPT_ITEMS
	self.SELECTED_SCRIPT_ITEMS = {}

	local function setupPriceInput(inputWidget, defaultValue)
		inputWidget.onFocus = function(widget)
			if tonumber(widget:getText()) == 0 then
				widget:setText("")
			end
		end

		inputWidget.onUnfocus = function(widget)
			if widget:getText() == "" then
				widget:setText(tostring(defaultValue))
			end
		end
	end

	setupPriceInput(self.sellPriceInput, 0)
	setupPriceInput(self.buyPriceInput, 0)
end

function KioskShopConfigUI:onSellPriceChanged(target, entry)
	if self.selectedItem then
		self.selectedItem.sellPrice = tonumber(entry:getText()) or 0
		-- self.selectedItemsList:invalidate()
		KioskShopConfigUI.log("Sell price updated to: " .. self.selectedItem.sellPrice)
	end
end

-- Icon update callbacks (ISTickBox changeOptionMethod signature)
-- Called when checkbox state changes: (target, index, isChecked)
function KioskShopConfigUI:onBuySpecialChanged(index, isChecked)
	-- Guard against nil or invalid state
	if not self.buyIconPlaceholder then return end

	if isChecked then
		self.buyPriceSpecialCheckbox.options[index] = "Special"
	else
		self.buyPriceSpecialCheckbox.options[index] = "Special ?"
	end

	-- Update icon placeholder
	self:updateIconPlaceholder(self.buyIconPlaceholder, isChecked)

	-- Update selected item data
	if self.selectedItem then
		self.selectedItem.buyPriceSpecial = isChecked
		KioskShopConfigUI.log("Buy special status changed to: " .. tostring(isChecked))
	end
end

function KioskShopConfigUI:onSellSpecialChanged(index, isChecked)
	-- Guard against nil or invalid state
	if not self.sellIconPlaceholder then return end

	if isChecked then
		self.sellPriceSpecialCheckbox.options[index] = "Special"
	else
		self.sellPriceSpecialCheckbox.options[index] = "Special ?"
	end

	-- Update icon placeholder
	self:updateIconPlaceholder(self.sellIconPlaceholder, isChecked)

	-- Update selected item data
	if self.selectedItem then
		self.selectedItem.sellPriceSpecial = isChecked
		KioskShopConfigUI.log("Sell special status changed to: " .. tostring(isChecked))
	end
end

function KioskShopConfigUI:updateIconPlaceholder(placeholder, isSpecial)
	local iconTexture = isSpecial and KioskShopConfigUI.eventCoinTexture or KioskShopConfigUI.copperCoinTexture

	if iconTexture then
		placeholder.texture = iconTexture
	end
end

-- Right table filter functions
function KioskShopConfigUI:filterRightName(item, filterText)
	if filterText == "" then return true end
	local itemName = string.lower(item.name or "")
	return checkStringPattern(filterText) and string.match(itemName, filterText) ~= nil
end

function KioskShopConfigUI:filterRightBuy(item, buyFilter)
	if buyFilter == "<Any>" then return true end
	local hasBuy = item.buyPrice > 0
	return (buyFilter == "Yes" and hasBuy) or (buyFilter == "No" and not hasBuy)
end

function KioskShopConfigUI:filterRightSell(item, sellFilter)
	if sellFilter == "<Any>" then return true end
	local hasSell = item.sellPrice > 0
	return (sellFilter == "Yes" and hasSell) or (sellFilter == "No" and not hasSell)
end

-- Apply right table filters (read from SELECTED_ITEMS, populate SELECTED_ITEMS_TABLE)
function KioskShopConfigUI:applyRightFilters()
	-- Preserve current selection before clearing
	local previousSelection = self.selectedItemsList.selected

	-- Clear display table (but NOT source data in SELECTED_ITEMS)
	self.selectedItemsList:clear()

	-- Get filter values
	local nameFilter = string.lower(self.rightNameFilterBox:getInternalText() or "")
	local buyFilter = self.rightBuyFilterCombo:getOptionText(self.rightBuyFilterCombo.selected) or "<Any>"
	local sellFilter = self.rightSellFilterCombo:getOptionText(self.rightSellFilterCombo.selected) or "<Any>"

	-- Build SELECTED_SCRIPT_ITEMS_TABLE by filtering from SELECTED_SCRIPT_ITEMS (source of truth)
	for i = 1, #self.SELECTED_SCRIPT_ITEMS do
		local item = self.SELECTED_SCRIPT_ITEMS[i]
		if item then
			local pass = true
			if not self:filterRightName(item, nameFilter) then pass = false end
			if not self:filterRightBuy(item, buyFilter) then pass = false end
			if not self:filterRightSell(item, sellFilter) then pass = false end
			if pass then
				self.selectedItemsList:addItem(item.name, item)
			end
		end
	end

	-- Restore selection if still valid
	if previousSelection and previousSelection > 0 and previousSelection <= #self.selectedItemsList.items then
		self.selectedItemsList.selected = previousSelection
	else
		self.selectedItemsList.selected = 0
	end
end

-- Global item selection (single click)
function KioskShopConfigUI:onGlobalItemSelected()
	local item = self.globalItemsList.items[self.globalItemsList.selected]
	if not item then return end

	local selectedItem = nil
	-- Unwrap if necessary
	if item and item.item and not item.name then
		selectedItem = item.item
	end

	if selectedItem == nil then
		return
	end

	KioskShopConfigUI.log("Selected global item: " ..
		tostring(selectedItem.name) ..
		" (type: " ..
		tostring(selectedItem.type) .. ")" .. " (fullType: " .. tostring(selectedItem.fullType) .. ")")
end

-- Right table item selection (single click)
function KioskShopConfigUI:onSelectedItemRightTable(_listBoxItem)
	if not _listBoxItem then return end

	KioskShopConfigUI.log("Selected right item: " ..
		tostring(_listBoxItem.item.name) ..
		" (type: " ..
		tostring(_listBoxItem.item.type) .. ")" .. " (fullType: " .. tostring(_listBoxItem.item.fullType) .. ")")
end

-- Double click handler for Global Items (vanilla pattern)
function KioskShopConfigUI:onGlobalItemDoubleClick(item)
	if not item then return end
	self:onAddItemToSelectedScriptItems(item)
	-- Deselect after adding (item becomes grayed out)
	self.globalItemsList.selected = 0
end

-- Remove item from selected items (double-click handler)
function KioskShopConfigUI:onRemoveItemFromSelectedScriptItems(item)
	if not item or not item.fullType then return end

	-- Find and remove from SELECTED_SCRIPT_ITEMS by fullType
	for i = #self.SELECTED_SCRIPT_ITEMS, 1, -1 do
		if self.SELECTED_SCRIPT_ITEMS[i] and self.SELECTED_SCRIPT_ITEMS[i].fullType == item.fullType then
			table.remove(self.SELECTED_SCRIPT_ITEMS, i)
			KioskShopConfigUI.log("Removed item from selected: " .. tostring(item.fullType))
			break
		end
	end

	-- Rebuild right table and clear editor
	self:applyRightFilters()
	self.selectedItemsList.selected = 0
	self:onClearItemEditor()
end

-- Add selected global item to selected items
function KioskShopConfigUI:onAddItemToSelectedScriptItems(item)
	-- Use passed item if provided (from double-click), otherwise get from selection
	if not item then
		item = self.globalItemsList.items[self.globalItemsList.selected]
	end
	if not item then return end

	-- Check if already in SELECTED_SCRIPT_ITEMS (by unique item fullType)
	for i = 1, #self.SELECTED_SCRIPT_ITEMS do
		local selectedItem = self.SELECTED_SCRIPT_ITEMS[i]
		if selectedItem and selectedItem.fullType == item.fullType then
			KioskShopConfigUI.log("onAddItemToSelectedScriptItems - Duplicate detected: " .. tostring(item.fullType))
			return -- Already added
		end
	end

	-- Add to SELECTED_SCRIPT_ITEMS (source of truth) with default config
	local newItem = {
		scriptItem = item.scriptItem,
		id = item.id,
		type = item.type,
		name = item.name,
		displayName = item.displayName,
		fullType = item.fullType,
		buyPrice = 0,
		sellPrice = 0,
		buyPriceSpecial = false,
		sellPriceSpecial = false
	}
	table.insert(self.SELECTED_SCRIPT_ITEMS, newItem)

	-- Rebuild display table from SELECTED_SCRIPT_ITEMS with current filters
	self:applyRightFilters()
end

function KioskShopConfigUI:onClearItemEditor()
	self.itemFullTypeLabel:setName('["_____"]')
	self.buyPriceInput:setText("0")
	self.sellPriceInput:setText("0")
	self.buyPriceSpecialCheckbox:setSelected(1, false)
	self.sellPriceSpecialCheckbox:setSelected(1, false)

	KioskShopConfigUI.log("Editor panel cleared")
end

-- Populate editor panel when right-side item is selected
function KioskShopConfigUI:onSelectedItemEditorUpdate(_listBoxItem)
	if not _listBoxItem then return end

	-- Store reference to current selected item
	self.selectedItem = _listBoxItem.item

	-- Item should have fullType directly (from SELECTED_SCRIPT_ITEMS)
	if _listBoxItem.item and _listBoxItem.item.fullType then
		self.itemFullTypeLabel:setName('["' .. tostring(_listBoxItem.item.fullType) .. '"]')
	else
		self.itemFullTypeLabel:setName('["' .. tostring(_listBoxItem.item.name) or "Unknown" .. '"]')
	end

	self.buyPriceInput:setText(tostring(_listBoxItem.item.buyPrice or 0))
	self.sellPriceInput:setText(tostring(_listBoxItem.item.sellPrice or 0))

	local buyPriceSpecialCheckboxChecked = _listBoxItem.item.buyPriceSpecial and true or false
	local sellPriceSpecialCheckboxChecked = _listBoxItem.item.sellPriceSpecial and true or false

	-- Set checkbox states
	self.buyPriceSpecialCheckbox:setSelected(1, buyPriceSpecialCheckboxChecked)
	self.sellPriceSpecialCheckbox:setSelected(1, sellPriceSpecialCheckboxChecked)

	-- Manually update icon placeholders (setSelected doesn't trigger changeOptionMethod)
	self:updateIconPlaceholder(self.buyIconPlaceholder, _listBoxItem.item.buyPriceSpecial)
	self:updateIconPlaceholder(self.sellIconPlaceholder, _listBoxItem.item.sellPriceSpecial)

	if buyPriceSpecialCheckboxChecked then
		self.buyPriceSpecialCheckbox.options[1] = "Special"
	else
		self.buyPriceSpecialCheckbox.options[1] = "Special ?"
	end

	if sellPriceSpecialCheckboxChecked then
		self.sellPriceSpecialCheckbox.options[1] = "Special"
	else
		self.sellPriceSpecialCheckbox.options[1] = "Special ?"
	end

	KioskShopConfigUI.log("Editor panel updated: " .. tostring(_listBoxItem.item.fullType or _listBoxItem.item.name))
end

-- Save editor values back to selected item
function KioskShopConfigUI:onSelectedItemEditorSave()
	-- Guard: check that editor widgets exist
	if not self.buyPriceInput or not self.sellPriceInput or
		not self.buyPriceSpecialCheckbox or not self.sellPriceSpecialCheckbox then
		return
	end

	if not self.selectedItem then return end

	self.selectedItem.buyPrice = tonumber(self.buyPriceInput:getText()) or 0
	self.selectedItem.sellPrice = tonumber(self.sellPriceInput:getText()) or 0
	self.selectedItem.buyPriceSpecial = self.buyPriceSpecialCheckbox:isSelected(1)
	self.selectedItem.sellPriceSpecial = self.sellPriceSpecialCheckbox:isSelected(1)

	self.selectedItemsList:invalidate()
	KioskShopConfigUI.log("Editor panel saved: " .. tostring(self.selectedItem.fullType))
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
	self:applyLeftTableFilters()
end

-- Select All button: Add all items from current page to SELECTED_SCRIPT_ITEMS
function KioskShopConfigUI:onSelectAllPage()
	local paginated = KioskItemsTable:getPaginatedItems(self.filteredScriptItems, self.currentPage, self.itemsPerPage)

	for i = 1, #paginated do
		local item = paginated[i]
		if item then
			self:onAddItemToSelectedScriptItems(item)
		end
	end

	KioskShopConfigUI.log("Selected All button: Added " .. #paginated .. " items from current page")
end

-- Deselect All button: Remove all filtered items from current page from SELECTED_SCRIPT_ITEMS
function KioskShopConfigUI:onDeselectAllPage()
	-- Get filtered selected items based on right-side filters
	local nameFilter = string.lower(self.rightNameFilterBox:getInternalText() or "")
	local buyFilter = self.rightBuyFilterCombo:getOptionText(self.rightBuyFilterCombo.selected)
	local sellFilter = self.rightSellFilterCombo:getOptionText(self.rightSellFilterCombo.selected)

	local filteredSelected = {}
	for i = 1, #self.SELECTED_SCRIPT_ITEMS do
		local item = self.SELECTED_SCRIPT_ITEMS[i]
		if self:filterRightName(item, nameFilter) and
			self:filterRightBuy(item, buyFilter) and
			self:filterRightSell(item, sellFilter) then
			table.insert(filteredSelected, item)
		end
	end

	-- Get paginated subset of filtered items
	local paginated = KioskItemsTable:getPaginatedItems(filteredSelected, self.rightCurrentPage, self.itemsPerPage)

	-- Remove from SELECTED_SCRIPT_ITEMS by fullType
	local removedCount = 0
	for i = 1, #paginated do
		local item = paginated[i]
		if item then
			for j = #self.SELECTED_SCRIPT_ITEMS, 1, -1 do
				local selectedItem = self.SELECTED_SCRIPT_ITEMS[j]
				if selectedItem and selectedItem.fullType == item.fullType then
					table.remove(self.SELECTED_SCRIPT_ITEMS, j)
					removedCount = removedCount + 1
					break
				end
			end
		end
	end

	self:applyRightFilters()
	KioskShopConfigUI.log("Deselect All button: Removed " .. removedCount .. " filtered items from current page")
end

-- Apply all active filters to items in left table (vanilla core loop pattern)
function KioskShopConfigUI:applyLeftTableFilters()
	self.globalItemsList:clear()

	-- Reset filtered list
	self.filteredScriptItems = {}

	-- Loop every item in full list
	for i = 1, #self.scriptItems do
		local item = self.scriptItems[i]
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
			table.insert(self.filteredScriptItems, item)
		end
	end

	-- Log filter status with current filter values
	local nameFilter = self.leftNameFilterBox:getInternalText() or ""
	local displayNameFilter = self.displayNameFilterBox:getInternalText() or ""
	local typeFilter = self.typeFilterCombo:getOptionText(self.typeFilterCombo.selected)

	KioskShopConfigUI.log("[FILTER] Applied: name='" .. nameFilter .. "', displayName='" .. displayNameFilter ..
		"', type='" .. typeFilter .. "'")
	KioskShopConfigUI.log("[FILTER RESULT] scriptItems: " .. #self.scriptItems .. " items, " ..
		"filtered: " ..
		#self.filteredScriptItems .. " items (removed: " .. (#self.scriptItems - #self.filteredScriptItems) .. ")")

	-- Debug: check filter results
	if #self.filteredScriptItems == 0 and #self.scriptItems > 0 then
		KioskShopConfigUI.log("  [WARNING] Filtered list empty but scriptItems has items!")
	end

	-- Debug: check first few filtered items
	for i = 1, math.min(3, #self.filteredScriptItems) do
		local item = self.filteredScriptItems[i]
		KioskShopConfigUI.log("  [SAMPLE] filteredScriptItems[" ..
			i .. "]: name='" .. tostring(item.name) .. "', type='" .. tostring(item.type) .. "'")
	end

	-- Paginate filtered results
	local maxPages = KioskItemsTable:getMaxPages(#self.filteredScriptItems, self.itemsPerPage)
	local paginated = KioskItemsTable:getPaginatedItems(self.filteredScriptItems, self.currentPage, self.itemsPerPage)

	KioskShopConfigUI.log("[PAGINATION] page " ..
		self.currentPage ..
		" / " .. maxPages .. " - displaying " .. #paginated .. " items (page size: " .. self.itemsPerPage .. ")")

	-- Add paginated items to listbox
	for i = 1, #paginated do
		local item = paginated[i]
		if not item or not item.name then
			KioskShopConfigUI.log("applyLeftFilters() - paginated[" .. i .. "] missing name: " .. tostring(item))
			if item then
				KioskShopConfigUI.log("  item keys: " .. table.concat(KioskItemsTable:getTableKeys(item) or {}, ", "))
			end
		end
		self.globalItemsList:addItem(item.name, item)
	end

	-- Clear selection after filtering (left side only)
	self.globalItemsList.selected = 0

	-- Update pagination labels
	self.pageLabel:setName("Page " .. self.currentPage .. " / " .. math.max(1, maxPages))
	self.totalLabel:setName("Total: " .. #self.filteredScriptItems)
end

-- Pagination (bypass debounce, repaginate existing filtered items)
function KioskShopConfigUI:onPrevPage()
	if self.currentPage > 1 then
		self.currentPage = self.currentPage - 1
		self:rebuildLeftPagination()
	end
end

function KioskShopConfigUI:onNextPage()
	local maxPages = KioskItemsTable:getMaxPages(#self.filteredScriptItems, self.itemsPerPage)
	if self.currentPage < maxPages then
		self.currentPage = self.currentPage + 1
		self:rebuildLeftPagination()
	end
end

function KioskShopConfigUI:onRightPrevPage()
	if self.rightCurrentPage > 1 then
		self.rightCurrentPage = self.rightCurrentPage - 1
		self:rebuildRightPagination()
	end
end

function KioskShopConfigUI:onRightNextPage()
	local maxPages = KioskItemsTable:getMaxPages(#self.SELECTED_SCRIPT_ITEMS, self.itemsPerPage)
	if self.rightCurrentPage < maxPages then
		self.rightCurrentPage = self.rightCurrentPage + 1
		self:rebuildRightPagination()
	end
end

function KioskShopConfigUI:rebuildRightPagination()
	-- Preserve selection during page change
	local previousSelection = self.selectedItemsList.selected

	self.selectedItemsList:clear()

	local maxPages = KioskItemsTable:getMaxPages(#self.SELECTED_SCRIPT_ITEMS, self.itemsPerPage)
	local paginated = KioskItemsTable:getPaginatedItems(self.SELECTED_SCRIPT_ITEMS, self.rightCurrentPage,
		self.itemsPerPage)

	for i = 1, #paginated do
		local item = paginated[i]
		self.selectedItemsList:addItem(item.name, item)
	end

	-- Restore selection (or set to 0 if previous selection no longer valid)
	if previousSelection and previousSelection > 0 and previousSelection <= #paginated then
		self.selectedItemsList.selected = previousSelection
	else
		self.selectedItemsList.selected = 0
	end

	self.rightPageLabel:setName("Page " .. self.rightCurrentPage .. " / " .. math.max(1, maxPages))
	self.rightTotalLabel:setName("Total: " .. #self.SELECTED_SCRIPT_ITEMS)
end

function KioskShopConfigUI:onClearLeftFilters()
	self.leftNameFilterBox:setText("")
	self.displayNameFilterBox:setText("")
	self.typeFilterCombo.selected = 1
	self:applyLeftTableFilters()
end

function KioskShopConfigUI:onGotoPage()
	local pageText = self.gotoPageBox:getText() or ""
	local pageNum = tonumber(pageText)

	if not pageNum then return end

	local maxPages = KioskItemsTable:getMaxPages(#self.filteredScriptItems, self.itemsPerPage)
	pageNum = math.max(1, math.min(pageNum, maxPages))

	self.currentPage = pageNum
	self:rebuildLeftPagination()
	self.gotoPageBox:setText("")
end

-- Rebuild pagination without re-filtering (fast pagination)
function KioskShopConfigUI:rebuildLeftPagination()
	-- Preserve selection during page change
	local previousSelection = self.globalItemsList.selected

	self.globalItemsList:clear()

	local maxPages = KioskItemsTable:getMaxPages(#self.filteredScriptItems, self.itemsPerPage)
	local paginated = KioskItemsTable:getPaginatedItems(self.filteredScriptItems, self.currentPage, self.itemsPerPage)

	for i = 1, #paginated do
		local item = paginated[i]
		self.globalItemsList:addItem(item.name, item)
	end

	-- Restore selection (or set to 0 if previous selection no longer valid)
	if previousSelection and previousSelection > 0 and previousSelection <= #paginated then
		self.globalItemsList.selected = previousSelection
	else
		self.globalItemsList.selected = 0
	end

	self.pageLabel:setName("Page " .. self.currentPage .. " / " .. math.max(1, maxPages))
end

-- Initialize list from game item registry (vanilla ISItemsListTable pattern)
function KioskShopConfigUI:initList()
	self.scriptItems = {}
	self.filteredScriptItems = {}

	local scriptItems = getAllItems()
	if not scriptItems then
		KioskShopConfigUI.log("initList() - getAllItems() returned nil")
		return
	end

	KioskShopConfigUI.log("initList() - getAllItems() returned " .. scriptItems:size() .. " items")

	for i = 0, scriptItems:size() - 1 do
		local scriptItem = scriptItems:get(i)
		if scriptItem then
			-- Try to get type
			local itemType = scriptItem:getItemType():toString()
			if not itemType or itemType == "" then
				itemType = "Unknown"
			end

			local name = scriptItem:getName() or "Unknown"
			local displayName = scriptItem:getDisplayName()
			if not displayName or displayName == "" then
				displayName = name
			end
			local moduleName = scriptItem:getModuleName() or "Base"
			local fullType = moduleName .. "." .. name

			table.insert(self.scriptItems, {
				scriptItem = scriptItem, -- Store full scriptItem object (vanilla pattern)
				id = i,
				type = itemType,
				fullType = fullType,
				name = name,
				displayName = displayName,
				module = moduleName,
				buyPrice = 0,
				sellPrice = 0,
				buyPriceSpecial = false,
				sellPriceSpecial = false
			})
		end
	end

	KioskShopConfigUI.log("initList() - self.scriptItems has " .. #self.scriptItems .. " items")

	-- Populate Type combo box with unique types
	local uniqueTypes = {}
	local typeMap = {}
	for i = 1, #self.scriptItems do
		local itemType = tostring(self.scriptItems[i].type or "Unknown")
		if not typeMap[itemType] then
			typeMap[itemType] = true
			table.insert(uniqueTypes, itemType)
		end
	end
	table.sort(uniqueTypes, function(a, b)
		return tostring(a) < tostring(b)
	end)

	self.typeFilterCombo:clear()
	self.typeFilterCombo:addOption("<Any>") -- Always first option for "no filter"
	for _, typeValue in ipairs(uniqueTypes) do
		self.typeFilterCombo:addOption(typeValue)
	end
	self.typeFilterCombo.selected = 1 -- Default to "<Any>"

	self.currentPage = 1
	self.leftNameFilterBox:setText("")
	self.displayNameFilterBox:setText("")
	self:applyLeftTableFilters()

	KioskShopConfigUI.log("initList() - after applyLeftTableFilters, globalItemsList has " ..
		#self.globalItemsList.items .. " items")

	-- Load SELECTED_SCRIPT_ITEMS from sandbox
	self:loadSelectedScriptItems()
end

-- Load SELECTED_SCRIPT_ITEMS from sandbox and rebuild right table
function KioskShopConfigUI:loadSelectedScriptItems()
	-- Load persisted data if it exists
	if self.character then
		-- For now, start with empty SELECTED_SCRIPT_ITEMS
		-- When proper serialization is implemented, load from:
		-- local loaded = KioskItemConfigPanel:loadFromSandbox(self.character)
		self.SELECTED_SCRIPT_ITEMS = {}
	end

	-- Rebuild right table display
	self:applyRightFilters()
end

-- Save SELECTED_SCRIPT_ITEMS to sandbox
function KioskShopConfigUI:saveSelectedScriptItems()
	if self.character then
		-- For now, just log that save was called
		-- When proper serialization is implemented, save to:
		-- KioskItemConfigPanel:saveToSandbox(self.character, self.SELECTED_SCRIPT_ITEMS)
		local itemCount = self.SELECTED_SCRIPT_ITEMS and #self.SELECTED_SCRIPT_ITEMS or 0
		KioskShopConfigUI.log("saveSelectedScriptItems() - Would save " .. itemCount .. " items")
	end
end

-- Close button callback
function KioskShopConfigUI:onClose()
	self:close()
end

-- Cleanup
function KioskShopConfigUI:close()
	-- Save SELECTED_SCRIPT_ITEMS before cleanup
	self:saveSelectedScriptItems()

	ISPanel.close(self)
	self.character = nil
	self.globalItemsList = nil
	self.selectedItemsList = nil
	self.leftNameFilterBox = nil
	self.displayNameFilterBox = nil
	self.typeFilterCombo = nil
	self.rightNameFilterBox = nil
	self.rightBuyFilterCombo = nil
	self.rightSellFilterCombo = nil
	self.filterWidgets = nil
	self.rightFilterWidgets = nil
	self.leftPanel = nil
	self.leftHeaderFilterPanel = nil
	self.leftFiltersPanel = nil
	self.leftPaginationPanel = nil
	self.leftWIPPanel = nil
	self.rightPanel = nil
	self.rightHeaderFilterPanel = nil
	self.rightFiltersPanel = nil
	self.rightPaginationPanel = nil
	self.rightWIPPanel = nil
	self.scriptItems = nil
	self.filteredScriptItems = nil
	self.scriptItems = nil
	self.SELECTED_SCRIPT_ITEMS = nil
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
