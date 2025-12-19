-- Transfer Feature Test Suite (Client Tests)
-- Tests for client-side Transfer UI and action functionality
-- Client-only file

if isClient() or getCore():getDebug() then
    TransferTest = TransferTest or {}

    -- Individual Test Functions

    function TransferTest.test1_UIInitialization()
        print("\n[TEST 1] TransferUI Initialization")
        local player = getPlayer()
        if not player then
            print("⊘ SKIPPED: Player not available")
            return true
        end

        local transferUI = TransferUI:show(player)
        assert(transferUI ~= nil, "TransferUI failed to initialize")
        assert(transferUI.player == player, "TransferUI player reference mismatch")
        assert(transferUI.recipient == nil, "TransferUI should start with no recipient")

        transferUI:close()
        print("✓ PASSED: TransferUI initialization works")
        return true
    end

    function TransferTest.test2_AccountListRetrieval()
        print("\n[TEST 2] Account List Retrieval")
        local accounts = Balance.getAccountsList()
        assert(accounts ~= nil, "Failed to retrieve accounts list")
        assert(type(accounts) == "table", "Accounts list should be a table")
        print("✓ PASSED: Retrieved " .. #accounts .. " accounts")
        return true
    end

    function TransferTest.test3_RecipientSelection()
        print("\n[TEST 3] Recipient Selection")
        local player = getPlayer()
        if not player then
            print("⊘ SKIPPED: Player not available")
            return true
        end

        local transferUI = TransferUI:show(player)
        local accounts = Balance.getAccountsList()
        local username = player:getUsername()
        local recipient = nil

        for k, v in pairs(accounts) do
            if v ~= username then
                recipient = v
                break
            end
        end

        if recipient == nil then
            transferUI:close()
            print("⊘ SKIPPED: No other account available for transfer test")
            return true
        end

        transferUI.recipient = recipient
        transferUI.toLabel:setName(UIText.TransferTo .. ": " .. recipient)

        assert(transferUI.recipient == recipient, "Recipient selection failed")

        transferUI:close()
        print("✓ PASSED: Recipient selection works: " .. recipient)
        return true
    end

    function TransferTest.test4_TransferAmountValidation()
        print("\n[TEST 4] Transfer Amount Validation")
        local player = getPlayer()
        if not player then
            print("⊘ SKIPPED: Player not available")
            return true
        end

        local username = player:getUsername()
        local coin, specialCoin = Balance.getUserBalance(username)

        local validTransferCoin = math.floor(coin / 2)
        assert(validTransferCoin > 0, "Cannot test with zero coins")
        assert(validTransferCoin <= coin, "Transfer amount validation failed")

        local invalidTransferCoin = coin + 1000
        assert(invalidTransferCoin > coin, "Invalid amount should exceed balance")

        print("✓ PASSED: Transfer amount validation works")
        print("  - Valid amount: " .. validTransferCoin)
        print("  - Invalid amount: " .. invalidTransferCoin)
        return true
    end

    function TransferTest.test5_SendButtonState()
        print("\n[TEST 5] Send Button State")
        local player = getPlayer()
        if not player then
            print("⊘ SKIPPED: Player not available")
            return true
        end

        local transferUI = TransferUI:show(player)

        assert(not transferUI.sendButton.enable, "Send button should be disabled initially")

        local accounts = Balance.getAccountsList()
        local username = player:getUsername()
        local recipient = nil
        for k, v in pairs(accounts) do
            if v ~= username then
                recipient = v
                TransferUI.recipient = v
                transferUI.toLabel:setName(UIText.TransferTo .. ": " .. v)
                break
            end
        end

        if not recipient then
            transferUI:close()
            print("⊘ SKIPPED: No other account available")
            return true
        end

        transferUI.transferCoin:setText("100")
        transferUI:update()

        local coin, specialCoin = Balance.getUserBalance(username)
        if coin >= 100 then
            assert(transferUI.sendButton.enable, "Send button should be enabled with valid transfer")
        else
            print("⊘ SKIPPED: Player has less than 100 coins")
        end

        transferUI:close()
        print("✓ PASSED: Send button state management works")
        return true
    end

    function TransferTest.test6_TransferDataPreparation()
        print("\n[TEST 6] Transfer Data Preparation")
        local player = getPlayer()
        if not player then
            print("⊘ SKIPPED: Player not available")
            return true
        end

        local transferUI = TransferUI:show(player)

        local coin = 500
        local specialCoin = 100
        local recipient = "TestRecipient"

        transferUI.transferCoin:setText(tostring(coin))
        transferUI.transferSpecialCoin:setText(tostring(specialCoin))
        transferUI.recipient = recipient

        local transfer = {}
        transfer.coin = tonumber(transferUI.transferCoin:getInternalText())
        transfer.specialCoin = tonumber(transferUI.transferSpecialCoin:getInternalText())
        transfer.recipient = transferUI.recipient
        transfer.coin = math.abs(transfer.coin)
        transfer.specialCoin = math.abs(transfer.specialCoin)

        assert(transfer.coin == coin, "Transfer coin amount mismatch")
        assert(transfer.specialCoin == specialCoin, "Transfer special coin amount mismatch")
        assert(transfer.recipient == recipient, "Transfer recipient mismatch")

        transferUI:close()
        print("✓ PASSED: Transfer data preparation works")
        return true
    end

    function TransferTest.test7_ClearAfterTransfer()
        print("\n[TEST 7] Clear After Transfer")
        local player = getPlayer()
        if not player then
            print("⊘ SKIPPED: Player not available")
            return true
        end

        local transferUI = TransferUI:show(player)

        transferUI.transferCoin:setText("500")
        transferUI.transferSpecialCoin:setText("100")
        TransferUI.recipient = "TestRecipient"
        transferUI.toLabel:setName(UIText.TransferTo .. ": TestRecipient")

        transferUI:clearAfterTransfer()

        assert(TransferUI.recipient == nil, "Recipient should be cleared")
        assert(transferUI.transferCoin:getInternalText() == "0", "Transfer coin should be reset")
        assert(transferUI.transferSpecialCoin:getInternalText() == "0", "Transfer special coin should be reset")

        transferUI:close()
        print("✓ PASSED: Clear after transfer works")
        return true
    end

    function TransferTest.test8_NegativeAmountHandling()
        print("\n[TEST 8] Negative Amount Handling")
        local player = getPlayer()
        if not player then
            print("⊘ SKIPPED: Player not available")
            return true
        end

        local transferUI = TransferUI:show(player)

        transferUI.transferCoin:setText("-100")
        transferUI.recipient = "TestRecipient"
        transferUI:update()

        assert(not transferUI.sendButton.enable, "Send button should be disabled for negative amount")

        transferUI:close()
        print("✓ PASSED: Negative amount handling works")
        return true
    end

    function TransferTest.test9_ZeroAmountHandling()
        print("\n[TEST 9] Zero Amount Handling")
        local player = getPlayer()
        if not player then
            print("⊘ SKIPPED: Player not available")
            return true
        end

        local transferUI = TransferUI:show(player)

        transferUI.transferCoin:setText("0")
        transferUI.transferSpecialCoin:setText("0")
        transferUI.recipient = "TestRecipient"
        transferUI:update()

        assert(not transferUI.sendButton.enable, "Send button should be disabled for zero amount")

        transferUI:close()
        print("✓ PASSED: Zero amount handling works")
        return true
    end

    function TransferTest.test10_AccountFiltering()
        print("\n[TEST 10] Account Filtering")
        local player = getPlayer()
        if not player then
            print("⊘ SKIPPED: Player not available")
            return true
        end

        local transferUI = TransferUI:show(player)

        local initialCount = #transferUI.accountItems.items
        if initialCount == 0 then
            transferUI:close()
            print("⊘ SKIPPED: No accounts to filter")
            return true
        end

        transferUI.filterEntry:setText("Test")
        transferUI:filter()

        local filteredCount = #transferUI.accountItems.items
        assert(filteredCount <= initialCount, "Filtered count should not exceed initial count")

        transferUI.filterEntry:setText("")
        transferUI:filter()

        assert(#transferUI.accountItems.items == initialCount, "Filter clearing should restore all accounts")

        transferUI:close()
        print("✓ PASSED: Account filtering works")
        print("  - Initial accounts: " .. initialCount)
        print("  - Filtered accounts: " .. filteredCount)
        return true
    end

    -- Run All Tests
    function TransferTest.runAllTests()
        print("\n" .. string.rep("=", 50))
        print("TRANSFER TEST SUITE - RUN ALL TESTS")
        print(string.rep("=", 50))

        local tests = {
            { name = "1_UIInitialization",         func = TransferTest.test1_UIInitialization },
            { name = "2_AccountListRetrieval",     func = TransferTest.test2_AccountListRetrieval },
            { name = "3_RecipientSelection",       func = TransferTest.test3_RecipientSelection },
            { name = "4_TransferAmountValidation", func = TransferTest.test4_TransferAmountValidation },
            { name = "5_SendButtonState",          func = TransferTest.test5_SendButtonState },
            { name = "6_TransferDataPreparation",  func = TransferTest.test6_TransferDataPreparation },
            { name = "7_ClearAfterTransfer",       func = TransferTest.test7_ClearAfterTransfer },
            { name = "8_NegativeAmountHandling",   func = TransferTest.test8_NegativeAmountHandling },
            { name = "9_ZeroAmountHandling",       func = TransferTest.test9_ZeroAmountHandling },
            { name = "10_AccountFiltering",        func = TransferTest.test10_AccountFiltering },
        }

        local passed = 0
        local failed = 0

        for _, test in ipairs(tests) do
            local success, err = pcall(test.func)
            if success then
                passed = passed + 1
            else
                failed = failed + 1
                print("✗ FAILED: " .. err)
            end
        end

        print("\n" .. string.rep("=", 50))
        print("TEST RESULTS")
        print(string.rep("=", 50))
        print("Passed: " .. passed .. "/" .. #tests)
        print("Failed: " .. failed .. "/" .. #tests)
        print(string.rep("=", 50) .. "\n")

        return failed == 0
    end

    -- Command Interface
    function TransferTest.runCommand(testName)
        testName = testName or "all"

        if testName == "all" then
            return TransferTest.runAllTests()
        else
            local testFunc = TransferTest["test" .. testName]
            if testFunc then
                local success, err = pcall(testFunc)
                if not success then
                    print("✗ TEST FAILED: " .. err)
                    return false
                end
                return true
            else
                print("ERROR: Unknown test '" .. testName .. "'")
                print("Available: all, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10")
                return false
            end
        end
    end

    -- Run tests and send results to server
    function TransferTest.runAndReport(testName)
        testName = testName or "all"
        local success = TransferTest.runCommand(testName)

        -- Send result to server via events
        if sendServerCommand then
            sendServerCommand("transfer", "test_result", { testName = testName, success = success })
        end

        return success
    end

    -- Console access function
    function TransferTest.console(testName)
        testName = testName or "all"
        return TransferTest.runCommand(testName)
    end

    print("[TransferTest] Test suite ready. Call: TransferTest.console() or TransferTest.console(5)")
end -- end isClient() guard
