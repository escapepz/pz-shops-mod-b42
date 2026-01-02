-- Init.lua (Shared)
-- Shared module initialization with explicit load order

local SharedLogger = require("nshopsb42/utils/SharedLogger")
local Utilities = require("nshopsb42/utils/Utilities")

require("nshopsb42/core/Shop")
require("nshopsb42/core/Balance")
require("nshopsb42/core/Currency")
require("nshopsb42/core/ShopRegistry")
require("nshopsb42/sales/ShopSellRegistry")
require("nshopsb42/events/ShopEvents")
require("nshopsb42/sales/ShopSellEvents")

-- CRITICAL FIX: Only load item registration and initialization on server/SP
-- Client should receive this data via network sync, not register items locally
if not Utilities.IsClientOrSinglePlayer() then
	require("nshopsb42/ShopInit")
	require("nshopsb42/sales/ShopSellInit")
	require("nshopsb42/ShopDefaultItems")
	SharedLogger.log("Shops", "[Shared Init] Server context: loaded item registration modules")
else
	SharedLogger.log(
		"Shops",
		"[Shared Init] Client context: skipping item registration modules (will receive via sync)"
	)
end

require("nshopsb42/audit/ShopAudit")
require("nshopsb42/core/TransactionRegistry")
require("nshopsb42/pricing/ShopPriceUtils")
require("nshopsb42/pricing/ShopPriceEvents")
require("nshopsb42/pricing/ShopPriceBuy")
require("nshopsb42/pricing/ShopPriceSell")
require("nshopsb42/pricing/ShopPriceCalculatorShared")
require("nshopsb42/pricing/ShopPriceModifierBuilder")
require("nshopsb42/utils/ShopUIText")
require("nshopsb42/core/PlayerShop")
require("nshopsb42/validation/InventoryTransferValidation")
require("nshopsb42/utils/Nfunction")

-- Note: Timed actions (ShopBuyAction, ShopSellAction, SendTransferAction, PlayerShopBuyAction)
-- are now loaded in client/nshopsb42/AClientInit.lua instead of here, since they depend on
-- client-only ISBaseTimedAction class. Server does not need them.

-- Note: ShopSpriteCursorUI is now client-only (moved to client/ directory)
-- It is loaded by client/nshopsb42/AClientInit.lua
