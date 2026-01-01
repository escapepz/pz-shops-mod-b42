-- BundleViewerUI - Show virtual bundle contents before purchase
local UIText = SHOPSB42.UIText

SHOPSB42.BundleViewerUI = ISCollapsableWindow:derive("nshopsb42_BundleViewerUI")
local BundleViewerUI = SHOPSB42.BundleViewerUI

BundleViewerUI.instance = nil
BundleViewerUI.SMALL_FONT_HGT = getTextManager():getFontFromEnum(UIFont.Small):getLineHeight()
BundleViewerUI.MEDIUM_FONT_HGT = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight()

local width = 300
local height = 300

function BundleViewerUI:initialise()
	ISCollapsableWindow.initialise(self)
end

function BundleViewerUI:instantiate()
	ISCollapsableWindow.instantiate(self)
end

function BundleViewerUI:show(bundleItem)
	if BundleViewerUI.instance then
		BundleViewerUI.instance:close()
	end
	
	-- Create new instance
	local x = (getCore():getScreenWidth() / 2) - (width / 2)
	local y = (getCore():getScreenHeight() / 2) - (height / 2)
	
	local o = BundleViewerUI:new(x, y, width, height, bundleItem)
	o:initialise()
	o:instantiate()
	o:addToUIManager()
	o:setVisible(true)
	o:bringToTop()
	
	BundleViewerUI.instance = o
end

function BundleViewerUI:createChildren()
	ISCollapsableWindow.createChildren(self)
	
	local y = 30
	local x = 20
	
	if self.bundleItem and self.bundleItem.items then
		for _, itemEntry in ipairs(self.bundleItem.items) do
			local itemName = getItemNameFromFullType(itemEntry.item)
			local quantity = itemEntry.quantity or 1
			
			local quantityStr = ""
			if quantity > 1 then
				quantityStr = " (" .. quantity .. ")"
			end
			
			self:drawText(itemName .. quantityStr, x, y, 1, 1, 1, 1, UIFont.Small)
			y = y + 25
		end
	end
end

function BundleViewerUI:render()
	ISCollapsableWindow.render(self)
	
	local y = 30
	local x = 20
	
	if self.bundleItem and self.bundleItem.items then
		for _, itemEntry in ipairs(self.bundleItem.items) do
			local itemName = getItemNameFromFullType(itemEntry.item)
			local quantity = itemEntry.quantity or 1
			
			local quantityStr = ""
			if quantity > 1 then
				quantityStr = " (" .. quantity .. ")"
			end
			
			self:drawText(itemName .. quantityStr, x, y, 1, 1, 1, 1, UIFont.Small)
			y = y + 25
		end
	end
end

function BundleViewerUI:onRightMouseDown(x, y)
	self:close()
	return true
end

function BundleViewerUI:close()
	ISCollapsableWindow.close(self)
	BundleViewerUI.instance = nil
	self:removeFromUIManager()
end

function BundleViewerUI:new(x, y, _width, _height, bundleItem)
	local o = ISCollapsableWindow:new(x, y, _width, _height)
	setmetatable(o, self)
	self.__index = self
	o.bundleItem = bundleItem
	o.title = bundleItem.name or "Bundle Contents"
	o.resizable = false
	o.pinButton = nil
	return o
end
