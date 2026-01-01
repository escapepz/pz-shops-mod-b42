-- Balance.lua
-- Virtual currency balance management
-- Extends SHOPSB42 namespace (no new globals)

local Utilities = require("nshopsb42/utils/Utilities")

SHOPSB42.Balance = SHOPSB42.Balance or {}
local Balance = SHOPSB42.Balance

function Balance.getUserAccount(username)
	local coinBalance = ModData.get("nshopsb42_CoinBalance")
	if not coinBalance then
		return nil
	end
	return coinBalance[username]
end

function Balance.getUserBalance(username)
	local account = Balance.getUserAccount(username)
	local coin = 0
	local specialCoin = 0
	if not account then
		return coin, specialCoin
	end
	if account.coin then
		coin = account.coin
	end
	if account.specialCoin then
		specialCoin = account.specialCoin
	end
	return coin, specialCoin
end

function Balance.getAccountsList()
	local accounts = {}
	local coinBalance = ModData.get("nshopsb42_CoinBalance")
	if not coinBalance then
		return accounts
	end
	for k, v in pairs(coinBalance) do
		table.insert(accounts, k)
	end
	return accounts
end

-- Virtual balance deposit (no physical coin items required)
-- Used for player shop income, quest rewards, and other sources of virtual currency
function Balance.deposit(username, coin, specialCoin)
	if not Utilities.IsServerOrSinglePlayer() then
		return
	end

	coin = coin or 0
	specialCoin = specialCoin or 0

	-- Reject zero-value deposits
	if coin <= 0 and specialCoin <= 0 then
		return
	end

	sendClientCommand(getPlayer(), "shops", "VirtualDeposit", {
		username = username,
		coin = coin,
		specialCoin = specialCoin,
		source = "PlayerShopIncome",
	})
end

return Balance
