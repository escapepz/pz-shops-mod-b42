---@diagnostic disable: duplicate-set-field
local fontConfig = {
	Small = { y = 17, iconY = 1 },
	Medium = { y = 20, iconY = 3 },
	Large = { y = 20, iconY = 4 },
}

-- Injects price line into tooltip for shop items
-- Shows: [coin icon] price
local function injectPrice(self, item, isSpecialCoin)
	-- Skip price injection if PlayerShopUI open (prices shown in cart already)
	if SHOPSB42.PlayerShopUI.instance then
		return
	end

	local price = item:getModData().price
	local fontSize = getCore():getOptionTooltipFont()
	local height = fontConfig[fontSize].y
	local x = 15
	local y = -20

	self:setY(self.tooltip:getY() - 25)
	self:setHeight(height)
	-- Draw background box
	self:drawRect(
		0,
		0,
		self.width,
		self.height + 10,
		self.backgroundColor.a,
		self.backgroundColor.r,
		self.backgroundColor.g,
		self.backgroundColor.b
	)
	-- Draw border
	self:drawRectBorder(
		0,
		0,
		self.width,
		self.height + 10,
		self.borderColor.a,
		self.borderColor.r,
		self.borderColor.g,
		self.borderColor.b
	)
	-- Draw coin icon
	local coinImg = SHOPSB42.Currency.CoinsTexture.Coin
	if isSpecialCoin then
		coinImg = SHOPSB42.Currency.CoinsTexture.SpecialCoin
	end
	self.tooltip:DrawTextureScaledAspect(
		coinImg.texture,
		x - 10,
		y + fontConfig[fontSize].iconY,
		coinImg.scale,
		coinImg.scale,
		1,
		1,
		1,
		1
	)
	-- Draw price value
	price = SHOPSB42.Currency.format(price)
	self.tooltip:DrawText(self.tooltip:getFont(), "" .. price, x + 10, y - fontConfig[fontSize].iconY, 1, 1, 1, 1)
	self:setY(self.tooltip:getY())
end

-- Injects wallet/balance section into tooltip
-- Shows: [wallet icon] owner
--        [coin icon] balance
--        [special coin icon] special balance (if enabled)
local function injectWallet(self, item)
	local fontSize = getCore():getOptionTooltipFont()
	local th = self.tooltip:getHeight()
	local belongsTo = item:getModData().belongsTo
	local x = 15
	local y = th + 5

	local player = getPlayer()
	local username = player:getUsername()
	local account = SHOPSB42.Balance.getUserAccount(username)
	if not account then
		return -- Player has no account yet
	end

	local renderBalance = true
	local rows = 3
	if not SHOPSB42.Currency.UseSpecialCoin then
		rows = 2
	end
	-- If wallet linkedTo doesn't match account linkedTo, wallet is "stale" - show owner only, no balance
	if not (account.linkedTo == item:getModData().linkedTo) then
		rows = 1
		renderBalance = false
	end

	local height = fontConfig[fontSize].y * rows

	self:setY(self.tooltip:getY() + th)
	self:setHeight(height)
	-- Draw background box
	self:drawRect(
		0,
		0,
		self.width,
		self.height + 10,
		self.backgroundColor.a,
		self.backgroundColor.r,
		self.backgroundColor.g,
		self.backgroundColor.b
	)
	-- Draw border
	self:drawRectBorder(
		0,
		0,
		self.width,
		self.height + 10,
		self.borderColor.a,
		self.borderColor.r,
		self.borderColor.g,
		self.borderColor.b
	)

	-- Draw wallet icon + owner name
	local wallet = SHOPSB42.Currency.WalletTexture.Account
	self.tooltip:DrawTextureScaledAspect(
		wallet.texture,
		x - 10,
		y + fontConfig[fontSize].iconY,
		wallet.scale,
		wallet.scale,
		1,
		1,
		1,
		1
	)
	self.tooltip:DrawText(self.tooltip:getFont(), belongsTo, x + 10, y, 1, 1, 0.8, self.borderColor.a)

	-- If wallet is stale or not linked to current player, don't show balance
	if not renderBalance then
		return
	end

	-- Draw coin balance
	local coin = account.coin
	y = y + fontConfig[fontSize].y
	local coinImg = SHOPSB42.Currency.CoinsTexture.Coin
	self.tooltip:DrawTextureScaledAspect(
		coinImg.texture,
		x - 10,
		y + fontConfig[fontSize].iconY,
		coinImg.scale,
		coinImg.scale,
		1,
		1,
		1,
		1
	)
	local coinFormatted = SHOPSB42.Currency.format(coin)
	self.tooltip:DrawText(self.tooltip:getFont(), "" .. coinFormatted, x + 10, y, 1, 1, 1, 1)

	-- Draw special coin balance (if enabled)
	y = y + fontConfig[fontSize].y
	coinImg = SHOPSB42.Currency.CoinsTexture.SpecialCoin
	if SHOPSB42.Currency.UseSpecialCoin then
		local specialCoin = account.specialCoin
		local specialCoinFormatted = SHOPSB42.Currency.format(specialCoin)
		self.tooltip:DrawTextureScaledAspect(
			coinImg.texture,
			x - 10,
			y + fontConfig[fontSize].iconY,
			coinImg.scale,
			coinImg.scale,
			1,
			1,
			1,
			1
		)
		self.tooltip:DrawText(self.tooltip:getFont(), "" .. specialCoinFormatted, x + 10, y, 1, 1, 1, 1)
	end
end

-- Main injection coordinator
-- Checks item modData and calls appropriate injection functions
local function injectTooltip(self)
	if not self or not self.item then
		return
	end
	if not self.item.getModData then
		return
	end

	local item = self.item
	local belongsTo = item:getModData().belongsTo
	local price = item:getModData().price
	if not (price or belongsTo) then
		return -- No custom data to inject
	end

	-- Initialize tooltip if not present
	if not self.tooltip then
		return
	end

	local isSpecialCoin = item:getModData().specialCoin

	-- Inject price line if item has price
	if price then
		injectPrice(self, item, isSpecialCoin)
	end

	-- Inject wallet/balance if item is a wallet
	if belongsTo then
		injectWallet(self, item)
	end
end
local oldRender = ISToolTipInv.render

function ISToolTipInv:render()
	-- Do not interfere during context-menu visibility checks
	if ISContextMenu.instance and ISContextMenu.instance.visibleCheck then
		pcall(function()
			oldRender(self)
		end)
		return
	end

	-- Inject custom tooltip content
	injectTooltip(self)

	-- Always call vanilla render (ensures base tooltips show)
	pcall(function()
		oldRender(self)
	end)
end
