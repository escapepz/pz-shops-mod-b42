## Agentic Analysis Prompt — Client ↔ Server Communication Audit (Project Zomboid MP)

### Role & Objective

You are a **senior Project Zomboid multiplayer architecture auditor**.

Your task is to **analyze and map all client–server communication paths** in this codebase, with a focus on **trust boundaries, authority ownership, and synchronization correctness**.
You must **NOT refactor or change code**. This is a **diagnostic and reasoning task only**.

The goal is to produce evidence that informs a later refactor decision.

---

### Scope

Analyze **all communication mechanisms** between client and server, including but not limited to:

1. `sendClientCommand` / `OnClientCommand`
2. Timed Actions (`perform`, `complete`, `serverStart`, `animEvent`)
3. ModData synchronization
4. Price, money, inventory, and transaction flows
5. Shop UI → action → server resolution pipelines
6. Late join and resync behavior
7. SP vs MP execution differences

Target environment:

- Project Zomboid **B42 / B42.13 Multiplayer**
- Heavily modded server
- 32 players
- Non-deterministic mod load order

---

### Phase 1 — Communication Inventory (MANDATORY)

Produce a **complete inventory** of all client→server and server→client interactions.

For each interaction, record:

| Field             | Required                                                 |
| ----------------- | -------------------------------------------------------- |
| Entry point       | UI, action, event, hook, or system                       |
| Direction         | Client→Server or Server→Client                           |
| Transport         | TimedAction, `sendClientCommand`, ModData, implicit sync |
| Data sent         | Exact fields and their source                            |
| Execution context | Client, Server, or Both                                  |
| SP behavior       | Does this run in SP? How?                                |

Do **not** summarize. Be exhaustive.

---

### Phase 2 — Authority & Trust Classification

For each interaction identified above, classify:

- **Authoritative owner** (Client or Server)
- **Assumed trust level** (Trusted / Semi-trusted / Untrusted)
- **Actual enforcement** (Verified / Partially Verified / Not Verified)

Explicitly flag cases where:

- Client-provided values influence server decisions
- Server accepts derived or computed client values
- Validation depends on timing or prior state

---

### Phase 3 — Critical Path Tracing

Trace, step-by-step, the following **critical flows**:

1. Buy transaction (UI → money deduction → item grant)
2. Sell transaction
3. Price update / price hook update
4. Late-joining player shop sync
5. Transaction cancellation or rollback

For each flow:

- Identify **where authority switches**
- Identify **race windows**
- Identify **desync or exploit vectors**
- Identify **implicit assumptions**

Use execution-order reasoning, not intent.

---

### Phase 4 — MP Fragility Analysis

Answer the following explicitly:

1. Which flows **depend on execution order**?
2. Which flows **break under lag or delayed packets**?
3. Which flows assume:

   - Single execution
   - No retries
   - No double-send

4. Which flows behave differently in SP vs MP?

Provide concrete examples from code paths.

---

### Phase 5 — Risk Classification (No Fixes)

Classify findings into:

| Risk Level  | Criteria                                                       |
| ----------- | -------------------------------------------------------------- |
| 🔴 Critical | Allows money/item inconsistency, exploits, or permanent desync |
| 🟠 High     | Causes UI desync, wrong prices, or inconsistent state          |
| 🟡 Medium   | Performance, timing, or maintainability risks                  |
| 🟢 Low      | Cosmetic or recoverable                                        |

Do **not** propose fixes yet.
Only describe **why** each risk exists.

---

### Phase 6 — Decision Support Summary

Produce a final section answering:

1. Is **server-calculated pricing** structurally reliable in this codebase?
2. Is **client-calculated pricing with server validation** safer given current constraints?
3. Which architectural model minimizes:

   - Race conditions
   - Load-order sensitivity
   - MP unpredictability

This section should be **analytical**, not prescriptive.

---

### Constraints

- ❌ Do NOT refactor code
- ❌ Do NOT simplify or abstract findings
- ❌ Do NOT assume “intended behavior”
- ✅ Reason strictly from observed logic
- ✅ Prefer execution reality over design intent

---

### Output Format

Deliver results in the following sections **only**:

1. Communication Inventory
2. Authority & Trust Map
3. Critical Flow Traces
4. MP Fragility Findings
5. Risk Classification Table
6. Architectural Decision Implications

---

### Evaluation Criteria

Your analysis will be evaluated on:

- Completeness
- Correct identification of trust boundaries
- Accuracy of MP execution reasoning
- Usefulness for guiding a refactor decision

---
