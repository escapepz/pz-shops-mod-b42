-- Currency Feature Test Suite (Client Tests)
-- Tests for client-side functionality

if not isClient() then return end

CurrencyTestClient = CurrencyTestClient or {}

-- Test 3: User Balance Retrieval
function CurrencyTestClient.testGetUserBalance()
    print("\nTEST 3: User Balance Retrieval")
    local testUsername = "TestPlayer"
    local coin, specialCoin = Balance.getUserBalance(testUsername)
    assert(coin ~= nil, "Balance.getUserBalance failed to return coin value")
    assert(specialCoin ~= nil, "Balance.getUserBalance failed to return specialCoin value")
    print("✓ User balance retrieval works")
end

-- Test 12: Wallet Balance Display
function CurrencyTestClient.testWalletBalanceDisplay()
    print("\nTEST 12: Wallet Balance Display")
    local testUsername = "DisplayTestPlayer"

    local coin, specialCoin = Balance.getUserBalance(testUsername)
    local coinFormatted = Currency.format(coin)
    local specialCoinFormatted = Currency.format(specialCoin)

    assert(coinFormatted ~= nil, "Coin formatting for display failed")
    assert(specialCoinFormatted ~= nil, "Special coin formatting for display failed")
    print("✓ Wallet balance displays: " .. coinFormatted .. " / " .. specialCoinFormatted)
end

-- Test 13: Insufficient Balance Check
function CurrencyTestClient.testInsufficientBalance()
    print("\nTEST 13: Insufficient Balance Check")
    local testUsername = "PoorTestPlayer"

    local coin, specialCoin = Balance.getUserBalance(testUsername)

    -- Simulate a purchase requiring more coins than available
    local purchaseCost = 10000
    local canAfford = coin >= purchaseCost

    assert(not canAfford, "Should not be able to afford expensive item")
    print("✓ Insufficient balance detection works")
end

-- Run client tests
function CurrencyTestClient.runClientTests()
    print("========================================")
    print("CURRENCY FEATURE TEST SUITE (CLIENT)")
    print("========================================")

    local tests = {
        CurrencyTestClient.testGetUserBalance,
        CurrencyTestClient.testWalletBalanceDisplay,
        CurrencyTestClient.testInsufficientBalance,
    }

    local passed = 0
    local failed = 0

    for _, test in ipairs(tests) do
        local success, err = pcall(test)
        if success then
            passed = passed + 1
        else
            failed = failed + 1
            print("✗ TEST FAILED: " .. err)
        end
    end

    print("\n========================================")
    print("TEST RESULTS (CLIENT)")
    print("========================================")
    print("Passed: " .. passed)
    print("Failed: " .. failed)
    print("Total:  " .. (passed + failed))
    print("========================================")

    return failed == 0
end

-- Console access function
function CurrencyTestClient.console()
    -- Check if required modules are loaded
    if not Balance then
        print("ERROR: Balance module not loaded")
        return false
    end
    if not Currency then
        print("ERROR: Currency module not loaded")
        return false
    end

    return CurrencyTestClient.runClientTests()
end

print("[CurrencyTestClient] Test suite ready. Call: CurrencyTestClient.console()")

local function runServerTests()
    sendClientCommand(
        "CurrencyTest", -- module
        "run",          -- command
        {}              -- args
    )
    print("[CurrencyTestClient] Test request sent to server")
end

-- Expose to Lua console
function CurrencyTestClient.server()
    runServerTests()
end

print("[CurrencyTestClient] Test for server is ready. Call CurrencyTestClient.server()")
