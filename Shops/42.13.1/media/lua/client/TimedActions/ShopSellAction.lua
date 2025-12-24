require "TimedActions/ISBaseTimedAction"
local Nfunction = require "Nfunction"
ShopSellAction = ISBaseTimedAction:derive("ShopSellAction")

function ShopSellAction:isValid()
    return true
end

function ShopSellAction:waitToStart()
    return self.character:shouldBeTurning()
end

function ShopSellAction:update()
    if not self.shopUI:getIsVisible() then 
        self:forceStop()
    end
end

function ShopSellAction:start()
end

function ShopSellAction:stop()
    ISBaseTimedAction.stop(self)
end

function ShopSellAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 50
end

function ShopSellAction:perform()
    if self.total > 0 or self.totalSpecial > 0 then
        self.character:playSound("CashRegister")
    end
    ISBaseTimedAction.perform(self)
end

function ShopSellAction:complete()
    local cartItems = self.shopUI.cartItems.items
    local playerInv = self.character:getInventory()
    local inventoryItems = {}
    local inventory = self.character:getInventory():getItems()
    for i = 0, inventory:size() -1 do
        local item = inventory:get(i)
        if not (item:isEquipped() or item:isFavorite()) then
            inventoryItems[item:getID()] = item
        end
    end
    local total = 0
    local totalSpecial = 0
    for k,v in pairs(cartItems) do
        local item = v.item
        local invItem = inventoryItems[item.id]
        if invItem then
            item.price = Nfunction.drainablePrice(invItem,item.priceFull)
            if item.specialCoin then
                totalSpecial = totalSpecial + item.price
            else
                total = total + item.price
            end
            if SandboxVars.Shops.SellLog then Nfunction.buildLogShop(invItem:getFullType()) end
            invItem:getContainer():Remove(invItem)
            sendRemoveItemFromContainer(playerInv, invItem)
        end
    end
    local shopSquare = self.shop:getSquare()
    local coords = {
        x = shopSquare:getX(),
        y = shopSquare:getY(),
        z = shopSquare:getZ(),
    }
    if SandboxVars.Shops.SellLog then Nfunction.logShop(coords,"Sell") end
    if total > 0 then
        for i = 1, total do
            local coin = instanceItem(Currency.BaseCoin)
            playerInv:AddItem(coin)
            sendAddItemToContainer(playerInv, coin)
        end
    end
    if totalSpecial > 0 then
        for i = 1, totalSpecial do
            local coin = instanceItem(Currency.SpecialCoin)
            playerInv:AddItem(coin)
            sendAddItemToContainer(playerInv, coin)
        end
    end
    self.shopUI.cartItems:clear()
    return true
end

function ShopSellAction:new(character, shopUI)
    local o = ISBaseTimedAction.new(self, character)
    o.shopUI = shopUI
    o.shop = shopUI.shop
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    return o
end 