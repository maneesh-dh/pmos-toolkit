---
name: plan
description: Create an execution plan from a spec — deep code study, TDD tasks with inline verification, decision logging, risk assessment, and a concrete final verification checklist. Third stage in the requirements -> spec -> plan pipeline. Always full format. Use when the user says "break this into tasks", "create the implementation steps", "how do we implement this", or has a spec ready for task breakdown.
user-invocable: true
argument-hint: "<path-to-spec-doc> [--backlog <id>] [--feature <slug>]"
---

# Implementation Plan Generator

Create a comprehensive, engineer-ready implementation plan from a spec. The plan must be good enough that a skilled developer with **zero codebase context** can execute it end-to-end without asking questions. This is the THIRD stage in a 3-stage pipeline:

```
/requirements  →  [/msf-req, /creativity]  →  /spec  →  [/simulate-spec]  →  /plan  →  /execute  →  /verify
                   optional enhancers                  optional validator     (this skill)
```

The plan translates a spec into **bite-sized, TDD-driven tasks** with exact file paths, exact commands, and inline verification at every step. It inherits architecture decisions from the spec and adds implementation-specific decisions.

**Announce at start:** "Using the plan skill to create an implementation plan."

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No `AskUserQuestion`:** State your assumption, document it in the output, and proceed. The user reviews after completion.
- **No subagents:** Perform research and analysis sequentially as a single agent.
- **No Playwright MCP:** Note browser-based verification as a manual step for the user.

---

## Backlog Bridge

This skill optionally integrates with `/backlog`. See `plugins/pmos-toolkit/skills/backlog/pipeline-bridge.md`.

**At skill start:**
- If `--backlog <id>` was passed: load the item file as supplementary context.

**At skill end (after writing the plan doc):**
- If `<id>` was set, invoke `/backlog set {id} plan_doc={doc_path}`, then `/backlog set {id} status=planned`. On failure, warn and continue.
- Run the auto-capture flow per `pipeline-bridge.md`: detect deferred-work bullets in the plan output, propose them as new backlog items via `AskUserQuestion`. On user confirmation, invoke `/backlog add` for each with `source:` pre-filled.

---

## Phase 0: Pipeline Setup (inline — do not skip)

Use workstream context (loaded by step 3 below) to inform task design — tech stack, constraints, and deployment patterns shape implementation planning.

<!-- pipeline-setup-block:start -->
1. **Read `.pmos/settings.yaml`.**
   - If missing → you MUST invoke the `Read` tool on `_shared/pipeline-setup.md` Section A and run first-run setup before proceeding. (Skipping this Read is the most common cause of folder-naming defects.)
2. Set `{docs_path}` from `settings.docs_path`.
3. If `settings.workstream` is non-null → load `~/.pmos/workstreams/{workstream}.md` as context preamble; if frontmatter `type` is `charter` or `feature` and a `product` field exists, also load `~/.pmos/workstreams/{product}.md` read-only.
4. Resolve `{feature_folder}`:
   - If `--feature <slug>` was passed → glob `{docs_path}/features/*_<slug>/`. **Exactly 1 match required**; on 0 or 2+ → you MUST `Read` `_shared/pipeline-setup.md` Section B before acting.
   - Else if `settings.current_feature` is set AND `{docs_path}/features/{current_feature}/` exists → use it.
   - Else → ask user (offer: create new with derived slug, pick existing from folder list, or specify via Other...).
5. **Edge cases — you MUST `Read` `_shared/pipeline-setup.md` Section B before acting:** slug collision, slug validation failure, legacy date-less folder encountered, ambiguous `--feature` lookup, any folder creation.
6. Read `~/.pmos/learnings.md` if present; note entries under `## /<this-skill-name>` and factor them into approach (skill body wins on conflict; surface conflicts to user before applying).
<!-- pipeline-setup-block:end -->

### Phase 0 — additional /plan steps (after the canonical block above)

7. **Acquire `.plan.lock`** (FR-66). Write `{feature_folder}/.plan.lock` with `pid + ISO timestamp + skill_version`. If the file already exists, refuse with a platform-aware error sourced via `_shared/platform-strings.md` citing the existing pid (e.g., `[/plan] Another plan run is in progress (pid=<n>, started <time>). Re-run with --force-lock if you are sure no other plan run is active.`). Release the lock on completion or on any fatal error. The `--force-lock` flag clears a stale lock without prompting.

8. **Back up existing plan** (FR-67). If `{feature_folder}/03_plan.md` exists, copy it to `{feature_folder}/03_plan_pre-cap-abandon_<ISO>.md`. The backup is removed on successful exit; restored to `03_plan.md` on the Cap-Hit Abandon disposition (FR-40).

9. **Validate spec frontmatter** (FR-50, FR-50a, E1):
   - **Spec missing** (FR-50) → refuse with platform-aware error: `No spec found at {feature_folder}/02_spec.md. Run /spec first.`
   - **Frontmatter parse** (FR-50a, *deviation per Decision Log P9*): parse via regex — extract YAML between leading `---` markers, line-by-line `^([a-z_]+):\s*(.*)$`. On a malformed line refuse with: `Spec frontmatter parse error at line N: <observed-token>. Fix YAML syntax and re-run.` (Wording differs from spec FR-50a's `<yaml-lib message>` because skills have no YAML library; refuse-on-malformed behavior is preserved.)
   - **Missing `tier`** (E1) → refuse with: `Spec at {feature_folder}/02_spec.md missing required tier: frontmatter — re-run /spec to add it.`

---

## Phase 1: Intake

1. **Locate the spec.** Follow `../.shared/resolve-input.md` with `phase=spec`, `label="spec"`.
2. **Read the spec end-to-end.** Summarize it back in 3-5 bullets and confirm understanding with the user via AskUserQuestion.
3. **Read tier and type from spec frontmatter** (FR-01). Re-use the parse from Phase 0 step 9; set `{tier}` and `{type}` for downstream phases. Tier-N gating in Phase 3 / Phase 4 keys off `{tier}`; per-task TDD precedence (FR-104a) keys off `{type}`.
4. **Surface simulate-spec findings** (FR-51). Glob `{feature_folder}/02_simulate-spec_*.md`. If a file exists with unresolved findings, run a §8.6 batched `AskUserQuestion` per finding before proceeding — options: **Update spec to address before planning** / **Treat as Open Question in plan** / **Accept as risk** / **Skip — already resolved upstream**.
5. **Check for an existing plan.** Look for `{feature_folder}/03_plan.md`.
   - If found: read it, ask if this is an update or fresh start.
   - If not found: proceed.
6. **`--fix-from <task-id>` branch** (FR-56, FR-67a, FR-67b, E10). When `--fix-from <task-id>` is passed:
   - Read `{feature_folder}/03_plan_defect_<task-id>.md` per spec §7.5. If the defect file does not exist, refuse with platform-aware error: `No defect file found at {path}. /execute writes this file on planning defect; nothing to fix from.`
   - `--widen-to <upstream-task-id>` (FR-67a) widens the rewrite scope to start at the upstream task.
   - `--cross-phase-downstream` (FR-67b) extends the rewrite into downstream phases when the defect changes a contract that downstream tasks depend on.
   - Enter Edit mode (FR-60) scoped per the flags; do not regenerate untouched tasks.

**Scope check:** If the spec covers multiple independent subsystems, suggest breaking this into separate plans — one per subsystem. Each plan should produce working, testable software on its own.

**Gate:** Do not proceed until you have confirmed your understanding of the spec with the user.

---

## Phase 2: Deep Code Study

Study the existing code that will be impacted. This is NOT a skim — you must read the actual files.

1. **Identify impacted surfaces.** From the spec, list every file, module, database table, API endpoint, and UI page that will be created or modified.
2. **Read each impacted file.** For existing files, note:
   - Current structure and patterns used
   - How similar features were implemented (look for precedent)
   - Test files that cover the impacted code
   - Integration points with other modules
3. **Read adjacent code.** Check imports, callers, and consumers of the code you'll modify.
4. **Check project conventions.** Read `CLAUDE.md`, `.claude/rules/`, and recent commits for patterns to follow.
5. **Trace data flow pipelines.** If the feature involves a write→read pipeline (search indexing, sync, export, import, queue, cache, aggregation), verify the full chain exists: write entry point → storage target → read entry point. Grep for each link. If any link is missing, add a task to implement it. (Skip for purely CRUD or purely UI features.)
6. **Read wireframes (if present).** Check `{feature_folder}/wireframes/` for HTML wireframes. If present, open each affected screen and note what the wireframe specifies. Treat wireframes as **reference, not specification**:

   - **Authoritative for:** IA, screen inventory, component presence, copy and labels, state coverage (loading/empty/error/success), navigation entry/exit, journey shape. Tasks must implement these.
   - **NOT authoritative for:** visual style, color, typography, spacing, iconography, component library. Tasks should adapt the wireframe to the host app's existing design system and conventions — never copy visual treatment verbatim when it conflicts with the host app.

   Every UI task in Phase 3 must cite the wireframe(s) it implements via a `**Wireframe refs:**` field — same discipline as `**Spec refs:**`. This preserves the wireframe→implementation→verification chain for /verify Phase 4 sub-step 3f. If the host app has established patterns (Tailwind tokens, component library, layout conventions) that differ from the wireframe's visual treatment, the task should explicitly say "follow host-app convention X" rather than "match wireframe."
7. **Detect stack signals** (FR-10). Glob host-repo root for manifest files: `package.json`, `Gemfile`, `go.mod`, `requirements.txt`, `pyproject.toml`, `Cargo.toml`, `pom.xml`, `composer.json`, `docker-compose.yml`, `Makefile`, `Dockerfile`. Compute file-count weight per stack. Log signals to a "Stack signals" subsection of Code Study Notes (FR-100).

   **JS-stack lockfile disambiguation** (FR-10a): map lockfile presence → stack: `package-lock.json` → npm; `pnpm-lock.yaml` → pnpm; `yarn.lock` + no `.yarnrc.yml` → yarn-classic; `yarn.lock` + `.yarnrc.yml` → yarn-berry; `bun.lockb` → bun. When `package.json` is present with no lockfile, default to npm and surface as a low-risk Phase 4 finding.

   **Tiebreak** (FR-14a): equal weights → alphabetical. In `--non-interactive` mode the tiebreak is logged to `03_plan_auto.md`.

   **Stack-ambiguity prompt** (§8.4) — interactive mode only: if signals are mixed (e.g., monorepo with both npm and python), surface via `AskUserQuestion`: `Detected mixed stack signals. Pick the primary for plan generation:` with options `<stack-1>` / `<stack-2>` / `Mono-repo: pick all` / `Other` (FR-14).

   **Greenfield substitute** (FR-91, E2). When no signals are observed, do NOT skip the gate — choose a reference system (the closest existing system the planner can cite) and record the choice in Code Study Notes. **Phase 2 gate:** structural choices must be justified against ≥1 reference system; absence of stack signals is not a license to invent.

8. **Peer-plan conflict scan** (FR-54, FR-54a). Glob `{docs_path}/features/*/03_plan.md` (excluding the current feature folder). Filter by frontmatter `status` ∈ {`Draft`, `Planned`, `Executing`}. Grep each peer plan for impacted file paths from step 1. On match, add a Risks-table row + an Open Question.

9. **Wireframe coverage** (FR-16, FR-16a). If `{feature_folder}/wireframes/` exists, every `*.html` file under it must be referenced by ≥1 task's `**Wireframe refs:**` field OR listed in a `## Wireframes Out of Scope` subsection of the plan. **Vestigial wireframes** (FR-16a): when no UI signal is detected (no UI tasks in the spec) but the wireframes folder exists, auto-emit `## Wireframes Out of Scope` with all wireframes listed.

10. **Spec re-open during planning** (§8.7, E13). When Phase 2 code study contradicts a spec decision (e.g., spec says "use Postgres" but `docker-compose.yml` shows MySQL), halt via `AskUserQuestion`: `Spec decision conflicts with repo standard. {Spec text} vs {observed standard}. How to resolve?` Options: **Halt /plan and update spec** (terminates this run; user re-runs /spec then /plan) / **Document override in spec via Decision Log entry** (open spec, add Decision Log entry citing the divergence with rationale, save, continue planning) / **Accept spec as-is despite divergence** (record decision in plan's Decision Log; proceed with spec's choice) / **Skip — not actually a conflict** (spec was correct; observation was misread). In `--non-interactive` mode this is a high-risk decision with no Recommended option → trigger FR-61a halt protocol (exit code 2 + write `03_plan_blocked.md`).

11. **Summarize findings** in a "Code Study Notes" section for the plan.

**Gate:** You must have read every impacted file before writing a single line of the plan.

---

## Phase 3: Write the Plan

Save to `{feature_folder}/03_plan.md`. Overwrite if it already exists.

### Tier Gates (Phase 3 emission rules per `{tier}` from Phase 1)

Each tier gates which sections / how much rigor the plan must include (FR-02, FR-03, FR-04):

- **Tier 1 (bugfix):** ≥1 task floor; **no Decision-Log floor** (skip the table when there is exactly one obvious fix); **no Phase 5** for plans this small (Phase 4 review is sufficient); reduced TN = `T0 + lint + test + Done-when walkthrough`.
- **Tier 2 (enhancement):** ≥1 Decision-Log entry; 1 review loop; Risks and Rollback are optional unless triggered by content; full TN.
- **Tier 3 (feature):** ≥3 Decision-Log entries; 2–4 review loops (cap-of-4 per FR-40); mandatory Risks table; Rollback is conditional on data/deploy involvement; full TN.

**Done-when rules (all tiers):** the `**Done when:**` line states lower bounds and qualitative gates only (FR-22). Plans MUST include ≥1 quantitative or executable assertion in Done-when (FR-22a) — e.g., "all 17 tests pass", "lint exits 0", "p95 < 500ms". The plan MUST include a "Done-when walkthrough" — a concrete narrative tracing the Done-when line through the system (FR-22b). Replaces the legacy "Manual spot check" line.

### Code Study Notes structure (FR-100)

The `## Code Study Notes` section MUST contain four subsections — each may be marked "None observed" but cannot be omitted:

- `### Patterns to follow` — with `file:line` refs
- `### Existing code to reuse` — file paths + one-line responsibility
- `### Constraints discovered` — gotchas, hidden invariants
- `### Stack signals` — the per-stack signals from Phase 2 step 7

### Readability promise (FR-101)

The plan must be executable by a developer with the codebase open but no prior conversation context. The plan inlines decisions and exact paths; the codebase remains source of truth for conventions.

### Glossary inheritance (FR-102)

The plan inherits its glossary from the spec via citation (`see 02_spec.md §X for glossary`); the plan introduces no new domain terms not already in the spec. Phase 4 review check: a novel domain term is a finding — low-risk if a re-word fits existing vocabulary; high-risk if the concept is genuinely new (route through spec, halt).

### Tests are illustrative (FR-103)

Plan-emitted tests are illustrative reference shape, not literal. /execute may adapt to host conventions (fixture names, framework version, helper signatures). Phase 4 checks shape preservation (same inputs/outputs/assertions), not literal text match.

### Plan Document Structure

```markdown
---
tier: 1|2|3
type: bugfix|enhancement|feature
feature: <slug>
spec_ref: 02_spec.md
requirements_ref: ../requirements/01_requirements.md
date: YYYY-MM-DD
status: Draft
commit_cadence: per-task
contract_version: 1
---

# <Feature Name> — Implementation Plan

---

## Overview

[2-4 sentences: what this builds, the approach, and the execution order]

**Done when:** [One sentence defining completion for the entire plan. State lower-bounds + qualitative gates ONLY (FR-22). MUST include ≥1 quantitative or executable assertion (FR-22a). e.g., "SOP Editor renders remediated images on all 110 routes, 0 same-step duplicates in DB, all 17 tests pass, Docker stack healthy, p95 render < 800ms."]

**Done-when walkthrough:** [REQUIRED at all tiers (FR-22b). Concrete narrative tracing each clause of the Done-when line through the system — what command, what response shape, what users see. Replaces the legacy Manual spot check line.]

**Execution order:**
[ASCII diagram or numbered list showing task dependencies.
 Mark parallelizable tasks with [P].]

[For plans with ≥ ~12 tasks, also include a Mermaid block (FR-25) auto-rendered from per-task `**Depends on:**` lines. GitHub renders ```mermaid blocks natively.]

---

## Decision Log

> Inherits architecture decisions from spec. Entries below are implementation-specific decisions made during planning.

[Tier 1: skip the table entirely if no implementation-specific decisions. Tier 3: ≥3 entries required.]

| # | Decision | Options Considered | Rationale |
|---|----------|-------------------|-----------|
| D1 | [What was decided] | (a) ..., (b) ..., (c) ... | [Why — include trade-offs] |

---

## Code Study Notes

> Glossary inherited from spec — see 02_spec.md for domain terminology. The plan introduces no new domain terms.

### Patterns to follow

- `path/to/file.py:42-58` — [pattern], reused at TN

### Existing code to reuse

- `path/to/existing.py` — [responsibility]; tasks `T2`, `T5` import from here

### Constraints discovered

- [Hidden invariant or gotcha discovered in Phase 2]

### Stack signals

- [Per-stack signals from Phase 2 step 7. Cite the relevant `_shared/stacks/<stack>.md` file.]

[Each subsection MAY be "None observed" but cannot be omitted.]

---

## Prerequisites

[What must be true before starting: running services, seed data, env vars, existing branches, etc.]

---

## File Map

> Generated index pointing back to per-task **Files:** sections — tasks are source of truth (FR-23).

| Action | File | Responsibility | Task |
|--------|------|---------------|------|
| Create | `exact/path/file.py` | [What this file does] | T2 |
| Modify | `exact/path/existing.py:123-145` | [What changes and why] | T3 |
| Test   | `tests/path/test_file.py` | [What it tests] | T2 |
| Move   | `from/old/path.py` → `to/new/path.py` | [Why moved] | T4 |
| Rename | `old_name.py` → `new_name.py` | [Why renamed] | T4 |
| Delete | `obsolete/path.py` | [Why removed] | T5 |

File-action verbs (FR-24): `Create`, `Modify`, `Delete`, `Move`, `Rename`, `Test`. Move/Rename rows MUST show source AND destination.

---

## Risks

> 5-column Risks table. Severity is **derived** from Likelihood + Impact (FR-80):
> any-H + no-L → High; any-H + any-L → Medium; both M → Medium; M + L → Low; both L → Low.
> Phase 4 hard-fails any High-severity risk that lacks a per-task Mitigation citation (FR-81).

| # | Risk | Likelihood | Impact | Severity | Mitigation | Mitigation in: |
|---|------|-----------|--------|----------|------------|----------------|
| R1 | [What could go wrong] | Low/Medium/High | Low/Medium/High | Low/Medium/High | [How to handle it] | T<n> |

---

## Rollback

- If TN fails after migration XXX: `alembic downgrade <previous>`
- If seed data corrupted: `python scripts/seed_sop_db.py --reset`
- If deploy fails: `docker compose up -d <previous-image>`

[Conditional: include only when the plan involves database migrations, deployments, or data mutations. Delete the section otherwise — do NOT leave a placeholder line decorated with a conditional caveat in the rendered plan.]

---

## Tasks

[For plans > ~12 tasks: group under `## Phase N: <name>` headings (FR-26, FR-27). Phases must be deployable slices of 5–10 tasks. Phase boundaries trigger full /verify + /compact handshake (FR-26a, see execute/SKILL.md Phase 2.5). Soft cap of 30k tokens per phase (FR-90). Last phase's verify IS the TN per FR-26.]

### T1: [Task Name]

**Goal:** [One sentence]
**Spec refs:** [Which spec sections/FR-IDs this implements; for spec headings cite `02_spec.md#kebab-anchor` per FR-31]
**Wireframe refs:** [If wireframes exist and this task touches UI: which screens (e.g., `wireframes/01_dashboard.html`). Omit field for non-UI tasks.]

**Depends on:** [Task IDs (e.g., `T2, T3`) or `none`]
**Idempotent:** [`yes` | `no — recovery: <substep>`. If `no`, FR-35 mandates a recovery substep; Phase 4 hard-fails non-idempotent without it.]
**Requires state from:** [Tasks whose runtime artifacts (e.g., generated files, DB rows) this task consumes. Omit when independent.]
**TDD:** [`yes — new-feature` | `yes — bug-fix` | `no — <reason>`. Three-valued enum per FR-37 (replaces the legacy 2-state rule). FR-104a precedence: per-task override → spec frontmatter `type:` → /backlog item `type=`. On override, emit a Decision-Log entry. FR-105 TDD-optional types: pure refactors, config/IaC, CSS-only, prototype spikes, file moves — author states the reason; Phase 4 reviews justification.]
**Data:** [Test data the task consumes (fixtures, seed rows, mock payloads). Omit when none.]

**Files:**
- Create: `path/to/file.py`
- Modify: `path/to/existing.py`
- Test: `tests/path/test.py`

**Steps:**

- [ ] Step 1: Write the failing test
  ```python
  def test_specific_behavior():
      result = function(input)
      assert result == expected
  ```
  [Tests are illustrative reference shape per FR-103, not literal. /execute may adapt fixture names / helper signatures to host conventions while preserving the same inputs/outputs/assertions.]

- [ ] Step 2: Run test to verify it fails
  Run: `pytest tests/path/test.py::test_name -v`
  Expected: FAIL with "function not defined"

- [ ] Step 3: Write minimal implementation
  ```python
  def function(input):
      return expected
  ```

- [ ] Step 4: Run test to verify it passes
  Run: `pytest tests/path/test.py::test_name -v`
  Expected: PASS

- [ ] Step 5: Commit
  ```bash
  git add tests/path/test.py src/path/file.py
  git commit -m "feat(T1): add specific feature"
  ```

**Bug-fix TDD shape (when `**TDD:** yes — bug-fix`):** Step 1 writes a regression test reproducing the bug; Step 2 confirms the test fails on pre-fix HEAD; Step 3 implements the fix; Step 4 confirms the test passes (FR-104).

**T0 (Prerequisite Check) — auto-generated, mandatory at all tiers (FR-12, FR-12a):**

- [ ] Run prereqs from the detected stack file (`_shared/stacks/<stack>.md` `## Prereq Commands`).
- [ ] Confirm dev-server / DB / queue is running (cite the actual commands from the stack file).

**Inline verification:**
- `ruff check src/path/file.py` — no lint errors
- `pytest tests/path/test.py -v` — N passed, 0 failed

---

### TN: Final Verification

**Goal:** Verify the entire implementation works end-to-end.

- [ ] **Lint & format:** [from detected stack file `## Lint/Test Commands`]
- [ ] **Type check:** [project-appropriate type checker command from stack file]
- [ ] **Unit tests:** [exact command per stack file] — expect N passes, 0 failures
- [ ] **Full test suite:** [exact command per stack file] — expect no regressions
- [ ] **Database migrations:** `alembic upgrade head` [emit only if migrations were added]
- [ ] **Docker deploy:** `docker compose build <services> && docker compose up -d <services>` [emit only if Docker is in scope]
- [ ] **API smoke test:** [from detected stack file `## API Smoke Patterns` — never bake `curl | python -m json.tool` in by default; FR-13]
- [ ] **Frontend smoke test (Playwright MCP):**
  1. Authenticate first (if auth enabled)
  2. Navigate to the relevant page
  3. Verify new UI elements render correctly
  4. Walk through the primary user flow
  5. Take a screenshot for verification
  6. **Hard-reload every parameterized route** the change touches (open the URL in a fresh tab, not via in-app navigation) and confirm the requested resource renders — not the index/first item. Catches router-resolver bugs that in-app nav hides.
  7. **Force at least one error path** (bad input, broken backend) and confirm the UI surfaces the failure with a recoverable CTA — not silent.
- [ ] **UX polish checklist** (any UI-touching change): `document.title` set per route, no internal IDs/enum keys leaked into copy, casing/date-format consistency, meaningful image `alt`, no dead disabled affordances, zero uncaught console errors during the journey, navigation labels match destination titles. Full checklist enforced in `/verify` Phase 4 sub-step 3f.
- [ ] **Wireframe diff** (if `{feature_folder}/wireframes/` exists): for each affected screen, open the wireframe and the live implementation side-by-side. Diff **only on the authoritative dimensions** (IA, copy, states, journeys) — NOT visual style, color, typography, spacing, or component library, which are expected to follow the host app. Classify every delta as `intentional — style adaptation`, `intentional — decision` (with rationale), or `regression` (fix before completion). Empty diff with no dimensions named is not acceptable.
- [ ] **Done-when walkthrough:** [trace each clause of the plan's Done-when line through the running system — replaces the legacy Manual spot check line per FR-22b]
- [ ] **Seed data:** `python scripts/seed_sop_db.py --reset` [emit only if data files changed]

**Cleanup (FR-92 — trigger-based emission; do NOT decorate with conditional caveats in the rendered plan):**

[Cleanup items are emitted only when their trigger fires — when the trigger does NOT fire, the line is OMITTED entirely from the rendered plan. Triggers:
- Any task creates files outside `src/`/`tests/` → emit "Remove temporary files and debug logging".
- /execute used `--worktree` → emit "Stop worktree containers if running: `docker compose -f docker-compose.worktree.yml -p <project> down`".
- Any task adds a feature flag → emit "Flip feature flags".
- Any user-facing change (UI signal OR docs files modified) → emit "Update documentation files (CLAUDE.md, changelogs, etc.)".]

[Every retained item must have an exact command and expected outcome.]

---

## Review Log

> Sidecar: detailed loop-by-loop findings live in `03_plan_review.md` (FR-45). This table is the summary index.

| Loop | Findings | Changes Made |
|------|----------|-------------|
| 1    | [Summary] | [Summary] |
| 2    | [Summary] | [Summary] |
```

### Task Design Rules

#### Optional: `## Phase N` Groupings (for large plans)

For plans with **more than ~12 tasks**, group tasks under `## Phase N: <name>` headings. Each phase boundary triggers full `/verify` + a `/compact` handshake when /execute reaches the end of the phase (see `execute/SKILL.md` Phase 2.5).

**Template:**

```markdown
## Tasks

## Phase 1: Schema and Migration
[Phase rationale: 1-2 sentences on why these tasks group as a deployable slice.]

### T1: ...
### T2: ...
### T3: ...

## Phase 2: API Layer
[Phase rationale.]

### T4: ...
### T5: ...
```

**Rules:**
- Phases are **optional**. Plans ≤ 8 tasks should skip them.
- Each phase boundary triggers **full /verify** (multi-agent code review + interactive QA) — slow. Make phases **deployable slices** of 5–10 tasks. Avoid 1–2 task phases (verify cost dwarfs the work).
- Phases are contiguous: a task belongs to exactly one phase; phase numbering starts at 1; no gaps.
- Phase 1 always begins at T1.

Plans without `## Phase N` headings continue to work — /execute treats them as a single implicit phase verified once at the end.

**TDD (red/green):** Every task that produces code must follow: write failing test -> verify it fails -> implement -> verify it passes -> commit. Show the actual test code, not "write a test for X."

**Bite-sized steps:** Each step is one action (2-5 minutes). Tasks map to ~1 hour of work. Steps within tasks map to ~1-5 minutes.

**Per-task spec refs:** Every task MUST cite which spec sections or FR-IDs it implements. Format: `**Spec refs:** FR-01, FR-02, Section 10.2`

**No placeholders:** Every step must contain the actual content. These are plan failures — never write them:
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat it — tasks may be read independently)
- Tests that only verify existence or status codes without asserting on actual data and behavior

**Exact file paths** in every task. **Exact commands** with expected output in every verification step.

**Incremental verification:** Every task has an "Inline verification" section. Do not batch all testing to the end.

**Prescribe the interface, leave the implementation:** Specify function names, signatures, test assertions, file paths, and commands. Leave internal algorithm details and refactoring decisions to the implementor.

**Task code block size:** if a single task's pasted code block exceeds ~80 lines, choose one of: (a) split the task into smaller tasks, (b) reference an external scratch file the implementor opens, or (c) prescribe the interface (function signatures, test assertions, expected behavior) and let the implementor write the body. Long pasted code blocks bias plan length and substitute for engineering judgment.

### Verification Must Prove Behavior

Every task's verification must answer: **"If the implementation had a subtle bug, would this catch it?"** If not, the verification is structural (proves existence) not behavioral (proves correctness) — and that's a plan failure.

**The litmus test:** Could the implementation be wrong in a plausible way and still pass this verification? If yes, the verification is insufficient — add behavioral tests until every plausible failure mode is covered. The goal is not "at least one behavioral test" — it is **enough behavioral tests to prove the feature works end-to-end**.

A good task verification has two parts:
1. **Automated tests** — assert on behavior with realistic data, not just status codes or "it compiles." Write as many as needed to cover the task's functionality: happy paths, edge cases, relationship loading, data integrity.
2. **Proof-of-life check** — exercises the feature end-to-end (curl, CLI run, manual browser check) with exact expected output

**Common structural-only verifications to avoid (plan failures):**

| Task type | Structural (proves existence only) | Behavioral (proves correctness) |
|-----------|-------------------------------|--------------------------------|
| API endpoint | `assert status == 200` on empty DB | Seed/use real data, assert response body has correct fields, relationships populated, enums as strings |
| DB migration | `alembic upgrade head` succeeds | Query tables, verify constraints reject bad data, verify seed data values (not just counts) |
| Frontend component | `npm run build` passes | Mount with realistic props and assert rendered output; or explicit manual step: "navigate to /path, verify X renders, click Y, verify Z" |
| Infrastructure | `docker compose config` parses | Start service, verify it connects to dependencies, verify port binding with actual request |
| CLI command | `--help` exits 0 | Run with real inputs, assert on output content |
| Config/schema | Import doesn't error | Instantiate with realistic values, assert fields, verify integration with consuming code |

When writing a task's test step, check: does the test use realistic data and assert on the actual output shape and content? A test that passes against an empty database or with no assertions on the response body is not a behavioral test.

### Decision Log Rules

The Decision Log is mandatory. Minimum 3 entries. Capture every non-trivial implementation choice:
- Task ordering decisions
- TDD vs implement-then-test for specific areas
- Where to put functions/files
- Which existing patterns to follow
- What to defer vs include

Each entry MUST have "Options Considered" and "Rationale."

---

## Phase 4: Review Loops

After writing the initial plan, run iterative review loops. Minimum 2 loops.

### Two Types of Review

Each loop runs BOTH checks:

**A. Structural Checklist** (catches missing/incomplete tasks):
1. Every spec section / FR-ID mapped to a task?
2. Every task has inline verification with exact commands?
3. TDD red/green in every task that produces code?
4. Exact file paths in every task?
5. Exact commands with expected output in every verification step?
6. No placeholder language anywhere?
7. **Type consistency:** Do types, method signatures, and property names used in later tasks match what was defined in earlier tasks? A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a plan bug.
8. Final verification task is concrete and complete?
9. **Verification quality:** Does every task's test assert on behavioral output with realistic data — not just status codes, exit codes, or "it compiles"? Apply the litmus test: could a subtly broken implementation still pass this verification?
10. **Wireframe linkage:** If `{feature_folder}/wireframes/` exists, does every UI-touching task cite a `**Wireframe refs:**` line? Tasks without wireframe refs are gaps unless the task is non-UI.
11. **Final-verification polish coverage:** Does TN include the hard-reload-every-route step, the force-an-error-path step, the UX polish checklist line, and (if wireframes exist) the wireframe diff line?
12. **Refactor-before-modify:** Does any task modify a function whose existing structure isn't preserved by the modification? If yes, the prerequisite refactor must be its own numbered sub-step before the additive change.

**B. Design-Level Self-Critique** (catches wrong/shallow task decomposition):
1. **Reviewer perspective:** If you were sent this plan for review, what comments would you add? Read it as a critical reviewer, not the author — flag tasks with unclear scope, missing verification steps, implicit dependencies, and assumptions about what's "obvious."
2. Are there tasks that are too large (>1 hour of focused work) and should be split? Are there tasks that are trivially small and should be merged?
3. Are there implicit dependencies between tasks that aren't reflected in the ordering? Would an engineer hit a blocker mid-task because a prerequisite wasn't completed?
4. Does the task ordering minimize context-switching? Are related changes grouped together?

### Loop Protocol

1. Run BOTH checklists above
2. Log findings in the Review Log table
3. **Present findings via `AskUserQuestion` — do NOT dump them as prose.** Findings shown as text force the user to hand-write dispositions; batching them as structured questions is faster, clearer, and produces a reviewable audit trail. See "Findings Presentation Protocol" below.
4. Apply the user's dispositions (Fix as proposed / Modify / Skip / Defer) — see protocol below
5. Fix issues inline — do NOT create a new file
6. Commit: `git commit -m "docs: plan review loop N for <feature>"`

### Findings Presentation Protocol

For every loop that produces findings (structural or design-critique):

1. **Group findings by category** (e.g., "Missing verification commands", "Oversized tasks", "Type inconsistencies across tasks"). Small categories can be merged; never present more than 4 findings in a single batch.
2. **One question per finding** via `AskUserQuestion`. Use this shape:
   - `question`: one-sentence restatement of the finding + the proposed fix (concrete — e.g., "Split Task 4 (migration + backfill + flag flip) into three tasks" not "break up task 4")
   - `options` (up to 4):
     - **Fix as proposed** — agent applies the stated change via `Edit`
     - **Modify** — user edits the proposal (free-form reply expected next turn)
     - **Skip** — not an issue; drop it (note briefly in Review Log)
     - **Defer** — log in Open Questions with rationale
3. **Batch up to 4 questions per `AskUserQuestion` call.** If there are more findings, issue multiple calls sequentially, one category per call.
4. **Skip `AskUserQuestion` only for findings that need open-ended input** (e.g., "what's the right rollback trigger?"). For those, ask inline as a normal follow-up after the batch — do not shoehorn into options.
5. **After dispositions arrive,** apply them in order, update the Review Log row to cite dispositions, then ask the user if they see additional gaps before declaring the loop complete.

**Platform fallback (no `AskUserQuestion`):** list findings as a numbered table with columns [Finding | Proposed Fix | Options: Fix/Modify/Skip/Defer]; ask the user to reply with the disposition numbers. Do NOT silently self-fix.

**Anti-pattern:** A wall of prose ending in "Let me know what you'd like to fix." This forces the user to re-state each finding in their reply. Always structure the ask.

**Edge cases of structured asks:** when a user reply slips outside the offered options (free-form text, a non-recommended pick that may break an invariant, or leftover findings that don't share a category), follow `../_shared/structured-ask-edge-cases.md`.

### Exit Criteria (ALL must be true)

- Every spec section / FR-ID maps to a task (zero gaps)
- Decision log has 3+ entries with rationale
- No placeholder language exists anywhere
- Every task has inline verification with exact commands
- Final verification task includes all applicable items
- Last loop found only cosmetic issues
- **User has confirmed they have no further concerns** (do not self-declare exit)

---

## Phase 5: Final Review

Run one final improvement pass:

1. **Spec coverage** — Re-read the spec. Is EVERYTHING mentioned covered? List gaps.
2. **Conciseness** — Can sections be tightened without losing information?
3. **Missing standard sections** — Prerequisites? File map? Decision log? Risks? Rollback? Review log?
4. **Coherence** — Any conflicting tasks, circular dependencies, or steps that assume work not yet done?
5. **Blind spots** — What would an engineer struggle with? What implicit knowledge does the plan assume?

**Share your analysis with the user BEFORE modifying anything.** Use the same `AskUserQuestion` batching as review loops (see Phase 4 Findings Presentation Protocol) — one question per final-review finding with Fix / Modify / Skip / Defer options, up to 4 per call. Do NOT declare the plan complete until the user confirms.

After final fixes, commit:
```
git add {feature_folder}/03_plan.md
git commit -m "docs: add implementation plan for <feature>"
```

Report to user:
- Plan location
- Task count
- Key decisions (top 3 from decision log)
- Open risks flagged

Then offer to execute:

> **"Plan complete and saved. Run `/pmos-toolkit:execute` to implement it, or review the plan first?"**

---

## Phase 6: Workstream Enrichment

**Skip if no workstream was loaded in Phase 0.** Otherwise, follow `_shared/pipeline-setup.md` Section C. For this skill, the signals to look for are:

- Technical dependencies discovered → workstream `## Tech Stack`
- Infrastructure details → workstream technical context sections

This phase is mandatory whenever Phase 0 loaded a workstream — do not skip it just because the core deliverable is complete.

---

## Phase 7: Capture Learnings

**This skill is not complete until the learnings-capture process has run.** Read and follow `learnings/learnings-capture.md` (relative to the skills directory) now. Reflect on whether this session surfaced anything worth capturing — surprising behaviors, repeated corrections, non-obvious decisions. Proposing zero learnings is a valid outcome for a smooth session; the gate is that the reflection happens, not that an entry is written.

---

## Anti-Patterns (DO NOT)

- Do NOT write the plan without reading impacted code first
- Do NOT skip the decision log or write entries without rationale
- Do NOT do only 1 review loop — minimum is 2
- Do NOT create a new plan file in each review loop — update the original
- Do NOT write verification steps without exact commands and expected output
- Do NOT claim the plan is complete without sharing review findings with the user
- Do NOT batch all testing into the final task — each task must have inline verification
- Do NOT write tests that only check error paths (404, empty results) — every task needs enough behavioral tests with realistic data to prove its functionality works, not just that routes exist
- Do NOT specify exact implementation code line-by-line — prescribe interfaces and test shapes, leave internals to judgment
- Do NOT combine unrelated changes into a single task — each task should be independently committable
- Do NOT forget the "Done when" one-liner — it defines what success looks like for the whole plan
- Do NOT skip the Cleanup subsection in final verification — temp files, containers, and debug logging accumulate
- Do NOT omit `**Wireframe refs:**` on UI tasks when wireframes exist — the link is what carries polish/consistency expectations into /verify Phase 4 sub-step 3f
- Do NOT instruct tasks to copy the wireframe's visual style verbatim. Wireframes are reference for IA / copy / states / journeys; visual style follows the host app's design system. Tasks should say "follow host-app pattern X" rather than "match wireframe pixel-for-pixel."
- Do NOT let TN's frontend smoke test stop at "renders correctly" — it must include hard-reload, an error-path probe, the UX polish checklist, and (if wireframes exist) a wireframe diff. Polish belongs in the plan, not as a verify afterthought.
- Do NOT create `## Phase N` groupings of 1–2 tasks — each phase boundary triggers full /verify (multi-agent code review + interactive QA), which dwarfs the implementation cost of a tiny phase. Target 5–10 tasks per phase, or skip phases entirely for small plans.
