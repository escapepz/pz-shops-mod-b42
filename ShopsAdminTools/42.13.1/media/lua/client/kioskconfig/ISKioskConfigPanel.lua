-- ISKioskConfigPanel: Minimalist Kiosk Shop Configurator
-- Based on ISCollapsableWindow pattern from ShopUI
-- Reference: docs/ShopsAdminTools/UI.md

ISKioskConfigPanel = ISCollapsableWindow:derive("ISKioskConfigPanel")

ISKioskConfigPanel.instance = nil
ISKioskConfigPanel.SMALL_FONT_HGT = getTextManager():getFontFromEnum(UIFont.Small):getLineHeight()
ISKioskConfigPanel.MEDIUM_FONT_HGT = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight()

local width = 600
local height = 500

-- Show the Kiosk Config panel
function ISKioskConfigPanel:show(player)
	if ISKioskConfigPanel.instance == nil then
		ISKioskConfigPanel.instance = ISKioskConfigPanel:new(0, 0, width, height, player)
		ISKioskConfigPanel.instance:initialise()
		ISKioskConfigPanel.instance:instantiate()
	end
	ISKioskConfigPanel.instance.pinButton:setVisible(false)
	ISKioskConfigPanel.instance.collapseButton:setVisible(false)
	ISKioskConfigPanel.instance:addToUIManager()
	ISKioskConfigPanel.instance:setVisible(true)
	return ISKioskConfigPanel.instance
end

-- Update lifecycle: only refresh when state changes
function ISKioskConfigPanel:update()
	if self.needsRefresh then
		self:refreshList()
		self.needsRefresh = false
	end
end

-- Render the UI
function ISKioskConfigPanel:render()
	ISCollapsableWindow.render(self)
end

-- Create UI children (hierarchy per UI.md)
function ISKioskConfigPanel:createChildren()
	ISCollapsableWindow.createChildren(self)

	local th = self:titleBarHeight()
	local padding = 10
	local topBarHeight = 35
	local footerHeight = 40
	local contentWidth = self.width - (padding * 2)
	local contentHeight = self.height - th - topBarHeight - footerHeight - (padding * 3)

	-- TopBar: SearchBox + ModeCombo
	self.topBar = ISPanel:new(padding, th + padding, contentWidth, topBarHeight)
	self.topBar:initialise()
	self.topBar.backgroundColor = { r = 0, g = 0, b = 0, a = 0.3 }
	self:addChild(self.topBar)

	-- SearchBox
	self.searchBox = ISTextEntryBox:new("", 10, 5, 250, 25)
	self.searchBox:initialise()
	self.searchBox:instantiate()
	self.searchBox:setText("")
	self.searchBox.onTextChange = function()
		self:onSearchChange()
	end
	self.topBar:addChild(self.searchBox)

	-- ModeCombo
	self.modeCombo = ISComboBox:new(270, 5, 120, 25, self, ISKioskConfigPanel.onModeChange)
	self.modeCombo:initialise()
	self.modeCombo:addOption("All Items")
	self.modeCombo:addOption("Active")
	self.modeCombo:addOption("Inactive")
	self.modeCombo:setSelected(1)
	self.topBar:addChild(self.modeCombo)

	-- ItemList: ISScrollingListBox
	self.itemList = ISScrollingListBox:new(padding, th + topBarHeight + (padding * 2), contentWidth, contentHeight)
	self.itemList:initialise()
	self.itemList:instantiate()
	self.itemList.itemHeight = 22
	self.itemList.font = UIFont.Small
	self.itemList.doDrawItem = self.drawItem
	self.itemList.onMouseDown = function()
		self:onItemSelected()
	end
	self.itemList.joypadParent = self
	self.itemList.drawBorder = false
	self:addChild(self.itemList)

	-- ConfigPanel: Detail view for selected item
	self.configPanel = ISPanel:new(padding, th + padding, contentWidth, 0)
	self.configPanel:initialise()
	self.configPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.2 }
	self.configPanel:setVisible(false)
	self:addChild(self.configPanel)

	-- Footer: Pagination controls
	self.footer = ISPanel:new(padding, self.height - footerHeight, contentWidth, footerHeight)
	self.footer:initialise()
	self.footer.backgroundColor = { r = 0, g = 0, b = 0, a = 0.3 }
	self:addChild(self.footer)

	self.prevButton = ISButton:new(10, 5, 60, 25, "< Prev", self, ISKioskConfigPanel.onPrevPage)
	self.prevButton:initialise()
	self.footer:addChild(self.prevButton)

	self.pageLabel = ISLabel:new(80, 10, ISKioskConfigPanel.SMALL_FONT_HGT, "Page 1/1", 1, 1, 1, 1, UIFont.Small, true)
	self.footer:addChild(self.pageLabel)

	self.nextButton = ISButton:new(contentWidth - 70, 5, 60, 25, "Next >", self, ISKioskConfigPanel.onNextPage)
	self.nextButton:initialise()
	self.footer:addChild(self.nextButton)

	-- Initialize data
	self.currentPage = 1
	self.itemsPerPage = 15
	self.searchFilter = ""
	self.modeFilter = "All Items"
	self.needsRefresh = true
end

-- Item rendering (minimalist: text only, no colors or animations)
function ISKioskConfigPanel:drawItem(y, item, alt)
	if y + self:getYScroll() >= self.height then
		return y + self.itemHeight
	end
	if y + self.itemHeight + self:getYScroll() <= 0 then
		return y + self.itemHeight
	end

	-- Draw border
	self:drawRectBorder(0, y, self:getWidth(), self.itemHeight - 1, 0.9, 0.5, 0.5, 0.5)

	-- Highlight selection
	if self.selected == item.index then
		self:drawRect(0, y, self:getWidth(), self.itemHeight - 1, 0.3, 0.3, 0.3, 0.3)
	end

	-- Draw item text
	self:drawText(item.name or "Unknown", 10, y + 5, 1, 1, 1, 0.9, UIFont.Small)

	return y + self.itemHeight
end

-- Selection → Detail pattern
function ISKioskConfigPanel:onItemSelected()
	local item = self.itemList.items[self.itemList.selected]
	if not item then return end
	self.configPanel:setItem(item)
end

-- Search filter callback
function ISKioskConfigPanel:onSearchChange()
	self.searchFilter = self.searchBox:getText()
	self.needsRefresh = true
end

-- Mode filter
function ISKioskConfigPanel:onModeChange()
	self.modeFilter = self.modeCombo:getOptionText(self.modeCombo:getSelected())
	self.needsRefresh = true
end

-- Pagination
function ISKioskConfigPanel:onPrevPage()
	if self.currentPage > 1 then
		self.currentPage = self.currentPage - 1
		self.needsRefresh = true
	end
end

function ISKioskConfigPanel:onNextPage()
	local maxPages = math.ceil(#self.itemList.items / self.itemsPerPage)
	if self.currentPage < maxPages then
		self.currentPage = self.currentPage + 1
		self.needsRefresh = true
	end
end

-- Refresh list from data source
function ISKioskConfigPanel:refreshList()
	self.itemList:clear()

	-- Placeholder: populate from Shops mod data
	-- TODO: Integrate with actual shop item list
	for i = 1, 30 do
		self.itemList:addItem("Item " .. i, { name = "Item " .. i, id = i })
	end
end

-- Cleanup (non-optional per UI.md)
function ISKioskConfigPanel:close()
	ISCollapsableWindow.close(self)
	self.character = nil
	self.itemList = nil
	self.configPanel = nil
	self.searchBox = nil
	self.modeCombo = nil
	if ISKioskConfigPanel.instance then
		ISKioskConfigPanel.instance:removeFromUIManager()
		ISKioskConfigPanel.instance = nil
	end
	self:removeFromUIManager()
end

-- Constructor
function ISKioskConfigPanel:new(x, y, width, height, player)
	local o = {}
	if x == 0 and y == 0 then
		x = (getCore():getScreenWidth() / 2) - (width / 2)
		y = (getCore():getScreenHeight() / 2) - (height / 2)
	end
	o = ISCollapsableWindow:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self
	o.title = "Kiosk Shop Configurator"
	o.character = player
	o.player = player
	o.resizable = false
	return o
end
