> **Normative reference:**  
> This rule set is enforced by `AGENTS.md`.  
> Agents must treat violations as errors.

Below is a **practical, enforceable documentation linter rule set** designed specifically for **long-running Project Zomboid MP mods** and agentic-generated documentation.
This is not theoretical; it is intended to stop entropy _immediately_.

---

# Documentation Linter Rule Set

**Scope:** `docs/`
**Goal:** Preserve long-term information architecture, prevent phase-driven sprawl, and enforce MP-safe clarity.

---

## 1. Folder-Level Rules (Hard Rules)

### DL-F1 — Allowed Top-Level Folders (Strict)

Only the following directories may exist directly under `docs/`:

```
architecture/
behavior/
multiplayer/
implementation/
history/
00_README.md
```

❌ Invalid:

```
docs/phase_3/
docs/wip/
docs/tmp/
docs/notes/
```

**Rationale:** Prevents time-based categorization.

---

### DL-F2 — No Nested Category Duplication

Category names may not appear below top level.

❌ Invalid:

```
docs/behavior/multiplayer/
docs/history/architecture/
```

**Rationale:** Each document must have one primary intent.

---

## 2. File Naming Rules (Hard Rules)

### DL-N1 — No Temporal or Phase Keywords

Filenames must NOT contain:

```
phase
step
iteration
rev
v1 v2 v3
2025 2026
wip
draft
final
test
tmp
```

❌ Invalid:

```
price_fix_phase2.md
ui_flow_2026_01.md
desync_v3_final.md
```

✅ Valid:

```
price_invalidation_rules.md
ui_rebuild_conditions.md
network_desync_causes.md
```

---

### DL-N2 — Lowercase Snake Case Only

```
[a-z0-9_]+.md
```

No CamelCase, no spaces.

---

## 3. Mandatory Document Header (Hard Rule)

Every document **must begin** with this block (within first 20 lines):

```md
# <Title>

**Category:** <architecture | behavior | multiplayer | implementation | history>  
**Stability:** <stable | volatile | historical>
```

### Enforcement Rules

- Folder **must match Category**
- `architecture` may not be marked `volatile`
- `history` must be marked `historical`

❌ Invalid:

```
docs/architecture/price_hooks.md
Category: behavior
```

---

## 4. Content Classification Rules (Soft → Hard Over Time)

### DL-C1 — Phase Language Detection (Warn)

The following phrases trigger warnings:

```
in this phase
next phase
current iteration
we decided to
temporary solution
for now
later we will
```

**Allowed only if:**

- Category = `history`

---

### DL-C2 — Authority Statements Required (MP Projects)

Any document in:

```
behavior/
multiplayer/
```

must contain **at least one** explicit authority statement:

Examples:

```
Server authoritative
Client derived
Client trusted for UI only
Broadcast is authoritative
Revision-gated
```

**Rationale:** Prevents silent trust regressions.

---

## 5. Cross-Document Integrity Rules

### DL-X1 — Architecture Referencing Rule

Documents in:

```
behavior/
multiplayer/
implementation/
```

must reference at least one architecture document:

Example:

```md
(See: architecture/client_server_authority.md)
```

**Rationale:** Prevents behavioral drift from design truth.

---

### DL-X2 — History Isolation Rule

Documents in `history/`:

- ❌ Must not define new rules
- ❌ Must not contain “must / should / required”
- ✅ May explain _why_ something exists

---

## 6. Anti-Agentic Spam Rules (Critical)

### DL-A1 — One Insight per Section

A section may define **one invariant, rule, or conclusion**.

❌ Invalid:

```
## Issues
- A happens
- B happens
- C happens
```

✅ Valid:

```
## Invariant: Price Broadcast Atomicity
...
```

---

### DL-A2 — Flow Diagrams Require Summary

Any diagram (mermaid, sequence, etc.) must be followed by:

```md
**Summary:** <1–3 sentences explaining why this matters>
```

---

## 7. Auto-Reject Conditions (CI-Fail)

Immediate failure if:

- New top-level folder created
- Missing header block
- Phase keyword in filename
- Architecture doc marked volatile
- MP doc without authority statement

---

## 8. Optional: Severity Levels

| Rule Type | Action                         |
| --------- | ------------------------------ |
| Hard      | CI fail                        |
| Soft      | Warning                        |
| Anti-Spam | Warning → Fail after threshold |

---

## 9. Minimal Linter Implementation Strategy

You can implement this with:

- Node.js + markdown-it
- Python + regex
- Pre-commit hook

You do **not** need AST parsing to get 90% value.

---

## 10. Cultural Rule (Most Important)

> Documentation exists to preserve **decisions and invariants**,
> not to narrate implementation progress.

If a document violates that, it belongs in `history/` or should not exist.

---
