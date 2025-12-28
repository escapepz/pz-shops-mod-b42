-- KioskItemConfigPanel: Item configuration UI
-- Handles Buy/Sell toggles and price inputs for selected items

KioskItemConfigPanel = {}
KioskItemConfigPanel.SMALL_FONT_HGT = getTextManager():getFontFromEnum(UIFont.Small):getLineHeight()

-- Create and setup config panel UI
function KioskItemConfigPanel:create(parent, x, y, width, height)
	local panel = ISPanel:new(x, y, width, height)
	panel:initialise()
	panel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.1 }
	panel:setVisible(false)
	parent:addChild(panel)

	-- Buy checkbox
	panel.buyCheckbox = ISTickBox:new(5, 10, 120, 20, "Allow Buy", parent, nil)
	panel.buyCheckbox:initialise()
	panel.buyCheckbox.onCheck = function()
		parent:onConfigChanged()
	end
	panel:addChild(panel.buyCheckbox)

	-- Sell checkbox
	panel.sellCheckbox = ISTickBox:new(130, 10, 120, 20, "Allow Sell", parent, nil)
	panel.sellCheckbox:initialise()
	panel.sellCheckbox.onCheck = function()
		parent:onConfigChanged()
	end
	panel:addChild(panel.sellCheckbox)

	-- Buy Price label and input
	local buyPriceLabel = ISLabel:new(5, 40, KioskItemConfigPanel.SMALL_FONT_HGT, "Buy Price:", 0.8, 0.8, 0.8, 1,
		UIFont.Small, true)
	panel:addChild(buyPriceLabel)

	panel.buyPriceBox = ISTextEntryBox:new("", 85, 40, 60, 22)
	panel.buyPriceBox:initialise()
	panel.buyPriceBox:instantiate()
	panel.buyPriceBox.onTextChange = function()
		parent:onConfigChanged()
	end
	panel:addChild(panel.buyPriceBox)

	-- Sell Price label and input
	local sellPriceLabel = ISLabel:new(160, 40, KioskItemConfigPanel.SMALL_FONT_HGT, "Sell Price:", 0.8, 0.8, 0.8, 1,
		UIFont.Small, true)
	panel:addChild(sellPriceLabel)

	panel.sellPriceBox = ISTextEntryBox:new("", 240, 40, 60, 22)
	panel.sellPriceBox:initialise()
	panel.sellPriceBox:instantiate()
	panel.sellPriceBox.onTextChange = function()
		parent:onConfigChanged()
	end
	panel:addChild(panel.sellPriceBox)

	return panel
end

-- Load item data into config panel
function KioskItemConfigPanel:loadItem(panel, item)
	if not panel or not item then
		panel:setVisible(false)
		return
	end

	panel:setVisible(true)
	panel.buyCheckbox:setChecked(item.buy or false)
	panel.sellCheckbox:setChecked(item.sell or false)
	panel.buyPriceBox:setText(tostring(item.buyPrice or 0))
	panel.sellPriceBox:setText(tostring(item.sellPrice or 0))
end

-- Get current config from panel
function KioskItemConfigPanel:getConfig(panel)
	if not panel then return nil end

	return {
		buy = panel.buyCheckbox:isChecked(),
		sell = panel.sellCheckbox:isChecked(),
		buyPrice = tonumber(panel.buyPriceBox:getText()) or 0,
		sellPrice = tonumber(panel.sellPriceBox:getText()) or 0
	}
end

-- Apply config to item
function KioskItemConfigPanel:applyToItem(panel, item)
	if not panel or not item then return end

	local config = KioskItemConfigPanel:getConfig(panel)
	item.buy = config.buy
	item.sell = config.sell
	item.buyPrice = config.buyPrice
	item.sellPrice = config.sellPrice
end
