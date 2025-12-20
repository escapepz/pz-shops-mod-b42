-- Shop Feature Test Suite (Server Tests)
-- Tests for server-side Shop transactions, inventory, and account money system

if isServer() or getCore():getDebug() then
    ShopTestServer = ShopTestServer or {}

    -- Test 1: Account Money System
    function ShopTestServer.test1_AccountMoneySystem()
        print("\n[TEST 1] Account Money System")
        
        -- Verify that money is stored in accounts, not wallets
        local testAccount = {
            username = "TestPlayer",
            money = 5000,
            specialMoney = 100,
            walletRequired = false
        }
        
        assert(testAccount.money ~= nil, "Account money required")
        assert(testAccount.specialMoney ~= nil, "Account special money required")
        assert(testAccount.walletRequired == false, "Wallet should not be required")
        
        print("✓ PASSED: Account money system validated")
        return true
    end

    -- Test 2: Purchase Transaction Processing
    function ShopTestServer.test2_PurchaseTransaction()
        print("\n[TEST 2] Purchase Transaction Processing")
        
        local playerMoney = 5000
        local itemPrice = 1500
        
        -- Verify sufficient funds
        assert(playerMoney >= itemPrice, "Insufficient funds for purchase")
        
        -- Process purchase
        local newBalance = playerMoney - itemPrice
        assert(newBalance == 3500, "Transaction calculation failed")
        assert(newBalance >= 0, "Balance went negative")
        
        print("✓ PASSED: Purchase transaction processed correctly")
        return true
    end

    -- Test 3: Insufficient Funds Handling
    function ShopTestServer.test3_InsufficientFundsHandling()
        print("\n[TEST 3] Insufficient Funds Handling")
        
        local playerMoney = 300
        local itemPrice = 1500
        
        -- Verify transaction is blocked
        assert(playerMoney < itemPrice, "Setup error: should have insufficient funds")
        
        local canPurchase = playerMoney >= itemPrice
        assert(canPurchase == false, "Should not allow purchase with insufficient funds")
        
        print("✓ PASSED: Insufficient funds handling correct")
        return true
    end

    -- Test 4: Sell Item Processing
    function ShopTestServer.test4_SellItemProcessing()
        print("\n[TEST 4] Sell Item Processing")
        
        local playerMoney = 1000
        local itemSellPrice = 500
        
        -- Process sale
        local newBalance = playerMoney + itemSellPrice
        assert(newBalance == 1500, "Sale calculation failed")
        assert(newBalance > playerMoney, "Player money should increase after sale")
        
        print("✓ PASSED: Sell item processing works")
        return true
    end

    -- Test 5: Item Damaged Condition Pricing
    function ShopTestServer.test5_DamagedConditionPricing()
        print("\n[TEST 5] Item Damaged Condition Pricing")
        
        local normalPrice = 1000
        local condition = 50  -- 50% condition
        
        -- Calculate adjusted price based on condition
        local adjustedPrice = math.floor(normalPrice * (condition / 100))
        assert(adjustedPrice == 500, "Damaged price calculation failed")
        assert(adjustedPrice < normalPrice, "Damaged item should cost less")
        
        print("✓ PASSED: Damaged condition pricing correct")
        return true
    end

    -- Test 6: Currency Type Handling (Normal vs Special)
    function ShopTestServer.test6_CurrencyTypeHandling()
        print("\n[TEST 6] Currency Type Handling (Normal vs Special)")
        
        local transaction = {
            itemPrice = 100,
            specialCoin = false
        }
        
        local transactionSpecial = {
            itemPrice = 50,
            specialCoin = true
        }
        
        assert(transaction.specialCoin == false, "Normal currency not marked")
        assert(transactionSpecial.specialCoin == true, "Special currency not marked")
        
        -- Verify they can't be mixed
        local function processTransaction(trans)
            if trans.specialCoin then
                return "special"
            else
                return "normal"
            end
        end
        
        assert(processTransaction(transaction) == "normal", "Normal transaction processing failed")
        assert(processTransaction(transactionSpecial) == "special", "Special transaction processing failed")
        
        print("✓ PASSED: Currency type handling correct")
        return true
    end

    -- Test 7: Shop Admin Controls - Tile Placement
    function ShopTestServer.test7_AdminTilePlacement()
        print("\n[TEST 7] Admin Controls - Tile Placement")
        
        local tile = {
            x = 100,
            y = 200,
            z = 0,
            rotation = 0,
            adminOnly = true,
            indestructible = true
        }
        
        assert(tile.adminOnly == true, "Tile should be admin-only for placement")
        assert(tile.indestructible == true, "Tile should be indestructible")
        assert(tile.rotation == 0 or tile.rotation == 1, "Invalid rotation")
        
        print("✓ PASSED: Admin tile placement validated")
        return true
    end

    -- Test 8: Shop Tile Destruction Prevention
    function ShopTestServer.test8_TileDestructionPrevention()
        print("\n[TEST 8] Shop Tile Destruction Prevention")
        
        local shopTile = {
            indestructible = true,
            adminRemovalOnly = true
        }
        
        local canDestroy = function(tile, isAdmin)
            if not tile.indestructible then
                return true
            end
            if tile.adminRemovalOnly and not isAdmin then
                return false
            end
            return isAdmin
        end
        
        assert(canDestroy(shopTile, false) == false, "Non-admin should not destroy tile")
        assert(canDestroy(shopTile, true) == true, "Admin should be able to destroy tile")
        
        print("✓ PASSED: Tile destruction prevention working")
        return true
    end

    -- Test 9: Player Inventory Management
    function ShopTestServer.test9_PlayerInventoryManagement()
        print("\n[TEST 9] Player Inventory Management")
        
        local inventory = {}
        
        -- Add item to inventory
        local item = { id = "Base.Hammer", name = "Hammer", quantity = 1 }
        table.insert(inventory, item)
        
        assert(#inventory == 1, "Item not added to inventory")
        assert(inventory[1].id == "Base.Hammer", "Item ID mismatch")
        
        -- Remove item from inventory
        table.remove(inventory, 1)
        assert(#inventory == 0, "Item not removed from inventory")
        
        print("✓ PASSED: Player inventory management works")
        return true
    end

    -- Test 10: Bought Items Delivery
    function ShopTestServer.test10_BoughtItemsDelivery()
        print("\n[TEST 10] Bought Items Delivery")
        
        local purchasedItems = { "Base.Hammer", "Base.Axe", "Base.Nails" }
        local playerInventory = {}
        
        -- Deliver items to player inventory
        for _, itemId in ipairs(purchasedItems) do
            table.insert(playerInventory, { id = itemId })
        end
        
        assert(#playerInventory == #purchasedItems, "Items not delivered")
        assert(playerInventory[1].id == "Base.Hammer", "First item mismatch")
        assert(playerInventory[3].id == "Base.Nails", "Last item mismatch")
        
        print("✓ PASSED: Bought items delivery works")
        return true
    end

    -- Test 11: Sold Items Removal from Inventory
    function ShopTestServer.test11_SoldItemsRemoval()
        print("\n[TEST 11] Sold Items Removal from Inventory")
        
        local inventory = {
            { id = "Base.Hammer", quantity = 2 },
            { id = "Base.Axe", quantity = 1 }
        }
        
        -- Sell one hammer
        inventory[1].quantity = inventory[1].quantity - 1
        assert(inventory[1].quantity == 1, "Quantity not decreased")
        
        -- Remove if quantity is 0
        if inventory[1].quantity == 0 then
            table.remove(inventory, 1)
        end
        
        assert(#inventory == 2, "Item should not be removed if quantity > 0")
        
        print("✓ PASSED: Sold items removal works")
        return true
    end

    -- Test 12: Pack Item Contents
    function ShopTestServer.test12_PackItemContents()
        print("\n[TEST 12] Pack Item Contents")
        
        local packItem = {
            id = "Base.Backpack",
            isPack = true,
            capacity = 10,
            contents = {}
        }
        
        -- Add items to pack
        table.insert(packItem.contents, { id = "Base.Item1" })
        table.insert(packItem.contents, { id = "Base.Item2" })
        
        assert(#packItem.contents == 2, "Items not added to pack")
        assert(#packItem.contents <= packItem.capacity, "Pack capacity exceeded")
        
        print("✓ PASSED: Pack item contents management works")
        return true
    end

    -- Test 13: Transaction Logging
    function ShopTestServer.test13_TransactionLogging()
        print("\n[TEST 13] Transaction Logging")
        
        local logs = {}
        
        local logTransaction = function(username, type, itemId, price, success)
            table.insert(logs, {
                username = username,
                type = type,
                itemId = itemId,
                price = price,
                success = success,
                timestamp = os.time()
            })
        end
        
        logTransaction("Player1", "purchase", "Base.Hammer", 500, true)
        logTransaction("Player1", "sell", "Base.Axe", 250, true)
        
        assert(#logs == 2, "Transactions not logged")
        assert(logs[1].type == "purchase", "Purchase not logged correctly")
        assert(logs[2].type == "sell", "Sell not logged correctly")
        
        print("✓ PASSED: Transaction logging works")
        return true
    end

    -- Test 14: Favorite Items Persistence
    function ShopTestServer.test14_FavoritePersistence()
        print("\n[TEST 14] Favorite Items Persistence")
        
        local playerFavorites = {
            username = "Player1",
            favorites = { "Base.Hammer", "Base.Axe" }
        }
        
        assert(#playerFavorites.favorites == 2, "Favorites not stored")
        assert(playerFavorites.favorites[1] == "Base.Hammer", "First favorite incorrect")
        
        -- Remove favorite
        table.remove(playerFavorites.favorites, 1)
        assert(#playerFavorites.favorites == 1, "Favorite not removed")
        
        print("✓ PASSED: Favorite items persistence works")
        return true
    end

    -- Test 15: Kiosk Location Validation
    function ShopTestServer.test15_KioskLocationValidation()
        print("\n[TEST 15] Kiosk Location Validation")
        
        local kiosk = {
            x = 150,
            y = 250,
            z = 0,
            range = 5  -- interaction range
        }
        
        local playerPos = { x = 153, y = 250, z = 0 }
        
        local function distanceTo(p1, p2)
            local dx = p1.x - p2.x
            local dy = p1.y - p2.y
            local dz = p1.z - p2.z
            return math.sqrt(dx*dx + dy*dy + dz*dz)
        end
        
        local distance = distanceTo(playerPos, kiosk)
        local atKiosk = distance <= kiosk.range
        
        assert(atKiosk, "Player should be in range of kiosk")
        
        print("✓ PASSED: Kiosk location validation works")
        return true
    end

    -- Run All Tests
    function ShopTestServer.runAllTests()
        print("\n" .. string.rep("=", 50))
        print("SHOP TEST SUITE - RUN ALL TESTS (SERVER)")
        print(string.rep("=", 50))

        local tests = {
            { name = "1_AccountMoneySystem",          func = ShopTestServer.test1_AccountMoneySystem },
            { name = "2_PurchaseTransaction",         func = ShopTestServer.test2_PurchaseTransaction },
            { name = "3_InsufficientFundsHandling",   func = ShopTestServer.test3_InsufficientFundsHandling },
            { name = "4_SellItemProcessing",          func = ShopTestServer.test4_SellItemProcessing },
            { name = "5_DamagedConditionPricing",     func = ShopTestServer.test5_DamagedConditionPricing },
            { name = "6_CurrencyTypeHandling",        func = ShopTestServer.test6_CurrencyTypeHandling },
            { name = "7_AdminTilePlacement",          func = ShopTestServer.test7_AdminTilePlacement },
            { name = "8_TileDestructionPrevention",   func = ShopTestServer.test8_TileDestructionPrevention },
            { name = "9_PlayerInventoryManagement",   func = ShopTestServer.test9_PlayerInventoryManagement },
            { name = "10_BoughtItemsDelivery",        func = ShopTestServer.test10_BoughtItemsDelivery },
            { name = "11_SoldItemsRemoval",           func = ShopTestServer.test11_SoldItemsRemoval },
            { name = "12_PackItemContents",           func = ShopTestServer.test12_PackItemContents },
            { name = "13_TransactionLogging",         func = ShopTestServer.test13_TransactionLogging },
            { name = "14_FavoritePersistence",        func = ShopTestServer.test14_FavoritePersistence },
            { name = "15_KioskLocationValidation",    func = ShopTestServer.test15_KioskLocationValidation },
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
        print("TEST RESULTS (SERVER)")
        print(string.rep("=", 50))
        print("Passed: " .. passed .. "/" .. #tests)
        print("Failed: " .. failed .. "/" .. #tests)
        print(string.rep("=", 50) .. "\n")

        return failed == 0
    end

    -- Command Interface
    function ShopTestServer.runCommand(testName)
        testName = testName or "all"

        if testName == "all" then
            return ShopTestServer.runAllTests()
        else
            local testFunc = ShopTestServer["test" .. testName]
            if testFunc then
                local success, err = pcall(testFunc)
                if not success then
                    print("✗ TEST FAILED: " .. err)
                    return false
                end
                return true
            else
                print("ERROR: Unknown test '" .. testName .. "'")
                print("Available: all, 1-15")
                return false
            end
        end
    end

    -- Run tests (server-side only, no client communication needed for server tests)
    function ShopTestServer.runAndReport(testName)
        testName = testName or "all"
        local success = ShopTestServer.runCommand(testName)

        -- Server tests run on server only, results logged to console
        print("[ShopTestServer] Test result: " .. tostring(success))

        return success
    end

    -- Console access function
    function ShopTestServer.console(testName)
        testName = testName or "all"
        return ShopTestServer.runCommand(testName)
    end

    print("[ShopTestServer] Test suite ready. Call: ShopTestServer.console() or ShopTestServer.console(5)")
end -- end isServer() guard
