-- Project Zomboid Custom UI - Design Patterns & Examples
-- This file shows common patterns for creating different types of UIs

require "ISUI/ISWindow"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISTextEntryBox"
require "ISUI/ISScrollingListBox"
require "ISUI/ISTabPanel"


-- ==============================================================
-- PATTERN 1: Simple Alert Dialog
-- ==============================================================
SimpleAlertDialog = ISWindow:derive("SimpleAlertDialog")

function SimpleAlertDialog:initialise()
    ISWindow.initialise(self)
    
    -- Message label
    self.messageLabel = ISLabel:new(
        10, 30, 100,
        "Are you sure?",
        1, 1, 1, 1,
        UIFont.Medium
    )
    self.messageLabel:initialise()
    self:addChild(self.messageLabel)
    
    -- Yes button
    self.yesBtn = ISButton:new(10, 80, 80, 20, "Yes", self, SimpleAlertDialog.onYes)
    self.yesBtn:initialise()
    self.yesBtn:enableAcceptColor()
    self:addChild(self.yesBtn)
    
    -- No button
    self.noBtn = ISButton:new(100, 80, 80, 20, "No", self, SimpleAlertDialog.onNo)
    self.noBtn:initialise()
    self.noBtn:enableCancelColor()
    self:addChild(self.noBtn)
end

function SimpleAlertDialog:onYes(button)
    print("User clicked Yes")
    self:setVisible(false)
    self:removeFromUIManager()
end

function SimpleAlertDialog:onNo(button)
    print("User clicked No")
    self:setVisible(false)
    self:removeFromUIManager()
end

function SimpleAlertDialog:new(x, y, message)
    local o = ISWindow:new("Confirmation", x, y, 200, 120)
    setmetatable(o, self)
    self.__index = self
    o.message = message
    return o
end


-- ==============================================================
-- PATTERN 2: Form with Input Validation
-- ==============================================================
FormWindow = ISWindow:derive("FormWindow")

function FormWindow:initialise()
    ISWindow.initialise(self)
    self.minimumWidth = 300
    self.minimumHeight = 250
    
    -- Field 1
    local label1 = ISLabel:new(10, 30, 20, "Username:", 1, 1, 1, 1, UIFont.Small, true)
    label1:initialise()
    self:addChild(label1)
    
    self.usernameField = ISTextEntryBox:new("", 100, 30, 150, 20)
    self.usernameField:initialise()
    self:addChild(self.usernameField)
    
    -- Field 2
    local label2 = ISLabel:new(10, 60, 20, "Password:", 1, 1, 1, 1, UIFont.Small, true)
    label2:initialise()
    self:addChild(label2)
    
    self.passwordField = ISTextEntryBox:new("", 100, 60, 150, 20)
    self.passwordField:initialise()
    self:addChild(self.passwordField)
    
    -- Error message label
    self.errorLabel = ISLabel:new(10, 90, 20, "", 1, 0, 0, 1, UIFont.Small)
    self.errorLabel:initialise()
    self:addChild(self.errorLabel)
    
    -- Buttons
    self.submitBtn = ISButton:new(100, 200, 80, 20, "Submit", self, FormWindow.onSubmit)
    self.submitBtn:initialise()
    self.submitBtn:enableAcceptColor()
    self:addChild(self.submitBtn)
    
    self.resetBtn = ISButton:new(190, 200, 80, 20, "Reset", self, FormWindow.onReset)
    self.resetBtn:initialise()
    self.resetBtn:enableCancelColor()
    self:addChild(self.resetBtn)
end

function FormWindow:validateForm()
    local username = self.usernameField:getText()
    local password = self.passwordField:getText()
    
    if username == "" then
        self.errorLabel:setName("Username required")
        return false
    end
    
    if password == "" then
        self.errorLabel:setName("Password required")
        return false
    end
    
    if string.len(username) < 3 then
        self.errorLabel:setName("Username too short")
        return false
    end
    
    self.errorLabel:setName("")
    return true
end

function FormWindow:onSubmit(button)
    if self:validateForm() then
        print("Form valid! Username: " .. self:usernameField:getText())
        self:setVisible(false)
        self:removeFromUIManager()
    end
end

function FormWindow:onReset(button)
    self.usernameField:setText("")
    self.passwordField:setText("")
    self.errorLabel:setName("")
end

function FormWindow:new(x, y)
    local o = ISWindow:new("Login Form", x, y, 300, 250)
    setmetatable(o, self)
    self.__index = self
    return o
end


-- ==============================================================
-- PATTERN 3: Data Table / List Viewer
-- ==============================================================
DataTableWindow = ISWindow:derive("DataTableWindow")

function DataTableWindow:initialise()
    ISWindow.initialise(self)
    self.minimumWidth = 400
    self.minimumHeight = 300
    
    -- Search bar
    self.searchField = ISTextEntryBox:new("", 10, 30, 200, 20)
    self.searchField:initialise()
    self:addChild(self.searchField)
    
    self.searchBtn = ISButton:new(220, 30, 60, 20, "Search", self, DataTableWindow.onSearch)
    self.searchBtn:initialise()
    self:addChild(self.searchBtn)
    
    -- Data list
    self.dataList = ISScrollingListBox:new(10, 60, self:getWidth() - 20, 150)
    self.dataList:initialise()
    self.dataList:instantiate()
    self:addChild(self.dataList)
    
    -- Details panel
    self.detailPanel = ISPanel:new(10, 220, self:getWidth() - 20, 60)
    self.detailPanel:initialise()
    self.detailPanel:instantiate()
    self.detailPanel.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.8}
    self:addChild(self.detailPanel)
    
    self.detailLabel = ISLabel:new(10, 10, 20, "Select an item to view details", 0.8, 0.8, 0.8, 1, UIFont.Small)
    self.detailLabel:initialise()
    self.detailPanel:addChild(self.detailLabel)
end

function DataTableWindow:loadData(items)
    self.dataList:clear()
    for i, item in ipairs(items) do
        self.dataList:addItem(item.name, item)
    end
end

function DataTableWindow:onSearch(button)
    local query = self.searchField:getText()
    print("Searching for: " .. query)
    -- Implement search logic here
end

function DataTableWindow:update()
    ISWindow.update(self)
    
    -- Update details when selection changes
    local selected = self.dataList:getSelectedItem()
    if selected then
        self.detailLabel:setName("Selected: " .. selected.item.name)
    end
end

function DataTableWindow:new(x, y)
    local o = ISWindow:new("Data Viewer", x, y, 400, 350)
    setmetatable(o, self)
    self.__index = self
    return o
end


-- ==============================================================
-- PATTERN 4: Status Monitor / Dashboard
-- ==============================================================
DashboardWindow = ISWindow:derive("DashboardWindow")

function DashboardWindow:initialise()
    ISWindow.initialise(self)
    self.minimumWidth = 400
    self.minimumHeight = 300
    
    -- Stats
    self.healthLabel = ISLabel:new(10, 30, 20, "Health: 100/100", 0, 1, 0, 1, UIFont.Small)
    self.healthLabel:initialise()
    self:addChild(self.healthLabel)
    
    self.hungerLabel = ISLabel:new(10, 50, 20, "Hunger: 50/100", 1, 1, 0, 1, UIFont.Small)
    self.hungerLabel:initialise()
    self:addChild(self.hungerLabel)
    
    self.thirstLabel = ISLabel:new(10, 70, 20, "Thirst: 25/100", 0, 1, 1, 1, UIFont.Small)
    self.thirstLabel:initialise()
    self:addChild(self.thirstLabel)
    
    -- Progress bars
    self.healthBar = ISPanel:new(150, 30, 100, 15)
    self.healthBar:initialise()
    self:addChild(self.healthBar)
    
    self.hungerBar = ISPanel:new(150, 50, 100, 15)
    self.hungerBar:initialise()
    self:addChild(self.hungerBar)
    
    self.thirstBar = ISPanel:new(150, 70, 100, 15)
    self.thirstBar:initialise()
    self:addChild(self.thirstBar)
    
    -- Update timer
    self.updateTimer = 0
end

function DashboardWindow:prerender()
    ISWindow.prerender(self)
    
    -- Draw progress bars
    self:drawProgressBar(150, 30, 100, 15, 1.0, {r=0, g=1, b=0, a=1})  -- Health
    self:drawProgressBar(150, 50, 100, 15, 0.5, {r=1, g=1, b=0, a=1})  -- Hunger
    self:drawProgressBar(150, 70, 100, 15, 0.25, {r=0, g=1, b=1, a=1}) -- Thirst
end

function DashboardWindow:update()
    ISWindow.update(self)
    
    self.updateTimer = self.updateTimer + 1
    if self.updateTimer > 30 then  -- Update every 30 frames
        self.updateTimer = 0
        -- Refresh data here
    end
end

function DashboardWindow:new(x, y)
    local o = ISWindow:new("Dashboard", x, y, 400, 300)
    setmetatable(o, self)
    self.__index = self
    o.updateTimer = 0
    return o
end


-- ==============================================================
-- PATTERN 5: Tabbed Interface
-- ==============================================================
TabbedWindow = ISWindow:derive("TabbedWindow")

function TabbedWindow:initialise()
    ISWindow.initialise(self)
    self.minimumWidth = 400
    self.minimumHeight = 300
    
    -- Create tab panel
    self.tabPanel = ISTabPanel:new(10, 30, self:getWidth() - 20, self:getHeight() - 60)
    self.tabPanel:initialise()
    self.tabPanel:instantiate()
    self:addChild(self.tabPanel)
    
    -- Tab 1
    self.tab1 = ISPanel:new(0, 0, self.tabPanel:getWidth(), self.tabPanel:getHeight())
    self.tab1:initialise()
    
    local label1 = ISLabel:new(10, 10, 20, "Tab 1 Content", 1, 1, 1, 1, UIFont.Medium)
    label1:initialise()
    self.tab1:addChild(label1)
    
    self.tabPanel:addTab("Tab 1", self.tab1)
    
    -- Tab 2
    self.tab2 = ISPanel:new(0, 0, self.tabPanel:getWidth(), self.tabPanel:getHeight())
    self.tab2:initialise()
    
    local label2 = ISLabel:new(10, 10, 20, "Tab 2 Content", 1, 1, 1, 1, UIFont.Medium)
    label2:initialise()
    self.tab2:addChild(label2)
    
    self.tabPanel:addTab("Tab 2", self.tab2)
    
    -- Close button
    self.closeBtn = ISButton:new(
        self:getWidth() - 100, self:getHeight() - 25, 90, 20,
        "Close", self, TabbedWindow.onClose
    )
    self.closeBtn:initialise()
    self:addChild(self.closeBtn)
end

function TabbedWindow:onClose(button)
    self:setVisible(false)
    self:removeFromUIManager()
end

function TabbedWindow:new(x, y)
    local o = ISWindow:new("Tabbed Window", x, y, 400, 350)
    setmetatable(o, self)
    self.__index = self
    return o
end


-- ==============================================================
-- PATTERN 6: Modal Popup (Always on Top)
-- ==============================================================
ModalPopup = ISWindow:derive("ModalPopup")

function ModalPopup:initialise()
    ISWindow.initialise(self)
    
    self.messageLabel = ISLabel:new(
        10, 30, 80,
        "Please wait...",
        1, 1, 1, 1,
        UIFont.Medium
    )
    self.messageLabel:initialise()
    self:addChild(self.messageLabel)
end

function ModalPopup:new(x, y, message)
    local o = ISWindow:new("Loading", x, y, 250, 100)
    setmetatable(o, self)
    self.__index = self
    o.message = message
    return o
end

function OpenModalPopup(message)
    local win = ModalPopup:new(
        getCore():getScreenWidth()/2 - 125,
        getCore():getScreenHeight()/2 - 50,
        message
    )
    win:initialise()
    win:instantiate()
    win.messageLabel:setName(message)
    win:addToUIManager()
    win:setAlwaysOnTop(true)  -- Keep on top
    return win
end


-- ==============================================================
-- PATTERN 7: Context Menu Alternative (Custom Right-Click)
-- ==============================================================
CustomContextMenu = ISWindow:derive("CustomContextMenu")

function CustomContextMenu:initialise()
    ISWindow.initialise(self)
    
    self.options = {}
    self.buttons = {}
    self.selectedIndex = 0
end

function CustomContextMenu:addOption(text, callback)
    table.insert(self.options, {text=text, callback=callback})
    
    local y = 30 + (30 * (#self.options - 1))
    local btn = ISButton:new(10, y, 150, 25, text, self, CustomContextMenu.onOptionClick)
    btn:initialise()
    btn.optionIndex = #self.options
    self:addChild(btn)
    
    table.insert(self.buttons, btn)
end

function CustomContextMenu:onOptionClick(button)
    local option = self.options[button.optionIndex]
    if option and option.callback then
        option.callback()
    end
    self:setVisible(false)
    self:removeFromUIManager()
end

function CustomContextMenu:new(x, y)
    local o = ISWindow:new("Menu", x, y, 170, 30)
    setmetatable(o, self)
    self.__index = self
    return o
end


-- ==============================================================
-- PATTERN 8: Floating Tooltip / Info Box
-- ==============================================================
FloatingInfo = ISPanel:derive("FloatingInfo")

function FloatingInfo:initialise()
    ISPanel.initialise(self)
    self.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.9}
    self.borderColor = {r=0.5, g=0.5, b=0.5, a=1}
    
    self.textLabel = ISLabel:new(5, 5, 20, "Info", 0.8, 0.8, 0.8, 1, UIFont.Small)
    self.textLabel:initialise()
    self:addChild(self.textLabel)
    
    self.fadeTimer = 0
end

function FloatingInfo:update()
    ISPanel.update(self)
    
    self.fadeTimer = self.fadeTimer + 1
    if self.fadeTimer > 300 then  -- Fade after 5 seconds
        self.backgroundColor.a = math.max(0, self.backgroundColor.a - 0.02)
        if self.backgroundColor.a <= 0 then
            self:setVisible(false)
            self:removeFromUIManager()
        end
    end
end

function FloatingInfo:new(x, y, text, width)
    width = width or 150
    local height = 40
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.text = text
    return o
end


-- ==============================================================
-- USAGE EXAMPLES
-- ==============================================================

function ExampleUsagePatterns()
    -- Pattern 1: Simple Alert
    local alert = SimpleAlertDialog:new(100, 100)
    alert:initialise()
    alert:instantiate()
    alert:addToUIManager()
    
    -- Pattern 3: Data Table
    local table = DataTableWindow:new(150, 150)
    table:initialise()
    table:instantiate()
    table:loadData({
        {name="Item 1"},
        {name="Item 2"},
        {name="Item 3"}
    })
    table:addToUIManager()
    
    -- Pattern 5: Tabbed
    local tabbed = TabbedWindow:new(200, 200)
    tabbed:initialise()
    tabbed:instantiate()
    tabbed:addToUIManager()
    
    -- Pattern 8: Floating Info
    local info = FloatingInfo:new(400, 100, "This is info text", 200)
    info:initialise()
    info:instantiate()
    info:addToUIManager()
end

print("=== UI Patterns Loaded ===")
