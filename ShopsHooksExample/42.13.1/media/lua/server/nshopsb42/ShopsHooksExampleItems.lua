-- ShopsHooksExampleItems.lua
-- Item registration loader for ShopsHooksExample
-- Simply loads all item files from ShopItems/ folder
-- Modders can edit files in ShopItems/ to add items - no complex code needed

-- Just load all the item files - they register themselves
require("nshopsb42/ShopItems/Food")
require("nshopsb42/ShopItems/Weapons")
require("nshopsb42/ShopItems/FirstAid")
require("nshopsb42/ShopItems/ForSell")

-- Return empty table for compatibility
return {}
