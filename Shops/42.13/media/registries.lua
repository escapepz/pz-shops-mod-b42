-- Shops Registry Configuration

-- Helper function to safely register items
local function safeRegister(registryName, itemName)
    local registry = _G[registryName]
    if not registry then return end

    local keyName = string.gsub(itemName, ":", "_")
    if registry[keyName] then return end -- Already registered

    if registryName == "CharacterTrait" then
        CharacterTrait.register(itemName)
    elseif registryName == "CharacterProfession" then
        CharacterProfession.register(itemName)
    elseif registryName == "ItemTag" then
        ItemTag.register(itemName)
    elseif registryName == "MoodleType" then
        MoodleType.register(itemName)
    elseif registryName == "WeaponCategory" then
        WeaponCategory.register(itemName)
    end
end

-- Core Registry Items
safeRegister("CharacterTrait", "shops:merchant")
safeRegister("CharacterProfession", "shops:shopkeeper")
safeRegister("ItemTag", "shops:merchandise")
safeRegister("ItemTag", "shops:PlayerShop")
safeRegister("ItemTag", "shops:PlayerShopFreezer")
safeRegister("ItemTag", "shops:Write")
safeRegister("MoodleType", "shops:haggled")
safeRegister("WeaponCategory", "shops:tools")

-- Note: Craft Recipes are defined in S_Recipes.txt, not registered here

-- Shop-specific registries (adapt as needed)
--Brochure.register("shops:StoreAd")
--Flier.register("shops:SaleFlier")
--Newspaper.register("shops:ShopsNews")
