# ShopsHooksExample Refactoring Plan

## Overview
Refactor ShopsHooksExample to align with current Shops mod implementation, using TestPriceHooks as the canonical reference for hook behavior and semantics.

---

## Phase 1: Analysis & Research

### 1.1 Audit Current ShopsHooksExample
- [ ] Review existing ShopsHooksExample structure and files
- [ ] Identify outdated APIs, events, or assumptions
- [ ] Document what needs to be removed/replaced
- [ ] Note any client-side price authority violations

### 1.2 Study Canonical References
- [ ] Examine `TestPriceHooks.lua` for:
  - Hook registration patterns
  - Modifier vs override semantics
  - Server-side execution constraints
  - Resync lifecycle (`ShopFinalizeHandler.onPriceHooksChanged()`)
- [ ] Review `TestPriceHooksCommand.lua` for:
  - Client → Server command flow patterns
  - Debug/test usage (which to avoid in example)
  - Event triggering patterns
- [ ] Study `ShopPriceEvents` structure and behavior
- [ ] Verify buy vs sell asymmetry expectations

### 1.3 Document Current Shops Hook API
- [ ] Confirm the 4 hook registration functions:
  - `registerOnShopModifyBuyPrice`
  - `registerOnShopOverrideBuyPrice`
  - `registerOnShopModifySellPrice`
  - `registerOnShopOverrideSellPrice`
- [ ] Document their signatures and expected behavior
- [ ] Note modifier stacking behavior
- [ ] Confirm override short-circuit behavior

---

## Phase 2: Design Refactored Example

### 2.1 Scope & Item Selection
- [ ] Choose 1–2 items for example (e.g., Apple, BaseballBat)
- [ ] Plan what hooks to demonstrate:
  - 1 buy modifier hook
  - 1 sell modifier hook
  - 1 override hook (buy or sell)

### 2.2 Architecture Design
- [ ] Define module structure:
  - Init file (register hooks, set up namespace)
  - Hooks file (hook functions)
  - Optional state file (if needed for example)
- [ ] Plan namespace usage (SHOPSB42 only, no globals)
- [ ] Document which hooks are server-side only
- [ ] Plan resync trigger points

### 2.3 Code Organization Plan
- [ ] Separate concerns:
  - Hook registration
  - Hook implementation
  - State management (if any)
  - Resync/propagation logic
- [ ] Plan inline comments:
  - Explain _why_ resync is needed
  - Clarify modifier vs override behavior
  - Note multiplayer safety constraints

---

## Phase 3: Implementation

### 3.1 Remove Outdated Code
- [ ] Identify and remove deprecated APIs from ShopsHooksExample
- [ ] Remove any client-side price calculation logic
- [ ] Remove test-only code (debug spam, console commands)
- [ ] Remove direct price caching outside Shops APIs
- [ ] Remove globals

### 3.2 Implement Hook Registration
- [ ] Create init file with proper SHOPSB42 namespace
- [ ] Register all example hooks via correct Shops APIs
- [ ] Ensure hooks target only the 1–2 chosen items
- [ ] Add inline comments explaining registration

### 3.3 Implement Example Hooks
- [ ] **Buy Modifier Hook**
  - Example: Apply percentage discount based on item condition or player status
  - Append to modifiers table
  - Document stacking behavior
  
- [ ] **Sell Modifier Hook**
  - Example: Apply different modifier for selling (e.g., lower buy price for NPCs)
  - Append to modifiers table
  - Show buy vs sell asymmetry
  
- [ ] **Override Hook**
  - Example: Return fixed final price for specific condition
  - Return nil if no override applies
  - Document short-circuit behavior

### 3.4 Implement Resync Logic
- [ ] Trigger `ShopFinalizeHandler.onPriceHooksChanged()` when hooks change
- [ ] Document when resync is necessary
- [ ] Ensure resync is called after any dynamic hook changes
- [ ] Note that initial registration doesn't need explicit resync

### 3.5 Code Quality Pass
- [ ] Verify SHOPSB42 namespace usage only
- [ ] Check for any remaining globals
- [ ] Ensure clean separation of concerns
- [ ] Verify inline comments explain _why_, not _what_
- [ ] Match coding style from TestPriceHooks

---

## Phase 4: Testing & Validation

### 4.1 Syntax & Structure Validation
- [ ] Verify Lua syntax is correct
- [ ] Confirm all hook registrations use correct APIs
- [ ] Check namespace references are correct
- [ ] Verify no undefined globals

### 4.2 Behavioral Validation
- [ ] Confirm hooks execute server-side only
- [ ] Test modifier stacking behavior
- [ ] Test override short-circuit behavior
- [ ] Verify buy vs sell hooks behave correctly
- [ ] Confirm prices propagate to client via Shops mechanisms

### 4.3 Multiplayer Safety Validation
- [ ] Ensure no client-side price authority
- [ ] Verify no direct UI mutation
- [ ] Check no direct price caching outside Shops APIs
- [ ] Confirm all changes propagate via Shops resync
- [ ] Verify no race conditions or sync issues

### 4.4 Documentation Validation
- [ ] Verify code is self-documenting
- [ ] Check inline comments are concise and clear
- [ ] Ensure developer can copy → adjust items → get working hooks

---

## Phase 5: Deliverables

### 5.1 Refactored Code
- [ ] Finalized ShopsHooksExample Lua files
- [ ] All files in correct directory structure
- [ ] Formatted with stylua (tabs, no UTF-8 BOM)

### 5.2 Documentation
- [ ] Brief summary of changes
- [ ] List of what changed vs old example
- [ ] Explanation of which Shops behaviors are demonstrated
- [ ] Note any intentional limitations
- [ ] Quick-start guide for adapting the example

---

---

## 📌 Agentic Refactor Prompt — *ShopsHooksExample (Server-Only Reference)*

### Role
You are an expert **Project Zomboid B42.13 Multiplayer** Lua engineer, specializing in **SHOPSB42**, server-authoritative economy systems, and price hook lifecycles.

### Objective
Refactor **ShopsHooksExample** so it becomes a **pure server-side reference implementation** that demonstrates **correct Shops price hook usage**, aligned with the current Shops mod.

The example must:
* Execute **entirely on the server**
* Contain **no client-side code**
* Contain **no client → server command flow**
* Serve as a **canonical, copy-paste-safe example** for mod authors

### Canonical References (Source of Truth)
You MUST treat the following as authoritative:

* **Server-side hook behavior & lifecycle**
  → `TestPriceHooks.lua`

* **Current Shops mod internals**, including:
  * `ShopPriceEvents`
  * `ShopFinalizeHandler.onPriceHooksChanged`
  * Buy vs Sell asymmetry
  * Modifier vs Override precedence
  * Server-authoritative price resolution

> ⚠️ `TestPriceHooksCommand.lua` is **NOT** to be replicated in the example.
> Client → server command flow is **documentation-only**, not part of this mod.

### Scope & Intent
This example is:
* ✅ **Server-only**
* ✅ **Always-on hooks**
* ✅ **Documentation-grade**

This example is **NOT**:
* ❌ A testing harness
* ❌ A debug console mod
* ❌ A UI-driven mod
* ❌ A command-based mod

### Required Refactor Tasks

#### 1. Remove Client/Command Flow Completely
You MUST:
* Remove **all** client-side files
* Remove:
  * `sendClientCommand`
  * `OnClientCommand`
  * Debug console commands
  * Any command routing logic
* Assume hooks are **static or server-controlled**

> The example should load, register hooks, and function correctly **without any player interaction**.

#### 2. Server-Side Hook Registration
Register hooks using the **current Shops APIs only**:
* `registerOnShopModifyBuyPrice`
* `registerOnShopOverrideBuyPrice`
* `registerOnShopModifySellPrice`
* `registerOnShopOverrideSellPrice`

All hooks must:
* Execute server-side only
* Never mutate UI state
* Never trust client input
* Never cache prices outside Shops APIs

#### 3. Partial, Focused Example
Limit scope intentionally:
* Use **1–2 items only** (e.g. `Base.Apple`, `Base.BaseballBat`)
* Demonstrate:
  * One **buy modifier**
  * One **sell modifier**
  * One **override**
* Keep logic deterministic and simple

This is a **reference**, not a feature-complete economy.

#### 4. Hook Semantics (Non-Negotiable)
The example MUST clearly demonstrate:

* Modifier hooks:
  * Append to `modifiers`
  * Stack correctly
* Override hooks:
  * Return final price or `nil`
  * Short-circuit modifier resolution
* Buy vs Sell asymmetry:
  * Separate hooks
  * Different intent

Inline comments must explain **why** each behavior exists.

#### 5. Resync & Lifecycle Rules
You MUST:
* Use `ShopFinalizeHandler.onPriceHooksChanged()` **only where appropriate**
* Document:
  * Why initial registration does NOT require resync
  * When resync would be required in a dynamic system
* Avoid unnecessary resync calls

#### 6. Code Quality & Structure
The final example MUST:
* Use `SHOPSB42` namespace exclusively
* Introduce **no globals**
* Be cleanly structured (init / hooks / state)
* Match the coding style of `TestPriceHooks`
* Include concise, architectural comments

### Documentation Requirement
Because client → server flow is removed:
* Add **clear comments** stating:
  * "This example is server-only"
  * "Client → server control is documented elsewhere"
* Assume a separate **Shops API documentation page** explains:
  * How admins or mods can trigger hook changes
  * How command routing works (out of scope here)

### Deliverables
Produce:
1. **Refactored server-only ShopsHooksExample Lua code**
2. A **short summary** explaining:
   * What was removed (client flow, commands)
   * What Shops behaviors are demonstrated
   * Why the example is intentionally limited

Do **not** redesign Shops.
Do **not** invent new APIs.
Do **not** reintroduce client authority.

### Success Criteria
A developer should be able to:
> Drop this example into a server → adjust item IDs → immediately get correct, MP-safe price hooks, with zero client code.

---

## Key Constraints

### Non-Negotiable Rules
- ✅ Do NOT invent APIs
- ✅ Do NOT rely on deprecated B41 behavior
- ✅ Do NOT simplify away required resync logic
- ✅ If uncertain, defer to TestPriceHooks behavior exactly
- ✅ **Server-side only** — No client code, no commands, no UI
- ✅ **No client → server flow** in implementation (documentation only)

### Canonical References (Source of Truth)
- TestPriceHooks.lua → Server-side hook behavior & lifecycle
- TestPriceHooksCommand.lua → Reference only (NOT replicated)
- Shops mod source → ShopPriceEvents, ShopFinalizeHandler.onPriceHooksChanged()

---

## Success Criteria

A developer should be able to:
1. Copy refactored ShopsHooksExample
2. Adjust item IDs to their own
3. Immediately get correct, live, MP-safe price hooks in the current Shops mod

No additional setup, no undocumented dependencies, no trial-and-error.

---

## Execution Timeline

- **Phase 1 (Analysis)**: Review existing code and canonical references
- **Phase 2 (Design)**: Plan refactored structure and scope
- **Phase 3 (Implementation)**: Write clean, aligned code
- **Phase 4 (Testing)**: Validate behavior and MP safety
- **Phase 5 (Deliverables)**: Document and finalize
