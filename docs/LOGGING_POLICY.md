Below is a **one-page logging policy** suitable to be committed directly to your repository (for example: `docs/LOGGING_POLICY.md`).
It reflects your **final, corrected design** and avoids ambiguity for future contributors.

---

# Shops Mod – Logging Policy

**Project Zomboid 42.13 Multiplayer**

## Purpose

This document defines **how logging must be implemented and controlled** in the Shops mod.
It separates **player-visible logging** from **server-authoritative audit logging** to ensure:

- Multiplayer safety
- Rollback resilience
- Predictable sandbox behavior
- Long-running server stability

---

## Logging Categories

### 1. Audit Logs (Authoritative)

**Purpose**

- Fraud detection
- Rollback investigation
- Server forensics
- Post-crash recovery

**Characteristics**

- Server-side only
- Always enabled
- Stored in `ModData`
- Never controlled by sandbox variables
- Pruned by time and/or entry count

**Examples**

- `ShopAudit.append(...)`
- `BalanceAudit.append(...)`
- Transaction registry state changes
- Rollback markers (`processed`, `rolled_back`)

**Rules**

- MUST NOT check sandbox variables
- MUST NOT be suppressed
- MUST NOT be written by clients
- MAY be mirrored to file for operators (optional)

---

### 2. Gameplay / UI Logs (Cosmetic)

**Purpose**

- Player feedback
- Informational messages
- Optional verbosity

**Characteristics**

- Cosmetic only
- Safe to suppress completely
- Never authoritative

**Examples**

- `Nfunction.logShop(...)`
- `Nfunction.buildLogShop(...)`
- Chat messages
- UI notifications
- Optional console prints

**Sandbox Control**

- `SandboxVars.Shops.PurchaseLog` → BUY actions
- `SandboxVars.Shops.SellLog` → SELL actions

**Rules**

- MUST respect sandbox variables
- MUST be gated centrally inside logging functions
- MUST NOT rely on call-site sandbox checks
- MUST NOT affect game state

---

### 3. Debug / Developer Logs

**Purpose**

- Development
- Troubleshooting
- Temporary diagnostics

**Examples**

- `print(...)`
- Debug instrumentation

**Rules**

- MUST be guarded by `isDebugEnabled()` or equivalent
- MUST NOT use sandbox variables
- MUST NOT be relied on for gameplay or audits

---

## Sandbox Variable Scope

Sandbox variables in the `Shops` module:

- `Shops.PurchaseLog`
- `Shops.SellLog`

**These variables control cosmetic/UI logging only.**

They:

- DO NOT affect audit logs
- DO NOT affect server-side persistence
- DO NOT affect rollback or security logic

---

## Central Enforcement Rule (Critical)

> **Sandbox checks must live inside logging functions, never at call sites.**

### Correct

```lua
function Nfunction.logShop(action, data)
    if action == "BUY" and not SandboxVars.Shops.PurchaseLog then return end
    if action == "SELL" and not SandboxVars.Shops.SellLog then return end
    ...
end
```

### Incorrect

```lua
if SandboxVars.Shops.PurchaseLog then
    Nfunction.logShop(...)
end
```

This prevents shared-code bypass and future regressions.

---

## File Logging

If file logging is used:

- **Audit file logs**

  - Mirror ModData audit logs
  - Always enabled
  - Ignore sandbox variables

- **Gameplay file logs**

  - Optional
  - Must respect sandbox variables
  - Prefer routing through `Nfunction.logShop`

File logs must never replace ModData as the source of truth.

---

## Naming Conventions

To avoid confusion:

- `log*` → cosmetic, sandbox-controlled
- `audit*` → authoritative, unconditional
- `debug*` → developer-only

Example:

- `logShop()`
- `ShopAudit.append()`
- `debugShop()`

---

## What Contributors Must NOT Do

- Do not gate audit logs with sandbox vars
- Do not write audit data from clients
- Do not assume sandbox vars affect persistence
- Do not add call-site sandbox checks
- Do not suppress forensic data

---

## Summary Rule

> **If a log affects player experience, it respects sandbox variables.
> If a log protects the server, it ignores sandbox variables.**

This policy is mandatory for all new code in the Shops mod.
