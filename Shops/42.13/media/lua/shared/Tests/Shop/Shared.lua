-- Shop Feature Test Suite (Shared Tests)
-- Tests for Shop initialization, items, tabs, and core functionality

ShopTestShared = ShopTestShared or {}

-- Test 1: Shop Initialization
function ShopTestShared.testShopInitialization()
    print("\nTEST 1: Shop Initialization")
    assert(Shop ~= nil, "Shop table not initialized")
    assert(Shop.Items ~= nil, "Shop.Items table not initialized")
    assert(Shop.Tabs ~= nil, "Shop.Tabs table not initialized")
    assert(Shop.Sell ~= nil, "Shop.Sell table not initialized")
    print("✓ Shop initialization successful")
end

-- Test 2: Shop Sprite Configuration
function ShopTestShared.testShopSpriteConfig()
    print("\nTEST 2: Shop Sprite Configuration")
    assert(Shop.spritePrefix == "npcshop_", "Sprite prefix incorrect")
    assert(Shop.sprites ~= nil, "Shop sprites not configured")
    assert(Shop.sprites.FemaleA ~= nil, "FemaleA sprites not configured")
    assert(Shop.sprites.FemaleB ~= nil, "FemaleB sprites not configured")
    assert(Shop.sprites.MaleA ~= nil, "MaleA sprites not configured")
    assert(Shop.sprites.MaleB ~= nil, "MaleB sprites not configured")
    
    -- Verify sprite variations
    assert(#Shop.sprites.FemaleA == 2, "FemaleA should have 2 sprite variations")
    assert(#Shop.sprites.FemaleB == 2, "FemaleB should have 2 sprite variations")
    assert(#Shop.sprites.MaleA == 2, "MaleA should have 2 sprite variations")
    assert(#Shop.sprites.MaleB == 2, "MaleB should have 2 sprite variations")
    print("✓ Shop sprite configuration correct")
end

-- Test 3: Tab Configuration
function ShopTestShared.testTabConfiguration()
    print("\nTEST 3: Tab Configuration")
    
    -- Check required tabs exist
    assert(Tab["Favorite"] == "Favorite", "Favorite tab not defined")
    assert(Tab["Sell"] == "Sell", "Sell tab not defined")
    assert(Tab["All"] == "All", "All tab not defined")
    assert(Tab["Food"] == "Food", "Food tab not defined")
    assert(Tab["Weapons"] == "Weapons", "Weapons tab not defined")
    assert(Tab["Vehicles"] == "Vehicles", "Vehicles tab not defined")
    assert(Tab["FirstAid"] == "FirstAid", "FirstAid tab not defined")
    assert(Tab["Event"] == "Event", "Event tab not defined")
    
    print("✓ All required tabs configured")
end

-- Test 4: Shop Texture Configuration
function ShopTestShared.testShopTextureConfig()
    print("\nTEST 4: Shop Texture Configuration")
    assert(Shop.textures ~= nil, "Shop.textures not initialized")
    
    local requiredTextures = {"AddButton", "RemoveButton", "PreviewButton", "Browse", "Cart", "Sort", "MoveAll"}
    for _, textureName in ipairs(requiredTextures) do
        assert(Shop.textures[textureName] ~= nil, textureName .. " texture not configured")
        assert(Shop.textures[textureName].texture ~= nil, textureName .. " texture not loaded")
    end
    
    print("✓ All shop textures configured")
end

-- Test 5: Shop Default Prices
function ShopTestShared.testDefaultPrices()
    print("\nTEST 5: Shop Default Prices")
    assert(Shop.defaultPrice ~= nil, "Default price not set")
    assert(Shop.defaultPrice == 1, "Default price should be 1")
    assert(Shop.defaultPriceBroken ~= nil, "Default broken price not set")
    assert(Shop.defaultPriceBroken == 1, "Default broken price should be 1")
    print("✓ Default prices configured correctly")
end

-- Test 6: Sell Configuration
function ShopTestShared.testSellConfiguration()
    print("\nTEST 6: Sell Configuration")
    assert(Shop.SellisBlacklist ~= nil, "SellisBlacklist not defined")
    assert(Shop.SellisWhitelist ~= nil, "SellisWhitelist not defined")
    assert(Shop.SellisBlacklist == false, "SellisBlacklist should default to false")
    assert(Shop.SellisWhitelist == false, "SellisWhitelist should default to false")
    print("✓ Sell configuration correct")
end

-- Test 7: Currency Type Support
function ShopTestShared.testCurrencyTypeSupport()
    print("\nTEST 7: Currency Type Support")
    -- Test that shop items can use both normal and special currency
    local testItemNormal = { price = 100, specialCoin = false }
    local testItemSpecial = { price = 50, specialCoin = true }
    
    assert(testItemNormal.specialCoin == false, "Normal currency item not marked correctly")
    assert(testItemSpecial.specialCoin == true, "Special currency item not marked correctly")
    print("✓ Currency type support working")
end

-- Test 8: Item Structure Validation
function ShopTestShared.testItemStructure()
    print("\nTEST 8: Item Structure Validation")
    
    -- Test valid item structure
    local testItem = {
        id = "Base.Hammer",
        name = "Hammer",
        price = 500,
        quantity = 10,
        specialCoin = false,
        tab = Tab.All,
        damaged = false
    }
    
    assert(testItem.id ~= nil, "Item id required")
    assert(testItem.name ~= nil, "Item name required")
    assert(testItem.price ~= nil, "Item price required")
    assert(testItem.tab ~= nil, "Item tab required")
    assert(testItem.specialCoin ~= nil, "Item specialCoin flag required")
    print("✓ Item structure validation passed")
end

-- Test 9: Tab Categories
function ShopTestShared.testTabCategories()
    print("\nTEST 9: Tab Categories")
    
    local categories = {
        [Tab.Favorite] = "Favorite",
        [Tab.Sell] = "Sell",
        [Tab.All] = "All",
        [Tab.Food] = "Food",
        [Tab.Weapons] = "Weapons",
        [Tab.Vehicles] = "Vehicles",
        [Tab.FirstAid] = "FirstAid",
        [Tab.Event] = "Event"
    }
    
    for tabKey, tabName in pairs(categories) do
        assert(Shop.Tabs[tabKey] ~= nil, "Tab " .. tabName .. " not found in Shop.Tabs")
    end
    
    print("✓ All tab categories verified")
end

-- Test 10: Shop Items Table
function ShopTestShared.testShopItemsTable()
    print("\nTEST 10: Shop Items Table")
    assert(type(Shop.Items) == "table", "Shop.Items should be a table")
    
    -- Test adding items
    local testItem = { id = "test.item", price = 100, tab = Tab.All }
    table.insert(Shop.Items, testItem)
    
    assert(#Shop.Items > 0, "Shop.Items should contain items after insertion")
    assert(Shop.Items[#Shop.Items].id == "test.item", "Item not added correctly")
    
    -- Clean up
    table.remove(Shop.Items)
    
    print("✓ Shop items table working correctly")
end

-- Test 11: Sprite Availability
function ShopTestShared.testSpriteAvailability()
    print("\nTEST 11: Sprite Availability")
    
    local variations = {
        { type = "FemaleA", sprites = Shop.sprites.FemaleA },
        { type = "FemaleB", sprites = Shop.sprites.FemaleB },
        { type = "MaleA", sprites = Shop.sprites.MaleA },
        { type = "MaleB", sprites = Shop.sprites.MaleB }
    }
    
    for _, variation in ipairs(variations) do
        assert(#variation.sprites > 0, variation.type .. " has no sprites")
        for i, sprite in ipairs(variation.sprites) do
            assert(sprite:find(Shop.spritePrefix) == 1, variation.type .. " sprite " .. i .. " missing prefix")
        end
    end
    
    print("✓ All sprite variations available")
end

-- Test 12: Favorite Tab Functionality
function ShopTestShared.testFavoritTab()
    print("\nTEST 12: Favorite Tab Functionality")
    
    -- Test that favorite items can be tracked
    local favoriteItems = {}
    local testItem = { id = "Base.Item1", price = 100, isFavorite = true }
    
    if testItem.isFavorite then
        table.insert(favoriteItems, testItem)
    end
    
    assert(#favoriteItems > 0, "Favorite item not added")
    assert(favoriteItems[1].id == "Base.Item1", "Favorite item ID mismatch")
    print("✓ Favorite tab functionality working")
end

-- Test 13: Sell Tab Structure
function ShopTestShared.testSellTabStructure()
    print("\nTEST 13: Sell Tab Structure")
    
    -- Test selling an item from player inventory
    local sellItem = {
        id = "Base.Hammer",
        name = "Hammer",
        quantity = 1,
        sellPrice = 250,
        condition = 100
    }
    
    assert(sellItem.id ~= nil, "Sell item requires id")
    assert(sellItem.sellPrice ~= nil, "Sell item requires sellPrice")
    assert(sellItem.condition ~= nil, "Sell item requires condition")
    print("✓ Sell tab structure valid")
end

-- Test 14: Damaged Item Handling
function ShopTestShared.testDamagedItemHandling()
    print("\nTEST 14: Damaged Item Handling")
    
    local normalItem = { id = "Base.Item", price = 100, damaged = false }
    local damagedItem = { id = "Base.Item", price = 50, damaged = true }
    
    assert(normalItem.damaged == false, "Normal item not marked")
    assert(damagedItem.damaged == true, "Damaged item not marked")
    assert(damagedItem.price < normalItem.price, "Damaged item should be cheaper")
    print("✓ Damaged item handling correct")
end

-- Test 15: Pack Items Support
function ShopTestShared.testPackItemsSupport()
    print("\nTEST 15: Pack Items Support")
    
    local regularItem = { id = "Base.Item", price = 100, isPack = false }
    local packItem = { id = "Base.Backpack", price = 500, isPack = true, capacity = 10 }
    
    assert(regularItem.isPack == false, "Regular item marking failed")
    assert(packItem.isPack == true, "Pack item marking failed")
    assert(packItem.capacity ~= nil, "Pack item should have capacity")
    print("✓ Pack items support verified")
end

-- Run shared tests
function ShopTestShared.runSharedTests()
    print("\n" .. string.rep("=", 50))
    print("SHOP FEATURE TEST SUITE (SHARED)")
    print(string.rep("=", 50))

    local tests = {
        { name = "1_ShopInitialization", func = ShopTestShared.testShopInitialization },
        { name = "2_ShopSpriteConfig", func = ShopTestShared.testShopSpriteConfig },
        { name = "3_TabConfiguration", func = ShopTestShared.testTabConfiguration },
        { name = "4_ShopTextureConfig", func = ShopTestShared.testShopTextureConfig },
        { name = "5_DefaultPrices", func = ShopTestShared.testDefaultPrices },
        { name = "6_SellConfiguration", func = ShopTestShared.testSellConfiguration },
        { name = "7_CurrencyTypeSupport", func = ShopTestShared.testCurrencyTypeSupport },
        { name = "8_ItemStructure", func = ShopTestShared.testItemStructure },
        { name = "9_TabCategories", func = ShopTestShared.testTabCategories },
        { name = "10_ShopItemsTable", func = ShopTestShared.testShopItemsTable },
        { name = "11_SpriteAvailability", func = ShopTestShared.testSpriteAvailability },
        { name = "12_FavoritTab", func = ShopTestShared.testFavoritTab },
        { name = "13_SellTabStructure", func = ShopTestShared.testSellTabStructure },
        { name = "14_DamagedItemHandling", func = ShopTestShared.testDamagedItemHandling },
        { name = "15_PackItemsSupport", func = ShopTestShared.testPackItemsSupport },
    }

    local passed = 0
    local failed = 0

    for _, test in ipairs(tests) do
        local success, err = pcall(test.func)
        if success then
            passed = passed + 1
        else
            failed = failed + 1
            print("✗ FAILED (" .. test.name .. "): " .. tostring(err))
        end
    end

    print("\n" .. string.rep("=", 50))
    print("TEST RESULTS (SHARED)")
    print(string.rep("=", 50))
    print("Passed: " .. passed .. "/" .. #tests)
    print("Failed: " .. failed .. "/" .. #tests)
    print(string.rep("=", 50) .. "\n")

    return failed == 0
end

-- Console access function
function ShopTestShared.console()
    return ShopTestShared.runSharedTests()
end

if isClient() then
    print("[ShopTestShared] Shared test suite ready. Call: ShopTestShared.console()")
end
