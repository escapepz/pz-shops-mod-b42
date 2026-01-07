-- ShopCatalog.lua (Shared)
-- Tier 0: Built-in default listing (always available, revision 0)
-- This is the bootstrap floor for UI initialization
-- Used by both client (for bootstrap) and server (for reference)

-- Bootstrap default catalog with minimal items
-- This ensures UI can initialize even if server is offline or unreachable
SHOPSB42.ShopCatalog = {
	revision = 0,
	Items = {},
	PlayerBuy = {},
	PlayerSell = {},
	BuyIsWhitelist = true,
	SellIsWhitelist = false,
	defaultPrice = 100,
	defaultPriceBroken = 50,
}

return SHOPSB42.ShopCatalog
