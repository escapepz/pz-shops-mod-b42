Below is a **practical, agent-ready approach** to having an agentic coding tool review your **Shops mod architecture for performance**, explicitly scoped to a **32-player, heavily modded MP server** with **~100–120 ms latency**.

This is not generic advice; it is structured so an autonomous code reviewer can reason about **Project Zomboid’s MP execution model**, your **shop-specific data flows**, and the **real bottlenecks that appear only at scale**.

---

## 1. Frame the Target Runtime Environment Precisely

Your agent must understand _what “performance” means in this context_.

Include this at the top of the prompt:

> **Runtime Assumptions**
>
> - Game: Project Zomboid Build 42.13
> - Multiplayer, authoritative server
> - 32 concurrent players
> - 100–120 ms RTT latency
> - Heavily modded environment (many event listeners, frequent ModData sync)
> - Shops mod used concurrently by multiple players

This prevents the agent from optimizing for SP or low-population servers.

---

## 2. Define the Performance Threat Model (Critical)

Do **not** ask the agent to “optimize code”.
Ask it to **identify architectural pressure points**.

Give it this explicit threat model:

> **Performance Threat Model**
> The review must focus on:
>
> 1. Server main-thread pressure (Lua execution on tick / events)
> 2. Network amplification (broadcasts, ModData sync, sendClientCommand)
> 3. Client-side UI rebuild cost under frequent updates
> 4. O(N × players) patterns that scale poorly at 32 players
> 5. Latency-sensitive flows (round-trips during shop interaction)

This aligns directly with how PZ MP actually degrades under load.

---

## 3. Force an Architectural Review (Not Line-by-Line)

Agentic tools tend to get lost in micro-optimizations unless constrained.

Use **architecture-first instructions**:

> **Review Scope**
>
> - Analyze data ownership boundaries (server vs client)
> - Trace authoritative flows for:
>
>   - Price calculation
>   - Inventory mutation
>   - ModData reads/writes
>   - UI refresh triggers
>
> - Identify any logic that executes:
>
>   - Per player
>   - Per item
>   - Per tick
>   - Per price update
>
> - Ignore formatting, naming, and style issues

---

## 4. Require Explicit Flow Tracing

This is where your previous work gives you leverage.

Tell the agent to **trace these flows explicitly**:

> **Mandatory Flow Traces**
>
> 1. Player opens Shop UI
> 2. Price data arrives / updates
> 3. Player buys or sells an item
> 4. Price rules or hooks change
> 5. Player shop (P2P) transaction completes
>
> For each flow:
>
> - Identify server-side execution points
> - Identify network messages sent
> - Identify client-side recomputation or rebuilds
> - Estimate frequency under 32 players

This forces the agent to reason in _runtime terms_, not static code terms.

---

## 5. Add Hard Performance Questions the Agent Must Answer

These questions dramatically improve output quality:

> **Required Findings**
> The review must answer:
>
> - Where does this mod execute logic proportional to:
>
>   - number of players?
>   - number of shop items?
>   - number of UI rows?
>
> - Which updates are broadcast vs targeted?
> - Which ModData keys are written frequently?
> - Are any recalculations repeated that could be memoized or revision-gated?
> - Are any UI rebuilds triggered when invalidation would suffice?

You are effectively giving the agent a performance checklist.

---

## 6. Ask for Risk Classification, Not Just Suggestions

Instead of “recommend improvements”, require classification:

> **Output Format**
> For each issue found, classify as:
>
> - 🔴 Critical at 32 players
> - 🟠 Degrades under load
> - 🟢 Acceptable
>
> Include:
>
> - Why it scales poorly
> - When it becomes visible (player count / frequency)
> - Whether it is CPU-bound, network-bound, or UI-bound

This mirrors how you already reason about regressions and invariants.

---

## 7. Example Prompt You Can Use Directly

You can paste the following almost verbatim into an agentic coding tool:

---

**Agent Task: Multiplayer Performance Architecture Review**

> Review this Shops mod for multiplayer performance under the following conditions:
>
> - Project Zomboid B42.13, multiplayer
> - 32 concurrent players
> - 100–120 ms latency
> - Heavily modded server
>
> Focus on **architecture and runtime behavior**, not style.
>
> Analyze:
>
> - Server-authoritative logic
> - Network synchronization patterns
> - ModData usage frequency
> - UI rebuild vs invalidation strategy
>
> Trace these flows:
>
> 1. Shop UI open
> 2. Price sync / update
> 3. Buy / sell transaction
> 4. Price rule change
> 5. Player shop transaction
>
> For each issue found:
>
> - Classify severity (Critical / Degrading / Acceptable)
> - Explain scaling behavior at 32 players
> - Identify whether it is CPU, network, or UI bound
>
> Ignore formatting, naming, and non-runtime concerns.

---

## 8. What “Good” Looks Like for Your Mod

Based on your prior design decisions, a **healthy result** should conclude that:

- Price calculations are **revision-gated**, not reactive spam
- UI updates are **row-invalidated**, not fully rebuilt
- Server does **O(1)** work per transaction, not O(items)
- Broadcasts are **intentional and bounded**
- Player shop logic does **not** trust client input
- No per-tick or per-frame shop logic exists

If the agent flags anything violating those principles, it is worth addressing before publish.

---
