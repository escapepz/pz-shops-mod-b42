require "TimedActions/ISBaseTimedAction"

SendTransferAction = ISBaseTimedAction:derive("SendTransferAction")

function SendTransferAction:isValid()
    local username = self.character:getUsername()
    local coin,specialCoin = Balance.getUserBalance(username)
    local recipientAccount = Balance.getUserAccount(self.recipient)
    if not recipientAccount then return false end
    return coin >= self.coin and specialCoin >= self.specialCoin
end

function SendTransferAction:waitToStart()
    return self.character:shouldBeTurning()
end

function SendTransferAction:update()
    -- no-op for MP safety
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
    sendClientCommand(
        self.character,
        "BS",
        "Transfer",
        {
            coin = self.coin,
            specialCoin = self.specialCoin,
            recipient = self.recipient
        }
    )
    return true
end

function SendTransferAction:new(character, coin, specialCoin, recipient)
    local o = ISBaseTimedAction.new(self, character)

    o.coin = coin or 0
    o.specialCoin = specialCoin or 0
    o.recipient = recipient

    o.stopOnWalk = false
    o.stopOnRun = true
    o.maxTime = o:getDuration()

    return o
end
