# Grill Report — /plan skill design and instructions

**Date:** 2026-05-08
**Artifact:** `plugins/pmos-toolkit/skills/plan/SKILL.md`
**Depth:** deep • **Questions asked:** 62

---

## Resolved

### Tiering & Format
- **D1 (Tier inheritance):** plan inherits tier from spec; task count not capped per tier — driven by spec.
- **D1a (Section gating):** tier-gated floors. T1 skips decision-log min, 1 review loop, no Phase 5, no risks/rollback unless applicable, reduced TN. T2 = 1+ decision-log entry, 1 review loop, Phase 5 optional, full TN. T3 = current rules.
- **D29 (Done-when measurability):** Phase 4 check that Done-when contains quantitative or executable assertions; pairs with TN.
- **D46 (Done-when format):** lower bounds and qualitative gates, not exact counts (`≥ N tests pass`, `no regressions`, `route Y returns 200 with shape Z`).

### TDD & Tasks
- **D2 (TDD scope):** condition on task type. TDD mandatory for new logic / bug fixes / API or contract changes; optional for pure refactors covered by existing tests, config/IaC, CSS-only, prototype spikes. Each task declares `TDD: yes/no + why`.
- **D8 (Sizing):** reframe ~1hr/2-5min/80-line anchors as smells, not rules. "Too big if it can't be reviewed in one sitting or has >1 commit-worthy unit; too small if its verification is ceremonial." Drop 80-line cap; keep "long pasted code = prefer interface over body."
- **D52 (Test code drift):** plan tests are illustrative reference shape; /execute adapts to host conventions. Phase 4 checks shape preservation (same inputs/outputs/assertions), not literal match.
- **D55 (Bug-fix TDD):** explicit second pattern — regression test reproduces the bug against current code, watch fail, fix, watch pass. Auto-applied when `--backlog` item type=bug.

### Phase Structure
- **D3 (Phase 4/5 fold):** drop Phase 5 entirely; fold "Conciseness" and "Blind spots" into Phase 4 design-critique items.
- **D9 (Phase grouping):** drop ">12 task trigger" and "5-10 floor." Phases used when a deployable slice exists mid-plan; size = "enough to be worth a /verify run." Author decides; reviewer/grill catches abuse.
- **D4 (TN vs phase verify):** TN becomes the last phase's verify when phases exist — not a separate task. Phase-less plans keep TN as the single end-of-plan verify.
- **D31 (Length budget):** phase-aware chunking; soft guideline that each phase < ~30k tokens; Phase 4 soft check.

### Verification & TN
- **D5 (Platform-neutral TN):** rewrite frontend smoke as tool-agnostic ("navigate, hard-reload, force error path, capture evidence"); add CC-only Playwright note.
- **D34 (API smoke):** stack-detection driven — generated from detected interface (HTTP/GraphQL/gRPC/CLI/static); no baked-in `curl | json.tool`.
- **D21 (Cleanup):** derive applicability from plan content (file creation patterns, `--worktree` use, feature-flag tasks, user-facing changes). Emit only applicable items; drop `[only if]` decoration.
- **D62 (Manual spot check):** replace with "Done-when walkthrough" — clause-by-clause evidence check (command output / screenshot / log line). Forces concreteness via Done-when measurability rule.
- **D47 (UI gating):** Phase 4 #11 polish-coverage and TN frontend/wireframe-diff items run iff plan touches UI (any task has `**Wireframe refs:**` OR Phase 2 detected frontend file changes).

### Wireframes
- **D7 (Layout-pattern gap):** when wireframe pattern has no host equivalent, task explicitly notes the gap and proposes resolution (extend host system / nearest equivalent / escalate). No silent "match the wireframe."
- **D16 (Bidirectional coverage):** Phase 4 check that every wireframe HTML file is referenced by ≥1 task or explicitly listed in an "Out of Scope" subsection with rationale. Catches dropped screens at planning time.

### Risks
- **D17 (Coupling):** add "Mitigation in:" column citing task ID. Mitigation-must-cite-task rule gates on Severity (not Likelihood). Phase 4 check.
- **D38 (Axes):** add Impact column; derive Severity (High = any cell with at least one H and no L). Mitigation rule keys on Severity = High.

### Tasks Structure & Files
- **D12 (File Map):** tasks win as source of truth; File Map becomes a generated index/summary. Authoring rule: edit task, not map.
- **D13 (Spec re-open):** plan never silently overrides spec. Re-opening a spec decision halts and sends back to /spec via AskUserQuestion.
- **D48 (File verbs):** full set Create / Modify / Delete / Move / Rename / Test. Move/Rename specify source+dest. Phase 4 check: Delete/Rename rows must have a corresponding broken-reference task.
- **D54 (Req refs):** push to /spec — spec carries req-refs at any tier; plan inherits transitively via Spec refs. No new task field.

### Dependencies & Execution
- **D18/D18a ([P] marker):** wired into /execute via explicit per-task `**Depends on:** T2, T5` lines. /plan auto-derives [P] = tasks whose dependencies are satisfied at the same point. Phase 4 enforces acyclic graph and no concurrent file overlap among [P] tasks.
- **D25 (Exec-order diagram):** auto-rendered (Mermaid/DOT) from per-task dependencies. Single source of truth = `**Depends on:**` lines.
- **D32 (Idempotency):** per-task `**Idempotent:** yes/no/why`. Non-idempotent tasks include recovery substep. /execute prompts before retry.
- **D56 (State ordering):** per-task `**Requires state from:**` field complementing Depends-on. /execute runs upstream setup before verification. Phase 4 check: orphan state-mutating tasks flagged.

### Prerequisites
- **D19 (T0 task):** auto-add T0 Prerequisite-Check with exact commands + expected output for each prereq. /execute fails fast on T0 failure. T0 read-only and idempotent.
- **D19a (Stack contextualization):** Phase 2 explicit step: detect stack signals (package.json, Gemfile, go.mod, requirements.txt, docker-compose.yml, Makefile) and record in Code Study Notes. T0 prereqs and TN commands generated from signals. Ship per-stack snippet libraries (node, python, rails, go, static).

### Review Loops
- **D14 (Convergence):** hard cap of 4 loops with user override (continue / accept-and-proceed / abandon).
- **D15 (Finding fatigue):** auto-apply low-risk findings (typo, missing exact command, lint) with end-of-loop digest. High-risk findings (task split/merge, dependency change, new sections) batched into AskUserQuestion. Cuts modal calls 3-4x.
- **D20 (Multi-agent):** Loop 1 self-review. Loop 2 dispatches a fresh subagent (Explore or general-purpose) given only plan + spec for blind review. Platform fallback: skip on no-subagent platforms.
- **D33 (Review Log):** move to sidecar `{feature_folder}/03_plan_review.md`. Plan doc stays focused on /execute consumption. Phase 5 cites sidecar path.
- **D50 (Skip memory):** persistent Skip List in sidecar with finding fingerprints. Subsequent loops dedupe against it. Re-raise requires explicit user override.
- **D60 (Skip on replan):** replan archives Skip List under `## Archived (pre-replan YYYY-MM-DD)` heading. New loops start with empty list; archived entries visible to agent for reference. Edit mode preserves Skip List as-is.

### Operational
- **D6 (Zero-context promise):** soften to "developer with the codebase open but no prior conversation context." Codebase remains source of truth for conventions.
- **D11 (Backlog hook scope):** captures out-of-scope notices (adjacent bugs, refactor opportunities, follow-ups surfaced during code study) — not deferred spec items. Rename trigger from "deferred work" to "out-of-scope notices." Add a Notices section the hook scans.
- **D22 (Closing offer):** platform-aware phrasing via shared `_shared/platform-strings.md` table (CC: `/pmos-toolkit:execute`, Gemini: "activate execute skill", Copilot: "use execute skill").
- **D44 (Closing tools):** closing offer names /execute, `/grill 03_plan.md`, /simulate-spec — structured next-step menu, platform-neutral.
- **D26 (Update modes):** three modes via AskUserQuestion when plan exists — (a) **Edit** (in-place fix, no review loops, no Supersedes), (b) **Replan** (Supersedes header, full Phase 4, preserve completed-task refs), (c) **Append** (new tasks added, review only on additions).
- **D42 (Mid-execute replan):** /execute halts on planning defect, writes `{feature_folder}/03_plan_defect_<task-id>.md` with failure context, prompts user to run `/plan --fix-from <task-id>`. /plan reads defect, runs Edit mode scoped to affected task + downstream, /execute resumes from failed task.
- **D10 (One plan per spec):** keep single `03_plan.md`. Replan overwrites with Supersedes header preserving completed-task refs. Multi-subsystem split happens at /spec time, not /plan time.

### Cross-Skill & Setup
- **D27 (Learnings power):** learnings tagged `override: true` (with rationale) take precedence over skill body. Untagged learnings stay advisory. Forces explicit opt-in to overrides.
- **D35 (Phase 0 reads):** Phase 0 step 0 = unconditional `Read` of `_shared/pipeline-setup.md`. Drop conditional-on-edge-case rule. Eliminates the edge-case-detection failure mode the skill itself flags.
- **D45 (Slug derivation):** centralize in `_shared/pipeline-setup.md`. Rule: kebab-case, derived from spec H1 title, max 5 words, ASCII only. /requirements + /spec + /plan all call the same derivation.
- **D49 (Folder picker):** AskUserQuestion offers (1) most-recently-modified feature folder, (2) best slug-match against spec H1, (3) create new with derived slug, (4) Other (free-form). For Other with partial slug, list top-3 matches in follow-up.
- **D51 (No-spec entry):** /plan halts with platform-aware "No spec found at {path}. Run /spec first." Don't auto-invoke /spec.
- **D57 (Repo learnings):** Phase 0 reads both `~/.pmos/learnings.md` and `<repo_root>/.pmos/learnings.md`. On conflict, repo-local wins. Phase 7 capture asks "is this learning global or repo-specific?" before writing.
- **D24 (Workstream enrichment):** expand signal list — discovered conventions (with file refs), recurring constraints, deployment patterns, test infrastructure quirks, undocumented gotchas. Each maps to a workstream section. Phase 6 mandatory iff at least one signal fires.
- **D30 (Simulate-spec link):** Phase 1 reads `{feature_folder}/02_simulate-spec_*.md` if present; surfaces unresolved findings via AskUserQuestion before planning. Doesn't mandate /simulate-spec ran; consumes it if it did.
- **D43 (Cross-feature conflict):** Phase 2 globs `{docs_path}/features/*/03_plan.md` (excluding current), greps each for impacted file paths. Conflicts → Risks-table row with Mitigation = "coordinate with feature X" + Open Question.
- **D53 (Backlog AC):** if `--backlog` passed, Phase 4 check that every acceptance criterion in the backlog item is covered by a task or TN check, OR explicitly out-of-scope with rationale.

### Plan Authoring & Style
- **D23 (Anti-patterns):** prune to genuinely-novel meta-rules. Remove items already enforced by Phase 3/4 checklists. Keep "do not segue into implementing fixes," "do not write the plan without reading impacted code first," etc.
- **D28 (Commit cadence):** plan-level setting (per-task / per-phase / squash-at-end). /plan asks or detects via repo conventions. Tasks include commit step iff cadence is per-task. /execute reads same setting.
- **D39 (Test fixtures):** per-task `**Data:**` line citing data source ("use fixture X" / "create via factory Y" / "seed via scripts/seed_X.py"). Phase 2 surfaces existing fixtures/factories in Code Study Notes. Phase 4 check: every test cites a data source.
- **D40 (Greenfield):** Phase 2 substitutes reference-system study (similar libraries, framework conventions). Code Study Notes capture chosen reference + adopted patterns. Phase 2 gate: "have you justified your structural choices against ≥1 reference?"
- **D41 (Autonomous mode):** `--non-interactive` flag suppresses confirmation gates. Auto-applies Recommended option even on high-risk decisions. AskUserQuestion only when no Recommended exists for a high-risk decision. Plan ships with explicit "Auto-decisions made:" header. Enables /plan as subagent task, scheduled use, CI dry-runs.
- **D58 (Glossary):** plan inherits glossary from spec via citation; Phase 4 disallows plan-introduced new terms. Single source of truth at /spec.
- **D59 (Plan sizing):** no plan-level or per-task size estimate. Tier already conveys roughness.
- **D61 (Code Study Notes):** mandatory subsections — **Patterns to follow** (with file:line refs), **Existing code to reuse** (with file paths), **Constraints discovered** (gotchas, hidden invariants), **Stack signals**. Each can be marked "None observed" but cannot be omitted. Phase 4 check.

---

## Open / Deferred
- None — every branch resolved with a chosen option.

---

## Gaps surfaced (cross-skill changes implied)
- **/spec must emit stable anchor IDs at all tiers** (D37, D54)
- **/spec must own glossary** (D58)
- **`_shared/pipeline-setup.md` must own slug derivation function** (D45) and be unconditionally Read in Phase 0 (D35)
- **Per-stack snippet libraries** (node, python, rails, go, static) shipped under skill resources (D19a, D34)
- **/backlog item type field** reused for bug-fix TDD detection (D55)
- **/execute must consume:** `**Depends on:**` (D18a), `**Idempotent:**` (D32), `**Requires state from:**` (D56), `**Auto-decisions made:**` (D41), commit-cadence setting (D28), plan-defect handoff (D42)
- **`_shared/platform-strings.md` table** for closing-offer phrasing (D22, D44)

---

## Recommended next step

Material-decision count is large (62). Many decisions interlock (tier gating cascades into ~12 rules; stack-detection cascades into prereqs/TN/API-smoke; explicit dependencies cascade into [P]/exec-diagram/state-ordering).

**Two viable paths:**

1. **Treat this report as a requirements doc.** Run `/spec` against it to produce a /plan v2 design spec, then `/grill` the spec, then `/plan` (yes, on itself) to break the rewrite into a sequenced revision plan, then `/execute` in tranches with /verify after each.

2. **Direct revision plan.** Run `/plan` with this report as input to break into tranches grouped by interlock cluster (e.g., tranche A = tiering + section gating + Done-when; tranche B = stack detection + T0 + TN; tranche C = dependencies + idempotency + state ordering; tranche D = review-loop machinery; tranche E = cross-skill changes).

Path 1 is heavier but defensible given the scope. Path 2 is faster if you want to ship incrementally.
