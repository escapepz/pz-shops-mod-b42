Below is a **structured, agent-ready REVIEW GUIDE** that your agentic coding tool can follow to produce a **technical review equivalent in depth and quality to the one I gave**, specifically tailored for **Project Zomboid B42.13 Multiplayer mods**.

This is **not a fix guide**.
This is a **review methodology**.

---

# Agentic Review Guide

**Project Zomboid B42.13 MP – Mod Technical Review**

## Review Goal

Produce a **deterministic, engineering-grade review** that answers:

1. Is the mod **B42.13 MP compliant**?
2. Will it cause **silent rollback**?
3. Are there **dupe / exploit vectors**?
4. Is **client/server authority** respected?
5. Are **UI, TimedActions, and ModData** lifecycle-safe?

The output must be **actionable**, not descriptive.

---

## Global Review Rules (Hard Constraints)

The agent MUST:

- Treat **server as authoritative**
- Assume **silent rollback on violation**
- Treat **ModData misuse as critical**
- Ignore visual/style concerns unless they affect sync
- Flag risks even if code "works locally"

The agent MUST NOT:

- Assume B41 behavior
- Trust client-side validation
- Accept "works in SP" as valid for MP

---

## Phase 1 — Architecture & Authority Review

### Agent Checklist

For each file, classify it as:

- Client
- Server
- Shared

Then verify:

| Rule                   | Pass Criteria                   |
| ---------------------- | ------------------------------- |
| Currency mutation      | Server-only                     |
| Inventory mutation     | Server or validated server-side |
| Account creation       | Server-only                     |
| UI state               | Client-only                     |
| TimedAction completion | Server-authoritative            |

### Output Section

**"Architecture & MP Authority Model"**

Include:

- Overall architecture verdict (PASS / PARTIAL / FAIL)
- 2–3 key positive decisions
- 1–2 architectural risks (if any)

---

## Phase 2 — Transaction & Rollback Safety

### What the agent must look for

- Transaction IDs
- Replay protection
- Idempotency
- Reconnect behavior
- Double-execution protection

### Red flags

- No transaction ID
- Transaction ID generated client-side without server validation
- No registry of processed transactions
- ModData mutated twice for same intent

### Output Section

**"Transaction Safety & Rollback Resistance"**

Classify as:

- ❌ Unsafe
- ⚠ Partially safe
- ✅ Rollback-resistant

---

## Phase 3 — Currency & Balance Flow

### Mandatory Checks

- Where is balance stored?
- Who mutates it?
- Is ModData transmitted?
- Are nil accounts handled?

### Agent must verify

- `getOrCreate()` usage
- `ModData.transmit()` presence
- Server-only writes

### Output Section

**"Currency & Balance Flow"**

Include:

- Correct patterns
- One concrete risk (even if minor)

---

## Phase 4 — Inventory, Wallet & Tooltip Sync

### Required checks

- Inventory transfer restrictions
- Ownership validation
- Tooltip hooks safety
- UI suppression logic

### Special B42 checks

- Tooltip rendering during context-menu visibility
- `getPlayer()` assumptions
- Client-only crashes due to nil ModData

### Output Section

**"Wallet / Tooltip / Inventory Sync"**

Mark:

- Safe
- Safe with caveats
- Risky

---

## Phase 5 — UI Lifecycle & State Safety

### Agent must analyze

- `instance` singleton usage
- Open/close cleanup
- Re-entrancy protection
- Action-in-progress flags
- Distance auto-close

### Red flags

- UI not resetting flags
- Cart not cleared after action
- Multiple UI instances possible

### Output Section

**"Shop UI & State Management"**

Include:

- 3 concrete strengths
- 1 UX or state risk

---

## Phase 6 — TimedActions (Critical)

### Mandatory checks

- `isServer()` gating
- Inventory removal location
- Balance mutation location
- Sound effects (client-only allowed)
- Action cancellation behavior

### Red flags

- Client-side inventory removal
- Balance change in `perform()` on client
- No transaction finalization guard

### Output Section

**"TimedActions Review (Critical Area)"**

Explicitly state:

> "This is / is not safe for B42 MP because…"

---

## Phase 7 — World Objects & Destruction

### Agent checks

- Placement authority
- ModData ownership assignment
- Anti-griefing logic
- Admin override correctness

### Output Section

**"World Object Placement & Destruction"**

Short and factual.

---

## Phase 8 — Transfers & Inter-Player Actions

### Required checks

- Server-side validation
- Cooldowns (client vs server)
- Pending / confirmed flow
- Failure handling

### Output Section

**"Transfer System Review"**

Mark:

- Secure
- Secure with UX assumptions
- Unsafe

---

## Phase 9 — ModData & Persistence Audit

### Agent must verify

- Which ModData keys exist
- Creation vs mutation
- Transmit calls
- Growth behavior

### Output Section

**"ModData Lifecycle & Persistence"**

Explicitly list:

- Which keys persist
- Which do not
- Why

---

## Phase 10 — Risk Register

The agent MUST include a **Known Risks** section even if everything passes.

### Categories

- Performance
- Data growth
- Edge reconnect
- Abuse / spam
- Admin misuse

---

## Final Verdict Section (Mandatory)

Format exactly:

```
B42.13 MP Compliance: PASS / PARTIAL / FAIL
Rollback Safety: STRONG / MEDIUM / WEAK
Dupe Resistance: STRONG / MEDIUM / WEAK
Architecture Quality: HIGH / MEDIUM / LOW
```

Followed by **1–2 sentences max** justification.

---

## Optional Follow-ups (Agent Suggests, Not Executes)

- QA checklist
- Stress scenarios
- Feature integration review
- Admin tooling

---

## Output Quality Requirements

The agent's review must:

- Be structured
- Use technical language
- Avoid speculation
- Avoid repeating code
- Avoid restating obvious facts

If the agent cannot justify a claim, it must mark it as **unknown**.

---

## Summary Instruction for Agent

> "Review this mod as if silent rollback is guaranteed on mistake.
> Your job is not to praise, but to prevent future corruption."
