---
tier: 2
type: enhancement
feature: plan-skill-redesign
status: Draft
date: 2026-05-08
requirements: ../../../.pmos/grills/2026-05-08_plan-skill-design.md
---

# /plan Skill Redesign — Spec

**Date:** 2026-05-08
**Status:** Draft
**Requirements:** `.pmos/grills/2026-05-08_plan-skill-design.md` (the grill report — 62 resolved decisions, 7 cross-skill changes)

---

## 1. Problem Statement

The current `/plan` skill (`plugins/pmos-toolkit/skills/plan/SKILL.md`, ~500 lines) mandates a single full-format output regardless of scope: ≥3 decision-log entries, ≥2 review loops, file map, risks, rollback, 15-item TN with Playwright/wireframe-diff/UX-polish, even for one-line bug fixes routed through Tier-1 `/requirements` and `/spec`. It hardcodes Python/pytest/Docker/Alembic/curl examples that are wrong for non-Python repos. It has internal contradictions (zero-context promise vs Phase 2 conventions; Platform Adaptation says "no Playwright" while TN prescribes 7 Playwright steps), redundancy (Phase 4 vs Phase 5; TN vs phase-boundary /verify), and gaps (no autonomous mode, no mid-execute replan protocol, no cross-feature conflict detection, no idempotency or state-ordering signal for /execute, no convergence cap on review loops).

**Primary success metric:** A skilled engineer can take a Tier-1 bug-fix spec and a Tier-3 feature spec through `/plan` in the same repo with the same skill, getting tier-appropriate output (one-task plan vs full multi-phase plan) — no manual section-deletion, no hardcoded Python commands, no inconsistent platform behavior.

---

## 2. Goals

| # | Goal | Success Metric |
|---|------|---------------|
| G1 | Tier-aware output: T1/T2/T3 plans differ in mandatory sections, review-loop floor, decision-log floor, and TN coverage | Generate one plan per tier from the test-fixture specs; assert section-presence per tier table |
| G2 | Stack-aware verification: prereqs, lint/test commands, API smoke patterns derived from detected stack signals (not hardcoded) | Run /plan in a Node repo, a Python repo, a Go repo; resulting `T0` and `TN` cite stack-correct commands; zero hits for "alembic" or "pytest" in non-Python output |
| G3 | Platform-neutral templates: TN, prereq commands, closing offer adapt to Claude Code / Gemini / Copilot / Codex | Skill body has no unconditional Playwright/`/pmos-toolkit:execute` strings outside `_shared/platform-strings.md` |
| G4 | Explicit /execute handshake: tasks declare dependencies, idempotency, required state, data sources | Generated plans carry `**Depends on:**`, `**Idempotent:**`, `**Requires state from:**`, `**Data:**` on every task; /execute v2 consumes these |
| G5 | Convergent review loops with memory: hard cap, persistent skip list, sidecar review log, low-risk auto-apply | Loop never exceeds 4 iterations; loops 2+ dedupe against skip list; review log lives at `03_plan_review.md` |
| G6 | Operational completeness: autonomous mode, mid-execute replan handoff, cross-feature conflict detection, three update modes | `--non-interactive` flag works end-to-end on a sample spec; `/plan --fix-from <task-id>` resumes from defect file; Edit/Replan/Append modes all produce expected diffs |
| G7 | Coordinated cross-skill release: /spec emits anchors and tier+type frontmatter; /execute consumes new task fields; /backlog type field used; new shared resources in place | Single pmos-toolkit minor version bump ships all changes; backwards-compat shim warns (does not error) on missing optional fields |

---

## 3. Non-Goals

- **Per-task or per-plan effort estimates** — D59 confirmed; tier signals roughness, no T-shirt sizing.
- **Multiple plan-doc files per feature** (e.g., `03_plan_<slice>.md`) — D10 keeps single `03_plan.md`; multi-subsystem split happens at /spec time.
- **Auto-invoking /spec when no spec exists** — D51 refuses; user runs /spec explicitly.
- **Running /plan with no requirements doc** — out of scope; /plan still requires a spec.
- **Internationalization of plan output** — English-only.
- **Migrating in-flight plan files (pre-v2 format) to v2** — old plans run on the old skill; new plans run on v2. Hard cut for the format itself; backwards-compat shim only at the consumer side (/execute warns on missing fields, doesn't fail).
- **Designing /spec v2, /execute v2, /backlog changes in detail** — those land as separate specs; this spec defines the *contract* /plan v2 needs from them, not their internals.

---

## 4. Decision Log

> Inherits 62 decisions D1–D62 from the grill report (`.pmos/grills/2026-05-08_plan-skill-design.md`). Entries below are spec-stage decisions made during multi-role interview that resolve operational ambiguities the grill left unstated.

| # | Decision | Options Considered | Rationale |
|---|----------|-------------------|-----------|
| S1 | Tier signal: spec frontmatter `tier: 1\|2\|3` | (a) frontmatter, (b) /plan re-detects, (c) AskUserQuestion at start | Frontmatter is single-source-of-truth and matches /spec's tier-detection investment. /plan re-detection risks disagreement; AskUserQuestion costs an interaction every run. |
| S2 | Stack libraries: per-stack file `_shared/stacks/<stack>.md` | (a) per-stack file, (b) inline in SKILL.md, (c) yaml registry | Per-file is user-extensible without code change, easy to grep, and lets each stack carry prose snippets (not just commands). YAML loses prose flexibility; inline bloats SKILL.md. |
| S3 | Cross-skill rollout: coordinated single release with backwards-compat shim | (a) coordinated single release, (b) versioned protocol, (c) hard cut | Single release ships interlocking changes (tier frontmatter, anchors, new task fields, /execute consumers, _shared/stacks/, _shared/platform-strings.md, /backlog type field) without partial-state breakage. Shim warns on missing optional fields rather than failing. |
| S4 | UI-task detection: Wireframe refs OR frontend-file path | (a) either signal, (b) wireframes-only, (c) per-task `ui:` flag | Either-signal catches non-wireframed UI work (small CSS tweaks, ad-hoc components). Wireframes-only misses cases. Per-task flag adds boilerplate. Frontend file path comes from stack detection (S2). |
| S5 | Bug-fix TDD trigger: spec frontmatter `type: bugfix` OR backlog `type=bug` OR per-task `**TDD:** bug-fix` override | (a) three-signal union, (b) --backlog only, (c) always for Tier 1 | Three-signal union covers backlog and non-backlog flows without false-positive Tier-1 enhancements (which aren't bugs). /spec emits `type` field (S6) so the signal is uniform. |
| S6 | Spec frontmatter: `tier`, `type`, `feature`, `status`, `date`, `requirements` mandatory at all tiers | implicit in S1, S5 | Single contract surface for downstream skills. Explicit frontmatter eliminates content-sniffing. |
| S7 | Non-interactive cap-hit fallback: accept-and-proceed + `## Convergence Warning` block at top of plan | (a) accept + warn, (b) abandon, (c) loop unbounded | Autonomous use is a real driver (subagent tasks, scheduled runs, CI dry-runs). Abandoning blocks legitimate flows. Unbounded looping risks runaway. Visible warning preserves trust (/verify and humans see it). |
| S8 | Backwards-compat shim contract: /execute v2 reads `**Depends on:**` / `**Idempotent:**` / `**Requires state from:**` / `**Data:**` if present; missing fields produce a single-line warning per task, not an error | shim design follow-up to S3 | Lets pre-v2 plans (and partial-migration plans) execute. The warning surfaces drift; the warning being per-task makes the cleanup unit visible. |

---

## 5. User Journeys

Three primary journeys. Each is described to the level of "what /plan does and what the user sees."

### 5.1 Journey A: Tier-1 bug fix from /backlog item type=bug

```
user: /backlog promote BG-42 --through plan
  /requirements (tier 1, type bugfix)  →  /spec (tier 1, anchors)  →  /plan
/plan reads spec frontmatter: tier=1, type=bugfix
/plan detects backlog item: type=bug → bug-fix TDD pattern
Phase 0: read _shared/pipeline-setup.md (S3 mandatory read)
Phase 1: read spec, summarize back, confirm with user
Phase 2: deep code study scoped to impacted file(s); detect stack (e.g., python via requirements.txt)
Phase 3: write 03_plan.md
  - 1 task: T1 (regression test reproducing bug, fix, regression test passes)
  - No decision log floor, no risks, no rollback, no Phase 5
  - TN reduced: lint + test + manual spot check from Done-when walkthrough
  - File Map = generated index pointing to T1
Phase 4: 1 review loop (T1 floor); auto-apply low-risk findings
Done-when walkthrough: regression test fails on pre-fix HEAD, passes on fix
user: /execute → fix lands
```

### 5.2 Journey B: Tier-3 feature with wireframes, multi-phase, on Node repo

```
user: /plan @docs/features/2026-06-01_team-permissions/02_spec.md
/plan reads frontmatter: tier=3, type=feature
Phase 0: pipeline-setup.md (mandatory), repo-local + global learnings
Phase 1: read spec, summarize, confirm; check 02_simulate-spec_*.md (D30) — none, proceed
Phase 2: deep code study; detect stack=node (package.json present); load _shared/stacks/node.md;
         glob peer feature folders (D43) — flag overlap on src/auth/* with feature X;
         scan wireframes/ — 8 screens
Phase 3: write 03_plan.md
  - Phases: 4 phases, 6-8 tasks each (deployable slices)
  - Tasks declare Depends on / Idempotent / Requires state from / Data / Wireframe refs / Spec refs / TDD: yes
  - Risks table with Likelihood + Impact + Mitigation-in-Tn citation
  - Decision log: implementation-specific entries; spec re-opens halt and route back to /spec (D13)
  - File Map = generated index from per-task Files
  - Mermaid execution-order diagram auto-rendered from Depends-on
  - TN absorbed into last phase's verify (D4); no separate end-of-plan TN
  - Stack signals → T0 prereqs use `npm ci`, `docker compose ps`, etc; API smoke uses node-fetch shape
Phase 4: ≤4 loops; loop 2 dispatches blind subagent reviewer; skip list persists in 03_plan_review.md
Phase 5 (folded into Phase 4): conciseness + blind-spots checks
Closing offer (platform-aware via _shared/platform-strings.md): "Spec complete. Run **/pmos-toolkit:execute** to implement, **/grill 03_plan.md** to stress-test the plan adversarially before executing, or **/simulate-spec** to re-validate the upstream spec against scenarios. Each next-step is independent — pick zero, one, or several."
```

### 5.3 Journey C: Mid-execute defect → replan → resume

```
/execute on T7: planning defect — task assumes table X.col_y exists, doesn't
/execute writes docs/features/.../03_plan_defect_T7.md with failure context
/execute halts: "Run /pmos-toolkit:plan --fix-from T7 to repair"
user: /plan --fix-from T7
/plan reads defect file, enters Edit mode (D26 mode a) scoped to T7 + downstream
Phase 4: 1 review loop on the affected slice; preserves Skip List (D60 — Edit mode preserves)
03_plan.md updated in-place (no Supersedes header — Edit, not Replan)
user: /execute resumes from T7
```

---

## 6. Functional Requirements

### 6.1 Tier system

| ID | Requirement |
|----|-------------|
| FR-01 | /plan reads `tier: 1\|2\|3` from spec frontmatter; refuses with platform-aware error if absent |
| FR-02 | T1 plans: skip Decision-Log min, 1 review loop, no Phase 5 (already folded), no Risks/Rollback unless plan content triggers them, reduced TN (lint + test + Done-when walkthrough only) |
| FR-03 | T2 plans: ≥1 Decision-Log entry, 1 review loop, optional Risks/Rollback, full TN |
| FR-04 | T3 plans: current floors (≥3 Decision-Log, 2-4 review loops, mandatory Risks, conditional Rollback, full TN) |
| FR-05 | Tier signal also drives bug-fix TDD trigger via `type: bugfix` (S5) |

### 6.2 Stack detection and library

| ID | Requirement |
|----|-------------|
| FR-10 | Phase 2 has explicit "detect stack signals" step: globs for `package.json`, `Gemfile`, `go.mod`, `requirements.txt`, `Cargo.toml`, `pom.xml`, `composer.json`, `docker-compose.yml`, `Makefile`, `Dockerfile`. Records detected stack(s) in Code Study Notes' "Stack signals" subsection (D61) |
| FR-11 | `_shared/stacks/<stack>.md` exists for at least: `node`, `python`, `rails`, `go`, `static`. Each file contains: prereq verification commands (T0), lint/test/format commands, API smoke pattern by interface (HTTP/GraphQL/gRPC/CLI/static), common fixture patterns |
| FR-12 | T0 (Prerequisite Check) task is auto-generated from detected stack(s); T0 is read-only and idempotent; /execute fails fast on T0 failure |
| FR-13 | TN's API smoke step is generated from detected stack — never `curl \| json.tool` baked in |
| FR-14 | When stack detection is ambiguous (multiple signals) /plan asks user via AskUserQuestion (or, in `--non-interactive`, picks the dominant signal by file-count and logs in Auto-decisions made:) |

### 6.3 Plan document structure

| ID | Requirement |
|----|-------------|
| FR-20 | Plan output starts with frontmatter (authoritative contract): `tier` (from spec), `type` (from spec), `feature` (slug, from spec), `spec_ref` (relative path), `requirements_ref` (relative path), `date` (YYYY-MM-DD), `status` (Draft / Planned / Executing / Done / Archived), `commit_cadence` (per-task / per-phase / squash; **default: per-task**; overridden by repo-level `.pmos/settings.yaml: plan.commit_cadence` or by AskUserQuestion at start when repo has no setting and the spec has unusual scope). Downstream consumers (/execute, /verify, peer-plan conflict scan) read from this contract — no other source of truth. Phase 4 validates frontmatter consistency: `commit_cadence: per-phase` requires `## Phase N` blocks to exist; `commit_cadence: squash` requires no per-task commit step in any task's Steps; mismatches are hard-fails |
| FR-21 | Plan body sections in order: Overview (with Done-when), Decision Log, Code Study Notes (4 mandatory subsections per D61), Prerequisites (T0 reference), File Map (generated index), Risks (if applicable), Rollback (if applicable), Tasks, (no separate Review Log — sidecar) |
| FR-22 | Done-when uses lower bounds and qualitative gates only (D46); Phase 4 check rejects exact counts |
| FR-22a | Done-when must contain at least one quantitative or executable assertion (test count, route count, command output, file existence). Vague phrases ("works correctly", "is performant", "looks right") fail Phase 4 (D29) |
| FR-22b | TN includes a "Done-when walkthrough" — clause-by-clause evidence check (command output / screenshot / log line) — at all tiers. Replaces the legacy "Manual spot check" line entirely (D62) |
| FR-23 | File Map is a generated index ("see T1, T3, T7 — `src/x/y.ts`") derived from per-task `**Files:**` sections; tasks are source of truth (D12) |
| FR-24 | File-action verbs: Create, Modify, Delete, Move, Rename, Test (D48). Move/Rename rows specify source AND destination |
| FR-25 | Execution-order diagram is auto-rendered Mermaid from per-task `**Depends on:**` lines (D25). Emitted as an inline ` ```mermaid ` fenced block in the plan markdown — rendered natively by GitHub and most markdown viewers; no external rendering pipeline required |
| FR-26 | When `## Phase N` groupings are used, last phase's verify IS the TN — no separate end-of-plan TN task (D4) |
| FR-27 | Phase grouping rule: phases are used when a deployable slice exists mid-plan; size = "enough to be worth a /verify run." No task-count thresholds (D9) |

### 6.4 Per-task fields (load-bearing)

Every task includes:

| ID | Field | Required? | Purpose |
|----|-------|-----------|---------|
| FR-30 | `**Goal:**` | Always | One-sentence task purpose |
| FR-31 | `**Spec refs:**` | Always | Cite anchor IDs from /spec frontmatter (cross-skill: requires /spec to emit anchors at all tiers — out of scope for this spec, see Open Questions) |
| FR-31a | Broken-ref detection. Phase 4 hard-fails when any task's `**Spec refs:**` cites an anchor that does not exist in the current `02_spec.md`. Same rule applies to `**Wireframe refs:**` against the `wireframes/` folder (referenced HTML file must exist). /verify Phase 4 re-runs both checks before declaring done — catches drift introduced by post-plan spec or wireframe edits | | |
| FR-32 | `**Wireframe refs:**` | If UI-touching (S4) | Wireframes-as-reference per D7; layout-pattern gaps must be called out |
| FR-33 | `**Files:**` | Always | Create/Modify/Delete/Move/Rename/Test rows |
| FR-34 | `**Depends on:**` | Always (may be `none`) | Task IDs gating this task; /execute consumes for ordering and [P] inference |
| FR-35 | `**Idempotent:**` | Always | `yes` / `no — <recovery substep ref>`; non-idempotent tasks include a recovery substep referenced by ID. Phase 4 hard-fails when a task declares `**Idempotent:** no` without a recovery substep present in its Steps list |
| FR-36 | `**Requires state from:**` | If applicable | Upstream task IDs whose post-state this task depends on (migrations applied, fixtures seeded, services started) |
| FR-37 | `**TDD:**` | Always | `yes — new-feature` / `yes — bug-fix` / `no — <reason>` |
| FR-38 | `**Data:**` | If task has tests | Data source: `fixture X`, `factory Y`, `seed via scripts/seed_X.py`, etc. |
| FR-39 | `**Steps:**` | Always | Bite-sized steps (smells not rules per D8) with exact commands and expected output for verification steps |

### 6.5 Review loop machinery

| ID | Requirement |
|----|-------------|
| FR-40 | Review loops have a hard cap of 4 (D14); on cap-hit interactive: AskUserQuestion (continue / accept-and-proceed / abandon); cap-hit non-interactive: accept-and-proceed + write `## Convergence Warning` at top of plan listing remaining findings (S7) |
| FR-41 | Findings are auto-classified as low-risk or high-risk. Low-risk auto-applied with end-of-loop digest; high-risk batched into AskUserQuestion (max 4 per call) (D15) |
| FR-41a | Auto-classification rule. **Low-risk:** (a) typos and grammar, (b) missing exact command in a verification step that already has expected output, (c) lint-style suggestions, (d) section-presence completions where content already exists elsewhere in the plan, (e) wireframe-ref additions when the wireframe file is unambiguous, (f) cosmetic clarifications to existing rules. **High-risk:** (a) task split or merge, (b) dependency-graph changes, (c) new sections, (d) decision-log reversals, (e) any change that alters TN scope, (f) any change that shifts tier-gated mandates, (g) any change to frontmatter contract or cross-skill handshake. **Default for ambiguous findings: high-risk** (escalate, don't auto-apply) |
| FR-42 | Loop 1 = self-review. Loop 2 (if reached) dispatches a fresh subagent (Explore or general-purpose) given only plan + spec for blind-review findings. Platform fallback: skip subagent on no-subagent platforms (D20) |
| FR-43 | Skip List persists across loops as a `## Skip List` section in `03_plan_review.md` sidecar; subsequent loops dedupe their findings against fingerprints (D50). Re-raising a skipped finding requires explicit user override |
| FR-44 | On Replan (D26 mode b) Skip List moves under `## Archived (pre-replan YYYY-MM-DD)`; on Edit (mode a) Skip List preserved; on Append (mode c) Skip List preserved (D60) |
| FR-45 | Review Log lives in sidecar `{feature_folder}/03_plan_review.md` — not inline in `03_plan.md` (D33) |
| FR-46 | Phase 5 is folded into Phase 4 design-critique (Conciseness + Blind spots become checklist items) (D3) |

### 6.6 Cross-skill contracts

| ID | Requirement |
|----|-------------|
| FR-50 | /plan refuses with platform-aware "No spec found at {path}. Run /spec first." when spec is missing (D51) — does not auto-invoke /spec |
| FR-51 | /plan reads `02_simulate-spec_*.md` if present in feature folder; surfaces unresolved findings via AskUserQuestion before planning (D30) |
| FR-52 | /plan invokes `/backlog set {id} plan_doc={path}` then `/backlog set {id} status=planned` when `--backlog <id>` is passed; on failure warns and continues |
| FR-53 | /plan deferred-work auto-capture targets out-of-scope notices (adjacent bugs, refactor opportunities) via a new `## Notices` section the hook scans — not deferred spec items (D11). Spec coverage gaps remain a Phase 4 hard-fail |
| FR-54 | Phase 2 globs `{docs_path}/features/*/03_plan.md` (excluding current) and greps for impacted file paths; conflicts produce a Risks-table row with Mitigation = "coordinate with feature X" + Open Question (D43) |
| FR-54a | "In flight" definition for FR-54: peer plans whose plan frontmatter `status` is `Draft`, `Planned`, or `Executing`. Plans with `status: Done` or `status: Archived`, or feature folders containing `04_complete.md` or `05_verified.md`, are excluded from the conflict scan |
| FR-55 | If `--backlog <id>` passed: Phase 4 check that every backlog acceptance criterion maps to a task or TN line OR is in a `## Backlog Out-of-Scope` subsection with rationale (D53) |
| FR-56 | On planning defect during /execute: /execute writes `{feature_folder}/03_plan_defect_<task-id>.md`; /plan invoked as `/plan --fix-from <task-id>` reads the defect, enters Edit mode scoped to that task and downstream, preserves completed-task refs (D42) |

### 6.7 Operational modes

| ID | Requirement |
|----|-------------|
| FR-60 | When `03_plan.md` exists, /plan offers three modes via AskUserQuestion: **Edit** (in-place fix, no review loops, no Supersedes header), **Replan** (overwrite with `Supersedes: 03_plan_pre-replan_<ISO date>.md` header, full Phase 4 loops, preserve completed-task refs), **Append** (new tasks added to existing list, review loop scoped to additions only) (D26) |
| FR-61 | `--non-interactive` flag suppresses confirmation gates: Phase 1 summary auto-confirms, Phase 4 high-risk findings auto-applied per "apply Recommended option even on high-risk; AskUserQuestion only when no Recommended exists for high-risk." Auto-applied choices persist to sidecar `03_plan_auto.md` (one entry per choice: prompt verbatim + option chosen + rationale). The sidecar is **overwritten** on every /plan run — it always reflects the auto-decisions of the most-recent run, not historical accumulation. The plan body has a single one-line pointer near the top: "See `03_plan_auto.md` for N auto-decisions made during non-interactive run." |
| FR-62 | Phase 0 step 0 = unconditional `Read` of `_shared/pipeline-setup.md` (D35). Drop conditional-on-edge-case rule |
| FR-63 | Slug derivation lives in `_shared/pipeline-setup.md` and is shared by /requirements, /spec, /plan: kebab-case, derived from spec H1 title, max 5 words, ASCII only (D45) |
| FR-64 | Phase 0 reads both `~/.pmos/learnings.md` and `<repo_root>/.pmos/learnings.md`. On conflict, repo-local wins. Both can be overridden by skill body unless tagged `override: true` (D27, D57) |
| FR-65 | Folder picker (when no `--feature` and no `current_feature`) offers via AskUserQuestion: most-recently-modified folder, best slug-match against spec H1, create-new-with-derived-slug, Other (free-form, partial-match fallback) (D49) |

### 6.8 Risks-table coupling

| ID | Requirement |
|----|-------------|
| FR-80 | Risks table columns: Risk \| Likelihood (L/M/H) \| Impact (L/M/H) \| Severity (derived) \| Mitigation \| Mitigation in:. Severity formula: any-H + no-L = **High**; any-H + any-L = **Medium**; both M = **Medium**; M + L (either order) = **Low**; both L = **Low** |
| FR-81 | Severity = High risks must cite a task ID or TN line in `Mitigation in:`; Phase 4 hard-fails uncited High-severity risks. Medium and Low risks may cite or stay advisory |

### 6.9 Plan-content rules

| ID | Requirement |
|----|-------------|
| FR-90 | Phase 4 soft check: no `## Phase N` block exceeds ~30k tokens (rough guideline). Oversize → finding to split (low-risk if a natural slice exists; high-risk if the phase is one logical unit) (D31) |
| FR-91 | Greenfield substitute. When stack detection finds nothing recognizable, Phase 2 substitutes reference-system study (similar libraries, framework conventions, comparable internal tools). Code Study Notes' "Stack signals" subsection records "None observed; reference: <chosen reference>". Phase 2 gate becomes "structural choices justified against ≥1 reference" (D40, E2) |
| FR-92 | TN Cleanup items are emitted only when their trigger condition fires. Triggers: any task creates files outside `src/`/`tests/` → temp-file cleanup; `--worktree` flag was used → worktree-container shutdown; any task adds a feature flag → flag-flip line; any user-facing change → docs update line. No `[only if applicable]` decoration in output (D21) |
| FR-100 | Code Study Notes has 4 mandatory subsections (each may be marked "None observed", but cannot be omitted): **Patterns to follow** (with `file:line` refs), **Existing code to reuse** (with file paths), **Constraints discovered** (gotchas, hidden invariants), **Stack signals** (per FR-10) (D61) |
| FR-101 | Plan readability promise (revised): "executable by a developer with the codebase open but no prior conversation context." The plan inlines decisions and exact paths; the codebase remains source of truth for conventions (D6) |
| FR-102 | Plan inherits glossary from spec via citation (`see 02_spec.md §X for glossary`); plan introduces no new domain terms not already defined in the spec. Phase 4 check: novel domain term → finding (low-risk: re-word; high-risk: add to spec, halt) (D58) |
| FR-103 | Plan tests are illustrative reference shape, not literal. /execute may adapt to host conventions (fixture names, framework version, helper signatures). Phase 4 checks shape preservation (same inputs/outputs/assertions), not literal text match (D52) |
| FR-104 | Bug-fix TDD task shape (when S5 trigger fires): step 1 writes a regression test that *reproduces the bug* against current code, step 2 confirms the test fails on pre-fix HEAD, step 3 implements the fix, step 4 confirms the test passes. Distinct from new-feature TDD which writes a test for desired behavior with no expectation of pre-existing failure (D55) |
| FR-105 | TDD-optional task types (per `**TDD:** no — <reason>`): pure refactors covered by existing tests, config/IaC changes, CSS-only tweaks, prototype spikes, file moves/renames without behavior change. Author must state the reason; Phase 4 reviews the justification rather than the existence of TDD (D2) |

### 6.10 Platform neutrality

| ID | Requirement |
|----|-------------|
| FR-70 | TN's frontend smoke test is rewritten as platform-neutral verbs ("navigate to X, hard-reload, force error path Y, capture evidence"); CC-only Playwright commands appear in a small CC-flavored block delimited as such (D5) |
| FR-71 | Closing offer phrasing is sourced from `_shared/platform-strings.md` (CC: `/pmos-toolkit:execute`, Gemini: "activate execute skill", Copilot: "use execute skill", Codex: equivalent) (D22, D44) |
| FR-72 | Closing offer names three next steps: /execute, `/grill 03_plan.md`, /simulate-spec on the spec (D44) |
| FR-73 | TN polish-coverage and wireframe-diff items run iff plan is UI-touching per S4 (D47) |

---

## 7. API Changes (Cross-Skill Contracts)

This section enumerates the *contract changes* /plan v2 needs from sibling skills and shared resources. Implementation specs for those siblings are out of scope.

### 7.1 /spec v_next must emit

```yaml
---
tier: 1 | 2 | 3
type: feature | enhancement | bugfix
feature: <slug>
date: YYYY-MM-DD
status: Draft | Final
requirements: <relative path to 01_requirements.md>
---
```

Plus stable section anchors at all tiers (FR-31). Tier-1 specs that today have no FR-IDs gain section anchors (e.g., `### 1. Problem Statement {#problem}` or markdown-header-derived).

### 7.2 /execute v_next must consume

Reading the per-task fields FR-34 through FR-38. Behavior:

- `**Depends on:**` → execution ordering; concurrent `[P]` candidates derived
- `**Idempotent:** no — <recovery>` → /execute prompts user before retrying the task
- `**Requires state from:** T2, T5` → /execute ensures T2/T5's post-state is in place before running this task's verifications (re-runs setup steps if needed)
- `**Data:**` → /execute treats it as documentation; no behavior change (informational)
- `commit_cadence` (plan frontmatter) → /execute commits per-task vs per-phase vs squash-at-end

Backwards-compat shim: missing fields produce a single-line warning per task; do not error (S8).

Defect handoff: /execute writes `{feature_folder}/03_plan_defect_<task-id>.md` on planning defect (FR-56).

### 7.3 /backlog v_next must

Add a `type` field to backlog item frontmatter with values `feature | enhancement | bug`. Used by /plan FR-05/S5 to trigger bug-fix TDD pattern automatically.

### 7.4 Shared resources to ship

| Path | Contents |
|------|----------|
| `_shared/stacks/node.md` | T0 prereq commands, lint/test/format commands, HTTP smoke pattern, common Jest/Vitest fixture patterns |
| `_shared/stacks/python.md` | Same shape, pytest/poetry/uv variants |
| `_shared/stacks/rails.md` | Same shape, RSpec/minitest variants |
| `_shared/stacks/go.md` | Same shape, `go test`, `gofmt -l` |
| `_shared/stacks/static.md` | Static-site pattern: build commands, file-existence checks, link-check |
| `_shared/platform-strings.md` | Per-platform phrasing for closing offer + skill-invocation references |
| `_shared/pipeline-setup.md` updates | Slug derivation function (FR-63); folder-picker logic (FR-65) |

---

## 8. Frontend Design

The "frontend" of /plan is the AskUserQuestion interaction shapes. Three are load-bearing:

### 8.1 Update-mode picker (FR-60)

Triggered when `03_plan.md` exists at start.

- **Question:** "An existing plan was found at `{path}`. Update mode?"
- **Options:** Edit (in-place, surgical) / Replan (full regeneration with Supersedes header) / Append (add tasks, review only on additions) / Cancel

### 8.2 Findings batch (FR-41)

Per Findings Presentation Protocol, max 4 high-risk findings per call.

- **Question shape:** one-sentence finding + concrete proposed fix
- **Options:** Fix as proposed / Modify (free-form next turn) / Skip (writes to skip list) / Defer (writes to Open Questions)

### 8.3 Convergence cap-hit (FR-40)

- **Interactive:** "Loop 4 still finds {N} issues. Continue / Accept-and-proceed / Abandon."
- **Non-interactive:** no prompt; auto Accept-and-proceed + write `## Convergence Warning` block.

---

## 9. Edge Cases

| # | Scenario | Condition | Expected Behavior |
|---|----------|-----------|-------------------|
| E1 | Spec frontmatter missing `tier:` | tier-detection key absent | /plan halts with platform-aware "Spec at {path} missing required `tier:` frontmatter — re-run /spec to add it." Does not guess tier. |
| E2 | Stack detection finds nothing recognizable | Greenfield repo, single README.md | Phase 2 substitutes reference-system study (D40); Code Study Notes' "Stack signals" subsection = "None observed; reference: <chosen reference repo>" |
| E3 | Stack detection finds multiple signals | Mono-repo with package.json + go.mod + Dockerfile | Interactive: AskUserQuestion (offer dominant signal first). Non-interactive: pick by file-count weight; log to Auto-decisions made: |
| E4 | Backlog AC has criteria absent from spec | `--backlog BG-7` passed; spec doesn't cover AC #3 | Phase 4 hard-fail unless spec is updated OR criterion added to `## Backlog Out-of-Scope` with rationale (FR-55) |
| E5 | Cross-feature conflict detected | Phase 2 grep finds `src/auth.ts` is touched by feature X's 03_plan.md | Add Risks row "concurrent change to src/auth.ts in feature X plan" + Open Question; do NOT halt |
| E6 | Wireframe pattern with no host-system equivalent | Wireframe shows tabs, host has no tabs | Affected task explicitly notes the gap and proposes resolution (extend / nearest equivalent / escalate) — not silent (D7) |
| E7 | All wireframes referenced; one orphan wireframe file | `wireframes/05_settings_mobile.html` not cited by any task | Phase 4 hard-fail unless added to `## Out of Scope` subsection with rationale (D16) |
| E8 | Replan after partial /execute | T1-T5 done, spec changed, user runs /plan choosing Replan | New plan written with `Supersedes: 03_plan_pre-replan_<date>.md` header preserving completed-task refs; old plan archived; Skip List archived to `## Archived (pre-replan ...)` (D60) |
| E9 | Loop 1 surfaces a finding the user Skipped in a previous /plan run | Skip List from prior session has matching fingerprint | /plan auto-suppresses the finding (dedupe per FR-43); does not re-prompt unless user override |
| E10 | Mid-execute defect on a phased plan | /execute halts on T11 (phase 2 of 4) | Defect file written; user runs `/plan --fix-from T11`; /plan enters Edit mode scoped to T11 + downstream tasks in phase 2; phase 1 tasks untouched (FR-56) |
| E11 | `--non-interactive` run cap-hits with high-risk findings | 4 loops, 3 high-risk findings remain | Auto-accept; plan ships with `## Convergence Warning` section listing the 3 findings verbatim (S7, FR-40) |
| E12 | Plan has no UI tasks but wireframes folder exists | Backend-only spec, vestigial wireframes/ from earlier requirements | Phase 4 #11 polish-coverage check passes trivially (no UI signal — S4 false); wireframe diff in TN omitted; Phase 4 still runs the bidirectional wireframe coverage check and surfaces orphans as E7 |
| E13 | Spec re-opens during planning | Planner notices spec says "use Postgres" but Phase 2 finds repo standard is MySQL | /plan halts via AskUserQuestion: "Spec decision conflicts with repo standard. Update spec, or document override in spec?" Does NOT silently override (D13) |

---

## 10. Testing & Verification Strategy

### 10.1 Unit-level (skill structure)

- **Frontmatter contract:** grep test-fixture spec files at each tier; assert frontmatter contains `tier`, `type`, `feature`, `date`, `requirements`, `status`. Run after any /spec change.
- **Stack-library completeness:** for each `_shared/stacks/<stack>.md`, assert presence of sections "Prereq commands", "Lint/test commands", "API smoke patterns". Run as a CI lint.
- **Platform-strings completeness:** assert `_shared/platform-strings.md` has entries for at least `claude-code`, `gemini`, `copilot`, `codex`, each with `execute_invocation` and `skill_reference` keys.

### 10.2 Integration-level (skill behavior)

Build three test-fixture specs in `docs/features/_test-fixtures/` (or a similar parking lot):

- `tier1_bugfix.md` — tier 1, type bugfix, single FR
- `tier2_enhancement.md` — tier 2, 3 FRs, no wireframes
- `tier3_feature.md` — tier 3, 8 FRs, wireframes/ folder, NFRs

For each, run /plan in a real sub-repo with the matching stack (Node for Tier 3, Python for Tier 1, etc.), then assert on the produced `03_plan.md`:

```bash
# Tier 1 — minimal output
test -f docs/features/_test-fixtures/tier1_bugfix/03_plan.md
grep -c '^### T' .../03_plan.md  # expect 1
! grep -q '^## Decision Log$' .../03_plan.md  # T1 skips floor
! grep -q 'pytest' .../03_plan.md  # stack=python, but T1 reduced TN — test that Done-when walkthrough is present
grep -q '^## Done-when walkthrough' .../03_plan.md

# Tier 3 — full output
test -f .../tier3_feature/03_plan.md
grep -q '^## Phase 1' .../03_plan.md  # phases used
grep -E '^\*\*Depends on:\*\*' .../03_plan.md | wc -l  # > 0
grep -E '^\*\*Idempotent:\*\*' .../03_plan.md | wc -l  # > 0
grep -q 'mermaid' .../03_plan.md  # auto-rendered exec-order diagram
! grep -q 'curl.*json.tool' .../03_plan.md  # stack=node — no baked python smoke
! grep -q 'alembic' .../03_plan.md
test -f .../tier3_feature/03_plan_review.md  # sidecar exists
```

### 10.3 Cross-skill handshake

- **/spec emits anchors:** synthetic spec with `### 6.2 Auth flow {#auth-flow}` → /plan task with `**Spec refs:** auth-flow` resolves; broken refs surface in Phase 4.
- **/backlog type=bug → bug-fix TDD:** synthetic backlog item type=bug → /plan emits `**TDD:** yes — bug-fix` and the task contains "regression test reproducing bug" prose.
- **/execute defect handoff:** mock /execute writing `03_plan_defect_T7.md` → run `/plan --fix-from T7` → assert T7's task is rewritten in-place, T1-T6 untouched, no Supersedes header.
- **Backwards-compat shim:** /execute v_next given a task missing `**Idempotent:**` → emits warning, continues.

### 10.4 Manual / live runs

- Live /plan run on a real Tier-3 feature (e.g., a /plan v2 sub-feature itself: maybe the `_shared/stacks/` ship). Confirm produced plan reads cleanly without manual cleanup.
- /grill the produced plan; fewer than 5 substantive grill findings means the redesign held up.

### 10.5 Verification commands (post-implementation)

```bash
# Skill body well-formed
test -f plugins/pmos-toolkit/skills/plan/SKILL.md
test -d plugins/pmos-toolkit/skills/_shared/stacks
ls plugins/pmos-toolkit/skills/_shared/stacks/{node,python,rails,go,static}.md
test -f plugins/pmos-toolkit/skills/_shared/platform-strings.md

# Lint
markdownlint plugins/pmos-toolkit/skills/plan/SKILL.md

# Anti-patterns prune (D23) — old anti-patterns should be gone
! grep -q 'Do NOT do only 1 review loop' plugins/pmos-toolkit/skills/plan/SKILL.md  # rule moved to FR-03/04 floors
! grep -q 'curl.*json.tool' plugins/pmos-toolkit/skills/plan/SKILL.md  # baked-in command removed
```

---

## 11. Open Questions

| # | Question | Owner | Needed By |
|---|----------|-------|-----------|
| 1 | /spec v_next anchor scheme: derive from H2 heading slugs (auto), or require explicit `{#anchor}` markers (manual)? Affects FR-31 plumbing. | spec-author | before /spec v_next implementation |
| 2 | /execute v_next: how to resolve `**Requires state from:**` chains spanning phases? Run upstream-phase setup commands, or refuse cross-phase state requirements? | execute-author | before /execute v_next implementation |
| 3 | `_shared/stacks/<stack>.md`: who owns updates when stack conventions evolve (e.g., Bun vs Node, uv vs pip)? Project policy for stack-library maintenance. | toolkit-maintainer | before public release |
| 4 | Test-fixture spec parking lot: `docs/features/_test-fixtures/` is a real-feature folder convention; a separate `tests/fixtures/specs/` may be cleaner. Decide before writing test-fixtures. | toolkit-maintainer | before /plan v2 release |
| 5 | Backwards-compat shim sunset: warnings forever, or sunset after N minor versions? | toolkit-maintainer | before /plan v2 release |

---

## 12. Review Log

| Loop | Findings | Changes Made |
|------|----------|-------------|
| 1 | **Structural (8 missing FRs from grill decisions):** Done-when measurability + walkthrough at all tiers (D29/D62); Risks coupling + axes (D17/D38); length budget (D31), greenfield substitute (D40), cleanup applicability (D21); Code Study Notes subsections (D61), zero-context softening (D6), glossary inheritance (D58), test illustrative (D52), bug-fix TDD shape (D55), TDD-optional refactors (D2). **Design (4 holes):** auto-classification rule undefined (FR-41); frontmatter contract scattered (FR-20); "in flight" undefined (FR-54); Open Q #6 unresolved. **Cosmetic (1):** Mermaid render mechanism unstated (FR-25). | All 13 findings approved (8 structural batch + 4 design batch + 1 auto-applied cosmetic). Added FR-22a/22b, FR-41a, FR-54a, FR-80/81, FR-90/91/92, FR-100–105. Rewrote FR-20 as authoritative frontmatter contract. Clarified FR-25 Mermaid emit. Updated FR-61 (auto-decisions sidecar). Removed Open Q #6. Note: section numbering inserted 6.8/6.9, original Platform Neutrality renumbered to 6.10 — existing FR-IDs preserved (no re-numbering). |
| 2 | **High-risk (1):** broken-ref detection rule for Spec refs / Wireframe refs after spec edits — undefined. **Low-risk auto-applied (3):** FR-35 missing validation that non-idempotent tasks have a recovery substep; FR-20 missing validation that `commit_cadence` matches plan structure; FR-80 Severity formula imprecise (Medium/Low boundary). | All 4 findings approved. Added FR-31a (Phase 4 + /verify both check broken refs). Tightened FR-35 (Phase 4 hard-fails missing recovery substep). Added validation clause to FR-20 (commit_cadence ↔ phases consistency). Pinned FR-80 Severity formula explicitly. |
