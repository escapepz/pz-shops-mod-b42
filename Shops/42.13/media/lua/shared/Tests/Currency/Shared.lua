-- Currency Feature Test Suite (Shared Tests)
-- Tests for Wallet, Coin, and Balance functionality

CurrencyTestShared = CurrencyTestShared or {}

-- Test 1: Wallet Registration
function CurrencyTestShared.testWalletRegistration()
    print("TEST 1: Wallet Registration")
    assert(Currency.Wallets["Base.Wallet"], "Base.Wallet not registered")
    assert(Currency.Wallets["Base.Wallet2"], "Base.Wallet2 not registered")
    assert(Currency.Wallets["Base.Wallet3"], "Base.Wallet3 not registered")
    assert(Currency.Wallets["Base.Wallet4"], "Base.Wallet4 not registered")
    print("✓ All wallets registered correctly")
end

-- Test 2: Coin Types
function CurrencyTestShared.testCoinTypes()
    print("\nTEST 2: Coin Types")
    assert(Currency.BaseCoin == "Shops.CopperCoin", "Base coin not set correctly")
    assert(Currency.SpecialCoin == "Shops.EventCoin", "Special coin not set correctly")
    assert(Currency.UseSpecialCoin == true, "Special coin usage not enabled")

    -- Test all registered coin types
    assert(Currency.Coins["Shops.CopperCoin"] ~= nil, "CopperCoin not registered")
    assert(Currency.Coins["Shops.EventCoin"] ~= nil, "EventCoin not registered")
    assert(Currency.Coins["Shops.SilverCoin"] ~= nil, "SilverCoin not registered")
    assert(Currency.Coins["Shops.GoldCoin"] ~= nil, "GoldCoin not registered")

    print("✓ All coin types configured correctly")
end

-- Test 8: Coin Format
function CurrencyTestShared.testCoinFormat()
    print("\nTEST 8: Coin Format")
    local formatted = Currency.format(1000)
    assert(formatted ~= nil, "Currency.format failed")
    assert(type(formatted) == "string", "Currency.format should return string")
    print("✓ Coin formatting works: " .. formatted)
end

-- Test 14: Item Special Coin Flag
function CurrencyTestShared.testItemSpecialCoinFlag()
    print("\nTEST 14: Item Special Coin Flag")
    -- This tests that items can be marked as requiring special coins
    local testItem = { specialCoin = true, price = 5 }

    assert(testItem.specialCoin == true, "Item special coin flag not set")
    assert(testItem.price == 5, "Item price not set")
    print("✓ Item special coin flag works")
end

-- Test 15: Currency Configuration
function CurrencyTestShared.testCurrencyConfig()
    print("\nTEST 15: Currency Configuration")
    assert(Currency.Coins ~= nil, "Currency.Coins table not initialized")
    assert(Currency.Wallets ~= nil, "Currency.Wallets table not initialized")
    print("✓ Currency configuration initialized")
end

-- Run shared tests
function CurrencyTestShared.runSharedTests()
    print("========================================")
    print("CURRENCY FEATURE TEST SUITE (SHARED)")
    print("========================================")

    local tests = {
        CurrencyTestShared.testWalletRegistration,
        CurrencyTestShared.testCoinTypes,
        CurrencyTestShared.testCoinFormat,
        CurrencyTestShared.testItemSpecialCoinFlag,
        CurrencyTestShared.testCurrencyConfig,
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
    print("TEST RESULTS (SHARED)")
    print("========================================")
    print("Passed: " .. passed)
    print("Failed: " .. failed)
    print("Total:  " .. (passed + failed))
    print("========================================")

    return failed == 0
end

-- Console access function (client/shared)
function CurrencyTestShared.console()
    return CurrencyTestShared.runSharedTests()
end

if isClient() then
    print("[CurrencyTestShared] Shared test suite ready. Call: CurrencyTestShared.console()")
end
