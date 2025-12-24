require "TimedActions/ISBaseTimedAction"

SendTransferAction = ISBaseTimedAction:derive("SendTransferAction")

function SendTransferAction:isValid()
    local username = self.character:getUsername()
    local coin,specialCoin = Balance.getUserBalance(username)
    local transfer = self.transfer
    local recipientAccount = Balance.getUserAccount(transfer.recipient)
    if not recipientAccount then return false end
    return coin >= transfer.coin and specialCoin >= transfer.specialCoin
end

function SendTransferAction:waitToStart()
    return self.character:shouldBeTurning()
end

function SendTransferAction:update()
    if not self.transferUI:getIsVisible() then 
        self:forceStop()
    end
end

function SendTransferAction:start()
end

function SendTransferAction:stop()
    ISBaseTimedAction.stop(self)
end

function SendTransferAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 50
end

function SendTransferAction:perform()
    ISBaseTimedAction.perform(self)
end

function SendTransferAction:complete()
    local transfer = self.transfer
    sendClientCommand("BS", "Transfer", {transfer.coin,transfer.specialCoin,transfer.recipient})
    local transferUI = self.transferUI
    transferUI:clearAfterTransfer()
    return true
end

function SendTransferAction:new(character, transferUI, transfer)
    local o = ISBaseTimedAction.new(self, character)
    o.transferUI = transferUI
    o.transfer = transfer
    o.stopOnWalk = false
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    return o
end 