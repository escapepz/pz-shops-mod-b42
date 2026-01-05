SHOPSB42.ShopTabUI = ISPanelJoypad:derive("ShopTabUI")
local ShopTabUI = SHOPSB42.ShopTabUI
local Shop = SHOPSB42.Shop
local UIText = SHOPSB42.UIText
local PreviewUI = SHOPSB42.PreviewUI
local ContainerViewerUI = SHOPSB42.ContainerViewerUI
local BundleViewerUI = SHOPSB42.BundleViewerUI
local Tab = SHOPSB42.Tab
local Currency = SHOPSB42.Currency
ShopTabUI.SMALL_FONT_HGT = getTextManager():getFontFromEnum(UIFont.Small):getLineHeight()
ShopTabUI.MEDIUM_FONT_HGT = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight()
ShopTabUI.addButtonX = 380
ShopTabUI.previewButtonX = ShopTabUI.addButtonX + 25
ShopTabUI.favoriteButtonX = ShopTabUI.addButtonX - 20

local addBtn = Shop.textures.AddButton
local previewBtn = Shop.textures.PreviewButton
local browseBtn = Shop.textures.Browse

-- Color definitions for price display
local goodColor = { r = 0, g = 1, b = 0, a = 1 } -- Bright green for good prices
local neutralColor = { r = 0.85, g = 0.85, b = 0.85, a = 1 } -- Light gray for neutral prices
local grayColor = { r = 0.3, g = 0.3, b = 0.3, a = 1 } -- Dark gray for base price reference

function ShopTabUI:initialise()
	ISPanelJoypad.initialise(self)
	self:create()
end

function ShopTabUI:setShopUI(instance)
	self.ShopUI = instance
end

function ShopTabUI:onFilterChange()
	self.parent:filter()
end

function ShopTabUI:setCategoryType(tabType)
	self.tabType = tabType
end

function ShopTabUI:doDrawShopItem(y, item, alt)
	-- Ensure item prices are valid numbers to prevent nil/NaN errors
	-- This guards against price updates arriving before UI rebuild, and ensures prices are never tables
	if item and item.item then
		-- Ensure price is a number, not a table (defensive against server data format changes)
		if type(item.item.price) == "table" then
			item.item.price = item.item.price.price or 0
		end
		if type(item.item.basePrice) == "table" then
			item.item.basePrice = item.item.basePrice.price or item.item.basePrice.basePrice or 0
		end
		-- Set missing basePrice
		if item.item.price and not item.item.basePrice then
			item.item.basePrice = item.item.price
		end
	end

	local baseItemDY = 0
	if item.item.name then
		baseItemDY = self.SMALL_FONT_HGT
		item.height = self.itemheight + baseItemDY
	end

	if y + self:getYScroll() >= self.height then
		return y + item.height
	end
	if y + item.height + self:getYScroll() <= 0 then
		return y + item.height
	end

	local a = 0.9
	self:drawRectBorder(
		0,
		y,
		self:getWidth(),
		item.height - 1,
		a,
		self.borderColor.r,
		self.borderColor.g,
		self.borderColor.b
	)

	if self.selected == item.index then
		self:drawRect(0, y, self:getWidth(), item.height - 1, 0.3, 0.7, 0.35, 0.15)
	end

	local favTexture = nil
	local favAlpha = 0.3

	if not (self.parent.tabType == Tab.Sell) then
		if item.index == self.selectedRow and not self:isMouseOverScrollBar() and self:isMouseOver() then
			local mouseX = self:getMouseX()
			favTexture = self.parent.favNotCheckedTex
			if mouseX > 240 and mouseX < 260 then
				favTexture = self.parent.favCheckedTex
				favAlpha = 1
			end
		end
		if item.item.favorite then
			favTexture = self.parent.favoriteStar
			favAlpha = 1
		end
	end

	local quantity = ""
	if item.item.quantity then
		quantity = " (" .. item.item.quantity .. ")"
	end
	self:drawText(item.item.name .. quantity, 40, y + 10, 1, 1, 1, a, UIFont.Small)

	-- Favorite icon at 240
	if favTexture then
		self:drawTexture(favTexture, 240, y + 10, favAlpha, 1, 1, 1)
	end

	-- Draw prices if either finalPrice or basePrice exist (not both nil/zero)
	-- This allows display even when prices are being calculated or are very small
	if (item.item.price and item.item.price > 0) or (item.item.basePrice and item.item.basePrice > 0) then
		-- Ensure both prices are valid numbers
		local finalPrice = item.item.price or 0
		local basePrice = item.item.basePrice or item.item.price or 0

		-- Additional safety: ensure prices are numbers, not NaN or infinity
		if
			type(finalPrice) ~= "number"
			or finalPrice ~= finalPrice
			or finalPrice == math.huge
			or finalPrice == -math.huge
		then
			finalPrice = 0
		end
		if
			type(basePrice) ~= "number"
			or basePrice ~= basePrice
			or basePrice == math.huge
			or basePrice == -math.huge
		then
			basePrice = 0
		end

		-- Defensive nil/zero checks to prevent NullPointerException in drawText
		-- This handles cases where:
		-- 1. Price updates arrive before UI is fully rebuilt
		-- 2. New clients join and items are constructed without basePrice
		-- 3. Prices are nil or 0 due to sync timing issues
		if not basePrice or basePrice == 0 then
			basePrice = finalPrice
		end
		if not finalPrice or finalPrice == 0 then
			finalPrice = basePrice
		end

		-- Final safety check: both must be valid positive numbers or exit
		if not finalPrice or not basePrice or finalPrice <= 0 or basePrice <= 0 then
			return y + item.height
		end

		local coinImg = Currency.CoinsTexture.Coin
		if item.item.specialCoin then
			coinImg = Currency.CoinsTexture.SpecialCoin
		end

		-- Coin icon at 260 (after favorite at 240)
		self:drawTextureScaledAspect(coinImg.texture, 260, y + 10, coinImg.scale, coinImg.scale, 1, 1, 1, 1)

		-- Price section starts at 280, constrained to not overlap buttons
		local priceX = 280

		local finalPriceFormatted = Currency.format(finalPrice)

		-- Determine if this is a Sell tab (colors are inverted for Sell)
		local isSellTab = self.parent.tabType == Tab.Sell

		if finalPrice ~= basePrice then
			-- Price changed: finalPrice at original position, basePrice moves below
			if finalPrice > basePrice then
				---@diagnostic disable-next-line: unnecessary-if
				-- SELL TAB: Price increased is GOOD for player - show in good color with +%
				-- BUY TAB: Price increased is BAD for player - show in neutral color
				if isSellTab then
					self:drawText(
						finalPriceFormatted,
						priceX,
						y + 8,
						goodColor.r,
						goodColor.g,
						goodColor.b,
						a,
						UIFont.Small
					)
					local basePriceFormatted = Currency.format(basePrice)
					self:drawText(
						basePriceFormatted,
						priceX,
						y + 8 + self.SMALL_FONT_HGT,
						grayColor.r,
						grayColor.g,
						grayColor.b,
						a,
						UIFont.Small
					)

					local gain = finalPrice - basePrice
					local gainPct = 0
					if basePrice and basePrice > 0 then
						gainPct = math.floor((gain / basePrice) * 100)
						-- Ensure gainPct is a valid number (not NaN or infinity)
						if gainPct ~= gainPct or gainPct == math.huge or gainPct == -math.huge then
							gainPct = 0
						end
					end
					self:drawText(
						"+" .. gainPct .. "%",
						priceX + 48,
						y + 8,
						goodColor.r,
						goodColor.g,
						goodColor.b,
						a,
						UIFont.Small
					)
				else
					-- BUY TAB: Price increased is BAD for player - show in neutral color at top, basePrice grayed below
					self:drawText(
						finalPriceFormatted,
						priceX,
						y + 8,
						neutralColor.r,
						neutralColor.g,
						neutralColor.b,
						a,
						UIFont.Small
					)
					local basePriceFormatted = Currency.format(basePrice)
					self:drawText(
						basePriceFormatted,
						priceX,
						y + 8 + self.SMALL_FONT_HGT,
						grayColor.r,
						grayColor.g,
						grayColor.b,
						a,
						UIFont.Small
					)
				end
			else
				---@diagnostic disable-next-line: unnecessary-if
				if isSellTab then
					-- SELL TAB: Price decreased is BAD for player - show in neutral color
					self:drawText(
						finalPriceFormatted,
						priceX,
						y + 8,
						neutralColor.r,
						neutralColor.g,
						neutralColor.b,
						a,
						UIFont.Small
					)
					local basePriceFormatted = Currency.format(basePrice)
					self:drawText(
						basePriceFormatted,
						priceX,
						y + 8 + self.SMALL_FONT_HGT,
						grayColor.r,
						grayColor.g,
						grayColor.b,
						a,
						UIFont.Small
					)
				else
					-- BUY TAB: Price decreased is GOOD for player - show in good color with -%
					self:drawText(
						finalPriceFormatted,
						priceX,
						y + 8,
						goodColor.r,
						goodColor.g,
						goodColor.b,
						a,
						UIFont.Small
					)
					local basePriceFormatted = Currency.format(basePrice)
					self:drawText(
						basePriceFormatted,
						priceX,
						y + 8 + self.SMALL_FONT_HGT,
						grayColor.r,
						grayColor.g,
						grayColor.b,
						a,
						UIFont.Small
					)

					local discount = basePrice - finalPrice
					local discountPct = 0
					if basePrice and basePrice > 0 then
						discountPct = math.floor((discount / basePrice) * 100)
						-- Ensure discountPct is a valid number (not NaN or infinity)
						if discountPct ~= discountPct or discountPct == math.huge or discountPct == -math.huge then
							discountPct = 0
						end
					end
					self:drawText(
						"-" .. discountPct .. "%",
						priceX + 48,
						y + 8,
						goodColor.r,
						goodColor.g,
						goodColor.b,
						a,
						UIFont.Small
					)
				end
			end
		else
			-- No change: show final price in neutral color at original position
			self:drawText(
				finalPriceFormatted,
				priceX,
				y + 8,
				neutralColor.r,
				neutralColor.g,
				neutralColor.b,
				a,
				UIFont.Small
			)
		end
	end

	if item.item.invItem or item.item.texture then
		local texture = item.item.texture
		if not texture then
			texture = item.item.invItem:getTex()
		end
		self:drawTextureScaledAspect(texture, 6, y + 5, 30, 30, 1, 1, 1, 1)
	end

	if item.item.invItem and item.item.invItem:IsInventoryContainer() then
		self:drawTextureScaledAspect(
			browseBtn.texture,
			self.parent.previewButtonX,
			y + 10,
			browseBtn.scale,
			browseBtn.scale,
			1,
			1,
			1,
			1
		)
	end

	-- Show browse button for virtual bundles
	if item.item.isVirtualBundle and item.item.items then
		self:drawTextureScaledAspect(
			browseBtn.texture,
			self.parent.previewButtonX,
			y + 10,
			browseBtn.scale,
			browseBtn.scale,
			1,
			1,
			1,
			1
		)
	end

	self:drawTextureScaledAspect(addBtn.texture, self.parent.addButtonX, y + 10, addBtn.scale, addBtn.scale, 1, 1, 1, 1)

	if item.item.VehicleID then
		self:drawTextureScaledAspect(
			previewBtn.texture,
			self.parent.previewButtonX,
			y + 10,
			previewBtn.scale,
			previewBtn.scale,
			1,
			1,
			1,
			1
		)
	end

	return y + item.height
end

function ShopTabUI:onMouseDownShopItem(x, y)
	ISScrollingListBox.onMouseDown(self, x, y)
	if PreviewUI.instance ~= nil then
		PreviewUI.instance:close()
	end
	if ContainerViewerUI.instance ~= nil then
		ContainerViewerUI.instance:close()
	end
	if BundleViewerUI.instance ~= nil then
		BundleViewerUI.instance:close()
	end
	if self.selectedRow then
		local selectedRow = self.items[self.selectedRow]
		if not selectedRow then
			return
		end
		if self.previewBtn then
			-- Handle virtual bundle browse
			if selectedRow.item.isVirtualBundle and selectedRow.item.items then
				BundleViewerUI:show(selectedRow.item)
				return
			end
			-- Handle container browse
			if selectedRow.item.invItem and selectedRow.item.invItem:IsInventoryContainer() then
				ContainerViewerUI:show(selectedRow.item.invItem)
				return
			end
			-- Handle vehicle preview
			if not selectedRow.item.VehicleID then
				return
			end
			PreviewUI:show(selectedRow.item.name, selectedRow.item.VehicleID)
			return
		end
		if self.favoriteBtn then
			if not (self.parent.tabType == Tab.Sell) then
				self.parent:manageFavorites(self.selectedRow)
			end
			return
		end
		if self.addBtn then
			self.parent:addToCart(self.selectedRow)
		end
	end
end

function ShopTabUI:manageFavorites(selectedRow)
	if not self.shopItems.items[selectedRow] then
		return
	end
	local item = self.shopItems.items[selectedRow].item
	if not item then
		return
	end
	local shopFavorites = self.ShopUI.player:getModData().shopFavorites
	local check = not item.favorite
	if check then
		local data = copyTable(item)
		data.name = nil
		data.invItem = nil
		if item.items then
			data.items = item.items
		end
		shopFavorites[item.type] = data
	else
		if self.tabType == Tab.Favorite then
			self.shopItems:removeItemByIndex(selectedRow)
		end
		shopFavorites[item.type] = nil
	end
	item.favorite = check
	self.ShopUI.reloadItems = true
end

function ShopTabUI:onMouseMoveShopItem(dx, dy)
	local list = self.parent.shopItems
	if not list then
		return
	end
	list.selectedRow = nil
	list.previewBtn = nil
	list.favoriteBtn = nil
	list.addBtn = nil
	if list:isMouseOverScrollBar() or not list:isMouseOver() then
		self.parent.ShopUI:toggleTooltip(false)
		return
	end
	local rowIndex = list:rowAt(list:getMouseX(), list:getMouseY())
	if not rowIndex then
		self.parent.ShopUI:toggleTooltip(false)
		return
	end
	local selectedRow = list.items[rowIndex]
	if not selectedRow then
		self.parent.ShopUI:toggleTooltip(false)
		return
	end
	list.selectedRow = rowIndex
	local mouseX = self:getMouseX()
	if mouseX > 240 and mouseX < 260 then
		list.favoriteBtn = true
	end
	if mouseX > self.parent.addButtonX then
		list.addBtn = true
	end
	if mouseX > self.parent.previewButtonX then
		list.previewBtn = true
	end
	if not selectedRow.item then
		self.parent.ShopUI:toggleTooltip(false)
		return
	end
	self.parent.ShopUI:toggleTooltip(true, selectedRow.item)
end

function ShopTabUI:prerender()
	self.shopItems.doDrawItem = ShopTabUI.doDrawShopItem
	self.shopItems.onMouseMove = ShopTabUI.onMouseMoveShopItem
	self.shopItems.onMouseDown = ShopTabUI.onMouseDownShopItem
end

function ShopTabUI:addToCart(selectedRow)
	local item = self.shopItems.items[selectedRow]
	if not item then
		return
	end
	if self.ShopUI.actionInProgress then
		return
	end
	self.ShopUI:toggleTooltip(false)

	-- Ensure basePrice is set before adding to cart
	-- This is critical for cart display logic which needs both finalPrice and basePrice
	if item.item and item.item.price and not item.item.basePrice then
		item.item.basePrice = item.item.price
	end

	-- Phase 2.3: Store preview price for transaction validation
	if item.item and item.item.price and item.type then
		self.ShopUI:storePreviewPrice(item.type, item.item.price)
	end

	self.ShopUI.cartItems:addItem(item.text, item.item)
	if self.tabType == Tab.Sell then
		self.shopItems:removeItemByIndex(selectedRow)
	end
	self.ShopUI.cartItems:setYScroll(-10000)
	self.ShopUI:updateTotal()
end

function ShopTabUI:filter()
	local filterText = string.trim(self.filterEntry:getInternalText())
	local tabType = self.tabType
	self.shopItems.items = self.ShopUI.shopItemsCache[tabType]
	filterText = string.lower(filterText)
	local shopItems = self.shopItems.items
	if not shopItems then
		return
	end
	self.shopItems:clear()
	for k, v in ipairs(shopItems) do
		if string.contains(string.lower(v.item.name), filterText) then
			if tabType == Tab.Favorite then
				if v.item.favorite then
					self.shopItems:addItem(v.text, v.item)
				end
			else
				self.shopItems:addItem(v.text, v.item)
			end
		end
	end
end

function ShopTabUI:create()
	local x = 30
	local y = 50

	self.filterLabel = ISLabel:new(x, y - 20, 1, UIText.Search, 1, 1, 1, 1, UIFont.Small, true)
	self:addChild(self.filterLabel)

	local width = ((self.width / 3) - getTextManager():MeasureStringX(UIFont.Small, UIText.Search)) - 98
	self.filterEntry =
		ISTextEntryBox:new("", getTextManager():MeasureStringX(UIFont.Small, UIText.Search) + 40, y - 28, width, 1)
	self.filterEntry:initialise()
	self.filterEntry:instantiate()
	self.filterEntry:setText("")
	self.filterEntry:setClearButton(true)
	self.filterEntry.onTextChange = ShopTabUI.onFilterChange
	self:addChild(self.filterEntry)
	self.lastText = self.filterEntry:getInternalText()

	self.sortPriceButton = ISButton:new((self.width / 2) - 160, y - 30, 25, 25, "", self, ShopTabUI.sortPriceBtn)
	self.sortPriceButton.borderColor.a = 0.0
	self.sortPriceButton.backgroundColor.a = 0
	self.sortPriceButton.backgroundColorMouseOver.a = 0
	self.sortPriceButton:setImage(Shop.textures.Sort.texture)
	self.sortPriceButton:initialise()
	self.sortPriceButton.enable = true
	self:addChild(self.sortPriceButton)

	self.moveAllButton = ISButton:new((self.width / 2) - 50, y - 30, 25, 25, "", self, ShopTabUI.moveAllBtn)
	self.moveAllButton.borderColor.a = 0.0
	self.moveAllButton.backgroundColor.a = 0
	self.moveAllButton.backgroundColorMouseOver.a = 0
	self.moveAllButton:setImage(Shop.textures.MoveAll.texture)
	self.moveAllButton:initialise()
	self.moveAllButton.enable = false
	self.moveAllButton:setVisible(false)
	self:addChild(self.moveAllButton)

	self.shopItems = ISScrollingListBox:new(x, y, (self.width / 3) + 110, self.height - 100)
	self.shopItems:initialise()
	self.shopItems:instantiate()
	self.shopItems.font = UIFont.NewSmall
	self.shopItems.itemheight = 2 + self.MEDIUM_FONT_HGT + 4
	self.shopItems.selected = 0
	self.shopItems.joypadParent = self
	self.shopItems.drawBorder = false
	self.shopItems.SMALL_FONT_HGT = self.SMALL_FONT_HGT
	self.shopItems.MEDIUM_FONT_HGT = self.MEDIUM_FONT_HGT
	self:addChild(self.shopItems)
end

local sortToggle = true
function ShopTabUI:sortPriceBtn()
	local items = self.shopItems.items
	if not items then
		return
	end
	table.sort(items, function(v1, v2)
		if sortToggle then
			return v1.item.price < v2.item.price
		end
		return v1.item.price > v2.item.price
	end)
	self.shopItems.items = items
	sortToggle = not sortToggle
end

function ShopTabUI:moveAllBtn()
	local items = self.shopItems.items
	if not items then
		return
	end
	for k, v in pairs(items) do
		self.ShopUI.cartItems:addItem(v.item.text, v.item)
	end
	self.shopItems:clear()
end

function ShopTabUI:new(x, y, width, height)
	local o = {}
	o = ISPanelJoypad:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self
	o.favoriteStar = getTexture("media/ui/FavoriteStar.png")
	o.favCheckedTex = getTexture("media/ui/FavoriteStarChecked.png")
	o.favNotCheckedTex = getTexture("media/ui/FavoriteStarUnchecked.png")
	o.favWidth = o.favoriteStar and o.favoriteStar:getWidth() or 13
	o:noBackground()
	self.parent = o
	return o
end
