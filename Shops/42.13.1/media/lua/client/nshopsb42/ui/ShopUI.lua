local Nfunction = require("nshopsb42/utils/Nfunction")
local UIText = SHOPSB42.UIText
local Currency = SHOPSB42.Currency
local Balance = SHOPSB42.Balance
local Shop = SHOPSB42.Shop
local Tab = SHOPSB42.Tab
local PreviewUI = SHOPSB42.PreviewUI
local ContainerViewerUI = SHOPSB42.ContainerViewerUI
local ShopUITooltip = SHOPSB42.ShopUITooltip
local ShopTabUI = SHOPSB42.ShopTabUI
local ShopBuyAction = SHOPSB42.ShopBuyAction
local ShopSellAction = SHOPSB42.ShopSellAction
local Calculator = require("nshopsb42/pricing/ShopPriceCalculatorShared")
local SharedLogger = SHOPSB42.SharedLogger

local function generateTxnId()
	return tostring(getGameTime():getWorldAgeHours()) .. "-" .. tostring(ZombRand(1, 1000000000))
end

-- Calculate buy price using shared calculator or calculated prices
local function calcBuyPrice(itemId, player, basePrice)
	if not basePrice then
		return nil
	end

	-- Check if server calculated this price (server-only hooks)
	local calculatedPrices = Shop.CalculatedPrices or {}
	if calculatedPrices.buyPrices and calculatedPrices.buyPrices[itemId] then
		local price = calculatedPrices.buyPrices[itemId]

		-- DEBUG: Log price calculations for Base.Apple
		if itemId == "Base.Apple" then
			SharedLogger.log(
				"Shops",
				"[ShopUI:calcBuyPrice] Base.Apple: basePrice="
					.. basePrice
					.. ", calculated="
					.. price
					.. " (from server)"
			)
		end

		return price
	end

	-- Try using shared calculator for preview
	local modifiers = Shop.PriceModifiers or {}
	local price = Calculator.calcBuyPrice(itemId, player, modifiers)

	-- Fallback to base price if calculator returns nil (server-only)
	if not price then
		price = basePrice
	end

	-- DEBUG: Log price calculations for Base.Apple
	if itemId == "Base.Apple" then
		SharedLogger.log(
			"Shops",
			"[ShopUI:calcBuyPrice] Base.Apple: basePrice="
				.. basePrice
				.. ", calculated="
				.. price
				.. ", modifiers count="
				.. #modifiers
		)
	end

	return price
end

-- Calculate sell price using shared calculator or calculated prices
local function calcSellPrice(item, player, basePrice)
	if not basePrice or not item then
		return nil
	end

	local itemId = item:getFullType()

	-- Check if server calculated this price (server-only hooks)
	local calculatedPrices = Shop.CalculatedPrices or {}
	if calculatedPrices.sellPrices and calculatedPrices.sellPrices[itemId] then
		local price = calculatedPrices.sellPrices[itemId]

		-- DEBUG: Log price calculations for Base.Apple
		if itemId == "Base.Apple" then
			SharedLogger.log(
				"Shops",
				"[ShopUI:calcSellPrice] Base.Apple: basePrice="
					.. basePrice
					.. ", calculated="
					.. price
					.. " (from server)"
			)
		end

		return price
	end

	-- Try using shared calculator for preview (Phase 4.1: use separate modifiers)
	local modifiers = {
		sellModifiers = Shop.SellModifiers or {},
		sellOverrides = Shop.SellOverrides or {},
	}
	local price = Calculator.calcSellPrice(item, player, modifiers)

	-- Fallback to base price if calculator returns nil (server-only)
	if not price then
		price = basePrice
	end

	-- DEBUG: Log price calculations for Base.Apple
	if itemId == "Base.Apple" then
		SharedLogger.log(
			"Shops",
			"[ShopUI:calcSellPrice] Base.Apple: basePrice="
				.. basePrice
				.. ", calculated="
				.. price
				.. ", modifiers count="
				.. #modifiers
		)
	end

	return price
end

SHOPSB42.ShopUI = ISCollapsableWindow:derive("ShopUI")
local ShopUI = SHOPSB42.ShopUI
ShopUI.instance = nil
ShopUI.SMALL_FONT_HGT = getTextManager():getFontFromEnum(UIFont.Small):getLineHeight()
ShopUI.MEDIUM_FONT_HGT = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight()
ShopUI.removeButtonX = 380
ShopUI.previewButtonX = ShopUI.removeButtonX + 25
ShopUI.shopItemsCache = {}
ShopUI.total = 0
ShopUI.totalSpecial = 0
ShopUI.actionInProgress = false
ShopUI.reloadItems = false
ShopUI.lastTab = "none"
ShopUI.ItemExistsCache = {}
ShopUI._wasShopActionRunning = false -- State latch for race condition prevention
ShopUI._lastPricingState = nil -- Track pricing revisions when UI closes for reopening detection
local posX = 0
local posY = 0

local removeBtn = Shop.textures.RemoveButton
local previewBtn = Shop.textures.PreviewButton
local cartImg = Shop.textures.Cart
local browseBtn = Shop.textures.Browse
local width = 995
local height = 550

function ShopUI:show(player, viewMode, shop)
	-- Phase 3: Gate on initial sync completion (atomicity check)
	local ShopSyncClient = SHOPSB42.ShopSyncClient
	if ShopSyncClient and not ShopSyncClient.isShopReady() then
		SharedLogger.log("Shops", "[ShopUI:show] Shop not yet synced from server. Waiting...")
		-- Queue the open request to retry when sync completes
		ShopUI._pendingShowRequest = {
			player = player,
			viewMode = viewMode,
			shop = shop,
		}
		-- Register callback to retry when sync completes
		if ShopSyncClient.onInitialSyncComplete then
			ShopSyncClient.onInitialSyncComplete(function()
				if ShopUI._pendingShowRequest then
					SharedLogger.log("Shops", "[ShopUI:show] Retrying show after sync complete")
					local req = ShopUI._pendingShowRequest
					ShopUI._pendingShowRequest = nil
					ShopUI:show(req.player, req.viewMode, req.shop)
				end
			end)
		end
		return nil
	end

	local square = player:getSquare()
	posX = square:getX()
	posY = square:getY()

	SharedLogger.log(
		"Shops",
		"[ShopUI:show] ENTRY - instance=" .. tostring(ShopUI.instance ~= nil) .. ", viewMode=" .. tostring(viewMode)
	)

	if ShopUI.instance == nil then
		SharedLogger.log("Shops", "[ShopUI:show] Creating new ShopUI instance")
		ShopUI.instance = ShopUI:new(0, 0, width, height, player)
		ShopUI.instance.shop = shop
		ShopUI.instance.viewMode = viewMode
		ShopUI.instance:initialise()
		ShopUI.instance:instantiate()
		if viewMode then
			ShopUI.instance:setTitle(UIText.ShopUITitle .. " (View Only)")
		end
	end
	ShopUI.instance.pinButton:setVisible(false)
	ShopUI.instance.collapseButton:setVisible(false)
	ShopUI.instance:addToUIManager()
	ShopUI.instance:setVisible(true)

	-- Check if prices changed while UI was closed
	local ShopSyncClient = SHOPSB42.ShopSyncClient
	local Shop = SHOPSB42.Shop
	if ShopSyncClient and ShopSyncClient.checkAndHandlePriceChanges then
		SharedLogger.log("Shops", "[ShopUI:show] Calling checkAndHandlePriceChanges()...")
		ShopSyncClient.checkAndHandlePriceChanges()
		SharedLogger.log("Shops", "[ShopUI:show] checkAndHandlePriceChanges() completed")
	end

	-- Check if pricing state changed since last UI close
	if ShopUI._lastPricingState and Shop then
		local currentBuyRev = Shop.BuyPriceRevision
		local currentSellRev = Shop.SellRuleRevision
		local lastBuyRev = ShopUI._lastPricingState.buyRev
		local lastSellRev = ShopUI._lastPricingState.sellRev

		if currentBuyRev ~= lastBuyRev or currentSellRev ~= lastSellRev then
			SharedLogger.log(
				"Shops",
				"[ShopUI:show] Pricing state changed since last close: buyRev="
					.. tostring(lastBuyRev)
					.. "->"
					.. tostring(currentBuyRev)
					.. ", sellRev="
					.. tostring(lastSellRev)
					.. "->"
					.. tostring(currentSellRev)
			)
			-- Mark that prices changed while closed (UI was closed between revisions)
			ShopSyncClient.pricesChangedWhileClosed = true
			-- Trigger UI refresh
			local refreshResult = ShopSyncClient.refreshUIForPriceChange()
			SharedLogger.log("Shops", "[ShopUI:show] Triggered price change refresh due to revision mismatch")
		end
	end

	-- DEBUG: Log current pricing state when UI opens
	if ShopSyncClient then
		SharedLogger.log(
			"Shops",
			"[ShopUI:show] Pricing state: buyRev="
				.. tostring(Shop.BuyPriceRevision)
				.. ", sellRev="
				.. tostring(Shop.SellRuleRevision)
				.. ", complete="
				.. tostring(Shop._initialSyncComplete)
		)
		if Shop.BuyPrices and Shop.BuyPrices["Base.Apple"] then
			SharedLogger.log(
				"Shops",
				"[ShopUI:show] Base.Apple cached price: " .. tostring(Shop.BuyPrices["Base.Apple"])
			)
		end
	end

	return ShopUI.instance
end

function ShopUI:update()
	if not self.viewMode then
		local player = self.player
		if player:DistTo(posX, posY) > 2 then
			self:close()
		end
	end
	local username = self.player:getUsername()
	local coin, specialCoin = Balance.getUserBalance(username)
	local coinFormatted = Currency.format(coin)
	self.balanceCoinLabel:setName("" .. coinFormatted)
	local specialCoinFormatted = Currency.format(specialCoin)
	self.balanceSpecialCoinLabel:setName("" .. specialCoinFormatted)
	if self.actionInProgress then
		self.buyCartButton.enable = false
		self.buyCartButton:setVisible(false)
		self.sellCartButton.enable = false
		self.sellCartButton:setVisible(false)
		self.cancelBuyButton.enable = true
		self.cancelBuyButton:setVisible(true)
		return
	end
	self:updateTotal()
end

function ShopUI:doDrawCartItem(y, item, alt)
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

	local quantity = ""
	if item.item.quantity then
		quantity = " (" .. item.item.quantity .. ")"
	end
	self:drawText(item.item.name .. quantity, 40, y + 10, 1, 1, 1, a, UIFont.Small)
	if item.item.price then
		local basePrice = item.item.basePrice or item.item.price
		local finalPrice = item.item.price
		local discount = basePrice - finalPrice

		local coinImg = Currency.CoinsTexture.Coin
		if item.item.specialCoin then
			coinImg = Currency.CoinsTexture.SpecialCoin
		end

		-- Coin icon at 260
		self:drawTextureScaledAspect(coinImg.texture, 260, y + 10, coinImg.scale, coinImg.scale, 1, 1, 1, 1)

		-- Price section starts at 280, constrained to not overlap buttons
		local priceX = 280

		if discount > 0 then
			-- Show base price (gray strikethrough) at X=280
			local basePriceFormatted = Currency.format(basePrice)
			self:drawText(basePriceFormatted, priceX, y + 8, 0.5, 0.5, 0.5, a, UIFont.Small)

			-- Show final price (green) at X=315 (35px spacing)
			local finalPriceFormatted = Currency.format(finalPrice)
			self:drawText(finalPriceFormatted, priceX + 35, y + 8, 0.2, 1, 0.2, a, UIFont.Small)

			-- Show discount percentage at X=345 (75px spacing) - compact format
			local discountPct = math.floor((discount / basePrice) * 100)
			self:drawText("-" .. discountPct .. "%", priceX + 75, y + 8, 0.2, 1, 0.2, a, UIFont.Small)
		else
			-- No discount: show final price in white at X=280
			-- If price is approximate, dim it (0.7, 0.7, 0.7 instead of 1, 1, 1)
			local finalPriceFormatted = Currency.format(finalPrice)
			local priceColor = item.priceIsApproximate and 0.7 or 1
			self:drawText(finalPriceFormatted, priceX, y + 8, priceColor, priceColor, priceColor, a, UIFont.Small)
		end
	end

	if item.item.invItem or item.item.texture then
		local texture = item.item.texture
		if not texture then
			texture = item.item.invItem:getTex()
		end
		self:drawTextureScaledAspect(texture, 6, y + 5, 30, 30, 1, 1, 1, 1)
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
	end

	self:drawTextureScaledAspect(
		removeBtn.texture,
		self.parent.removeButtonX,
		y + 10,
		removeBtn.scale,
		removeBtn.scale,
		1,
		1,
		1,
		1
	)

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

function ShopUI:onMouseMove(dx, dy)
	self.mouseOver = true
	if self.moving then
		self:setX(self.x + dx)
		self:setY(self.y + dy)
		self:bringToTop()
	end
	if ShopUI.instance.panel.activeView.view.shopItems:isMouseOver() then
		return
	end
	if ShopUI.instance.cartItems:isMouseOver() then
		return
	end
	ShopUI.instance:toggleTooltip(false)
end

function ShopUI:onMouseDown(x, y)
	ISCollapsableWindow.onMouseDown(self, x, y)
	if PreviewUI.instance then
		PreviewUI.instance:close()
	end
end

function ShopUI:onMouseDownCartItem(x, y)
	ISScrollingListBox.onMouseDown(self, x, y)
	if PreviewUI.instance then
		PreviewUI.instance:close()
	end
	if ContainerViewerUI.instance then
		ContainerViewerUI.instance:close()
	end
	if self.selectedRow then
		local selectedRow = self.items[self.selectedRow]
		if not selectedRow then
			return
		end
		if self.previewBtn then
			if selectedRow.item.invItem and selectedRow.item.invItem:IsInventoryContainer() then
				ContainerViewerUI:show(selectedRow.item.invItem)
				return
			end
			if not selectedRow.item.VehicleID then
				return
			end
			PreviewUI:show(selectedRow.item.name, selectedRow.item.VehicleID)
			return
		end
		if self.removeBtn then
			ShopUI.instance:removeFromCart(self.selectedRow)
		end
	end
end

local currentTooltip = nil
local invTooltip = nil
local itemPackTooltip = nil
function ShopUI:toggleTooltip(show, item)
	if item then
		if item.invItem then
			if not invTooltip then
				invTooltip = ISToolTipInv:new(item.invItem)
			end
			currentTooltip = invTooltip
			item = item.invItem
			if itemPackTooltip then
				itemPackTooltip:removeFromUIManager()
				itemPackTooltip:setVisible(false)
			end
		else
			if not itemPackTooltip then
				itemPackTooltip = ShopUITooltip:new()
			end
			if invTooltip then
				invTooltip:removeFromUIManager()
				invTooltip:setVisible(false)
			end
			currentTooltip = itemPackTooltip
		end
		currentTooltip:initialise()
		currentTooltip:addToUIManager()
		currentTooltip:setItem(item)
		currentTooltip:setOwner(self)
		currentTooltip:setVisible(true)
	end
	if not show and currentTooltip then
		currentTooltip:removeFromUIManager()
		currentTooltip:setVisible(false)
	end
end

function ShopUI:onMouseMoveCartItem(dx, dy)
	local list = ShopUI.instance.cartItems
	if not list then
		return
	end
	list.selectedRow = nil
	list.previewBtn = nil
	list.removeBtn = nil
	if list:isMouseOverScrollBar() or not list:isMouseOver() then
		ShopUI.instance:toggleTooltip(false)
		return
	end
	local rowIndex = list:rowAt(list:getMouseX(), list:getMouseY())
	if not rowIndex then
		ShopUI.instance:toggleTooltip(false)
		return
	end
	local selectedRow = list.items[rowIndex]
	if not selectedRow then
		ShopUI.instance:toggleTooltip(false)
		return
	end
	local mouseX = self:getMouseX()
	list.selectedRow = rowIndex
	if mouseX > self.parent.removeButtonX then
		list.removeBtn = true
	end
	if mouseX > self.parent.previewButtonX then
		list.previewBtn = true
	end
	if not selectedRow.item.items then
		ShopUI.instance:toggleTooltip(false)
		return
	end
	ShopUI.instance:toggleTooltip(true, selectedRow.item)
end

function ShopUI:createCategories()
	for k, v in pairs(Shop.Tabs) do
		local tab = ShopTabUI:new(0, 0, self.width, self.panel.height - self.panel.tabHeight)
		tab:initialise()
		tab:setAnchorRight(true)
		tab:setAnchorBottom(true)
		tab:setShopUI(ShopUI.instance)
		tab:setCategoryType(k)
		self.panel:addView(v, tab)
		---@diagnostic disable-next-line: assign-type-mismatch
		tab.parent = self
	end
end

function ShopUI:getItemInstance(type)
	-- Always recreate item to avoid holding stale object references
	local success, result = pcall(function()
		return instanceItem(type)
	end)
	if success and result then
		self.ItemExistsCache[type] = true
		return result
	else
		self.ItemExistsCache[type] = nil
		return nil
	end
end

function ShopUI:onActivateView()
	local character = self.player
	if not character:getModData().shopFavorites then
		character:getModData().shopFavorites = {}
	end
	local tab = self.panel.activeView.view
	local tabType = tab.tabType
	local shopItems = tab.shopItems

	if self.reloadItems then
		shopItems:clear()
	end

	if self.lastTab == Tab.Sell or tabType == Tab.Sell then
		self.cartItems:clear()
	end
	self.lastTab = tabType

	-- Phase 3.6: Invalidate and recalc visible rows for new tab
	for _, row in ipairs(self:getVisibleRows()) do
		self:onRowBecameVisible(row)
	end

	if tabType == Tab.Sell then
		tab.moveAllButton.enable = true
		tab.moveAllButton:setVisible(true)
		shopItems:clear()
		if not self.viewMode then
			self.sellCartButton.enable = false
			self.sellCartButton:setVisible(true)
			self.buyCartButton.enable = false
			self.buyCartButton:setVisible(false)
		end
		local inventory = character:getInventory():getItems()
		for i = 0, inventory:size() - 1 do
			local item = inventory:get(i)
			local itemType = item:getFullType()
			local itemSell = Shop.PlayerSell[itemType]
			local isBroken = item:isBroken()
			if not (item:isEquipped() or item:isFavorite() or Currency.Coins[itemType]) then
				local canSell = false

				if Shop.SellisWhitelist then
					-- Whitelist mode: only registered items allowed
					canSell = itemSell ~= nil
				else
					-- Blacklist mode: all items allowed except those marked blacklisted
					canSell = not (itemSell and itemSell.blacklisted)
				end

				if canSell then
					local v = {}
					v.type = itemType
					local price = Shop.defaultPrice
					if isBroken then
						price = Shop.defaultPriceBroken
					end
					if itemSell then
						v.specialCoin = itemSell.specialCoin
						if isBroken then
							price = itemSell.priceBroken or Shop.defaultPriceBroken
						else
							price = itemSell.price or Shop.defaultPrice
						end
					end
					v.priceFull = price
					price = Nfunction.drainablePrice(item, price)
					local context = {
						shopId = self.shop and self.shop:getName() or "Unknown",
						quantity = 1,
						isSpecialCoin = v.specialCoin or false,
						isBroken = isBroken,
					}
					-- Use shared calculator for preview price
					local calculatedPrice = calcSellPrice(item, character, price)
					-- Fall back to old method if calculator unavailable
					local dynamicPrice = calculatedPrice or Shop.resolvePlayerSellPrice(character, item, context)
					v.price = dynamicPrice or price
					v.id = item:getID()
					v.name = Nfunction.trimString(item:getName(), 42)
					v.invItem = item
					if price > 0 then
						shopItems:addItem(itemType, v)
					end
				end
			end
		end
		self.shopItemsCache[tabType] = shopItems.items
		return
	else
		if self.sellCartButton then
			self.sellCartButton.enable = false
			self.sellCartButton:setVisible(false)
			self.buyCartButton:setVisible(true)
		end
	end

	if tabType == Tab.Favorite then
		shopItems:clear()
		local shopFavorites = character:getModData().shopFavorites
		for k, v in pairs(shopFavorites) do
			local shopItemDef = Shop.Items[k]
			local item = self:getItemInstance(k)
			if shopItemDef then
				local context = {
					shopId = self.shop and self.shop:getName() or "Unknown",
					quantity = 1,
					isSpecialCoin = shopItemDef.specialCoin or false,
					isBroken = false,
				}
				-- Use shared calculator for preview price
				local calculatedPrice = calcBuyPrice(k, character, shopItemDef.price)
				-- Fall back to old method if calculator unavailable
				local dynamicPrice = calculatedPrice or Shop.resolvePlayerBuyPrice(character, k, context)
				v.price = dynamicPrice or shopItemDef.price
				v.basePrice = shopItemDef.price -- Store base price for discount display
			end
			if item then
				local VehicleID = item:getModData().VehicleID
				if VehicleID then
					v.VehicleID = VehicleID
				end
				v.favorite = true
				v.type = k
				if not v.items then
					v.invItem = item
				else
					v.texture = item:getTex()
				end
				v.name = Nfunction.trimString(item:getName(), 42)
				shopItems:addItem(k, v)
			else
				character:getModData().shopFavorites[k] = nil
			end
		end
		self.shopItemsCache[tabType] = shopItems.items
		return
	end

	if shopItems.count > 0 then
		return
	end

	if not self.reloadItems then
		if self.shopItemsCache[tabType] then
			shopItems.items = self.shopItemsCache[tabType]
			return
		end
	end

	for k, v in pairs(Shop.Items) do
		if v and (v.tab == tabType or tabType == Tab.All) then
			local item = self:getItemInstance(k)
			if item then
				local VehicleID = item:getModData().VehicleID
				if VehicleID then
					v.VehicleID = VehicleID
				end
				v.favorite = character:getModData().shopFavorites[k]
				v.type = k
				if not v.items then
					v.invItem = item
				else
					v.texture = item:getTex()
				end
				v.name = Nfunction.trimString(item:getName(), 42)
				local context = {
					shopId = self.shop and self.shop:getName() or "Unknown",
					quantity = 1,
					isSpecialCoin = v.specialCoin or false,
					isBroken = false,
				}
				-- Determine the original shop item price for basePrice
				-- If this item is being loaded for the first time, v.price is the original shop item price
				-- If previously processed (tab reload after cache clear), use the existing basePrice to preserve original price
				local originalPrice = v.basePrice or v.price
				v.basePrice = originalPrice
				-- Use shared calculator for preview price
				local calculatedPrice = calcBuyPrice(k, character, originalPrice)
				-- Fall back to old method if calculator unavailable
				local dynamicPrice = calculatedPrice or Shop.resolvePlayerBuyPrice(character, k, context)
				v.price = dynamicPrice or originalPrice
				shopItems:addItem(k, v)
			end
		end
	end
	self.shopItemsCache[tabType] = shopItems.items
	self.reloadItems = false
end

function ShopUI:createChildren()
	ISCollapsableWindow.createChildren(self)
	local x = 30
	local y = 85

	local th = self:titleBarHeight()
	self.panel = ISTabPanel:new(0, th, (self.width / 2) - 25, self.height - 10)
	self.panel:initialise()
	self.panel:setAnchorRight(true)
	self.panel:setAnchorBottom(true)
	self.panel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
	self.panel.onActivateView = self.onActivateView
	self.panel.target = self
	self.panel:setEqualTabWidth(false)
	self:addChild(self.panel)
	self:createCategories()
	self:activateFirstTab()

	self.clearCartButton =
		ISButton:new((self.width / 2) + 380, y + 280, 80, 25, UIText.ClearCart, self, ShopUI.clearCartBtn)
	self.clearCartButton:initialise()
	self:addChild(self.clearCartButton)

	if not self.viewMode then
		self.buyCartButton =
			ISButton:new((self.width / 2) + 200, y + 350, 80, 25, UIText.BuyCart, self, ShopUI.buyCartBtn)
		self.buyCartButton:initialise()
		self.buyCartButton.enable = false
		self.buyCartButton:setVisible(true)
		self:addChild(self.buyCartButton)

		self.sellCartButton =
			ISButton:new((self.width / 2) + 200, y + 350, 80, 25, UIText.Sell, self, ShopUI.sellCartBtn)
		self.sellCartButton:initialise()
		self.sellCartButton.enable = false
		self.sellCartButton:setVisible(false)
		self:addChild(self.sellCartButton)

		self.cancelBuyButton =
			ISButton:new((self.width / 2) + 200, y + 350, 80, 25, UIText.Cancel, self, ShopUI.cancelBuyBtn)
		self.cancelBuyButton:initialise()
		self.cancelBuyButton.enable = false
		self.cancelBuyButton:setVisible(false)
		self:addChild(self.cancelBuyButton)
	else
		self.balanceLabel = ISLabel:new(
			(self.width / 2) + 150,
			y + 350,
			ShopUI.SMALL_FONT_HGT,
			UIText.ShopViewOnly,
			1,
			1,
			1,
			1,
			UIFont.Medium,
			true
		)
		self:addChild(self.balanceLabel)
	end

	self.cartTex = ISImage:new(x + 905, y - 35, 0, 0, cartImg.texture)
	self.cartTex.scaledWidth = cartImg.scale
	self.cartTex.scaledHeight = cartImg.scale
	self:addChild(self.cartTex)

	self.cartItems = ISScrollingListBox:new(x + 490, y, (self.width / 3) + 110, self.height / 2)
	self.cartItems:initialise()
	self.cartItems:instantiate()
	self.cartItems:setAnchorRight(false)
	self.cartItems:setAnchorBottom(true)
	self.cartItems.font = UIFont.NewSmall
	self.cartItems.itemheight = 2 + self.MEDIUM_FONT_HGT + 4
	self.cartItems.selected = 1
	self.cartItems.joypadParent = self
	self.cartItems.drawBorder = false
	self.cartItems.SMALL_FONT_HGT = self.SMALL_FONT_HGT
	self.cartItems.MEDIUM_FONT_HGT = self.MEDIUM_FONT_HGT
	self.cartItems.doDrawItem = ShopUI.doDrawCartItem
	self.cartItems.onMouseMove = ShopUI.onMouseMoveCartItem
	self.cartItems.onMouseDown = ShopUI.onMouseDownCartItem
	self:addChild(self.cartItems)

	self.balanceLabel = ISLabel:new(x + 490, 20, ShopUI.SMALL_FONT_HGT, UIText.Balance, 1, 1, 1, 1, UIFont.Medium, true)
	self:addChild(self.balanceLabel)

	local coinImg = Currency.CoinsTexture.Coin
	self.balanceCoinTex = ISImage:new(x + 550, 20, 0, 0, coinImg.texture)
	self.balanceCoinTex.scaledWidth = coinImg.scale + 5
	self.balanceCoinTex.scaledHeight = coinImg.scale + 5
	self:addChild(self.balanceCoinTex)

	self.balanceCoinLabel = ISLabel:new(x + 575, 20, ShopUI.SMALL_FONT_HGT, "0", 1, 1, 1, 1, UIFont.Medium, true)
	self:addChild(self.balanceCoinLabel)

	self.coinTex = ISImage:new(x + 535, y + 280, 0, 0, coinImg.texture)
	self.coinTex.scaledWidth = coinImg.scale + 5
	self.coinTex.scaledHeight = coinImg.scale + 5
	self:addChild(self.coinTex)

	self.totalLabel =
		ISLabel:new(x + 490, y + 280, ShopUI.SMALL_FONT_HGT, UIText.Total, 1, 1, 1, 1, UIFont.Medium, true)
	self:addChild(self.totalLabel)

	self.totalCoinLabel = ISLabel:new(x + 560, y + 280, ShopUI.SMALL_FONT_HGT, "0", 1, 1, 1, 1, UIFont.Medium, true)
	self:addChild(self.totalCoinLabel)

	coinImg = Currency.CoinsTexture.SpecialCoin
	self.balanceSpecialCoinTex = ISImage:new(x + 550, 45, 0, 0, coinImg.texture)
	self.balanceSpecialCoinTex.scaledWidth = coinImg.scale + 5
	self.balanceSpecialCoinTex.scaledHeight = coinImg.scale + 5
	self:addChild(self.balanceSpecialCoinTex)

	self.balanceSpecialCoinLabel = ISLabel:new(x + 575, 45, ShopUI.SMALL_FONT_HGT, "0", 1, 1, 1, 1, UIFont.Medium, true)
	self:addChild(self.balanceSpecialCoinLabel)

	self.specialCoinTex = ISImage:new(x + 535, y + 305, 0, 0, coinImg.texture)
	self.specialCoinTex.scaledWidth = coinImg.scale + 5
	self.specialCoinTex.scaledHeight = coinImg.scale + 5
	self:addChild(self.specialCoinTex)

	self.totalSpecialCoinLabel =
		ISLabel:new(x + 560, y + 305, ShopUI.SMALL_FONT_HGT, "0", 1, 1, 1, 1, UIFont.Medium, true)
	self:addChild(self.totalSpecialCoinLabel)

	if not Currency.UseSpecialCoin then
		self.balanceSpecialCoinTex:setVisible(false)
		self.balanceSpecialCoinLabel:setVisible(false)
		self.specialCoinTex:setVisible(false)
		self.totalSpecialCoinLabel:setVisible(false)
	end
end

function ShopUI:activateFirstTab()
	for k, v in pairs(Shop.Tabs) do
		self.panel:activateView(v)
		break
	end
end

function ShopUI:removeFromCart(selectedRowIndex)
	if self.actionInProgress then
		return
	end
	self:toggleTooltip(false)
	local selectedRow = self.cartItems.items[selectedRowIndex]
	if not selectedRow then
		return
	end

	local tab = self.panel.activeView.view
	local tabType = tab.tabType
	if tabType == Tab.Sell then
		tab.shopItems:addItem(selectedRow.item.type, selectedRow.item)
	end
	self.cartItems:removeItemByIndex(selectedRowIndex)
end

function ShopUI:clearCartBtn()
	if self.actionInProgress then
		return
	end
	local tab = self.panel.activeView.view
	local tabType = tab.tabType
	if tabType == Tab.Sell then
		for k, v in pairs(self.cartItems.items) do
			tab.shopItems:addItem(v.item.type, v.item)
		end
	end
	self.cartItems:clear()
end

function ShopUI:cancelBuyBtn()
	-- ✓ SAFE: Use ISTimedActionQueue.clear() - the only correct way to cancel from UI
	ISTimedActionQueue.clear(self.player)

	-- Reset action in progress flag and UI state
	self.actionInProgress = false
	self._wasShopActionRunning = false

	-- Restore cart and button visibility
	local tabType = self.panel.activeView.view.tabType
	if tabType == Tab.Sell then
		self.sellCartButton.enable = true
		self.sellCartButton:setVisible(true)
	else
		self.buyCartButton.enable = true
		self.buyCartButton:setVisible(true)
	end
	self.cancelBuyButton.enable = false
	self.cancelBuyButton:setVisible(false)
end

function ShopUI:buildBuyTicket()
	local ticket = {
		txnId = generateTxnId(),
		coin = 0,
		specialCoin = 0,
		items = {},
	}

	for _, row in ipairs(self.cartItems.items) do
		local item = row.item
		if item then
			-- Use stored price calculated during item list prep (server will recompute authoritatively)
			-- DO NOT recalculate on client to avoid price desync
			local itemPrice = item.price

			-- Accumulate price
			if item.specialCoin then
				ticket.specialCoin = ticket.specialCoin + itemPrice
			else
				ticket.coin = ticket.coin + itemPrice
			end

			-- Handle compound items (packs)
			if item.items then
				-- This is a pack item, store with items array
				local packEntry = {
					type = item.type,
					items = {},
					drop = item.drop,
					isVirtualBundle = item.isVirtualBundle or false,
				}
				for _, packItem in ipairs(item.items) do
					table.insert(packEntry.items, {
						item = packItem.item,
						quantity = packItem.quantity or 1,
					})
				end
				table.insert(ticket.items, packEntry)
			else
				-- Simple item
				table.insert(ticket.items, {
					type = item.type,
					quantity = item.quantity or 1,
				})
			end
		end
	end

	return ticket
end

function ShopUI:buyCartBtn()
	-- Phase 3.3: Debounce check before dispatch
	if not self:canDispatchAction() then
		return
	end

	self.actionInProgress = true

	local ticket = self:buildBuyTicket()
	-- Extract shop coordinates for serialization (objects don't serialize over network)
	local shopCoords = nil
	if self.shop then
		local square = self.shop:getSquare()
		shopCoords = { x = square:getX(), y = square:getY(), z = square:getZ() }
	else
		shopCoords = { x = 0, y = 0, z = 0 }
	end
	local action = ShopBuyAction:new(self.player, shopCoords, ticket)

	ISTimedActionQueue.add(action)
	self.buyCartButton.enable = false
	self.buyCartButton:setVisible(false)
	self.cancelBuyButton.enable = true
	self.cancelBuyButton:setVisible(true)
end

function ShopUI:buildSellList()
	local sellList = {
		txnId = generateTxnId(),
		items = {},
	}

	for _, row in ipairs(self.cartItems.items) do
		local item = row.item
		if item then
			local invItem = item.invItem

			if invItem then
				-- Recalculate price on client for preview (server will recompute authoritatively)
				local itemPrice = item.price
				local context = {
					shopId = self.shop and self.shop:getName() or "Unknown",
					quantity = 1,
					isSpecialCoin = item.specialCoin or false,
					isBroken = item.isBroken or false,
				}
				local dynamicPrice = Shop.resolvePlayerSellPrice(self.player, invItem, context)
				if dynamicPrice then
					itemPrice = dynamicPrice
				end

				table.insert(sellList.items, {
					itemID = invItem:getID(),
					price = itemPrice,
					specialCoin = item.specialCoin or false,
				})
			end
		end
	end

	return sellList
end

function ShopUI:sellCartBtn()
	-- Phase 3.3: Debounce check before dispatch
	if not self:canDispatchAction() then
		return
	end

	-- Validate wallet is linked before starting sell
	local username = self.player:getUsername()
	local account = Balance.getUserAccount(username)
	if not account or not account.linkedTo then
		getCore():getUI():showConfirmDialog(
			UIText.SellError or "Error",
			UIText.WalletNotLinked or "You must create and link a wallet to sell items. Visit the Wallet Station first.",
			function() end,
			nil
		)
		return
	end

	self.actionInProgress = true

	local sellList = self:buildSellList()
	-- Extract shop coordinates for serialization (objects don't serialize over network)
	local shopCoords = nil
	if self.shop then
		local square = self.shop:getSquare()
		shopCoords = { x = square:getX(), y = square:getY(), z = square:getZ() }
	else
		shopCoords = { x = 0, y = 0, z = 0 }
	end
	local action = ShopSellAction:new(self.player, shopCoords, sellList)

	ISTimedActionQueue.add(action)
	self.sellCartButton.enable = false
	self.sellCartButton:setVisible(false)
	self.cancelBuyButton.enable = true
	self.cancelBuyButton:setVisible(true)
end

function ShopUI:render()
	ISCollapsableWindow.render(self)
	local actionQueue = ISTimedActionQueue.getTimedActionQueue(self.player)
	local currentAction = actionQueue.current -- ✓ CRITICAL: Use queue.current, not queue[1]

	-- Check if this is a shop action (using marker field, not class identity)
	local isShopAction = currentAction
		and (currentAction._shopActionType == "buy" or currentAction._shopActionType == "sell")

	if isShopAction and currentAction then
		-- Action is running: draw progress
		self._wasShopActionRunning = true
		self:drawProgressBar((self.width / 2) + 180, 420, 120, 10, currentAction:getJobDelta(), self.fgBar)
	else
		-- Action is not running: finalize UI state once (state latch prevents flickering)
		if self._wasShopActionRunning then
			self._wasShopActionRunning = false
			-- Clear cart and reset buttons only on transition
			if self.actionInProgress then
				self.cartItems:clear()
				self:updateTotal()
			end
			self.actionInProgress = false
		end
	end
end

function ShopUI:updateTotal()
	local total = 0
	local totalSpecial = 0
	self.totalCoinLabel:setName("" .. total)
	self.totalSpecialCoinLabel:setName("" .. totalSpecial)
	for k, v in pairs(self.cartItems.items) do
		local cost = v.item.price
		if not v.item.specialCoin then
			total = total + cost
		else
			totalSpecial = totalSpecial + cost
		end
	end
	if total > 0 then
		local totalFormat = Currency.format(total)
		self.totalCoinLabel:setName("" .. totalFormat)
	end
	if totalSpecial > 0 then
		local totalSpecialFormat = Currency.format(totalSpecial)
		self.totalSpecialCoinLabel:setName("" .. totalSpecialFormat)
	end
	if self.viewMode then
		return
	end

	local tabType = self.panel.activeView.view.tabType
	if tabType == Tab.Sell then
		self.sellCartButton.enable = false
		self.sellCartButton:setVisible(true)
	else
		self.buyCartButton.enable = false
		self.buyCartButton:setVisible(true)
	end
	self.cancelBuyButton.enable = false
	self.cancelBuyButton:setVisible(false)
	self.total = total
	self.totalSpecial = totalSpecial
	if total == 0 and totalSpecial == 0 then
		return
	end

	local username = self.player:getUsername()
	local coin, specialCoin = Balance.getUserBalance(username)
	if tabType == Tab.Sell and (total > 0 or totalSpecial > 0) then
		self.buyCartButton.enable = false
		self.buyCartButton:setVisible(false)
		self.cancelBuyButton.enable = false
		self.cancelBuyButton:setVisible(false)

		-- Check if wallet is linked before enabling sell
		local account = Balance.getUserAccount(username)
		if account and account.linkedTo then
			self.sellCartButton.enable = true
			self.sellCartButton:setVisible(true)
		else
			self.sellCartButton.enable = false
			self.sellCartButton:setVisible(true)
		end
		return
	end
	if coin >= total and specialCoin >= totalSpecial and not (tabType == Tab.Sell) then
		self.buyCartButton.enable = true
		self.buyCartButton:setVisible(true)
		self.sellCartButton.enable = false
		self.sellCartButton:setVisible(false)
		self.cancelBuyButton.enable = false
		self.cancelBuyButton:setVisible(false)
	end
end

function ShopUI:close()
	ISCollapsableWindow.close(self)

	-- Reset UI state flags to prevent stale state
	self.actionInProgress = false
	self.reloadItems = false
	self.selected = nil

	-- Save pricing state before closing for comparison when reopening
	local Shop = SHOPSB42.Shop
	if Shop then
		ShopUI._lastPricingState = {
			buyRev = Shop.BuyPriceRevision,
			sellRev = Shop.SellRuleRevision,
		}
		SharedLogger.log(
			"Shops",
			"[ShopUI:close] Saved pricing state: buyRev="
				.. tostring(ShopUI._lastPricingState.buyRev)
				.. ", sellRev="
				.. tostring(ShopUI._lastPricingState.sellRev)
		)
	end

	if PreviewUI.instance then
		PreviewUI.instance:close()
	end
	if ContainerViewerUI.instance then
		ContainerViewerUI.instance:close()
	end
	if ShopUI.instance then
		ShopUI.instance:removeFromUIManager()
		ShopUI.instance = nil
	end
	self:removeFromUIManager()
end

-- Phase 3.2: Cancel pending transactions
function ShopUI:cancelPendingTransactions()
	if self.activeTimedAction then
		self.activeTimedAction:forceStop()
		self.activeTimedAction = nil
	end

	self:setButtonsEnabled(false)

	-- Optional short debounce (300ms)
	self._priceUpdateCooldown = getTimestampMs()
end

-- Phase 3.3: Debounce check before transaction dispatch
function ShopUI:canDispatchAction()
	if self._priceUpdateCooldown and getTimestampMs() - self._priceUpdateCooldown < 300 then
		return false
	end
	return true
end

-- Helper: Set button enabled state
function ShopUI:setButtonsEnabled(enabled)
	if self.buyCartButton then
		self.buyCartButton.enable = enabled
	end
	if self.sellCartButton then
		self.sellCartButton.enable = enabled
	end
	if self.cancelBuyButton then
		self.cancelBuyButton.enable = enabled
	end
end

-- Phase 3.4b: Rebuild active tab (reuses onActivateView logic)
function ShopUI:rebuildActiveTab()
	local tab = self.panel.activeView and self.panel.activeView.view
	if not tab or not tab.shopItems then
		return false
	end

	local tabType = tab.tabType
	local oldScroll = tab.shopItems.yScroll or 0

	-- Temporarily set reloadItems to force rebuild
	local oldReloadItems = self.reloadItems
	self.reloadItems = true

	-- Call the standard activation handler to rebuild the tab
	self:onActivateView()

	-- Restore scroll position
	if tab.shopItems then
		tab.shopItems:setYScroll(oldScroll)
	end

	self.reloadItems = oldReloadItems
	return true
end

-- Phase 3.5: Recalculate single row price lazily
function ShopUI:recalculateRowPrice(row)
	if not row then
		return
	end

	local player = self.player
	local mods = Shop.PriceModifiers or {}

	-- Preserve the original base price if not already set
	if not row.basePrice then
		row.basePrice = row.price
	end

	local price
	if row.type then
		-- Buy tab: use authoritative server price first (for price hooks)
		local calc = Shop.CalculatedPrices
		if calc and calc.buyPrices and calc.buyPrices[row.type] then
			-- Server-authoritative price (e.g., from price hooks)
			price = calc.buyPrices[row.type]
			row.priceIsApproximate = false
		else
			-- Fallback to preview calculator if no server price
			price = Calculator.calcBuyPrice(row.type, player, mods)
			row.priceIsApproximate = true
		end
	elseif row.item and row.item.invItem then
		-- Sell tab: calculate sell price for inventory item (preview-only, no server override)
		price = Calculator.calcSellPrice(row.item.invItem, player, mods)
		row.priceIsApproximate = true
	end

	if not price then
		price = row.basePrice
		row.priceIsApproximate = true
	end

	row.price = price
	row.priceRevision = Shop.PriceHookRevision
end

-- Phase 3.6: Row activation handler (called when row becomes visible)
function ShopUI:onRowBecameVisible(row)
	if not row then
		return
	end

	-- If row's price revision is stale, recalculate
	if row.priceRevision ~= Shop.PriceHookRevision then
		self:recalculateRowPrice(row)
	end
end

-- Phase 3.7: Set whether price is approximate (estimated vs calculated)
function ShopUI:setPriceApproximate(row, isApproximate)
	if row then
		row.priceIsApproximate = isApproximate
	end
end

-- Helper: Get visible rows from current tab (computed from scroll position)
function ShopUI:getVisibleRows()
	local tab = self.panel.activeView and self.panel.activeView.view
	if not tab then
		return {}
	end

	local list = tab.shopItems
	if not list or not list.items then
		return {}
	end

	-- Compute visible rows using scroll math (mirrors vanilla rendering)
	local itemHeight = list.itemheight or list.fontHeight or 16
	local yScroll = list.yScroll or 0
	local viewHeight = list.height

	local firstRow = math.floor(yScroll / itemHeight) + 1
	local visibleCount = math.ceil(viewHeight / itemHeight) + 1
	local lastRow = math.min(firstRow + visibleCount, #list.items)

	local rows = {}
	for i = firstRow, lastRow do
		if list.items[i] then
			rows[#rows + 1] = list.items[i]
		end
	end

	return rows
end

function ShopUI:new(x, y, width, height, player)
	local o = {}
	if x == 0 and y == 0 then
		x = (getCore():getScreenWidth() / 2) - (width / 2)
		y = (getCore():getScreenHeight() / 2) - (height / 2)
	end
	o = ISCollapsableWindow:new(x, y, width, height)
	setmetatable(o, self)
	o.fgBar = { r = 0, g = 0.6, b = 0, a = 0.7 }
	self.__index = self
	o.title = UIText.ShopUITitle
	o.player = player
	o.resizable = false

	-- Phase 3.4: Initialize row price revision tracking
	o._priceUpdateCooldown = nil

	return o
end
