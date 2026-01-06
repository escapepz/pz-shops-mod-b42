# Task 6.1.5 Implementation Checklist

**Total Time Estimate**: 4-6 hours  
**Complexity**: Medium  
**Risk**: Critical (fixes vulnerabilities)

---

## Pre-Implementation

- [ ] Read `TASK_6.1.5_CRITICAL_BUG_FIXES.md` (detailed implementation plan)
- [ ] Decide on approach for Bug #2 (complex vs simple)
- [ ] Review current code line numbers (may have drifted)
- [ ] Create feature branch: `feature/6.1.5-critical-bugs`
- [ ] Back up current code

---

## Bug #1: Income Theft - ShopCommandDispatcher.lua

**Time**: 1-2 hours | **Complexity**: ⭐ Low

### Implementation
- [ ] Find shop creation code (where shop is instantiated)
  - Look in: ISAddPlayerShopAction.lua, PlayerShop.lua
- [ ] Add `modData.owner = player:getUsername()` on creation
- [ ] Find PlayerShopPickupShop() function in ShopCommandDispatcherServer.lua
- [ ] Add backwards-compatible owner check:
  ```lua
  local shopOwner = modData.owner
  if not shopOwner then
      modData.owner = player:getUsername()  -- Auto-assign
  elseif shopOwner ~= player:getUsername() then
      return  -- Reject non-owner
  end
  ```
- [ ] Add SharedLogger.log() for rejections

### Testing
- [ ] Test: Owner can pick up shop (✅ succeeds)
- [ ] Test: Non-owner cannot pick up shop (✅ fails)
- [ ] Test: Old save without owner field (✅ auto-assigns)
- [ ] Test: Income blocks pickup regardless (✅ still blocks)

### Code Review
- [ ] Line numbers match current code
- [ ] No breaking changes to existing logic
- [ ] Backwards compatibility confirmed
- [ ] Logging added for debugging

### Deployment
- [ ] Commit with message: "Fix: Add ownership validation to PlayerShopPickupShop"
- [ ] Tag: `6.1.5-bug1-income-theft`

---

## Bug #2: Money Duplication - PlayerShopBuyAction.lua

**Time**: 1.5-2 hours | **Complexity**: ⭐⭐ Medium

### Choose Approach
- [ ] **Simple**: Pre-deduct balance before item transfer
  - [ ] Move balance deduction to BEFORE item loop
  - [ ] Remove BalanceWithdraw command
  - [ ] Simpler, atomic
  
- [ ] **Complex**: Speculative withdrawal with client confirmation
  - [ ] Add PendingWithdrawals tracking
  - [ ] Add trackWithdrawal() / verifyWithdrawal() helpers
  - [ ] Modify complete() to return false (pending)
  - [ ] Add client BalanceWithdrawConfirm handler
  - [ ] Add server BalanceWithdrawConfirm handler
  - [ ] Handle 5-second timeout

### Implementation (Simple Path)
- [ ] Find PlayerShopBuyAction.lua L158-174
- [ ] Move this code UP (before item transfer loop):
  ```lua
  local account = ModData.get("CoinBalance")[username]
  account.coin = account.coin - totalCoin
  account.specialCoin = account.specialCoin - totalSpecialCoin
  ModData.transmit("CoinBalance")
  ```
- [ ] Remove BalanceWithdraw command
- [ ] Update shop income recording (still needed)

### Implementation (Complex Path)
- [ ] Add PendingWithdrawals table and helpers
- [ ] Add txnId to ticket (or generate one)
- [ ] Modify complete() to track withdrawal
- [ ] Add BalanceWithdrawConfirm handler (client-side)
- [ ] Add BalanceWithdrawConfirm handler (server-side)
- [ ] Handle timeout cleanup

### Testing
- [ ] Test: Player with sufficient funds (✅ succeeds)
- [ ] Test: Player with insufficient funds (✅ fails early)
- [ ] Test: Network lag doesn't cause dupe (✅ atomic)
- [ ] Test: Client disconnect doesn't cause dupe (✅ pre-check)

### Code Review
- [ ] Transaction is now atomic
- [ ] No race condition window
- [ ] Balance deduction is authoritative
- [ ] Logging shows deduction timestamp

### Deployment
- [ ] Commit with message: "Fix: Make player shop buy transaction atomic"
- [ ] Tag: `6.1.5-bug2-money-dupe`

---

## Bug #3: Silent Item Loss - ShopSellAction.lua

**Time**: 1.5-2 hours | **Complexity**: ⭐⭐ Medium

### Implementation
- [ ] Find ShopSellAction.lua L126-193
- [ ] Refactor into two phases:

**Phase 1: VALIDATE**
- [ ] Create itemsToSell = {} table
- [ ] Loop through sellList.items
  - [ ] Check item exists with getItemById()
  - [ ] Run LazyMigration
  - [ ] Calculate price
  - [ ] Add to itemsToSell ONLY if valid
  - [ ] Log rejected items
- [ ] After loop, check if all items found
  - [ ] If missing: log "PARTIAL" and continue (SKIP mode)
  - [ ] OR: return false and reject entire transaction (REJECT mode)

**Phase 2: REMOVE**
- [ ] Loop through itemsToSell (not original sellList)
  - [ ] Double-check item still exists (defensive)
  - [ ] Remove item if exists
  - [ ] Log and skip if disappeared (race condition)
  - [ ] Accumulate payment only for items actually removed

### Notifications
- [ ] Find TransactionResult command handler
- [ ] Add itemsMissing = itemsRequested - itemsSold
- [ ] Send itemsMissing count to client
- [ ] Mark success = false if ANY items missing (strict)

### Testing
- [ ] Test: All items present (✅ all sold)
- [ ] Test: Item removed during action (✅ race handled)
- [ ] Test: Multiple items partially missing (✅ partial payment)
- [ ] Test: Zero items sold (✅ no balance change)

### Code Review
- [ ] Pre-validation prevents silent failures
- [ ] Defensive double-check catches races
- [ ] Client gets itemsMissing notification
- [ ] Audit log shows what happened
- [ ] Logging is comprehensive

### Deployment
- [ ] Commit with message: "Fix: Add pre-validation to prevent silent item loss"
- [ ] Tag: `6.1.5-bug3-item-loss`

---

## Testing & Validation

### Unit Testing
- [ ] Bug #1: 4 test cases (1 hour)
- [ ] Bug #2: 4 test cases (1 hour)
- [ ] Bug #3: 4 test cases (1 hour)
- [ ] All tests passing

### Integration Testing
- [ ] Single-player mode (SP mode)
  - [ ] Player shop buy works
  - [ ] Player shop income received
  - [ ] Picking up shop as owner
  - [ ] Item selling works
  
- [ ] Multi-player mode (MP mode)
  - [ ] Non-owner cannot pickup shop
  - [ ] Multiple players buying simultaneously
  - [ ] Item loss during concurrent actions
  - [ ] Balance stays consistent

### Regression Testing
- [ ] Old saves load without errors
- [ ] Existing transactions still work
- [ ] No new desync/network issues
- [ ] Performance impact < 10ms per transaction

### Load Testing
- [ ] 20+ concurrent players buying/selling
- [ ] Measure transaction latency
- [ ] Check for packet storms
- [ ] Monitor server logs for errors

### Checklist
- [ ] All 12-16 test cases passing
- [ ] No new error logs
- [ ] Network traffic stable
- [ ] Performance within acceptable range

---

## Code Review Before Merge

- [ ] [ ] All code follows mod style (tabs, CamelCase, lowercase variables)
- [ ] [ ] Logging uses SHOPSB42.SharedLogger.log()
- [ ] [ ] No debug prints left in code
- [ ] [ ] Comments explain WHY, not just WHAT
- [ ] [ ] Edge cases handled (nil checks, empty lists, timeouts)
- [ ] [ ] Backwards compatible (old saves work)
- [ ] [ ] No performance regressions
- [ ] [ ] All tests passing

---

## Documentation Updates

- [ ] [ ] Update CHANGES_CURRENT.md with bug fixes
- [ ] [ ] Add comments to code explaining the fix
- [ ] [ ] Update B42.13_MP_Migration_Guide.md if needed
- [ ] [ ] Create bug fix summary for release notes

---

## Deployment

### Before Deploying
- [ ] All tests passing
- [ ] Code reviewed by 1+ team member
- [ ] Performance benchmarked
- [ ] Backwards compatibility verified

### Deploy
- [ ] Create release tag: `v6.1.5-critical-fixes`
- [ ] Write release notes summarizing the 3 fixes
- [ ] Deploy to test server first
- [ ] Monitor logs for 24 hours
- [ ] Deploy to production

### Monitor
- [ ] [ ] Check server logs for errors (first 24 hours)
- [ ] [ ] Verify player shop transactions working
- [ ] [ ] Monitor balance consistency
- [ ] [ ] Check for network issues
- [ ] [ ] Collect feedback from players

---

## Success Criteria

✅ All 3 critical vulnerabilities are fixed  
✅ No new bugs introduced  
✅ All tests passing  
✅ Backwards compatible with old saves  
✅ Performance impact < 5% per transaction  
✅ Network traffic stable or reduced  

---

## Rollback Plan

If critical issues found after deployment:

1. **Income Theft Fix**: Remove owner check, fallback to income-only blocking
2. **Money Dupe Fix**: Revert to speculative withdrawal (but log all issues)
3. **Item Loss Fix**: Revert to current behavior (but log all skips)

All fixes have **safe rollback paths**.

---

## Time Breakdown

| Phase | Task | Time | Status |
|-------|------|------|--------|
| 1 | Setup & review | 0.5h | ⏳ Before start |
| 2 | Bug #1 implementation | 1h | ⏳ Day 1 |
| 2 | Bug #1 testing | 0.5h | ⏳ Day 1 |
| 3 | Bug #2 implementation | 1h | ⏳ Day 1 |
| 3 | Bug #2 testing | 1h | ⏳ Day 2 |
| 4 | Bug #3 implementation | 1h | ⏳ Day 2 |
| 4 | Bug #3 testing | 1h | ⏳ Day 2 |
| 5 | Integration + regression testing | 1.5h | ⏳ Day 3 |
| 6 | Code review & documentation | 1h | ⏳ Day 3 |
| 7 | Deploy & monitor | Ongoing | ⏳ Day 4+ |
| **TOTAL** | | **~8 hours** | |

---

## Ready to Start?

- [ ] Detailed plan read: `TASK_6.1.5_CRITICAL_BUG_FIXES.md`
- [ ] Questions answered (simple vs complex approach)
- [ ] Feature branch created
- [ ] Test environment ready
- [ ] Let's go! 🚀

