-- Phase 2.3: Client-side transaction validation and price mismatch handling
-- Purpose: Validate server prices against client preview prices without triggering resync

local TxnValidation = {}

-- Track the last transaction for validation
local lastTransaction = {
	itemIds = {}, -- List of item IDs in the cart
	previewPrices = {}, -- Client-side preview prices (item -> price)
	totalPreview = 0, -- Total client preview cost
	txnId = nil, -- Transaction ID
}

-- Phase 2.3: Record a transaction before sending to server
-- Called when player clicks "Buy" button
function TxnValidation.recordTransaction(txnId, cartItems, previewPriceMap)
	if not txnId or not cartItems then
		return
	end

	local totalPreview = 0
	lastTransaction.itemIds = {}
	lastTransaction.previewPrices = {}
	lastTransaction.txnId = txnId

	-- Calculate total preview cost from cart items
	for i, cartItem in pairs(cartItems.items or {}) do
		local itemId = cartItem.item.type
		local itemPrice = cartItem.item.price

		if itemId and itemPrice then
			table.insert(lastTransaction.itemIds, itemId)
			lastTransaction.previewPrices[itemId] = itemPrice
			totalPreview = totalPreview + itemPrice
		end
	end

	lastTransaction.totalPreview = totalPreview

	SHOPSB42.SharedLogger.log(
		"Shops",
		"[TransactionValidationClient:recordTransaction] txnId="
			.. txnId
			.. " itemCount="
			.. #lastTransaction.itemIds
			.. " totalPreview="
			.. totalPreview
	)
end

-- Phase 2.3: Validate transaction result against recorded cart
-- Called when CoinBalance is updated after a transaction
-- Returns (isValid, details)
function TxnValidation.validateTransaction(txnId, balanceDelta, tolerance)
	tolerance = tolerance or 1

	-- If no transaction was recorded, we can't validate
	if not lastTransaction.txnId or lastTransaction.txnId ~= txnId then
		return true, "no_prior_transaction"
	end

	-- balanceDelta should match what was deducted (negative for spend)
	local actualDelta = math.abs(balanceDelta)
	local expectedDelta = lastTransaction.totalPreview

	-- Check if delta is within tolerance
	local diff = math.abs(actualDelta - expectedDelta)
	if diff > tolerance then
		SHOPSB42.SharedLogger.log(
			"Shops",
			"[TransactionValidationClient:validateTransaction] Price mismatch detected!"
				.. " txnId="
				.. txnId
				.. " expectedDelta="
				.. expectedDelta
				.. " actualDelta="
				.. actualDelta
				.. " diff="
				.. diff
				.. " tolerance="
				.. tolerance
		)
		return false, {
			expectedDelta = expectedDelta,
			actualDelta = actualDelta,
			diff = diff,
		}
	end

	SHOPSB42.SharedLogger.log(
		"Shops",
		"[TransactionValidationClient:validateTransaction] Transaction validated successfully"
			.. " txnId="
			.. txnId
			.. " delta="
			.. actualDelta
	)
	return true, nil
end

-- Phase 2.3: Clear recorded transaction (called after validation)
function TxnValidation.clearTransaction()
	lastTransaction = {
		itemIds = {},
		previewPrices = {},
		totalPreview = 0,
		txnId = nil,
	}
end

-- Phase 2.3: Get last recorded transaction (for debugging)
function TxnValidation.getLastTransaction()
	-- Return the table directly (Kahlua doesn't support table.copy)
	-- Safe because we only read from it
	return lastTransaction
end

-- Phase 3c: Handle targeted transaction result from server
function TxnValidation.handleTransactionResult(data)
	if not data then
		SHOPSB42.SharedLogger.log("Shops", "[TransactionValidationClient:handleTransactionResult] No data provided")
		return
	end

	local txnId = data.txnId
	local txnType = data.type
	local success = data.success

	SHOPSB42.SharedLogger.log(
		"Shops",
		"[TransactionValidationClient:handleTransactionResult] Received - txnId="
			.. (txnId or "unknown")
			.. " type="
			.. (txnType or "unknown")
			.. " success="
			.. tostring(success)
	)

	-- Log settlement details
	if success then
		if txnType == "BUY" then
			SHOPSB42.SharedLogger.log(
				"Shops",
				"[TransactionValidationClient:handleTransactionResult] BUY confirmed - "
					.. "cost="
					.. (data.finalCost or 0)
					.. " newBalance="
					.. (data.newBalance or 0)
			)
		elseif txnType == "SELL" then
			SHOPSB42.SharedLogger.log(
				"Shops",
				"[TransactionValidationClient:handleTransactionResult] SELL confirmed - "
					.. "revenue="
					.. (data.finalRevenue or 0)
					.. " newBalance="
					.. (data.newBalance or 0)
			)
		end
	else
		SHOPSB42.SharedLogger.log("Shops", "[TransactionValidationClient:handleTransactionResult] Transaction FAILED")
	end

	-- Clear recorded transaction after result received
	TxnValidation.clearTransaction()
end

SHOPSB42.TransactionValidationClient = TxnValidation
return TxnValidation
