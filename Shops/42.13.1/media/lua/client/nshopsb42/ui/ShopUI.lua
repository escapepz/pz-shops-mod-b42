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
local SharedLogger = SHOPSB42.SharedLogger
local ClientShopListingService = require("nshopsb42/ui/ClientShopListingService") -- Phase 3: Client listing service

-- IMPORTANT: Tab Architecture and Revision Mapping
-- =================================================
-- Shop.BuyPriceRevision (affects buy-side tabs):
--   - Tab.All       (shows all available items across all categories)
--   - Tab.Food, Tab.Weapons, Tab.Vehicle, Tab.Event, Tab.FirstAid (custom registered tabs)
--   - Tab.Favorite  (custom user-favorites, sourced from items in the above tabs)
--
-- Shop.SellRuleRevision (affects sell-side tabs):
--   - Tab.Sell      (shows player inventory items available to sell)
--
-- When invalidateUI is triggered by price changes:
--   - BUY_PRICE_DELTA: lazy-recalculates visible row prices (rows self-heal on visibility)
--   - SELL_RULE_CHANGE: rebuilds entire Sell tab (inventory rules don't support lazy recalc)
--   - When any tab rebuilds, cache for other tabs should be invalidated to ensure consistency

local function generateTxnId()
	local player = getPlayer()
	if not player then
		return nil
	end
	-- Format: username-timestamp-random (ensures player-scoped uniqueness)
	-- timestamp = os.time() is server epoch, unique per second
	-- random = small number for additional entropy within same second
	return player:getUsername() .. "-" .. tostring(os.time()) .. "-" .. tostring(ZombRand(1, 1000))
end

-- Phase 3: Calculate buy price using deterministic client-side listing
-- Prioritizes ClientShopListingService for zero-network preview pricing
-- Phase 3 (consolidated): Calculate buy price using deterministic client-side listing
-- Canonical source: ClientShopListingService (calls PricingContract internally)
-- ZERO network traffic - all calculations happen locally
-- No server price check needed (Phase 2 broadcasts disabled; transactions validate server-side)
local function calcBuyPrice(itemId, player, basePrice)
	if not basePrice then
		return nil
	end

	player = player or getPlayer()

	-- PRIORITY 1: Use ClientShopListingService for deterministic preview pricing
	-- This calls PricingContract internally for consistent client/server pricing
	---@diagnostic disable-next-line: unnecessary-if
	if ClientShopListingService and ClientShopListingService.calculatePreviewBuyPrice then
		local previewPrice =
			ClientShopListingService.calculatePreviewBuyPrice(itemId, "npc_general_store", basePrice, player)

		-- DEBUG: Log price calculations for Base.Apple
		if itemId == "Base.Apple" then
			SharedLogger.log(
				"Shops",
				"[ShopUI:calcBuyPrice] Base.Apple: basePrice="
					.. basePrice
					.. ", preview="
					.. (previewPrice or "nil")
					.. " (from ClientShopListingService)"
			)
		end

		if previewPrice then
			return previewPrice
		end
	end

	-- FALLBACK: Use base price if calculation fails
	return basePrice
end

-- Phase 3 (consolidated): Calculate sell price using deterministic client-side listing
-- Canonical source: ClientShopListingService (calls PricingContract internally)
-- ZERO network traffic - all calculations happen locally
-- No server price check needed (Phase 2 broadcasts disabled; transactions validate server-side)
local function calcSellPrice(item, player, basePrice)
	if not basePrice or not item then
		return nil
	end

	local itemId = item:getFullType()
	player = player or getPlayer()

	-- PRIORITY 1: Use ClientShopListingService for deterministic preview pricing
	-- This calls PricingContract internally for consistent client/server pricing
	---@diagnostic disable-next-line: unnecessary-if
	if ClientShopListingService and ClientShopListingService.calculatePreviewSellPrice then
		local itemCondition = item:getCondition()
		local previewPrice = ClientShopListingService.calculatePreviewSellPrice(
			itemId,
			"npc_general_store",
			basePrice,
			itemCondition,
			player
		)

		-- DEBUG: Log price calculations for Base.Apple
		if itemId == "Base.Apple" then
			SharedLogger.log(
				"Shops",
				"[ShopUI:calcSellPrice] Base.Apple: basePrice="
					.. basePrice
					.. ", preview="
					.. (previewPrice or "nil")
					.. " (from ClientShopListingService)"
			)
		end

		if previewPrice then
			return previewPrice
		end
	end

	-- FALLBACK: Use base price if calculation fails
	return basePrice
end

-- Phase 2.3: Validate transaction price mismatch between client preview and server final price
-- Returns (isValid, errorCode)
-- isValid = true if price is within tolerance
-- errorCode = "missing_price" (missing data) or "mismatch" (exceeds tolerance) or nil
local function validateTransactionPrice(itemId, clientPrice, serverPrice, tolerance)
	tolerance = tolerance or 1 -- Default: ±1 coin tolerance

	if not clientPrice or not serverPrice then
		return false, "missing_price"
	end

	local diff = math.abs(clientPrice - serverPrice)
	if diff > tolerance then
		SharedLogger.log(
			"Shops",
			"[ShopUI:validateTransactionPrice] Price mismatch: itemId="
				.. tostring(itemId)
				.. " clientPrice="
				.. tostring(clientPrice)
				.. " serverPrice="
				.. tostring(serverPrice)
				.. " diff="
				.. tostring(diff)
				.. " tolerance="
				.. tostring(tolerance)
		)
		return false, "mismatch"
	end

	return true, nil
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
	---@diagnostic disable-next-line: unnecessary-if
	if ShopSyncClient and not ShopSyncClient.isShopReady() then
		SharedLogger.log("Shops", "[ShopUI:show] Shop not yet synced from server. Waiting...")

		-- Notify player that shop data is syncing (Phase 4.2: user feedback when UI not ready)
		if player then
			player:setHaloNote(getText("IGUI_Shop_DataSyncing") or "Shop data is syncing with server", 200, 200, 0, 500)
			SharedLogger.log("Shops", "[ShopUI:show] Showed 'syncing' halo note")
		end

		-- Queue the open request to retry when sync completes
		ShopUI._pendingShowRequest = {
			player = player,
			viewMode = viewMode,
			shop = shop,
		}
		---@diagnostic disable-next-line: unnecessary-if
		-- Register callback to retry when sync completes
		if ShopSyncClient.onInitialSyncComplete then
			ShopSyncClient.onInitialSyncComplete(function()
				if ShopUI._pendingShowRequest then
					SharedLogger.log("Shops", "[ShopUI:show] Retrying show after sync complete")
					local req = ShopUI._pendingShowRequest
					ShopUI._pendingShowRequest = nil
					---@diagnostic disable-next-line: unnecessary-if
					if req then
						---@diagnostic disable-next-line: redundant-parameter
						ShopUI:show(req.player, req.viewMode, req.shop)
					end
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
	---@diagnostic disable-next-line: unnecessary-if
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

	---@diagnostic disable-next-line: unnecessary-if
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
		---@diagnostic disable-next-line: unnecessary-if
		if player and player:DistTo(posX, posY) > 2 then
			self:close()
		end
	end
	local username = self.player:getUsername()
	local coin, specialCoin = Balance.getUserBalance(username)
	local coinFormatted = Currency.format(coin)
	self.balanceCoinLabel:setName("" .. coinFormatted)
	local specialCoinFormatted = Currency.format(specialCoin)
	self.balanceSpecialCoinLabel:setName("" .. specialCoinFormatted)
	---@diagnostic disable-next-line: unnecessary-if
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
	-- basePrice is guaranteed to be set when item is added to cart (ShopTabUI.addToCart)
	-- Both finalPrice (item.price) and basePrice should always be present here
	-- Cart now uses same visual logic as listing view

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

		local coinImg = Currency.CoinsTexture.Coin
		if item.item.specialCoin then
			coinImg = Currency.CoinsTexture.SpecialCoin
		end

		-- Coin icon at 260
		self:drawTextureScaledAspect(coinImg.texture, 260, y + 10, coinImg.scale, coinImg.scale, 1, 1, 1, 1)

		-- Price section starts at 280, constrained to not overlap buttons
		local priceX = 280

		-- Color definitions (matching ShopTabUI)
		local goodColor = { r = 0, g = 1, b = 0, a = 1 }
		local neutralColor = { r = 0.85, g = 0.85, b = 0.85, a = 1 }
		local grayColor = { r = 0.3, g = 0.3, b = 0.3, a = 1 }

		-- Determine if this is a Sell tab (colors are inverted for Sell)
		-- Get active tab from ShopUI instance (self.parent is the ShopUI panel)
		local isSellTab = false
		if self.parent and self.parent.panel and self.parent.panel.activeView then
			local activeTab = self.parent.panel.activeView.view
			if activeTab then
				isSellTab = activeTab.tabType == Tab.Sell
			end
		end

		local finalPriceFormatted = Currency.format(finalPrice)
		local basePriceFormatted = Currency.format(basePrice)

		if finalPrice ~= basePrice then
			-- Price changed: apply listing logic to cart
			if finalPrice > basePrice then
				if isSellTab then
					-- SELL TAB: Price increased is GOOD for player - show in green with +%
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
					-- BUY TAB: Price increased is BAD for player - show in neutral color, basePrice grayed below
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
				-- finalPrice < basePrice
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
					-- BUY TAB: Price decreased is GOOD for player - show in green with -%
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
			-- No difference: show final price in neutral color at X=280
			-- If price is approximate, dim it (0.7, 0.7, 0.7 instead of neutralColor)
			local priceColor = item.priceIsApproximate and 0.7 or neutralColor.r
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
	if not ShopUI.instance then
		return
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
	---@diagnostic disable-next-line: unnecessary-if
	if PreviewUI.instance then
		PreviewUI.instance:close()
	end
end

function ShopUI:onMouseDownCartItem(x, y)
	ISScrollingListBox.onMouseDown(self, x, y)
	---@diagnostic disable-next-line: unnecessary-if
	if PreviewUI.instance then
		PreviewUI.instance:close()
	end
	---@diagnostic disable-next-line: unnecessary-if
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
			self:removeFromCart(self.selectedRow)
		end
	end
end

local invTooltip = nil

function ShopUI:toggleTooltip(show, item)
	---@diagnostic disable-next-line: unnecessary-if
	-- Tooltips disabled - use View UI instead for bundle contents
	if invTooltip then
		invTooltip:setVisible(false)
	end
end

function ShopUI:onMouseMoveCartItem(dx, dy)
	local list = self.cartItems
	if not list then
		return
	end
	list.selectedRow = nil
	list.previewBtn = nil
	list.removeBtn = nil
	if list:isMouseOverScrollBar() or not list:isMouseOver() then
		self:toggleTooltip(false)
		return
	end
	local rowIndex = list:rowAt(list:getMouseX(), list:getMouseY())
	if not rowIndex then
		self:toggleTooltip(false)
		return
	end
	local selectedRow = list.items[rowIndex]
	if not selectedRow then
		self:toggleTooltip(false)
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
		self:toggleTooltip(false)
		return
	end
	self:toggleTooltip(true, selectedRow.item)
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
	if not character then
		return
	end
	if not character:getModData().shopFavorites then
		character:getModData().shopFavorites = {}
	end
	if not self.panel or not self.panel.activeView then
		return
	end
	local tab = self.panel.activeView.view
	if not tab then
		return
	end
	local tabType = tab.tabType
	local shopItems = tab.shopItems
	if not shopItems then
		return
	end

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
			local playerSell = Shop.PlayerSell or {}
			local itemSell = playerSell[itemType]
			local isBroken = item:isBroken()
			-- WIP: Item filtering for Sell tab (conditions, drainage, item state refinements needed)
			if not (item:isEquipped() or item:isFavorite() or Currency.Coins[itemType]) then
				local canSell = false

				---@diagnostic disable-next-line: unnecessary-if
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
					---@diagnostic disable-next-line: unnecessary-if
					if itemSell then
						v.specialCoin = itemSell.specialCoin
						if isBroken then
							price = itemSell.priceBroken or Shop.defaultPriceBroken
						else
							price = itemSell.price or Shop.defaultPrice
						end
					end
					v.priceFull = price
					-- WIP: Drainable price adjustment for containers (may need refinement)
					price = Nfunction.drainablePrice(item, price)
					-- Store base price for discount display
					v.basePrice = price
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
			---@diagnostic disable-next-line: unnecessary-if
			if shopItemDef then
				local context = {
					shopId = self.shop and self.shop:getName() or "Unknown",
					quantity = 1,
					isSpecialCoin = shopItemDef.specialCoin or false,
					isBroken = false,
				}
				-- Always reset basePrice to the original shop item price
				-- This prevents stale cached prices from being used as basePrice
				v.basePrice = shopItemDef.price
				-- Use shared calculator for preview price
				local calculatedPrice = calcBuyPrice(k, character, shopItemDef.price)
				-- Fall back to old method if calculator unavailable
				local dynamicPrice = calculatedPrice or Shop.resolvePlayerBuyPrice(character, k, context)
				v.price = dynamicPrice or shopItemDef.price
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
				-- Get the original registration price from Shop.Items (never modified by price hooks)
				local originalPrice = Shop.Items[k] and Shop.Items[k].price or v.price
				-- Always use the original registration price as basePrice
				-- This prevents stale cached prices or price overrides from being misused as basePrice
				v.basePrice = originalPrice
				-- Use server-authoritative price first (with price hooks applied)
				local serverPrice = Shop.CalculatedPrices
					and Shop.CalculatedPrices.buyPrices
					and Shop.CalculatedPrices.buyPrices[k]
				---@diagnostic disable-next-line: unnecessary-if
				if serverPrice then
					-- Handle both table format (price + basePrice) and scalar format for backward compatibility
					if type(serverPrice) == "table" then
						v.price = serverPrice.price
						if serverPrice.basePrice then
							v.basePrice = serverPrice.basePrice
						end
					else
						v.price = serverPrice
					end
				else
					-- Fall back to preview calculator if no server price yet
					local calculatedPrice = calcBuyPrice(k, character, v.basePrice)
					local dynamicPrice = calculatedPrice or Shop.resolvePlayerBuyPrice(character, k, context)
					v.price = dynamicPrice or v.basePrice
				end
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

	---@diagnostic disable-next-line: unnecessary-if
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
	---@diagnostic disable-next-line: unnecessary-if
	if self.actionInProgress then
		return
	end
	self:toggleTooltip(false)
	local selectedRow = self.cartItems.items[selectedRowIndex]
	if not selectedRow then
		return
	end

	if not self.panel or not self.panel.activeView then
		return
	end
	local tab = self.panel.activeView.view
	if not tab then
		return
	end
	local tabType = tab.tabType
	if tabType == Tab.Sell then
		tab.shopItems:addItem(selectedRow.item.type, selectedRow.item)
	end
	self.cartItems:removeItemByIndex(selectedRowIndex)
end

function ShopUI:clearCartBtn()
	---@diagnostic disable-next-line: unnecessary-if
	if self.actionInProgress then
		return
	end
	if not self.panel or not self.panel.activeView then
		return
	end
	local tab = self.panel.activeView.view
	if not tab then
		return
	end
	local tabType = tab.tabType
	if tabType == Tab.Sell then
		for k, v in pairs(self.cartItems.items) do
			tab.shopItems:addItem(v.item.type, v.item)
		end
	end
	self.cartItems:clear()
end

function ShopUI:cancelBuyBtn()
	-- OK SAFE: Use ISTimedActionQueue.clear() - the only correct way to cancel from UI
	ISTimedActionQueue.clear(self.player)

	-- Reset action in progress flag and UI state
	self.actionInProgress = false
	self._wasShopActionRunning = false

	-- Restore cart and button visibility
	if not self.panel or not self.panel.activeView or not self.panel.activeView.view then
		return
	end
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
			if item.items and type(item.items) == "table" then
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

	-- Phase 2.3: Record transaction for price validation (lazy-load to avoid circular deps)
	if not self._transactionValidationLoaded then
		self._transactionValidationLoaded = true
		require("nshopsb42/transactions/TransactionValidationClient")
	end
	local TransactionValidationClient = SHOPSB42.TransactionValidationClient
	---@diagnostic disable-next-line: unnecessary-if
	if TransactionValidationClient then
		TransactionValidationClient.recordTransaction(ticket.txnId, self.cartItems, self._lastPreviewPrices)
		SharedLogger.log("Shops", "[ShopUI:buyCartBtn] Recorded transaction for validation - txnId=" .. ticket.txnId)
	end

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
	local currentAction = actionQueue.current -- OK CRITICAL: Use queue.current, not queue[1]

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
			---@diagnostic disable-next-line: unnecessary-if
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

	if not self.panel or not self.panel.activeView or not self.panel.activeView.view then
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
	---@diagnostic disable-next-line: unnecessary-if
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

	---@diagnostic disable-next-line: unnecessary-if
	if PreviewUI.instance then
		PreviewUI.instance:close()
	end
	---@diagnostic disable-next-line: unnecessary-if
	if ContainerViewerUI.instance then
		ContainerViewerUI.instance:close()
	end
	---@diagnostic disable-next-line: unnecessary-if
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
	---@diagnostic disable-next-line: unnecessary-if
	if self.buyCartButton then
		self.buyCartButton.enable = enabled
	end
	if self.sellCartButton then
		self.sellCartButton.enable = enabled
	end
	---@diagnostic disable-next-line: unnecessary-if
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
			-- Phase 4 Fix: Handle both table and scalar formats (backward compatibility)
			local priceData = calc.buyPrices[row.type]
			price = type(priceData) == "table" and priceData.price or priceData
			-- Phase 4 Fix: Extract basePrice from priceData if available
			if type(priceData) == "table" and priceData.basePrice then
				row.basePrice = priceData.basePrice
			end
			row.priceIsApproximate = false
		else
			---@diagnostic disable-next-line: unnecessary-if
			-- Phase 3: Use ClientShopListingService for deterministic preview (ZERO NETWORK)
			if ClientShopListingService and ClientShopListingService.calculatePreviewBuyPrice then
				price = ClientShopListingService.calculatePreviewBuyPrice(
					row.type,
					"npc_general_store",
					row.basePrice,
					player
				)
			else
				price = row.basePrice
			end
			row.priceIsApproximate = true
		end
	elseif row.item and row.item.invItem then
		---@diagnostic disable-next-line: unnecessary-if
		-- Sell tab: calculate sell price for inventory item (Phase 3: use ClientShopListingService)
		if ClientShopListingService and ClientShopListingService.calculatePreviewSellPrice then
			local itemCondition = row.item.invItem:getCondition()
			price = ClientShopListingService.calculatePreviewSellPrice(
				row.item.invItem:getFullType(),
				"npc_general_store",
				row.basePrice,
				itemCondition,
				player
			)
		else
			price = row.basePrice
		end
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

-- Clear cart when prices change (Phase 3.8)
-- Users must re-add items after price changes to ensure they see current prices
function ShopUI:clearCartOnPriceChange()
	if not self.cartItems then
		return
	end

	self.cartItems:clear()
	self:updateTotal()
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

-- Phase 2.3: Validate transaction price (mismatch handler)
-- Called when balance update arrives after a transaction
-- Returns (isValid, errorMessage)
function ShopUI.validateTransactionPrice(itemId, clientPrice, serverPrice, tolerance)
	tolerance = tolerance or 1 -- Default: ±1 coin

	if not clientPrice or not serverPrice then
		return false, "missing_price"
	end

	local diff = math.abs(clientPrice - serverPrice)
	if diff > tolerance then
		SharedLogger.log(
			"Shops",
			"[ShopUI:validateTransactionPrice] Price mismatch: "
				.. tostring(itemId)
				.. " client="
				.. tostring(clientPrice)
				.. " server="
				.. tostring(serverPrice)
				.. " diff="
				.. tostring(diff)
		)
		return false, "mismatch"
	end

	return true, nil
end

-- Phase 2.3: Instance method to validate transaction price
function ShopUI:validateTransactionPriceInstance(itemId, clientPrice, serverPrice, tolerance)
	return ShopUI.validateTransactionPrice(itemId, clientPrice, serverPrice, tolerance)
end

-- Phase 2.3: Store preview price for an item (called when item is added to cart)
function ShopUI:storePreviewPrice(itemId, price)
	if not self._lastPreviewPrices then
		self._lastPreviewPrices = {}
	end
	self._lastPreviewPrices[itemId] = price
end

-- Phase 2.3: Retrieve stored preview price
function ShopUI:getStoredPreviewPrice(itemId)
	if not self._lastPreviewPrices then
		return nil
	end
	return self._lastPreviewPrices[itemId]
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

	-- Phase 2.3: Initialize preview price tracking
	o._lastPreviewPrices = {}

	return o
end
