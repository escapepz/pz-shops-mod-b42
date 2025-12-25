if not isServer() then return end

local BServer = {}

local logfile = "timestamp_economy.log"
local msg = ""

function BServer.OnInitGlobalModData()
    ModData.getOrCreate("CoinBalance")
end
Events.OnInitGlobalModData.Add(BServer.OnInitGlobalModData)

function BServer.writeLog(msg)
    if Valhalla and Valhalla.Commands then
        local args = {file = logfile, line = msg}
        Valhalla.Commands.writeToLog(nil, args)
        return
    end
    print(msg)
end

function BServer.CreateAccount(player,args)
    local username = player:getUsername()
    local linkedTo = args[1]
    local walletID = args[2]
    local account = ModData.get("CoinBalance")[username]

    if account then
        account.linkedTo = linkedTo

        msg= "Link: %s linked new wallet: %s"
        msg = string.format(msg,username,linkedTo)
        BServer.writeLog(msg)

    else
        ModData.get("CoinBalance")[username] = {coin = 0, specialCoin = 0, linkedTo = linkedTo}

        msg= "NewAccount: %s, Coin: 0 SpecialCoin: 0"
        msg = string.format(msg,username,linkedTo)
        BServer.writeLog(msg)

    end
    
    -- Sync wallet modData to all clients if wallet ID is provided
    if walletID then
        local wallet = player:getInventory():getItemById(walletID)
        if wallet then
            -- Set wallet modData on server to match client state
            local walletModData = wallet:getModData()
            walletModData.belongsTo = username
            walletModData.linkedTo = linkedTo
            print("[BalanceServer] CreateAccount: Syncing wallet modData - walletID=" .. tostring(walletID) .. ", belongsTo=" .. tostring(walletModData.belongsTo) .. ", linkedTo=" .. tostring(walletModData.linkedTo))
            syncItemModData(player, wallet)
        else
            print("[BalanceServer] CreateAccount: Wallet not found - walletID=" .. tostring(walletID))
        end
    end
    
    ModData.transmit("CoinBalance")
end

function BServer.Deposit(player,args)
    local username = player:getUsername()
    local account = ModData.get("CoinBalance")[username]
    if not account then return end
    account.coin = account.coin+args[1]
    account.specialCoin = account.specialCoin + args[2]

    msg = "Deposit: %s oldBalance: Coin: %s SpecialCoin %s newBalance: Coin: %s SpecialCoin %s"
    msg = string.format(msg,username,account.coin-args[1],account.specialCoin-args[2],account.coin,account.specialCoin)
    BServer.writeLog(msg)

    -- Remove coin items from player inventory if provided
    if args[3] and type(args[3]) == "table" then
        for i, itemID in ipairs(args[3]) do
            local item = player:getInventory():getItemById(itemID)
            if item then
                item:getContainer():Remove(item)
            end
        end
    end

    ModData.transmit("CoinBalance")
end

function BServer.Transfer(player,args)
    local username = player:getUsername()
    local account = ModData.get("CoinBalance")[username]
    local recipientAccount = ModData.get("CoinBalance")[args[3]]
    if not account or not recipientAccount then return end
    account.coin = account.coin-args[1]
    account.specialCoin = account.specialCoin-args[2]
    recipientAccount.coin = recipientAccount.coin+args[1]
    recipientAccount.specialCoin = recipientAccount.specialCoin+args[2]

    msg = "Transfer: Sender %s oldBalance: Coin: %s SpecialCoin %s newBalance: Coin: %s SpecialCoin %s Recipient: %s oldBalance: Coin: %s SpecialCoin %s newBalance: Coin: %s SpecialCoin %s"
    msg = string.format(msg,username,account.coin+args[1],account.specialCoin+args[2],account.coin,account.specialCoin,
    args[3],recipientAccount.coin-args[1],recipientAccount.specialCoin-args[2],recipientAccount.coin,recipientAccount.specialCoin)
    BServer.writeLog(msg)

    ModData.transmit("CoinBalance")
    local noti = { 
        sender = username,
        coin = args[1],
        specialCoin = args[2],
    }

    local players = getOnlinePlayers()
    local playersSize = players:size()
    if not playersSize then return end
    for i = 0, playersSize - 1, 1 do
        local player = players:get(i)
        if player:getUsername() == args[3] then
            sendServerCommand(player,"BS", "TransferReceived", noti)
            break;
        end
    end
end

function BServer.Withdraw(player,args)
    local username = player:getUsername()
    local account = ModData.get("CoinBalance")[username]
    if not account then return end
    if account.coin >= args[1] then
        account.coin = account.coin-args[1]
    end
    if account.specialCoin >= args[2] then
        account.specialCoin = account.specialCoin-args[2]
    end

    msg = "Withdraw: %s oldBalance: Coin: %s SpecialCoin %s newBalance: Coin: %s SpecialCoin %s"
    msg = string.format(msg,username,account.coin+args[1],account.specialCoin+args[2],account.coin,account.specialCoin)
    BServer.writeLog(msg)

    ModData.transmit("CoinBalance")
end

function BServer.UnlinkWallet(player,args)
    local username = player:getUsername()
    local walletID = args[1]
    local account = ModData.get("CoinBalance")[username]
    if not account then return end
    account.linkedTo = nil

    msg = "Unlink: %s unlinked wallet"
    msg = string.format(msg,username)
    BServer.writeLog(msg)

    -- Sync wallet modData to all clients if wallet ID is provided
    if walletID then
        local wallet = player:getInventory():getItemById(walletID)
        if wallet then
            -- Clear wallet modData on server to match client state
            local walletModData = wallet:getModData()
            walletModData.belongsTo = nil
            walletModData.linkedTo = nil
            print("[BalanceServer] UnlinkWallet: Syncing wallet modData - walletID=" .. tostring(walletID) .. ", belongsTo=" .. tostring(walletModData.belongsTo) .. ", linkedTo=" .. tostring(walletModData.linkedTo))
            syncItemModData(player, wallet)
        else
            print("[BalanceServer] UnlinkWallet: Wallet not found - walletID=" .. tostring(walletID))
        end
    end

    ModData.transmit("CoinBalance")
end

local function BS_OnClientCommand(module, command, player, args)
    if module == "BS" and BServer[command] then
        BServer[command](player, args)
    end
end

Events.OnClientCommand.Add(BS_OnClientCommand)