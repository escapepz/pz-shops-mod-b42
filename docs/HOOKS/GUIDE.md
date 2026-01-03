Below is a **ready-to-copy prompt** you can give directly to an **agentic coding tool** (e.g. code-refactor / code-audit agent).
It is explicitly scoped to refactor **ShopsHooksExample** so it accurately reflects the **current Shops mod implementation**, using **`TestPriceHooks` as the canonical reference for partial hooks**.

This prompt is written to enforce **behavioral equivalence, architectural alignment, and MP correctness**, not a superficial rewrite.

---

## 📌 Agentic Refactor Prompt — _ShopsHooksExample Modernization_

### Role

You are an expert **Project Zomboid (B42.13 MP)** Lua mod engineer with deep knowledge of **SHOPSB42 architecture**, multiplayer synchronization, and server-authoritative pricing systems.

---

### Objective

Refactor the existing **ShopsHooksExample** mod so that it:

1. **Fully matches the current implementation and expectations of the Shops mod**
2. **Demonstrates correct hook usage** using _partial, real examples_ derived from **`TestPriceHooks`**
3. Is **safe, correct, and idiomatic for B42.13 Multiplayer**
4. Serves as a **reference-quality example mod**, not a test harness

---

### Canonical References (Source of Truth)

You MUST treat the following as authoritative:

- **Server-side hook behavior & lifecycle**
  → `TestPriceHooks.lua`

- **Client → Server command flow & debug usage**
  → `TestPriceHooksCommand.lua`

- **Current Shops mod behavior**, including:

  - `ShopPriceEvents`
  - `ShopFinalizeHandler.onPriceHooksChanged`
  - Price recalculation & resync semantics
  - Buy vs Sell asymmetry
  - Override vs Modifier precedence

---

### Required Refactor Tasks

#### 1. Architectural Alignment

- Remove **any outdated APIs, events, or assumptions** from ShopsHooksExample
- Align hook registration with:

  - `registerOnShopModifyBuyPrice`
  - `registerOnShopOverrideBuyPrice`
  - `registerOnShopModifySellPrice`
  - `registerOnShopOverrideSellPrice`

- Ensure **no client-side price authority** exists

---

#### 2. Hook Semantics (Critical)

The example mod MUST correctly demonstrate:

- ✅ Modifier hooks (append to `modifiers`)
- ✅ Override hooks (return final price or `nil`)
- ✅ Server-only execution
- ✅ Explicit resync via `ShopFinalizeHandler.onPriceHooksChanged()`

You MUST clearly show:

- Buy price hooks vs Sell price hooks
- Modifier stacking behavior
- Override short-circuit behavior

---

#### 3. Partial Example Scope (Intentional)

The refactored **ShopsHooksExample** should:

- Use **1–2 items only** (e.g. Apple, BaseballBat)
- Demonstrate:

  - One **buy modifier**
  - One **sell modifier**
  - One **override example**

- Avoid test-only logic (no debug spam, no console commands)

This is **documentation-grade**, not a testing mod.

---

#### 4. Multiplayer & Safety Constraints

Enforce all of the following:

- Hooks execute **server-side only**
- No direct UI mutation
- No client-side price calculation
- No direct price caching outside Shops APIs
- All changes must propagate via existing Shops resync mechanisms

---

#### 5. Code Quality Expectations

The final output MUST:

- Use `SHOPSB42` namespace only
- Avoid globals
- Be cleanly separated (init / hooks / state)
- Include **concise inline comments** explaining _why_ things happen, not what Lua syntax does
- Match the coding style used in `TestPriceHooks`

---

### Deliverables

Produce:

1. **Refactored ShopsHooksExample Lua code**
2. A **brief summary** explaining:

   - What changed vs the old example
   - Which current Shops behaviors it now correctly demonstrates
   - Any intentional limitations

Do **not** introduce new systems or redesign Shops.
Your task is **alignment and correctness**, not innovation.

---

### Non-Negotiable Rules

- Do NOT invent APIs
- Do NOT rely on deprecated B41 behavior
- Do NOT simplify away required resync logic
- If uncertain, defer to **`TestPriceHooks` behavior** exactly

---

### Success Criteria

After refactoring, a developer should be able to:

> Copy ShopsHooksExample → adjust item IDs → immediately get correct, live, MP-safe price hooks in the current Shops mod.

---
