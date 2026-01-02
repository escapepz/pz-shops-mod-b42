-- SendTransferAction is already loaded by shared/nshopsb42/Init.lua, no need to require again

SHOPSB42.TransferUI = ISCollapsableWindow:derive("TransferUI")
local TransferUI = SHOPSB42.TransferUI
local Currency = SHOPSB42.Currency
local Balance = SHOPSB42.Balance
local UIText = SHOPSB42.UIText
local SendTransferAction = SHOPSB42.SendTransferAction
TransferUI.instance = nil
TransferUI.SMALL_FONT_HGT = getTextManager():getFontFromEnum(UIFont.Small):getLineHeight()
TransferUI.MEDIUM_FONT_HGT = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight()
TransferUI.removeButtonX = 300
TransferUI.transferInProgress = false
TransferUI.accountsCache = {}
TransferUI.TRANSFER_STATE_IDLE = "idle"
TransferUI.TRANSFER_STATE_PENDING = "pending"
TransferUI.TRANSFER_STATE_CONFIRMED = "confirmed"
TransferUI.TRANSFER_STATE_REJECTED = "rejected"
TransferUI.TRANSFER_STATE_CANCELLED = "cancelled"
TransferUI.rejectionTimeout = 5000 -- milliseconds
TransferUI.COOLDOWN_MS = 1500 -- client-side UI cooldown (mirrors server minIntervalMs)
TransferUI._wasTransferActionRunning = false -- State latch for race condition prevention

local width = 280
local height = 300

function TransferUI:show(player)
	if TransferUI.instance == nil then
		TransferUI.instance = TransferUI:new(0, 0, width, height, player)
		TransferUI.instance:initialise()
		TransferUI.instance:instantiate()
	end
	TransferUI.instance.pinButton:setVisible(false)
	TransferUI.instance.collapseButton:setVisible(false)
	TransferUI.instance:addToUIManager()
	TransferUI.instance:setVisible(true)
	return TransferUI.instance
end

function TransferUI:update()
	local username = self.player:getUsername()
	local coin, specialCoin = Balance.getUserBalance(username)
	local coinFormatted = Currency.format(coin)
	self.balanceCoinLabel:setName("" .. coinFormatted)
	local specialCoinFormatted = Currency.format(specialCoin)
	self.balanceSpecialCoinLabel:setName("" .. specialCoinFormatted)

	-- Check for rejection timeout (server didn't confirm within timeout window)
	if self.state == self.TRANSFER_STATE_PENDING and self.pendingTransferTime then
		local elapsed = getTimestampMs() - self.pendingTransferTime
		if elapsed > self.rejectionTimeout then
			self:onRejectionTimeout()
		end
	end

	-- Don't allow UI changes while transfer in progress
	if self.transferInProgress then
		return
	end

	local transferCoin = tonumber(self.transferCoin:getInternalText())
	if transferCoin == nil then
		transferCoin = 0
	end
	local transferSpecialCoin = tonumber(self.transferSpecialCoin:getInternalText())
	if transferSpecialCoin == nil then
		transferSpecialCoin = 0
	end

	-- Check cooldown (non-authoritative, UX only)
	local now = getTimestampMs()
	local inCooldown = self.cooldownUntil and (now < self.cooldownUntil)

	if
		(transferCoin <= 0 and transferSpecialCoin <= 0)
		or not self.recipient
		or (transferCoin > coin or transferSpecialCoin > specialCoin)
		or inCooldown
	then
		self.sendButton.enable = false
		self.sendButton:setVisible(true)
		self.cancelButton.enable = false
		self.cancelButton:setVisible(false)
		return
	end
	if coin >= transferCoin and specialCoin >= transferSpecialCoin and self.recipient then
		self.sendButton.enable = true
		self.sendButton:setVisible(true)
		self.cancelButton.enable = false
		self.cancelButton:setVisible(false)
	end
end

function TransferUI:onMouseDownAccountItem(x, y)
	ISScrollingListBox.onMouseDown(self, x, y)
	if not self.selected then
		return
	end
	local selectedRow = self.items[self.selected]
	if selectedRow then
		local accountName = selectedRow.text
		TransferUI.recipient = accountName
		TransferUI.instance.toLabel:setName(UIText.TransferTo .. ": " .. accountName)
	end
end

function TransferUI:filter()
	local filterText = string.trim(self.filterEntry:getInternalText())
	self.accountItems.items = self.accountsCache
	filterText = string.lower(filterText)
	local accountItems = self.accountItems.items
	self.accountItems:clear()
	for k, v in ipairs(accountItems) do
		if string.contains(string.lower(v.text), filterText) then
			self.accountItems:addItem(v.text)
		end
	end
end

function TransferUI:onFilterChange()
	TransferUI.instance:filter()
end

local function twoDecimal(self)
	local quantity = self:getInternalText()
	local isNumber = tonumber(quantity)
	if not isNumber then
		return
	end
	local curPos = self:getCursorPos()
	if string.find(quantity, "%.") then
		self:setText(string.format("%.02f", quantity))
		self:setCursorPos(curPos)
	end
end

function TransferUI:onCoinChange()
	twoDecimal(self)
end

function TransferUI:onSpecialCoinChange()
	twoDecimal(self)
end

function TransferUI:createChildren()
	ISCollapsableWindow.createChildren(self)
	local x = 40
	local y = 85

	self.balanceLabel = ISLabel:new(x, 20, self.SMALL_FONT_HGT, UIText.Balance, 1, 1, 1, 1, UIFont.Medium, true)
	self:addChild(self.balanceLabel)

	local coinImg = Currency.CoinsTexture.Coin
	self.balanceCoinTex = ISImage:new(x + 60, 20, 0, 0, coinImg.texture)
	self.balanceCoinTex.scaledWidth = coinImg.scale + 5
	self.balanceCoinTex.scaledHeight = coinImg.scale + 5
	self:addChild(self.balanceCoinTex)

	self.balanceCoinLabel = ISLabel:new(x + 85, 20, self.SMALL_FONT_HGT, "0", 1, 1, 1, 1, UIFont.Medium, true)
	self:addChild(self.balanceCoinLabel)

	self.transferCoinTex = ISImage:new(x, 240, 0, 0, coinImg.texture)
	self.transferCoinTex.scaledWidth = coinImg.scale + 5
	self.transferCoinTex.scaledHeight = coinImg.scale + 5
	self:addChild(self.transferCoinTex)

	self.transferCoin = ISTextEntryBox:new("0", x + 30, 238, 100, 20)
	self.transferCoin.font = UIFont.Medium
	self.transferCoin:initialise()
	self.transferCoin:instantiate()
	self.transferCoin:setOnlyNumbers(true)
	self.transferCoin.onTextChange = TransferUI.onCoinChange
	self:addChild(self.transferCoin)

	coinImg = Currency.CoinsTexture.SpecialCoin
	self.balanceSpecialCoinTex = ISImage:new(x + 60, 45, 0, 0, coinImg.texture)
	self.balanceSpecialCoinTex.scaledWidth = coinImg.scale + 5
	self.balanceSpecialCoinTex.scaledHeight = coinImg.scale + 5
	self:addChild(self.balanceSpecialCoinTex)

	self.balanceSpecialCoinLabel = ISLabel:new(x + 85, 45, self.SMALL_FONT_HGT, "0", 1, 1, 1, 1, UIFont.Medium, true)
	self:addChild(self.balanceSpecialCoinLabel)

	self.transferSpecialCoinTex = ISImage:new(x, 270, 0, 0, coinImg.texture)
	self.transferSpecialCoinTex.scaledWidth = coinImg.scale + 5
	self.transferSpecialCoinTex.scaledHeight = coinImg.scale + 5
	self:addChild(self.transferSpecialCoinTex)

	self.transferSpecialCoin = ISTextEntryBox:new("0", x + 30, 268, 100, 20)
	self.transferSpecialCoin.font = UIFont.Medium
	self.transferSpecialCoin:initialise()
	self.transferSpecialCoin:instantiate()
	self.transferSpecialCoin.onTextChange = TransferUI.onSpecialCoinChange
	self.transferSpecialCoin:setOnlyNumbers(true)
	self:addChild(self.transferSpecialCoin)

	self.filterLabel = ISLabel:new(x, y + 3, 1, UIText.Search, 1, 1, 1, 1, UIFont.Small, true)
	self:addChild(self.filterLabel)

	self.filterEntry = ISTextEntryBox:new("", x + 40, y - 8, 150, 1)
	self.filterEntry.font = UIFont.Medium
	self.filterEntry:initialise()
	self.filterEntry:instantiate()
	self.filterEntry:setText("")
	self.filterEntry:setClearButton(true)
	self.filterEntry.onTextChange = TransferUI.onFilterChange
	self:addChild(self.filterEntry)
	self.lastText = self.filterEntry:getInternalText()

	self.accountItems = ISScrollingListBox:new(x, y + 20, 200, 100)
	self.accountItems:initialise()
	self.accountItems:instantiate()
	self.accountItems:setAnchorRight(false)
	self.accountItems:setAnchorBottom(true)
	self.accountItems.font = UIFont.NewSmall
	self.accountItems.itemheight = 2 + self.MEDIUM_FONT_HGT + 4
	self.accountItems.selected = 1
	self.accountItems.joypadParent = self
	self.accountItems.drawBorder = false
	self.accountItems.SMALL_FONT_HGT = self.SMALL_FONT_HGT
	self.accountItems.MEDIUM_FONT_HGT = self.MEDIUM_FONT_HGT
	self.accountItems.onMouseDown = TransferUI.onMouseDownAccountItem
	self:addChild(self.accountItems)

	local accounts = Balance.getAccountsList()
	local username = self.player:getUsername()
	for k, v in pairs(accounts) do
		if not (username == v) then
			self.accountItems:addItem(v)
		end
	end
	self.accountsCache = self.accountItems.items

	self.toLabel = ISLabel:new(x, 215, self.SMALL_FONT_HGT, UIText.TransferTo, 1, 1, 1, 1, UIFont.Medium, true)
	self:addChild(self.toLabel)

	self.sendButton = ISButton:new(x + 150, 253, 60, 25, UIText.Send, self, TransferUI.sendBtn)
	self.sendButton:initialise()
	self.sendButton.enable = false
	self:addChild(self.sendButton)

	self.cancelButton = ISButton:new(x + 150, 253, 60, 25, UIText.Cancel, self, TransferUI.cancelBtn)
	self.cancelButton:initialise()
	self.cancelButton.enable = false
	self.cancelButton:setVisible(false)
	self:addChild(self.cancelButton)

	if not Currency.UseSpecialCoin then
		self.balanceSpecialCoinTex:setVisible(false)
		self.balanceSpecialCoinLabel:setVisible(false)
		self.transferSpecialCoin:setVisible(false)
		self.transferSpecialCoinTex:setVisible(false)
	end
end

function TransferUI:clearAfterTransfer()
	TransferUI.recipient = nil
	self.toLabel:setName(UIText.TransferTo)
	self.transferCoin:setText("0")
	self.transferSpecialCoin:setText("0")
end

function TransferUI:onBalanceUpdate(data)
	-- Only reconcile if waiting for confirmation
	if self.state ~= self.TRANSFER_STATE_PENDING then
		return
	end

	local username = self.player:getUsername()
	local account = data[username]
	if not account then
		return
	end

	-- Server accepted and processed transfer
	self.state = self.TRANSFER_STATE_CONFIRMED
	self.transferInProgress = false
	self:clearAfterTransfer()

	self.sendButton.enable = true
	self.sendButton:setVisible(true)
	self.cancelButton.enable = false
	self.cancelButton:setVisible(false)
end

function TransferUI:onRejectionTimeout()
	-- If still pending after timeout, assume server rejected
	if self.state ~= self.TRANSFER_STATE_PENDING then
		return
	end

	self.state = self.TRANSFER_STATE_REJECTED
	self.transferInProgress = false

	self.sendButton.enable = true
	self.sendButton:setVisible(true)
	self.cancelButton.enable = false
	self.cancelButton:setVisible(false)
end

function TransferUI:cancelBtn()
	-- Only allow cancel before server dispatch
	if self.state ~= self.TRANSFER_STATE_PENDING then
		return
	end

	-- ✓ SAFE: Use ISTimedActionQueue.clear() - the only correct way to cancel from UI
	ISTimedActionQueue.clear(self.player)

	self.state = self.TRANSFER_STATE_CANCELLED
	self.transferInProgress = false
	self._wasTransferActionRunning = false
	self.sendButton.enable = true
	self.sendButton:setVisible(true)
	self.cancelButton.enable = false
	self.cancelButton:setVisible(false)
end

function TransferUI:sendBtn()
	self.state = self.TRANSFER_STATE_PENDING
	self.transferInProgress = true
	self.pendingTransferTime = getTimestampMs()
	self.cooldownUntil = self.pendingTransferTime + self.COOLDOWN_MS

	local coin = tonumber(self.transferCoin:getInternalText())
	if coin == nil then
		coin = 0
	end
	local specialCoin = tonumber(self.transferSpecialCoin:getInternalText())
	if specialCoin == nil then
		specialCoin = 0
	end
	local recipient = self.recipient
	coin = math.abs(coin)
	specialCoin = math.abs(specialCoin)

	self.sendButton.enable = false
	self.sendButton:setVisible(false)
	self.cancelButton.enable = true
	self.cancelButton:setVisible(true)

	local action = SendTransferAction:new(self.player, coin, specialCoin, recipient)
	ISTimedActionQueue.add(action)
end

function TransferUI:render()
	ISCollapsableWindow.render(self)
	local actionQueue = ISTimedActionQueue.getTimedActionQueue(self.player)
	local currentAction = actionQueue.current -- ✓ CRITICAL: Use queue.current, not queue[1]

	-- Check if this is a transfer action (using marker field, not class identity)
	local isTransferAction = currentAction and currentAction._shopActionType == "transfer"

	if isTransferAction and currentAction then
		-- Action is running: draw progress
		self._wasTransferActionRunning = true
		self:drawProgressBar(185, 240, 70, 10, currentAction:getJobDelta(), self.fgBar)
	else
		-- Action is not running: finalize UI state once (state latch prevents flickering)
		if self._wasTransferActionRunning then
			self._wasTransferActionRunning = false
			self.transferInProgress = false
		end
	end
end

function TransferUI:close()
	ISCollapsableWindow.close(self)
	-- Reset UI state flags to prevent stale state
	self.transferInProgress = false
	self.state = self.TRANSFER_STATE_IDLE
	self.pendingTransferTime = nil
	self.cooldownUntil = nil

	-- Reset form fields and selection
	TransferUI.recipient = nil
	if self.filterEntry then
		self.filterEntry:setText("")
	end

	TransferUI.instance:removeFromUIManager()
	TransferUI.instance = nil
	self:removeFromUIManager()
end

function TransferUI:new(x, y, width, height, player)
	local o = {}
	if x == 0 and y == 0 then
		x = (getCore():getScreenWidth() / 2) - (width / 2)
		y = (getCore():getScreenHeight() / 2) - (height / 2)
	end
	o = ISCollapsableWindow:new(x, y, width, height)
	setmetatable(o, self)
	o.fgBar = { r = 0, g = 0.6, b = 0, a = 0.7 }
	self.__index = self
	o.title = UIText.TransferUITitle
	o.player = player
	o.recipient = nil
	o.resizable = false
	o.state = self.TRANSFER_STATE_IDLE
	o.pendingTransferTime = nil
	o.cooldownUntil = nil
	return o
end

-- Event listener consolidated into ModDataDispatcherClient
