require "TimedActions/ISBaseTimedAction"

ShopBuyAction = ISBaseTimedAction:derive("ShopBuyAction")
local Nfunction = require "Nfunction"

function ShopBuyAction:isValid()
    local username = self.character:getUsername()
    local coin,specialCoin = Balance.getUserBalance(username)
    local ticket = self.ticket
    return coin >= ticket.coin and specialCoin >= ticket.specialCoin
end

function ShopBuyAction:waitToStart()
    return self.character:shouldBeTurning()
end

function ShopBuyAction:update()
    if not self.shopUI:getIsVisible() then 
        self:forceStop()
    end
end

function ShopBuyAction:start()
end

function ShopBuyAction:stop()
    ISBaseTimedAction.stop(self)
end

function ShopBuyAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 50
end

function ShopBuyAction:perform()
    self.character:playSound("CashRegister")
    ISBaseTimedAction.perform(self)
end

function ShopBuyAction:complete()
    local cartItems = self.shopUI.cartItems.items
    local playerInv = self.character:getInventory()
    for k,v in pairs(cartItems) do
        local item = v.item
        local packItems = item.items
        if packItems then
            local drop = item.drop
            local square = self.character:getSquare()
            for k,v in pairs(packItems) do
                if drop then
                    if v.quantity then
                        for i = 1,v.quantity,1 do
                            local newItem = instanceItem(v.item)
                            square:AddTileObject(newItem)
                            newItem:transmitCompleteItemToClients()
                            Nfunction.buildLogShop(v.item)
                        end
                    else
                        local newItem = instanceItem(v.item)
                        square:AddTileObject(newItem)
                        newItem:transmitCompleteItemToClients()
                        Nfunction.buildLogShop(v.item)
                    end
                else
                    if v.quantity then 
                        for i = 1, v.quantity do
                            local newItem = instanceItem(v.item)
                            playerInv:AddItem(newItem)
                            sendAddItemToContainer(playerInv, newItem)
                        end
                        Nfunction.buildLogShop(v.item,v.quantity)
                    else
                        local newItem = instanceItem(v.item)
                        playerInv:AddItem(newItem)
                        sendAddItemToContainer(playerInv, newItem)
                        Nfunction.buildLogShop(v.item)
                    end
                end
            end
        else
            if item.quantity then
                for i = 1, item.quantity do
                    local newItem = instanceItem(item.type)
                    playerInv:AddItem(newItem)
                    sendAddItemToContainer(playerInv, newItem)
                end
                Nfunction.buildLogShop(item.type,item.quantity)
            else
                local newItem = instanceItem(item.type)
                playerInv:AddItem(newItem)
                sendAddItemToContainer(playerInv, newItem)
                Nfunction.buildLogShop(item.type)
            end
        end 
    end
    local shopSquare = self.shop:getSquare()
    local coords = {
        x = shopSquare:getX(),
        y = shopSquare:getY(),
        z = shopSquare:getZ(),
    }
    Nfunction.logShop(coords)
    local ticket = self.ticket
    sendClientCommand(
        self.character,
        "BS",
        "Withdraw",
        {
            coin = ticket.coin,
            specialCoin = ticket.specialCoin
        }
    )
    self.shopUI.cartItems:clear()
    return true
end

function ShopBuyAction:new(character, shopUI, ticket)
    local o = ISBaseTimedAction.new(self, character)
    o.shopUI = shopUI
    o.shop = shopUI.shop
    o.ticket = ticket
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    return o
end 