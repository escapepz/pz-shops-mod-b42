Based on the audit verification just completed, here's the refactoring roadmap:

## Immediate Priority: Task 6.1.5 - Critical Bug Fixes

### 3 Critical Vulnerabilities to Fix

| Priority         | Risk              | File                               | Fix                                                        |
| ---------------- | ----------------- | ---------------------------------- | ---------------------------------------------------------- |
| 🥇 Low Effort    | Income Theft      | ShopCommandDispatcher.lua L193-310 | Add `shopOwner` field validation in PlayerShopPickupShop() |
| 🥈 Medium Effort | Money Duplication | PlayerShopBuyAction.lua L159-162   | Add post-BalanceWithdraw validation check                  |
| 🥉 Medium Effort | Silent Item Loss  | ShopSellAction.lua L127-191        | Add inventory lock or atomic item removal                  |

**Estimated Time**: 4-6 hours total  
**Risk Level**: Medium (logic changes, requires testing)

---

## Short Term (Week 1-2): Network Optimizations

From **WIP_VS_ORIGINAL.md** (currently NOT implemented but recommended):

### 1. Implement Tick Aggregator

**Goal**: Reduce ModData.transmit() calls from per-transaction to per-tick

**Current Pattern** (inefficient):

```lua
-- Each transaction immediately broadcasts
account.coin -= amount
ModData.transmit("CoinBalance")  -- L172 in ShopBuyAction
```

**Recommended Pattern** (optimized):

```lua
-- Queue updates
PendingBalanceUpdates[player] = { coin = delta, special = specialDelta }

-- Emit once per 50-100ms tick
flushBalanceUpdates()
```

**Impact**: Reduce network traffic by ~50-70%

### 2. Move ModData.transmit() Outside complete()

**Current**: Called inside TimedAction.complete() (violates rule)  
**Target**: Defer to tick aggregator or dispatcher

---

## Medium Term (Week 2-3): Determinism Validator

**File**: `PricingContract.lua` L157-171 (stub only)

### What's Needed:

- Bytecode scanning for forbidden operations (ZombRand, os.time, GameTime, pairs)
- Fail-fast at mod load time if violations detected
- Run automatically in dev mode

**Current**: Code review only; no runtime enforcement  
**Target**: Automated validator with CI integration

---

## Long Term (Week 4+): Testing & Documentation

### 1. Automated Test Suite

- Unit tests for PricingContract
- Integration tests for buy/sell flows
- Multi-player simulation tests
- Transaction race condition tests

### 2. Network Metrics

- Capture RakNet traffic before/after optimizations
- Measure 70%+ traffic reduction (WIP_VS_ORIGINAL target)
- Document baseline in CHANGES_CURRENT.md

### 3. Modder Documentation

- Custom shop template (currently missing)
- PricingContract modding guide
- Hooks API documentation

---

## Recommended Execution Order

```
Week 1:
  [Task 6.1.5] Fix 3 critical bugs
    ├─ Income Theft (1-2 hours)
    ├─ Money Duplication (1-2 hours)
    └─ Silent Item Loss (1-2 hours)

Week 2:
  [Network] Implement tick aggregator
    ├─ Design aggregator layer (2 hours)
    ├─ Refactor ModData.transmit() calls (2 hours)
    └─ Test under load (2 hours)

Week 3:
  [Validation] Implement determinism validator
    ├─ Build bytecode scanner (3 hours)
    ├─ Integrate with mod loader (1 hour)
    └─ Test with real mods (1 hour)

Week 4:
  [QA] Create test suite
    ├─ Write unit tests (4 hours)
    ├─ Run network profiling (2 hours)
    └─ Update documentation (2 hours)
```

---

## Quick Reference: What's Complete vs Pending

| Phase                           | Status      | Notes                   |
| ------------------------------- | ----------- | ----------------------- |
| Phase 1: Pricing Contract       | ✅ Complete | Deterministic, enforced |
| Phase 2: Client Listing         | ✅ Complete | Zero broadcasts         |
| Phase 3: Server Transactions    | ✅ Complete | Authoritative           |
| Phase 4: NPC/Player Distinction | ✅ Complete | Separate code paths     |
| Phase 5: Determinism Validator  | ⚠️ Stub     | Needs implementation    |
| Phase 6: Migration Framework    | ✅ Complete | Tested                  |
| **Task 6.1.5: Bug Fixes**       | ❌ Pending  | 3 critical issues       |
| **Network Optimization**        | ❌ Pending  | Tick aggregator         |
| **Testing & Metrics**           | ❌ Pending  | QA suite needed         |

---

## Start Task 6.1.5?

Would you like me to:

1. **Create a detailed implementation plan** for the 3 bug fixes?
2. **Write code patches** for each vulnerability?
3. **Set up test cases** for verification?
4. **Generate the tick aggregator design** for network optimization?

Let me know which to prioritize first.
