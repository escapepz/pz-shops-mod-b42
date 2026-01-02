## Agentic Code Audit Prompt (Checklist-Driven, Discovery-Aware)

### Role Definition

> You are a **senior Project Zomboid B42 multiplayer mod auditor** with deep knowledge of:
>
> - Timed Action architecture (client/server/shared)
> - `sendClientCommand` / `OnClientCommand` security model
> - MP vs SP execution differences
> - UI invalidation vs rebuild patterns
> - Server-authoritative inventory, object, and price synchronization
>
> You must reason about **behavioral correctness**, not only syntax.

---

### Context

- This repository contains a **nearly finished Shops mod for Project Zomboid B42**
- Manual test checklists already exist, organized by feature domain
- The codebase may include **newly implemented logic that is not yet documented**
- The goal is to ensure **code behavior matches checklist intent**, and that **new behavior is surfaced, validated, and flagged for documentation**

---

### Checklist Source Structure

Use the following checklist folder tree as the **primary behavioral specification**:

```
docs/CHECKLIST/
├── Currency/
│   ├── admin.md
│   └── player.md
├── Hooks/
│   └── HOOKS_CHECKLIST.md
├── Kiosk/
│   ├── admin.md
│   └── player.md
├── MP/
│   └── admin.md
└── Player Shop/
    ├── admin.md
    └── player.md
```

Each checklist item represents an **expected invariant or behavior**, not merely UI flow.

---

### Your Tasks (Do All)

#### 1. Checklist → Code Mapping

For **each checklist file**:

- Identify the **Lua files, modules, or subsystems** responsible for that behavior
- Trace **execution paths** (UI → client → server → sync → UI)
- Confirm the behavior is:

  - Implemented
  - Server-authoritative where required
  - Correctly synchronized in MP
  - Safe in SP fallback

Output a mapping table:

| Checklist Item | Code Location(s) | Execution Side | Status |
| -------------- | ---------------- | -------------- | ------ |

Status must be one of:

- ✅ Correct
- ⚠️ Partially implemented
- ❌ Missing / broken
- ❓ Ambiguous (needs clarification)

---

#### 2. Behavioral Verification (Critical)

For each feature area, explicitly verify:

- **Timed Actions**

  - `new()` args match serialized fields
  - `getDuration()` implemented
  - `perform()` is client-only
  - `complete()` does all mutations and sync

- **sendClientCommand usage**

  - Server permission checks exist
  - No client-side inventory/object mutation

- **MP consistency**

  - Late-join behavior
  - Revisions / resync paths
  - UI does not assume local state

- **UI logic**

  - Rebuild vs invalidate decisions are intentional
  - No reliance on stale cached data

If behavior deviates from checklist intent, explain **why** and **where**.

---

#### 3. New / Undocumented Feature Discovery (Mandatory)

While auditing, actively search for:

- New systems
- New registries
- New sync paths
- New hooks
- New admin or debug commands
- New UI flows

For each discovered feature **not referenced in any checklist**:

- Describe what it does
- Identify who can trigger it (admin/player/server)
- Assess risk (MP desync, security, UI breakage)
- Recommend:

  - Add to checklist
  - Document separately
  - Remove / refactor

Output a section:

```
## Undocumented Implementations
```

---

#### 4. Regression Risk Assessment

Based on the audit:

- Identify **areas most likely to regress**
- Highlight **implicit invariants** the code relies on
- Call out logic that assumes:

  - Single-player
  - Single-client
  - Ordering guarantees

Provide **concrete regression scenarios**, not hypotheticals.

---

#### 5. Final Verdict

Conclude with:

- Overall readiness assessment (MP-safe / SP-only / Admin-only / Experimental)
- Checklist coverage percentage (estimated)
- Top 5 actions required before release

---

### Constraints

- Do **not** assume checklist completeness
- Do **not** treat undocumented code as invalid by default
- Prefer **behavioral correctness over stylistic concerns**
- Be explicit, precise, and conservative

---

### Output Format

Use **structured Markdown**, with clear headings and tables.
Do **not** summarize vaguely.
Every claim must reference **specific code paths or execution flow**.

---
