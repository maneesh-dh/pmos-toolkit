---
name: plan
description: Create an execution plan from a spec — deep code study, TDD tasks with inline verification, decision logging, risk assessment, and a concrete final verification checklist. Third stage in the requirements -> spec -> plan pipeline. Always full format. Use when the user says "break this into tasks", "create the implementation steps", "how do we implement this", or has a spec ready for task breakdown.
user-invocable: true
argument-hint: "<path-to-spec-doc> [--backlog <id>] [--feature <slug>]"
---

# Implementation Plan Generator

Create a comprehensive, engineer-ready implementation plan from a spec. The plan must be good enough that a skilled developer with **zero codebase context** can execute it end-to-end without asking questions. This is the THIRD stage in a 3-stage pipeline:

```
/requirements  →  [/msf, /creativity]  →  /spec  →  [/simulate-spec]  →  /plan  →  /execute  →  /verify
                   optional enhancers              optional validator     (this skill)
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

## Phase 0: Load Workstream Context

Before any other work, follow the context loading instructions in `product-context/context-loading.md` (relative to the skills directory). This determines `{docs_path}` and loads workstream context if available. Use workstream context to inform task design — tech stack, constraints, and deployment patterns shape implementation planning. Also read `~/.pmos/learnings.md` if it exists. Note any entries under `## /plan` and factor them into your approach for this session.

**Resolve feature folder.** Follow `../_shared/feature-folder.md` with `skill_name=plan`, `feature_arg=<--feature value or empty>`, and `feature_hint=<topic from user input or spec arg>`. Use the returned folder path as `{feature_folder}`. The protocol creates the folder if needed.

---

## Phase 1: Intake

1. **Locate the spec.** Follow `../.shared/resolve-input.md` with `phase=spec`, `label="spec"`.
2. **Read the spec end-to-end.** Summarize it back in 3-5 bullets and confirm understanding with the user via AskUserQuestion.
3. **Check for an existing plan.** Look for `{feature_folder}/03_plan.md`.
   - If found: read it, ask if this is an update or fresh start.
   - If not found: proceed.

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
7. **Summarize findings** in a "Code Study Notes" section for the plan.

**Gate:** You must have read every impacted file before writing a single line of the plan.

---

## Phase 3: Write the Plan

Save to `{feature_folder}/03_plan.md`. Overwrite if it already exists.

### Plan Document Structure

```markdown
# <Feature Name> — Implementation Plan

**Date:** YYYY-MM-DD
**Spec:** `<path-to-spec>`
**Requirements:** `<path-to-requirements>` (if exists)

---

## Overview

[2-4 sentences: what this builds, the approach, and the execution order]

**Done when:** [One sentence defining completion for the entire plan. e.g., "SOP Editor renders remediated images on all 110 routes, 0 same-step duplicates in DB, all 17 tests pass, Docker stack healthy."]

**Execution order:**
[ASCII diagram or numbered list showing task dependencies.
 Mark parallelizable tasks with [P].]

---

## Decision Log

> Inherits architecture decisions from spec. Entries below are implementation-specific decisions made during planning.

| # | Decision | Options Considered | Rationale |
|---|----------|-------------------|-----------|
| D1 | [What was decided] | (a) ..., (b) ..., (c) ... | [Why — include trade-offs] |

---

## Code Study Notes

[Brief summary of what was learned in Phase 1 — patterns to follow, existing code to reuse, constraints discovered]

---

## Prerequisites

[What must be true before starting: running services, seed data, env vars, existing branches, etc.]

---

## File Map

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

- Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.
- Files that change together should live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. If a file has grown unwieldy, including a split in the plan is reasonable.

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `exact/path/file.py` | [What this file does] |
| Modify | `exact/path/existing.py:123-145` | [What changes and why] |
| Test   | `tests/path/test_file.py` | [What it tests] |

---

## Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| [What could go wrong] | Low/Medium/High | [How to handle it] |

---

## Rollback (if migrations or deploys are involved)

- If TN fails after migration XXX: `alembic downgrade <previous>`
- If seed data corrupted: `python scripts/seed_sop_db.py --reset`
- If deploy fails: `docker compose up -d <previous-image>`

[Only include if the plan involves database migrations, deployments, or data mutations. Delete section otherwise.]

---

## Tasks

### T1: [Task Name]

**Goal:** [One sentence]
**Spec refs:** [Which spec sections/FR-IDs this implements]
**Wireframe refs:** [If wireframes exist and this task touches UI: which screens (e.g., `wireframes/01_dashboard_desktop-web.html`). Omit the field for non-UI tasks.]

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
  git commit -m "feat: add specific feature"
  ```

**Inline verification:**
- `ruff check src/path/file.py` — no lint errors
- `pytest tests/path/test.py -v` — N passed, 0 failed

---

### TN: Final Verification

**Goal:** Verify the entire implementation works end-to-end.

- [ ] **Lint & format:** `ruff check . && ruff format --check .`
- [ ] **Type check:** [project-appropriate type checker command]
- [ ] **Unit tests:** `pytest <specific-test-files> -v` — expect N passes, 0 failures
- [ ] **Full test suite:** `pytest` — expect no regressions
- [ ] **Database migrations:** `alembic upgrade head` (if migrations added)
- [ ] **Docker deploy:** `docker compose build <services> && docker compose up -d <services>`
- [ ] **API smoke test:** `curl -sf <endpoint> | python3 -m json.tool` — verify response shape
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
- [ ] **Manual spot check:** [Feature-specific verification — be specific]
- [ ] **Seed data:** `python scripts/seed_sop_db.py --reset` (if data files changed)

**Cleanup:**
- [ ] Remove temporary files and debug logging [only if applicable]
- [ ] Stop worktree containers if running: `docker compose -f docker-compose.worktree.yml -p <project> down` [only if applicable]
- [ ] Flip feature flags if applicable
- [ ] Update documentation files (`CLAUDE.md`, changelogs, etc.) [only if applicable]

[Every retained item must have an exact command and expected outcome.]

---

## Review Log

| Loop | Findings | Changes Made |
|------|----------|-------------|
| 1    | [What was found] | [What was fixed] |
| 2    | [What was found] | [What was fixed] |
```

### Task Design Rules

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

**Skip if no workstream was loaded in Phase 0.** Otherwise, follow the enrichment instructions in `product-context/context-loading.md` Step 4. For this skill, the signals to look for are:

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
