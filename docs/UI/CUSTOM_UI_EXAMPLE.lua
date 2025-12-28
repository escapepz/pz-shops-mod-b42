-- Project Zomboid Custom UI Example Mod
-- This file demonstrates creating a complete custom UI window

-- ============================================================
-- STEP 1: Import required base classes
-- ============================================================
require "ISUI/ISWindow"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISTextEntryBox"
require "ISUI/ISPanel"
require "ISUI/ISScrollingListBox"


-- ============================================================
-- STEP 2: Create your custom window class
-- ============================================================
ExampleModWindow = ISWindow:derive("ExampleModWindow")

function ExampleModWindow:initialise()
    ISWindow.initialise(self)
    
    -- Set minimum size to prevent UI breaking
    self.minimumWidth = 400
    self.minimumHeight = 300
    
    -- Create a title label
    self.titleLabel = ISLabel:new(
        10, 10, 20,
        "Example Mod UI",
        1, 1, 1, 1,
        UIFont.Large
    )
    self.titleLabel:initialise()
    self:addChild(self.titleLabel)
    
    -- Create a description label
    self.descLabel = ISLabel:new(
        10, 40, 20,
        "This is a custom UI window created by a mod",
        0.8, 0.8, 0.8, 1,
        UIFont.Small
    )
    self.descLabel:initialise()
    self:addChild(self.descLabel)
    
    -- Create a text input field
    local inputLabel = ISLabel:new(
        10, 70, 20,
        "Enter Text:",
        1, 1, 1, 1,
        UIFont.Small,
        true
    )
    inputLabel:initialise()
    self:addChild(inputLabel)
    
    self.textInput = ISTextEntryBox:new("", 10, 90, 200, 25)
    self.textInput:initialise()
    self.textInput:instantiate()
    self:addChild(self.textInput)
    
    -- Create a list box
    local listLabel = ISLabel:new(
        10, 125, 20,
        "Select an Item:",
        1, 1, 1, 1,
        UIFont.Small,
        true
    )
    listLabel:initialise()
    self:addChild(listLabel)
    
    self.listBox = ISScrollingListBox:new(10, 145, 200, 100)
    self.listBox:initialise()
    self.listBox:instantiate()
    self.listBox:addItem("Item 1", "item1")
    self.listBox:addItem("Item 2", "item2")
    self.listBox:addItem("Item 3", "item3")
    self.listBox:addItem("Item 4", "item4")
    self:addChild(self.listBox)
    
    -- Create buttons
    self.okButton = ISButton:new(
        10, 260, 90, 20,
        "OK",
        self,
        ExampleModWindow.onOKClick
    )
    self.okButton:initialise()
    self.okButton:instantiate()
    self.okButton:enableAcceptColor()
    self:addChild(self.okButton)
    
    self.cancelButton = ISButton:new(
        110, 260, 90, 20,
        "Cancel",
        self,
        ExampleModWindow.onCancelClick
    )
    self.cancelButton:initialise()
    self.cancelButton:instantiate()
    self.cancelButton:enableCancelColor()
    self:addChild(self.cancelButton)
    
    -- Create a display panel for results
    self.resultPanel = ISPanel:new(220, 70, 150, 200)
    self.resultPanel:initialise()
    self.resultPanel:instantiate()
    self.resultPanel.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.8}
    self.resultPanel.borderColor = {r=0.5, g=0.5, b=0.5, a=1}
    self:addChild(self.resultPanel)
    
    self.resultLabel = ISLabel:new(
        10, 10, 20,
        "Results:",
        1, 1, 1, 1,
        UIFont.Small,
        true
    )
    self.resultLabel:initialise()
    self.resultPanel:addChild(self.resultLabel)
end


-- ============================================================
-- STEP 3: Override render() to draw custom content
-- ============================================================
function ExampleModWindow:render()
    ISWindow.render(self)
    
    -- Draw the result panel background
    self:drawRectStatic(220, 70, 150, 200, 0.8, 0.1, 0.1, 0.1)
    self:drawRectBorderStatic(220, 70, 150, 200, 1, 0.5, 0.5, 0.5)
    
    -- Draw some status text
    self:drawText("Status: Ready", 225, 100, 0.7, 1, 0.7, 1, UIFont.Small)
end


-- ============================================================
-- STEP 4: Handle events
-- ============================================================
function ExampleModWindow:onOKClick(button)
    -- Get the text from input
    local inputText = self.textInput:getText()
    
    -- Get selected item from list
    local selectedItem = self.listBox:getSelectedItem()
    local selectedValue = selectedItem and selectedItem.item or "None"
    
    -- Log the result
    print("=== Example Mod Output ===")
    print("Input Text: " .. inputText)
    print("Selected Item: " .. selectedValue)
    print("========================")
    
    -- Close the window
    self:setVisible(false)
    self:removeFromUIManager()
end

function ExampleModWindow:onCancelClick(button)
    self:setVisible(false)
    self:removeFromUIManager()
end

function ExampleModWindow:onMouseDown(x, y)
    ISWindow.onMouseDown(self, x, y)
    return true
end

function ExampleModWindow:onMouseUp(x, y)
    ISWindow.onMouseUp(self, x, y)
    return true
end


-- ============================================================
-- STEP 5: Constructor
-- ============================================================
function ExampleModWindow:new(x, y, width, height)
    local o = ISWindow:new("Example Mod Window", x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end


-- ============================================================
-- STEP 6: Global function to open the window
-- ============================================================
function OpenExampleModWindow()
    -- Check if window already exists
    if ExampleModWindow.instance then
        ExampleModWindow.instance:setVisible(true)
        ExampleModWindow.instance:bringToTop()
        return
    end
    
    -- Create new window
    local window = ExampleModWindow:new(100, 100, 400, 300)
    window:initialise()
    window:instantiate()
    window:addToUIManager()
    window:setVisible(true)
    
    -- Store instance for reuse
    ExampleModWindow.instance = window
end


-- ============================================================
-- STEP 7: Example of how to integrate with game hooks
-- ============================================================

-- Hook to add a context menu option
local function OnRightClickObject()
    -- This would be called on right-click in game
    OpenExampleModWindow()
end

-- Hook to open window with a key press
local function OnKeyPressed(key)
    if key == Keyboard.KEY_U then  -- Press U to open
        OpenExampleModWindow()
    end
end


-- ============================================================
-- ADVANCED EXAMPLE: Creating a dynamic list window
-- ============================================================
DynamicListWindow = ISWindow:derive("DynamicListWindow")

function DynamicListWindow:initialise()
    ISWindow.initialise(self)
    
    self.minimumWidth = 300
    self.minimumHeight = 200
    
    -- Title
    self.title = ISLabel:new(10, 10, 20, "Dynamic List", 1, 1, 1, 1, UIFont.Medium)
    self.title:initialise()
    self:addChild(self.title)
    
    -- Scrollable list
    self.list = ISScrollingListBox:new(10, 40, self:getWidth() - 20, self:getHeight() - 70)
    self.list:initialise()
    self.list:instantiate()
    self:addChild(self.list)
    
    -- Close button
    self.closeBtn = ISButton:new(
        self:getWidth() - 100, self:getHeight() - 25, 90, 20,
        "Close",
        self,
        DynamicListWindow.onClose
    )
    self.closeBtn:initialise()
    self.closeBtn:instantiate()
    self:addChild(self.closeBtn)
end

function DynamicListWindow:addListItem(name, data)
    self.list:addItem(name, data)
end

function DynamicListWindow:onClose(button)
    self:setVisible(false)
    self:removeFromUIManager()
end

function DynamicListWindow:new(x, y, width, height)
    local o = ISWindow:new("Dynamic List", x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

function OpenDynamicListWindow(items)
    local window = DynamicListWindow:new(100, 100, 300, 400)
    window:initialise()
    window:instantiate()
    
    -- Populate list
    if items then
        for i, item in ipairs(items) do
            window:addListItem(item.name, item.data)
        end
    end
    
    window:addToUIManager()
    window:setVisible(true)
    return window
end


-- ============================================================
-- Print message to console when loaded
-- ============================================================
print("=== Example Custom UI Loaded ===")
print("Use: OpenExampleModWindow() to open the window")
print("===================================")
