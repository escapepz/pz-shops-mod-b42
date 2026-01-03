# Clarification: Player Shop Pricing Model

**Date**: 2026-01-03  
**Status**: Documentation update (no code changes required if safe pattern is used)  
**Applies To**: PlayerShopBuyAction, PlayerShopSellAction

---

## Executive Summary

The initial concern about "client price trust" in Player Shops was based on a misconception that Player Shop pricing uses the same vulnerable pattern as NPC shops.

**Verdict: Player Shops are NOT vulnerable** if they source prices exclusively from server-owned IsoObject ModData.

---

## The Critical Distinction

### Configuration Data vs Transaction Input

| Aspect | NPC/Global Shop | Player Shop |
|--------|-----------------|-------------|
| **Price Origin** | Client-computed UI | Server-persisted ModData |
| **Category** | Transaction input | Configuration |
| **Trust Level** | ❌ Untrusted | ✅ Trusted |
| **Vulnerability** | Yes (fallback pattern) | No (if no fallback) |

### The Security Invariant

> Never trust client-supplied **transactional prices**

NOT: "Never trust ModData" or "Never trust client input"

---

## When Player Shop Pricing Is Safe

Player Shop transactions remain secure if **all three** conditions are met:

### 1. Prices Read Only From Server ModData ✅

```lua
-- ✅ SAFE: Read from server ModData
local price = shopObject:getModData().price
```

NOT from client payloads:

```lua
-- ❌ UNSAFE: Would read from client proposal
local price = entry.price
local price = cart[itemId].price
```

### 2. No Fallback to Client Values ✅

```lua
-- ✅ SAFE: No fallback pattern
local price = shopObject:getModData().price
if not price then
    return false  -- Reject transaction
end
```

NOT:

```lua
-- ❌ UNSAFE: Falls back to client value
local price = shopObject:getModData().price or entry.price
```

### 3. Missing Prices Cause Rejection ✅

```lua
-- ✅ SAFE: Reject if missing
if not shopObject:getModData().price then
    logError("Item has no price in shop ModData")
    return false
end
```

NOT:

```lua
-- ❌ UNSAFE: Silent fallback or default
local price = shopObject:getModData().price or 0
```

---

## Pre-Publish Audit Checklist

To confirm Player Shop pricing remains safe:

- [ ] Search `PlayerShopBuyAction.lua` for fallback patterns (keyword: `or entry`)
- [ ] Search `PlayerShopSellAction.lua` for fallback patterns
- [ ] Verify all price reads use `shopObject:getModData()`
- [ ] Confirm missing prices cause transaction rejection
- [ ] If all checks pass: ✅ **NO CODE CHANGES NEEDED**
- [ ] If fallback found: Remove client price trust before publishing

---

## Why This Matters

### The Vulnerable Pattern (NPC Shops)

```lua
-- Buyer controls price (client UI)
local price = precomputedPrice or fallback

-- Server accepts without revalidation
balance = balance - price
```

### The Safe Pattern (Player Shops)

```lua
-- Shop owner controls price (server ModData)
local price = shopObject:getModData().price

-- Server uses authoritative value only
if not price then reject() end
balance = balance - price
```

---

## Regression Prevention

This guardrail ensures future maintainers don't "improve" the code in ways that reintroduce the vulnerability:

❌ **Do NOT do this**:

```lua
-- Someone might think: "If ModData is missing, use entry price as fallback"
local price = shopObject:getModData().price or entry.price  -- WRONG
```

✅ **Only do this**:

```lua
-- ModData is authoritative, always
local price = shopObject:getModData().price
if not price then error("Missing price in shop ModData") end
```

---

## Result

- **Configuration-based pricing** (server ModData) is fundamentally different from **transaction-input pricing** (client payloads)
- Player Shops use the safer model and do **not** require code changes
- Pre-publish audit will confirm the safe pattern is consistently applied
- Guardrail checklist prevents accidental regressions in future maintenance

---

**Reference Documents**:
- `/docs/AUDIT/TASK_2_BEHAVIORAL_VERIFICATION.md` - Full behavioral analysis (Section 9)
- `/docs/AUDIT/PRE_PUBLISH_CHECKLIST.md` - Pre-publish audit checklist (Item 3.5)
