# Refactor Plan: Client-Side NPC Shop Listing

## Overview
Implement hybrid client-listing model from CLIENT_LISTING.md to reduce RakNet traffic, eliminate per-player sync, and maintain server authority over transactions.

---

## Phase 1: Foundation (Deterministic Shared Pricing)

### 1.1 Create PricingContract.lua
- Extract pricing logic into deterministic shared module
- Define allowed operations (table lookups, arithmetic, static config, read-only traits)
- Remove time-based, RNG-based, and mutable global dependencies
- Add inline validator comments for determinism guarantees

**🔴 MANDATORY CONSTRAINT:**
```lua
-- PricingContract inputs MUST be scalar snapshots only
-- NO inventory state, container reads, or world object access
-- Inputs: item type, static config, immutable player snapshot
-- If you need runtime data, it must come from server at transaction time
```

### 1.2 Audit Existing Pricing Code
- Scan current pricing implementation for non-deterministic calls
- Replace `ZombRand`, `os.time`, `GameTime` usage with immutable inputs
- Document any server-only modifiers that must remain out of shared code
- Create whitelist of safe operations

### 1.3 Build Shared Shop Catalog
- Move static NPC shop definitions to `shared/`
- Include: basePrice, category, stock (-1 = infinite), UI metadata
- Ensure data is immutable and load-order independent
- Format as:
  ```lua
  NPCShop.Items = {
      ["Base.Axe"] = { basePrice = 120, category = "Tools", stock = -1 },
      ...
  }
  ```

**🟢 FUTURE-PROOFING (For Live Pricing Later):**
Add two concepts to PricingContract now:
```lua
-- 1. PricingContract returns: price + revision number
--    return { finalPrice = 120, revision = 42 }

-- 2. All server Buy/Sell responses include revision:
--    sendServerCommand(player, "Shop", "BuyResult", {
--        success = true,
--        finalPrice = 120,
--        priceRevision = 42,  -- included always
--    })

-- This adds zero cost now, but unlocks live pricing without refactor later
```

---

## Phase 2: Client-Side Listing UI (Zero Network)

### 2.1 Refactor Client Shop UI
- Load shop catalog directly from `shared/` (no ModData)
- Calculate preview prices using PricingContract
- Render item list with preview pricing
- No server messages during listing view

**⚠️ MANDATORY UX CONSTRAINT:**
```lua
-- Preview prices must never LOCK the UI or transaction logic
-- Label internally as non-authoritative
-- This prevents "price jumping" complaints and false bug reports
-- Server price is always final truth on transaction
```

### 2.2 Remove Client ModData Syncing
- Eliminate per-player ModData broadcast for NPC shop prices
- Remove reactive listeners that trigger on price changes
- Stop global price sync on view open

### 2.3 Add Client Price Mismatch Handler
- UI tolerates server price ≠ preview price
- On transaction result, silently update UI
- Show error if funds insufficient (no resync)
- Prevent entire shop rebuild on single price change

---

## Phase 3: Server-Side Transaction Settlement

### 3.1 Refactor Buy/Sell Command Handlers
- Client sends minimal intent (shopId, itemType, quantity only)
- **No price included from client**
- **No trust of client calculations**

### 3.2 Server-Side Recomputation
1. Load shared PricingContract
2. Recompute price from same code as client
3. Apply server-only modifiers (if any) — must be documented
4. Validate player balance/inventory
5. Mutate player balance
6. Spawn item(s)
7. Send targeted response (no broadcast)

### 3.3 Execution Response Format
```lua
sendServerCommand(player, "Shop", "BuyResult", {
    success = true,
    finalPrice = 120,
    newBalance = 380,
    itemId = "...", -- for UI feedback
})
```
- Targeted to single player (not broadcast)
- Include only settlement details
- No shop state dump

**🔴 MANDATORY CRITICAL RULE:**
```lua
-- NO ModData.transmit() inside transaction execution handlers
-- Ban broadcast entirely from Buy/Sell paths
-- Late-join sync is handled separately in a dedicated phase
-- One forgotten transmit reintroduces packet storms
```

---

## Phase 4: NPC vs Player Shops Distinction

### 4.1 NPC Shops
- Use pure shared catalog
- Deterministic pricing
- Static availability
- Full client-side listing optimization

### 4.2 Player Shops
- Allow client-side listing (items + base prices)
- **Force server re-read item ModData at execution**
- Never cache ModData price client-side
- Accept that player shop prices may diverge due to mods

### 4.3 Separate Code Paths
- Create `ShopListingNPC.lua` and `ShopListingPlayer.lua`
- NPC path: purely deterministic, full optimization
- Player path: server-revalidating, safer but slightly more traffic

---

## Phase 5: Determinism Validation

### 5.1 Build Determinism Validator
- Scan PricingContract for forbidden operations
- Detect: `ZombRand`, `os.time`, `GameTime`, mutable globals
- Verify no iteration over unordered tables
- Check no mod load-order dependent hooks

**🔴 MANDATORY ADDITION:**
```lua
-- Enforce deterministic iteration rules:
-- MUST use ipairs() for arrays (ordered)
-- MUST use sorted key lists for maps (not pairs/next)
-- pairs() iteration order must NEVER affect pricing
-- This is a real-world MP desync source
```

### 5.2 Add Assertions to Shared Code
- Assert no time-based logic
- Assert no RNG calls
- Document why each assertion exists
- Fail fast if violated

### 5.3 Create Determinism Test
- Run same price calculation 100x with identical inputs
- Verify identical outputs
- Test across mod load orders (if applicable)

**🟢 OPTIONAL IMPROVEMENT:**
Add dev-only determinism assert:
```lua
-- Compare client preview vs server price
-- Log mismatch silently, do not fail
-- Helps catch divergence before production
```

---

## Phase 6: Migration & Testing

### 6.1 Update ModData Schema
- NPC shops: stop storing price in ModData
- Mark old price fields as deprecated
- Lazy-migrate existing saves (read old, ignore, write new)

### 6.2 Network Traffic Baseline
- Measure current RakNet traffic with WIP\_ (before refactor)
- Measure after client-listing implementation
- Target: zero per-player price sync, 1 targeted packet per transaction

**🟢 OPTIONAL IMPROVEMENT:**
```lua
-- Log packet count per transaction in dev builds
-- Prove the win with concrete metrics
-- Example: "Transaction complete in 2 packets vs 12 before"
```

### 6.3 Functional Testing
- Test NPC shop listing with no server connection (client can load)
- Test buy transaction with price mismatch (server wins)
- Test insufficient funds → error (no shop rebuild)
- Test multiple players browsing same shop (no cross-talk)
- Test lag scenarios (late price response arrives after client retry)

### 6.4 Compatibility Testing
- Test with vanilla NPC shops
- Test with modded NPC shops
- Test player shops (limited revalidation)
- Verify no desync on server restart

---

## Phase 7: Documentation & Rollout

### 7.1 Finalize PricingContract API
- Document all allowed operations
- Provide clear examples
- Define contract for modders

### 7.2 Update Guides
- Update migration guide with new pricing model
- Document when mods must use server-only pricing
- Provide code templates for custom shops

### 7.3 Changelog
- Record traffic reduction metrics
- Note breaking changes (if any)
- Credit CLIENT_LISTING analysis

---

## Success Criteria

| Metric | Target |
| --- | --- |
| RakNet traffic per player | Reduce by 70%+ |
| Price sync broadcasts | 0 global broadcasts |
| Transaction latency | ≤1 server roundtrip |
| Desync occurrences | 0 after Phase 6 |
| Determinism violations | 0 in production |
| Modder onboarding time | <15 min for custom NPC shop |

---

## Risk Mitigation

### Risk: Price divergence due to mod interactions
**Mitigation:** Server re-reads, mismatch UI, no resync. Document in pricing contract what is safe.

### Risk: Determinism validator is incomplete
**Mitigation:** Run validator on every pricing change. Add test suite. Fail in dev if new non-deterministic call is added.

### Risk: Player shops become inconsistent
**Mitigation:** Keep separate code path. Force server re-read of ModData on execution. Accept slight network overhead.

### Risk: Backwards compatibility with existing saves
**Mitigation:** Lazy-migrate ModData. Old price fields are ignored, new price computed on demand.

---

## Implementation Order

1. **Phase 1** - Build foundation (PricingContract, audit)
2. **Phase 5** - Add validation (can run parallel)
3. **Phase 2** - Client UI refactor (depends on Phase 1)
4. **Phase 3** - Server execution refactor (depends on Phase 1)
5. **Phase 4** - NPC/Player distinction (depends on Phase 2, 3)
6. **Phase 6** - Migration & testing (depends on Phase 4)
7. **Phase 7** - Documentation (final)

---

## Optional Advanced Improvements

### Single Sync Bus Abstraction
- Centralize all `sendServerCommand` emissions
- Easier to audit traffic later
- Single point for packet counting & logging

### Price Snapshot ID (Included in Future-Proofing)
- Server returns `priceRevision` with transaction result
- Client silently updates cache
- Useful for price history / debugging
- Already addressed in Phase 1.3 future-proofing

---

## Future Extension: Live NPC Pricing (Without Refactor)

### Model (Fully Compatible)

Live pricing (when added later) will be **revision-based snapshots**, never broadcast loops:

1. **Server advances `NPCShop.PriceRevision`** on economy event
2. **Client learns revision on transaction** (server returns it)
3. **Client can optionally request snapshot refresh** if out of sync
4. **No ModData.transmit(), no broadcast, no global sync**

### Why This Works

Your Phase 1 investment in PricingContract + revision tracking makes this **free to add later**:

```lua
-- Future: Optional explicit refresh (if UI wants live updates)
sendClientCommand("Shop", "RequestPriceSnapshot", {
    shopId = "npc_general_store",
    lastRevision = clientRevision,  -- client tells server what it knows
})

-- Server responds only if changed
sendServerCommand(player, "Shop", "PriceSnapshot", {
    revision = 43,
    prices = {...},  -- full snapshot, not incremental
})
```

Still:
- ✔ Targeted (not broadcast)
- ✔ Infrequent (only on request or refresh)
- ✔ Bounded (snapshot, not streaming)
- ✔ Deterministic (prices from PricingContract)
- ✔ Backward compatible (client can ignore)

### No Code Required Now

This is all **purely architectural planning**.
The refactor plan already supports it through Phase 1.3 future-proofing.

---

## Notes

- **Do not move to next phase until previous is tested**
- **Keep WIP\_ architecture and guarantees intact**
- **Server remains authoritative on all economy decisions**
- **Client is preview + UI only**

---

## Verification Checklist (Before Publishing)

- [ ] Zero `ModData.transmit()` calls in Buy/Sell handlers
- [ ] PricingContract validates: no inventory, containers, world state reads
- [ ] Determinism validator enforces: ipairs/sorted keys, no pairs()
- [ ] Client UI labeled internally as non-authoritative
- [ ] Player shop cache expires per frame
- [ ] Traffic baseline measured and documented
- [ ] All three mandatory corrections applied
- [ ] Code review confirms no RNG/time/globals in pricing
- [ ] Late-join sync tested and working separately
- [ ] PricingContract returns: `{ finalPrice, revision }`
- [ ] All server Buy/Sell responses include `priceRevision`
- [ ] Future live pricing model documented (revision-based snapshots)
