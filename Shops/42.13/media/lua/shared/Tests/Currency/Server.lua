-- CurrencyTestServer.lua
-- Server-only tests for BalanceServer.lua (NO client commands)

if not isServer() then return end

local BServer = require "BalanceServer"

CurrencyTestServer = {}

local STORE = "CoinBalance"
local PREFIX = "__TEST__"

--------------------------------------------------
-- Mock Player
--------------------------------------------------

local function MockPlayer(username)
    return {
        getUsername = function() return username end
    }
end

--------------------------------------------------
-- Utilities
--------------------------------------------------
---@class Utilities
local Utilities = {};

local function fileLog(msg)
    local writer = getFileWriter("CurrencyTestServer.log", true, true)
    if writer then
        writer:write(tostring(msg) .. "\n")
        writer:close()
    end
end

local function key(name)
    return PREFIX .. name
end

local function reset(username)
    ModData.getOrCreate(STORE)[username] = nil
end

local function get(username)
    return ModData.get(STORE)[username]
end

local function assertEq(a, b, msg)
    if a ~= b then
        error(msg .. " (expected=" .. tostring(b) .. ", got=" .. tostring(a) .. ")")
    end
end

--------------------------------------------------
-- Tests
--------------------------------------------------

function CurrencyTestServer.testCreateAccount()
    local user = key("Create")
    reset(user)

    local player = MockPlayer(user)
    BServer.CreateAccount(player, { "Wallet-A" })

    local acc = get(user)
    assert(acc ~= nil, "Account not created")
    assertEq(acc.coin, 0, "Initial coin wrong")
    assertEq(acc.specialCoin, 0, "Initial special coin wrong")
    assertEq(acc.linkedTo, "Wallet-A", "Wallet not linked")
end

function CurrencyTestServer.testDeposit()
    local user = key("Deposit")
    reset(user)

    local player = MockPlayer(user)
    BServer.CreateAccount(player, { "Wallet-A" })
    BServer.Deposit(player, { 100, 10 })

    local acc = get(user)
    assertEq(acc.coin, 100, "Coin deposit failed")
    assertEq(acc.specialCoin, 10, "Special deposit failed")
end

function CurrencyTestServer.testWithdraw()
    local user = key("Withdraw")
    reset(user)

    local player = MockPlayer(user)
    BServer.CreateAccount(player, { "Wallet-A" })
    BServer.Deposit(player, { 100, 50 })
    BServer.Withdraw(player, { 40, 20 })

    local acc = get(user)
    assertEq(acc.coin, 60, "Coin withdraw failed")
    assertEq(acc.specialCoin, 30, "Special withdraw failed")
end

function CurrencyTestServer.testTransfer()
    local sender = key("Sender")
    local recv = key("Receiver")

    reset(sender)
    reset(recv)

    local pSender = MockPlayer(sender)
    local pRecv = MockPlayer(recv)

    BServer.CreateAccount(pSender, { "Wallet-A" })
    BServer.CreateAccount(pRecv, { "Wallet-B" })
    BServer.Deposit(pSender, { 200, 40 })

    BServer.Transfer(pSender, { 100, 20, recv })

    local s = get(sender)
    local r = get(recv)

    assertEq(s.coin, 100, "Sender coin incorrect")
    assertEq(s.specialCoin, 20, "Sender special incorrect")
    assertEq(r.coin, 100, "Receiver coin incorrect")
    assertEq(r.specialCoin, 20, "Receiver special incorrect")
end

function CurrencyTestServer.testRelinkWalletOverwrite()
    local user = key("Relink")
    reset(user)

    local player = MockPlayer(user)
    BServer.CreateAccount(player, { "Wallet-A" })
    BServer.CreateAccount(player, { "Wallet-B" })

    local acc = get(user)
    assertEq(acc.linkedTo, "Wallet-B", "Wallet overwrite behavior changed")
end

--------------------------------------------------
-- Runner
--------------------------------------------------

function CurrencyTestServer.run()
    fileLog("========================================")
    fileLog(" BalanceServer - Server Test Suite")
    fileLog("========================================")

    local tests = {
        { func = CurrencyTestServer.testCreateAccount,         name = "testCreateAccount" },
        { func = CurrencyTestServer.testDeposit,               name = "testDeposit" },
        { func = CurrencyTestServer.testWithdraw,              name = "testWithdraw" },
        { func = CurrencyTestServer.testTransfer,              name = "testTransfer" },
        { func = CurrencyTestServer.testRelinkWalletOverwrite, name = "testRelinkWalletOverwrite" },
    }

    local pass, fail = 0, 0

    for _, test in ipairs(tests) do
        local ok, err = pcall(test.func)
        if ok then
            pass = pass + 1
            fileLog("[PASS] " .. test.name)
        else
            fail = fail + 1
            fileLog("[FAIL] " .. test.name .. " " .. err)
        end
    end

    fileLog("----------------------------------------")
    fileLog("Passed: " .. pass)
    fileLog("Failed: " .. fail)
    fileLog("Total: " .. (pass + fail))
    fileLog("========================================")

    return fail == 0
end

--- [SERVER]
--- Return true if the IsoPlayer is admin or single player + debug mode
---@param playerObj IsoPlayer
---@return boolean
function Utilities.IsPlayerAdmin(playerObj)
    return instanceof(playerObj, "IsoPlayer") and playerObj:isAccessLevel("Admin")
end

Events.OnGameBoot.Add(function()
    Events.OnClientCommand.Add(function(module, command, player, args)
        if module ~= "CurrencyTest" then return end
        if command ~= "run" then return end

        if not player then return end

        if not Utilities.IsPlayerAdmin(player) then
            fileLog("Denied test run from" .. player:getUsername())
            return
        end

        fileLog("[CurrencyTestServer] Triggered by" .. player:getUsername())

        CurrencyTestServer.run()
    end)

    fileLog("[CurrencyTestServer] Client command hook registered")
    print("[CurrencyTestServer] Ready.")
end)
