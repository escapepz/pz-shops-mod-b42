-- DeterminismTest.lua
-- Phase 5: Runtime determinism verification
-- Runs price calculations 100x with identical inputs, verifies outputs match

local SharedLogger = require("nshopsb42/utils/SharedLogger")
local Validator = require("nshopsb42/pricing/DeterminismValidator")
local PricingContract = require("nshopsb42/pricing/PricingContract")

SHOPSB42.DeterminismTest = SHOPSB42.DeterminismTest or {}
local DeterminismTest = SHOPSB42.DeterminismTest

-- Test cases for determinism
local TEST_CASES = {
	{
		name = "Buy price: No modifiers",
		func = "calculateBuyPrice",
		inputs = {
			itemId = "Base.Apple",
			shopId = "npc_general_store",
			basePrice = 50,
			playerSnapshot = { traits = {} },
			modifiers = nil,
		},
		expectedApproximatePrice = 50,
	},
	{
		name = "Buy price: Single modifier",
		func = "calculateBuyPrice",
		inputs = {
			itemId = "Base.Axe",
			shopId = "npc_general_store",
			basePrice = 100,
			playerSnapshot = { traits = {} },
			modifiers = {
				{ multiplier = 1.5, priority = 10 },
			},
		},
		expectedApproximatePrice = 150,
	},
	{
		name = "Buy price: Multiple modifiers sorted by priority",
		func = "calculateBuyPrice",
		inputs = {
			itemId = "Base.Screwdriver",
			shopId = "npc_general_store",
			basePrice = 30,
			playerSnapshot = { traits = {} },
			modifiers = {
				{ multiplier = 1.2, priority = 20 },
				{ multiplier = 1.1, priority = 10 },
			},
		},
		expectedApproximatePrice = 30 * 1.1 * 1.2, -- Applied in priority order
	},
	{
		name = "Sell price: No modifiers",
		func = "calculateSellPrice",
		inputs = {
			itemId = "Base.Apple",
			shopId = "npc_general_store",
			basePrice = 25,
			itemSnapshot = { condition = 1.0 },
			modifiers = nil,
		},
		expectedApproximatePrice = 25,
	},
	{
		name = "Sell price: With condition modifier",
		func = "calculateSellPrice",
		inputs = {
			itemId = "Base.Axe",
			shopId = "npc_general_store",
			basePrice = 50,
			itemSnapshot = { condition = 0.5 },
			modifiers = {
				{ multiplier = 0.5, priority = 10 },
			},
		},
		expectedApproximatePrice = 50 * 0.5,
	},
}

---
-- Serialize a result table for comparison
-- Converts price tables to strings for exact matching
--
-- @param result table|nil - Result from price function
-- @return string - String representation
--
local function serializeResult(result)
	if not result then
		return "nil"
	end

	if type(result) ~= "table" then
		return tostring(result)
	end

	-- Serialize table: { finalPrice = X, revision = Y }
	return "finalPrice=" .. (result.finalPrice or 0) .. ",revision=" .. (result.revision or 0)
end

---
-- Run 100 iterations of a price calculation with identical inputs
-- Verify all outputs are identical
--
-- @param testCase table - { name, func, inputs, expectedApproximatePrice }
-- @return boolean - true if all 100 runs produced identical output
-- @return table - { passed = bool, testName = str, runs = num, violations = table }
--
function DeterminismTest.runTest(testCase)
	if not testCase or not testCase.func then
		return false, { passed = false, error = "Invalid test case" }
	end

	local func = PricingContract[testCase.func]
	if type(func) ~= "function" then
		return false, { passed = false, error = "Function " .. testCase.func .. " not found" }
	end

	local results = {}
	local numRuns = 100
	local firstOutput = nil
	local violations = {}

	-- Run the function 100 times
	for run = 1, numRuns do
		local result = func(
			testCase.inputs.itemId,
			testCase.inputs.shopId,
			testCase.inputs.basePrice,
			testCase.inputs.playerSnapshot,
			testCase.inputs.modifiers
		)

		local serialized = serializeResult(result)

		if run == 1 then
			firstOutput = serialized
		elseif serialized ~= firstOutput then
			table.insert(violations, {
				run = run,
				expected = firstOutput,
				got = serialized,
			})
		end

		results[run] = result
	end

	local passed = #violations == 0
	return passed,
		{
			passed = passed,
			testName = testCase.name,
			func = testCase.func,
			runs = numRuns,
			violations = violations,
			firstOutput = firstOutput,
			inputs = testCase.inputs,
		}
end

---
-- Run all determinism tests
-- Logs results and returns summary
--
-- @return table - Summary of all test results
--
function DeterminismTest.runAllTests()
	SharedLogger.log("Shops", "[DeterminismTest] Starting determinism test suite (" .. #TEST_CASES .. " tests)...")

	local summary = {
		passed = 0,
		failed = 0,
		tests = {},
		startTime = os.time(),
	}

	for _, testCase in ipairs(TEST_CASES) do
		local testPassed, testResult = DeterminismTest.runTest(testCase)

		table.insert(summary.tests, testResult)

		if testPassed then
			summary.passed = summary.passed + 1
			SharedLogger.log("Shops", "  OK " .. testResult.testName)
		else
			summary.failed = summary.failed + 1
			SharedLogger.log("Shops", "  FAILED " .. testResult.testName)

			-- Log violation details
			if testResult.violations then
				for _, violation in ipairs(testResult.violations) do
					SharedLogger.log(
						"Shops",
						"    Run " .. violation.run .. ": Expected " .. violation.expected .. ", got " .. violation.got
					)
				end
			end
		end
	end

	summary.endTime = os.time()
	summary.duration = (summary.endTime - summary.startTime) or 0

	-- Log summary
	SharedLogger.log(
		"Shops",
		"[DeterminismTest] Results: " .. summary.passed .. " passed, " .. summary.failed .. " failed"
	)
	if summary.duration > 0 then
		SharedLogger.log("Shops", "[DeterminismTest] Duration: " .. summary.duration .. " seconds")
	end

	return summary
end

---
-- Verify no forbidden operations appear in price functions
-- Scans source code for forbidden patterns
--
-- @return table - Validation result { passed = bool, violations = table }
--
function DeterminismTest.validateSourceCode()
	SharedLogger.log("Shops", "[DeterminismTest] Validating source code for forbidden operations...")

	-- This would require access to function source, which Kahlua JVM doesn't provide
	-- Instead, rely on:
	-- 1. Code review (developer inspection)
	-- 2. Runtime testing (this test suite)
	-- 3. Assertions in price functions

	SharedLogger.log("Shops", "[DeterminismTest] Source code validation requires manual code review")
	SharedLogger.log(
		"Shops",
		"[DeterminismTest] Forbidden operations to check: ZombRand, os.time, GameTime, pairs() on maps, next()"
	)

	return { passed = true, violations = {} }
end

---
-- Run complete determinism validation
-- Includes source code validation + runtime tests
--
-- @return boolean - true if all tests pass
--
function DeterminismTest.runComplete()
	SharedLogger.log("Shops", "[DeterminismTest] Running complete determinism validation...")

	-- Validate source code
	DeterminismTest.validateSourceCode()

	-- Run all runtime tests
	local summary = DeterminismTest.runAllTests()

	---@diagnostic disable-next-line: unnecessary-if
	-- Log final result
	if summary.failed == 0 then
		SharedLogger.log("Shops", "[DeterminismTest] OKOKOK ALL DETERMINISM TESTS PASSED OKOKOK")
		return true
	else
		SharedLogger.log(
			"Shops",
			"[DeterminismTest] FAILEDFAILEDFAILED " .. summary.failed .. " TEST(S) FAILED FAILEDFAILEDFAILED"
		)
		return false
	end
end

---
-- Verify dev-only mismatch detection (optional enhancement)
-- Compare client preview vs server price (if both available)
--
-- @param clientPrice number - Price calculated client-side
-- @param serverPrice number - Price calculated server-side
-- @param itemId string - Item being tested
-- @return boolean - true if prices match
--
function DeterminismTest.compareClientServerPrices(clientPrice, serverPrice, itemId)
	if clientPrice == serverPrice then
		return true
	end

	-- Mismatch detected - log silently for debugging
	local diff = math.abs(clientPrice - serverPrice)
	SharedLogger.log(
		"Shops",
		"[DeterminismTest] Price mismatch for "
			.. itemId
			.. ": client="
			.. clientPrice
			.. " server="
			.. serverPrice
			.. " (diff="
			.. diff
			.. ")"
	)

	return false
end

return DeterminismTest
