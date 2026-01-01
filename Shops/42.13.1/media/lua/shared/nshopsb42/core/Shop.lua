-- Shop.lua (Shared Constants)
-- Shared shop UI configuration needed by both client and server
-- Extends SHOPSB42 namespace (no new globals)

SHOPSB42.Shop = SHOPSB42.Shop or {}
SHOPSB42.Tab = SHOPSB42.Tab or {}

local Shop = SHOPSB42.Shop
local Tab = SHOPSB42.Tab

-- Initialize Shop subtables
Shop.Items = Shop.Items or {}
Shop.Tabs = Shop.Tabs or {}
Shop.PlayerBuy = Shop.PlayerBuy or {}
Shop.PlayerSell = Shop.PlayerSell or {}

-- Price hook revision counter (tracks mutations post-finalization)
Shop.PriceHookRevision = 0

-- Define Tab constants needed by all code
Tab.Favorite = "Favorite"
Tab.Sell = "Sell"
Tab.All = "All"
Tab.Food = "Food"
Tab.Weapons = "Weapons"
Tab.Vehicles = "Vehicles"
Tab.FirstAid = "FirstAid"
Tab.Event = "Event"

-- Shop UI Configuration (used by both client and server)
Shop.Sell = Shop.Sell or {}
Shop.SellisWhitelist = false -- true = whitelist mode, false = blacklist mode
Shop.defaultPrice = 1
Shop.defaultPriceBroken = 1

-- NPC shop sprite names (used by client UI)
Shop.spritePrefix = "npcshop_"
Shop.sprites = {
	FemaleA = {
		"npcshop_0",
		"npcshop_1",
	},
	FemaleB = {
		"npcshop_2",
		"npcshop_3",
	},
	MaleA = {
		"npcshop_4",
		"npcshop_5",
	},
	MaleB = {
		"npcshop_6",
		"npcshop_7",
	},
}

-- Shop UI textures and buttons (used by client)
Shop.textures = {
	AddButton = {
		texture = getTexture("media/textures/ShopUI_Add.png"),
		scale = 20,
	},
	RemoveButton = {
		texture = getTexture("media/textures/ShopUI_Remove.png"),
		scale = 20,
	},
	PreviewButton = {
		texture = getTexture("media/textures/ShopUI_Preview.png"),
		scale = 20,
	},
	Browse = {
		texture = getTexture("media/textures/ShopUI_Browse.png"),
		scale = 20,
	},
	Cart = {
		texture = getTexture("media/textures/ShopUI_Cart.png"),
		scale = 30,
	},
	Sort = {
		texture = getTexture("media/textures/ShopUI_Sort.png"),
	},
	MoveAll = {
		texture = getTexture("media/textures/ShopUI_MoveAll.png"),
	},
}

-- Register tab display names (used by client UI and server for reference)
Shop.Tabs[Tab.Favorite] = getText("IGUI_Tab_Favorite")
Shop.Tabs[Tab.Sell] = getText("IGUI_Tab_Sell")
Shop.Tabs[Tab.All] = getText("IGUI_Tab_All")
Shop.Tabs[Tab.Food] = getText("IGUI_Tab_Food")
Shop.Tabs[Tab.Weapons] = getText("IGUI_Tab_Weapons")
Shop.Tabs[Tab.Vehicles] = getText("IGUI_Tab_Vehicles")
Shop.Tabs[Tab.FirstAid] = getText("IGUI_Tab_FirstAid")
Shop.Tabs[Tab.Event] = getText("IGUI_Tab_Event")

return Shop
