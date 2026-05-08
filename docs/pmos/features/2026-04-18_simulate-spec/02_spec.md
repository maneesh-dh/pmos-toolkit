# `/simulate-spec` Skill — Design

**Date:** 2026-04-18
**Status:** Draft
**Location:** `plugins/pmos-toolkit/skills/simulate-spec/SKILL.md`

---

## 1. Problem Statement

The pmos-toolkit pipeline produces detailed specs via `/spec`, then breaks them into implementation tasks via `/plan`. Between those two stages, there is no dedicated step that pressure-tests the spec against realistic and adversarial scenarios. `/spec`'s review loops catch structural gaps (missing sections, incomplete artifacts) and do design-level self-critique, but they do not systematically walk every user flow, edge case, and failure mode through the spec to verify coverage — nor do they produce a standalone artifact documenting why the design is believed to work.

Without this step, design flaws (missing schema columns, incomplete API payloads, unhandled concurrency, missing UI states, wire-up gaps between frontend and backend) tend to surface only during implementation — expensive and disruptive. `/simulate-spec` closes this gap by running a structured simulation pass on the spec and producing a simulation doc whose main output is a Gap Register with concrete spec revisions.

## 2. Goals

| # | Goal | Success Metric |
|---|------|----------------|
| G1 | Catch design gaps before implementation | Spec patches applied per simulation ≥ 3 on average for Tier 2-3 specs |
| G2 | Produce a durable "why we believe this works" artifact | Simulation doc exists and is referenced in code review / onboarding |
| G3 | Handle partial-stack specs (backend-only, CLI-first) without false-positive frontend gaps | Zero "missing frontend" gaps logged when spec declares frontend out of scope |
| G4 | Keep simulation effort proportionate to spec tier | Tier 1 skipped; Tier 2 inline; Tier 3 batched |
| G5 | Integrate cleanly as an optional enhancer between `/spec` and `/plan` | Skill announces, runs to completion, offers `/plan` at end |

## 3. Non-Goals

- **Not a replacement for `/plan`.** Pseudocode is restricted to 2-3 algorithmically complex flows — the rest stays in `/plan`'s TDD tasks.
- **Not a generative skill.** Does not produce new specs. Modifies the existing spec via user-approved patches only.
- **Not a code-review skill.** Operates on the spec document, not on implementation code.
- **Not run for Tier 1 (bug fix) specs.** Bug fixes do not benefit from end-to-end scenario simulation.
- **Not autonomous.** Every spec change requires explicit user approval (no silent edits).

## 4. Decision Log

| # | Decision | Options Considered | Rationale |
|---|----------|--------------------|-----------|
| D1 | Keep simulation as a separate skill rather than folding into `/spec` | (a) Separate skill, (b) Fold into `/spec` review loops | `/spec` is already 9 phases / 540+ lines. Separate skill preserves re-runnability, has distinct deliverable (simulation doc), supports opt-in by tier, matches the `/msf` and `/creativity` enhancer pattern. |
| D2 | Name the skill `/simulate-spec` | (a) `/pseudocode`, (b) `/trace`, (c) `/walkthrough`, (d) `/dry-run`, (e) `/simulate-spec` | User preference. Conveys intent (simulation) scoped to the artifact (spec). |
| D3 | Hybrid approach: scenario trace + adversarial + targeted pseudocode | (a) Scenario trace only, (b) Full pseudocode, (c) Hybrid | Scenario trace validates coverage; adversarial pass exposes failure modes; targeted pseudocode catches algorithmic complexity. Full pseudocode duplicates `/plan`. Trace alone misses algorithmic bugs. |
| D4 | Scenarios generated fresh, seeded by spec | (a) Extract from spec only, (b) Brainstormed fresh seeded by spec, (c) User-provided | The point of simulation is to find gaps the spec missed. Trusting only the spec's scenario list defeats the purpose. Matches ATAM's approach. |
| D5 | Adversarial pass uses fixed checklist + model-driven pass | (a) Fixed checklist, (b) Role-based, (c) Model-driven, (d) Hybrid checklist + model-driven | Checklist ensures coverage floor (10 standard failure categories). Model-driven adds design-specific sharpness. Role-based is redundant with `/spec`'s multi-role interview. |
| D6 | Artifact fitness critique organized into 6 buckets | (a) Per-spec-section, (b) 6 generic buckets with extensibility clause | 6 buckets (Data, Interfaces, Behavior, Interface, Wire-up, Operational) cover ~95% of specs. Extensibility clause handles the rest (CLI, cron, IaC, ML). |
| D7 | Output is a standalone simulation doc + coordinated spec patches | (a) Pure surfacing (gap list only), (b) Coordinated (patches proposed, user approves), (c) Autonomous (silent spec edits) | Coordinated preserves user control while eliminating mechanical re-mapping work. Matches `/spec`'s agent-proposes-user-approves pattern. |
| D8 | Scope Declaration in Phase 1 | (a) Auto-detect only, (b) User declares explicitly, (c) Combination | Auto-detect proposes; user confirms/expands. Handles backend-only, CLI-first, and multi-spec features without false-positive gaps. |
| D9 | Phase 5 generalizes to Interface ↔ Core Cross-Reference | (a) UI ↔ API only, (b) Generalized to whatever interface exists | Supports CLI-first development (CLI ↔ backend functions), library-only specs (public API ↔ internals), and webhook/external-caller patterns. |
| D10 | Single review loop (not 2+) | (a) No review loop, (b) Single pass, (c) Two or more passes matching `/spec` / `/plan` | Simulation is already adversarial by nature. A second pass is "critique the critique." Gap Resolution (Phase 7) already serves as a collaborative review. |

## 5. Pipeline Position

```
/requirements  →  [/msf, /creativity]  →  /spec  →  [/simulate-spec]  →  /plan  →  /execute  →  /verify
                   optional enhancers              optional validator     (this skill)
```

- **Input:** a spec document, located via shared `resolve-input.md` with `phase=specs`
- **Output:** `{docs_path}/simulations/YYYY-MM-DD-<feature>-simulation.md`
- **Side-effect:** coordinated spec revisions via user-approved patches
- **Handoff:** offers `/plan` at the end of the skill's final phase

## 6. Phase Structure

| Phase | Name | Purpose |
|-------|------|---------|
| 0 | Load Workstream Context | Load pmos workstream via `product-context/context-loading.md` |
| 1 | Intake, Tier Detection & Scope Declaration | Read spec, confirm tier, skip if Tier 1, establish scope |
| 2 | Scenario Enumeration | Build scenario list (happy + edge + adversarial checklist + model-driven); user confirms |
| 3 | Scenario Trace | Walk each scenario through spec → coverage matrix with gap flags |
| 4 | Artifact Fitness Critique | Per-bucket: Data, Interfaces, Behavior, Interface, Wire-up, Operational |
| 5 | Interface ↔ Core Cross-Reference | Wire-up table mapping every interface interaction to its core implementation |
| 6 | Targeted Pseudocode | 2-3 flows flagged as algorithmically complex |
| 7 | Gap Resolution | Agent proposes spec patches; user approves / accepts as risk / defers |
| 8 | Write Simulation Doc | Consolidate everything into the final artifact |
| 9 | Review Loop (single pass) | "Did we miss any scenarios, artifacts, or wire-up gaps?" |
| 10 | Workstream Enrichment | Via `product-context/context-loading.md` Step 4 |
| 11 | Capture Learnings | Via `learnings/learnings-capture.md` |

**Gate between Phase 2 and Phase 3:** user must confirm the scenario list before tracing starts.
**Gate between Phase 7 and Phase 8:** every gap must have a disposition before the doc is written.

## 7. Tier Adaptation

| Tier | Behavior |
|------|----------|
| Tier 1 (bug fix) | Skill refuses to run. Announces: "This is a Tier 1 spec — simulation is overkill. Skipping." |
| Tier 2 | All phases run. Inline gap resolution (one gap at a time). 1 review loop. |
| Tier 3 | All phases run. Batched gap resolution (by category). 1 review loop. Deeper adversarial coverage. |

## 8. Phase 1 — Intake, Tier Detection & Scope Declaration

1. **Locate spec** via `../.shared/resolve-input.md` with `phase=specs`, `label="spec"`
2. **Read spec end-to-end.** Confirm understanding with the user (summarize problem, goals, tier)
3. **Check for existing simulation** in `{docs_path}/simulations/`. If found, ask if update or fresh start
4. **Detect tier** from spec header. If Tier 1, announce and exit
5. **Scope Declaration** — the agent produces a proposal and asks the user to confirm:
   - **In this spec:** auto-detected layers (DB, API, FE, CLI, events, infra, etc.)
   - **Out of scope:** from Non-Goals section + agent proposals
   - **Companion specs:** user-provided paths (if multi-spec feature)
   - **Downstream consumers anticipated:** for forward-compat notes (e.g., "frontend coming in Phase 2")
6. **Record scope** in the simulation doc's Scope section

## 9. Phase 2 — Scenario Enumeration

Four passes, then consolidated confirmation:

**2a. Extract from spec.** Each User Journey and each Edge Case in the spec becomes a numbered scenario (S1, S2, ...).

**2b. Generate missing happy-path variants.** Different personas, different entry points, different starting states.

**2c. Adversarial checklist.** For each of these 10 categories, name 1-3 concrete scenarios where applicable (skip categories that don't apply):

1. Service/dependency down
2. Concurrent writes (same resource, same user, two users)
3. Partial failures (step N of M fails)
4. Retries & idempotency
5. Stale data / cache invalidation
6. Permission/auth edge cases (expired token, role changes mid-flow)
7. Data size / pagination limits
8. Network partition / timeout
9. Ordering (out-of-order events, late-arriving data)
10. Empty / null / malformed inputs

**2d. Model-driven pass.** Read the spec critically, name 3-5 failure modes *specific to this design* not captured above.

**Consolidated output:**

| # | Scenario | Source | Category |
|---|----------|--------|----------|
| S1 | Customer places order with expired promo | Spec §5.2 | happy |
| S14 | Two customers apply last-remaining promo simultaneously | Adversarial | concurrency |

**Gate:** "Here are N scenarios. Any missing? Any to remove?" — wait for user confirmation before Phase 3.

## 10. Phase 3 — Scenario Trace

For each scenario, produce a trace row decomposed into steps. For each step, cite the concrete spec artifact that implements it (FR-ID, API endpoint, DB column, sequence diagram, state transition). If no artifact exists, flag as **GAP**.

| Scenario | Step | Spec Artifact | Status |
|----------|------|---------------|--------|
| S14: Concurrent promo apply | 1. Customer A sends POST /orders/{id}/promo | API §9.3 | ✓ |
| | 2. Check promo availability | No `promo_usage` table with unique constraint | **GAP** |
| | 3. Decrement promo counter | Not specified | **GAP** |
| | 4. Return success | API §9.3 response | ✓ |

Gaps append to the **Gap Register** (shared across Phases 3-6).

## 11. Phase 4 — Artifact Fitness Critique

Six buckets. Only run for buckets that apply based on Scope Declaration.

**Bucket 1: Data & Storage**
- Schema shape, relationships, cardinality
- Constraints (unique, FK, NOT NULL, CHECK)
- Indexes supporting actual query patterns
- Lifecycle columns (created_at, updated_at, soft-delete, version)
- Temporal / audit needs
- Idempotency keys, optimistic locking
- Config & feature flags (persistent runtime state)

**Bucket 2: Service Interfaces**
- Request payload completeness
- Response payload usefulness (consumer needs, not just entity returns)
- Error responses enumerated with shape
- Pagination, filtering, sorting
- Idempotency keys on mutating endpoints
- Versioning strategy
- Events, messages, webhooks, 3rd-party integration contracts

**Bucket 3: Behavior (State / Workflows)**
- All states present including failed / cancelled / terminal
- Every transition defined
- Dead states (no way out) flagged
- Side effects named per transition

**Bucket 4: Interface** (adaptive, sub-typed by what exists):
- **UI:** component boundaries, state placement, loading/empty/error/partial/stale states, navigation, validation, accessibility, optimistic updates + rollback
- **CLI:** arguments, flags, output format, exit codes, `--help`, piping/composability, idempotency, `--dry-run`, logging verbosity
- **Library:** API ergonomics (naming, return shapes, error types, pagination patterns)
- **None declared:** skip

**Bucket 5: Wire-up** — handled in Phase 5 (Interface ↔ Core Cross-Reference)

**Bucket 6: Operational**
- NFR specificity (performance targets, accessibility requirements, security)
- Observability (logs, metrics, traces)
- Rollout: feature flags, migration order, rollback plan, graceful degradation
- Architecture diagram: external deps named, data flow directions, ownership boundaries

**Extensibility clause:** "Scan the spec for any artifact types not covered above (CLI, cron, IaC resources, ML training loops, etc.). For each, apply the same 'right vs. just present' critique."

Output: per-bucket findings appended to Gap Register with severity (**blocker / significant / minor / forward-compat**).

## 12. Phase 5 — Interface ↔ Core Cross-Reference

Required when an interface is in scope. Format varies by interface type:

| Interface present | Cross-ref table |
|-------------------|-----------------|
| Frontend (UI) | UI interaction ↔ API endpoint |
| CLI | CLI command ↔ API/function |
| External service / webhook | Caller ↔ endpoint |
| Library-only | Public function ↔ internal logic |
| None declared | Skip Phase 5 |

Standard columns:

| # | Interaction | Trigger | Endpoint/Function | Req Shape Match | Res Has What Consumer Needs | Error Mapping Defined | Notes |
|---|-------------|---------|------------------|-----------------|----------------------------|----------------------|-------|
| W1 | Click "Apply promo" | `<PromoInput>` | POST /orders/{id}/promo | ✓ | ✗ missing `discount_breakdown` | partial — no "expired" msg | Wire-up gap W1 |

**Reverse scan:**
- Every endpoint in the API section → does it have a consumer (or is it flagged internal)?
- Every mutating action in the Interface → does it map to a defined endpoint?

Orphans in either direction become gaps.

## 13. Phase 6 — Targeted Pseudocode

**Selection criteria** — a flow gets pseudocode if ANY apply:
- Non-trivial state machine (3+ states with branching transitions)
- Algorithmic complexity (sorting, matching, scoring, pricing, scheduling)
- Multi-step write with rollback needs
- Reconciliation / retry / idempotency logic
- Concurrency-sensitive (locks, optimistic versioning, CAS operations)

**Cap: 2-3 flows max.** Do NOT pseudocode every flow.

**Format per flow:**

```
Flow: <name>
Entry: <trigger>

FUNCTION <name>(<params>):
  # English description of step
  <variable> = <db call or logic>
  IF <condition>:
    ...
  RETURN <shape>
```

Followed by:
- **DB calls:** queries/mutations this flow performs
- **State transitions:** every state change named
- **Error branches:** every failure point and what happens
- **Concurrency notes:** what's protected by what (lock, transaction, constraint)

## 14. Phase 7 — Gap Resolution

For each gap in the Gap Register:

1. **Context:** which scenario or artifact exposed it, severity
2. **Proposed patch:** specific spec change with exact section and new content
3. **User picks** (Tier 2: one at a time; Tier 3: batched by category):
   - **Apply patch** — agent edits the spec file directly via Edit tool
   - **Modify patch** — user refines, agent applies
   - **Accept as risk** — logged in simulation doc §8 (Accepted Risks) with rationale
   - **Defer as open question** — logged in simulation doc §9 (Open Questions) with owner / needed-by

**Exit:** every gap has a disposition.

## 15. Simulation Doc Template

Saved to `{docs_path}/simulations/YYYY-MM-DD-<feature>-simulation.md`.

```markdown
# <Feature Name> — Design Simulation

**Date:** YYYY-MM-DD
**Spec:** `<path-to-spec>`
**Tier:** 2 | 3

---

## 1. Scope
- **In scope:** [layers covered]
- **Out of scope:** [layers deferred — with pointers if known]
- **Companion specs:** [paths]
- **Downstream consumers anticipated:** [list]

## 2. Scenario Inventory

| # | Scenario | Source | Category |
|---|----------|--------|----------|

## 3. Scenario Coverage Matrix

| Scenario | Step | Spec Artifact | Status |
|----------|------|---------------|--------|

## 4. Artifact Fitness Findings

### 4.1 Data & Storage
### 4.2 Service Interfaces
### 4.3 Behavior (State / Workflows)
### 4.4 Interface (UI / CLI / Library — whichever applies)
### 4.5 Operational (NFRs, Rollout)
### 4.6 Other Artifacts (if present)

## 5. Interface ↔ Core Cross-Reference

| # | Interaction | Trigger | Endpoint/Function | Req Shape Match | Res Has What Consumer Needs | Error Mapping Defined | Notes |

## 6. Targeted Pseudocode

### 6.1 [Flow Name]
[Pseudocode + DB calls + state transitions + error branches + concurrency notes]

## 7. Gap Register

| # | Gap | Exposed By | Severity | Disposition | Notes |
|---|-----|-----------|----------|-------------|-------|

## 8. Accepted Risks
Gaps the user explicitly chose not to fix, with rationale.

## 9. Open Questions

| # | Question | Owner | Needed By |

## 10. Spec Patches Applied

| # | Section | Change Summary | Gap # |

## 11. Review Log

| Loop | Findings | Changes Made |
```

## 16. Skill Frontmatter

```yaml
---
name: simulate-spec
description: Pressure-test a spec against realistic and adversarial scenarios before implementation — scenario trace, artifact fitness critique, interface cross-reference, targeted pseudocode. Optional validator between /spec and /plan in the requirements -> spec -> plan pipeline. Use when the user says "simulate the design", "validate this spec", "will this design actually work", "check for gaps in the design", or has a spec ready for end-to-end scrutiny before implementation.
user-invocable: true
argument-hint: "<path-to-spec-doc>"
---
```

## 17. Integration with Existing Patterns

- **Phase 0:** shared `product-context/context-loading.md` (workstream loading)
- **Phase 1:** shared `.shared/resolve-input.md` with `phase=specs` for spec location
- **Gap Resolution (Phase 7):** uses Edit tool on the spec file; every change logged in simulation doc §10
- **Phase 10:** shared workstream-enrichment pattern (Step 4 of context-loading)
- **Phase 11:** shared `learnings/learnings-capture.md`
- **AskUserQuestion** used for scope declaration, scenario confirmation, gap disposition
- **Tier detection** inherited from the spec (spec declares its tier in its header)
- **Handoff prompt** at end of Phase 11: "Simulation complete. Run `/pmos-toolkit:plan` to generate the implementation plan, or review the simulation first?"

## 18. Anti-Patterns (DO NOT)

- Do NOT run on Tier 1 bug-fix specs — overkill for isolated fixes
- Do NOT trace scenarios before the user confirms the scenario list
- Do NOT write pseudocode for every flow — max 2-3, only when algorithmic complexity triggers apply
- Do NOT flag out-of-scope layers as gaps — respect the Scope Declaration
- Do NOT silently update the spec — every patch requires user approval
- Do NOT conflate "not specified" with "wrong" — Scenario Trace finds coverage gaps, Artifact Fitness finds quality gaps; keep them separate in the Gap Register
- Do NOT run the simulation without reading the spec end-to-end first
- Do NOT skip Scope Declaration — assuming "full stack" causes false-positive gaps in backend-only or CLI-first specs
- Do NOT rubber-stamp gaps as "accepted risk" without recording rationale
- Do NOT batch gap resolution until after Phase 8 — gaps get resolved in Phase 7, before the doc is written
- Do NOT produce the simulation doc before all gaps have a disposition

## 19. Edge Cases

| # | Scenario | Condition | Expected Behavior |
|---|----------|-----------|-------------------|
| E1 | Spec has no User Journeys | Tier 2-3 spec with sparse flow coverage | Agent extracts implicit flows from FR table; asks user to confirm scenario list |
| E2 | Spec is explicitly backend-only | Scope declares "no frontend in this spec" | Phase 4 Bucket 4 and Phase 5 skipped; no frontend gaps logged; forward-compat notes produced if downstream consumer named |
| E3 | CLI-first development | Scope declares CLI as interface | Phase 4 Bucket 4 uses CLI critique prompts; Phase 5 produces CLI ↔ backend cross-ref; forward-compat notes produced if UI planned later |
| E4 | Multi-spec feature (companion spec provided) | User supplies companion-spec path | Agent reads companion during Phase 5 to complete cross-reference table |
| E5 | No interface declared (pure service / library) | Library-only spec | Phase 5 uses public-function ↔ internal-logic cross-ref |
| E6 | All gaps deferred as open questions | User defers everything | Simulation doc still written; review loop surfaces "heavy open-question load" as a warning; `/plan` handoff includes note to resolve open questions first |
| E7 | User runs `/simulate-spec` after editing spec | Existing simulation doc found | Agent asks: update existing or fresh start. Update mode re-runs tracing only against changed sections |
| E8 | Spec is Tier 1 | Bug fix spec | Skill refuses to run with clear message; user can override with explicit `--force` flag if they insist |

## 20. Testing & Verification Strategy

Since this is a skill (prompt-based), verification is primarily manual:

**Smoke test (after creation):**
- Create the skill file at `plugins/pmos-toolkit/skills/simulate-spec/SKILL.md`
- Bump plugin version in `plugin.json`
- Run the plugin validator (pre-existing `plugin-validator` agent)
- Invoke the skill on an existing Tier 2-3 spec in `docs/specs/`
- Verify all 11 phases execute in order
- Verify gates (Phase 2 confirmation, Phase 7 disposition) block progression
- Verify simulation doc is produced at `docs/simulations/YYYY-MM-DD-<feature>-simulation.md`
- Verify at least one spec patch is applied when gaps exist
- Verify Tier 1 spec triggers the skip path

**Regression check:**
- Run on the existing `2026-04-11-context-skill-design.md` or `2026-04-12-pipeline-input-resolution-design.md` spec (Tier 2 or 3) to confirm the skill finds real gaps

**Anti-patterns verification:**
- Confirm skill refuses Tier 1
- Confirm backend-only scope produces no frontend gaps
- Confirm pseudocode count ≤ 3

## 21. Rollout

- Single commit adds the skill file
- Plugin version bump (pre-push hook will enforce)
- No migration needed — purely additive
- No feature flag needed — skill is opt-in by invocation

## 22. Open Questions

| # | Question | Owner | Needed By | Resolution |
|---|----------|-------|-----------|------------|
| 1 | Should the skill's `--force` override for Tier 1 (edge case E8) be supported in v1, or defer? | User | Before `/plan` | **Resolved (2026-04-18):** `--force` supported in v1. Argument hint and Phase 1.4 updated. |
| 2 | For update mode (E7), should re-tracing be restricted to changed sections only (diff-aware) or full re-trace? | User | Before `/plan` | Open — defer to v2 if/when needed |
