---
name: plan
description: Create an execution plan from a spec — deep code study, TDD tasks with inline verification, decision logging, risk assessment, and a concrete final verification checklist. Third stage in the requirements -> spec -> plan pipeline. Always full format. Use when the user says "break this into tasks", "create the implementation steps", "how do we implement this", or has a spec ready for task breakdown.
user-invocable: true
argument-hint: "<path-to-spec-doc>"
---

# Implementation Plan Generator

Create a comprehensive, engineer-ready implementation plan from a spec. The plan must be good enough that a skilled developer with **zero codebase context** can execute it end-to-end without asking questions. This is the THIRD stage in a 3-stage pipeline:

```
/requirements  →  [/msf, /creativity]  →  /spec  →  /plan  →  /execute  →  /verify
                   optional enhancers              (this skill)
```

The plan translates a spec into **bite-sized, TDD-driven tasks** with exact file paths, exact commands, and inline verification at every step. It inherits architecture decisions from the spec and adds implementation-specific decisions.

**Announce at start:** "Using the plan skill to create an implementation plan."

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No `AskUserQuestion`:** State your assumption, document it in the output, and proceed. The user reviews after completion.
- **No subagents:** Perform research and analysis sequentially as a single agent.
- **No `superpowers:` skills:** Follow the inline instructions in this skill directly.
- **No Playwright MCP:** Note browser-based verification as a manual step for the user.

---

## Phase 0: Intake

1. **Locate the spec.** If the user passed an argument, use it. Otherwise check `docs/specs/` for a recent file. If nothing found, ask.
2. **Read the spec end-to-end.** Summarize it back in 3-5 bullets and confirm understanding with the user via AskUserQuestion.
3. **Check for an existing plan.** Look in `docs/plans/` for a file covering this feature.
   - If found: read it, ask if this is an update or fresh start.
   - If not found: proceed.

**Scope check:** If the spec covers multiple independent subsystems, suggest breaking this into separate plans — one per subsystem. Each plan should produce working, testable software on its own.

**Gate:** Do not proceed until you have confirmed your understanding of the spec with the user.

---

## Phase 1: Deep Code Study

Study the existing code that will be impacted. This is NOT a skim — you must read the actual files.

1. **Identify impacted surfaces.** From the spec, list every file, module, database table, API endpoint, and UI page that will be created or modified.
2. **Read each impacted file.** For existing files, note:
   - Current structure and patterns used
   - How similar features were implemented (look for precedent)
   - Test files that cover the impacted code
   - Integration points with other modules
3. **Read adjacent code.** Check imports, callers, and consumers of the code you'll modify.
4. **Check project conventions.** Read `CLAUDE.md`, `.claude/rules/`, and recent commits for patterns to follow.
5. **Summarize findings** in a "Code Study Notes" section for the plan.

**Gate:** You must have read every impacted file before writing a single line of the plan.

---

## Phase 2: Write the Plan

Save to `docs/plans/YYYY-MM-DD-<feature-name>-implementation-plan.md`.

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
- [ ] **Manual spot check:** [Feature-specific verification — be specific]
- [ ] **Seed data:** `python scripts/seed_sop_db.py --reset` (if data files changed)

**Cleanup:**
- [ ] Remove temporary files and debug logging
- [ ] Stop worktree containers if running: `docker compose -f docker-compose.worktree.yml -p <project> down`
- [ ] Flip feature flags if applicable
- [ ] Update documentation files (`CLAUDE.md`, changelogs, etc.)

[Only include items that apply to this feature. But every item must have the exact command and expected outcome.]

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

## Phase 3: Review Loops

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

**B. Design-Level Self-Critique** (catches wrong/shallow task decomposition):
1. **Reviewer perspective:** If you were sent this plan for review, what comments would you add? Read it as a critical reviewer, not the author — flag tasks with unclear scope, missing verification steps, implicit dependencies, and assumptions about what's "obvious."
2. Are there tasks that are too large (>1 hour of focused work) and should be split? Are there tasks that are trivially small and should be merged?
3. Are there implicit dependencies between tasks that aren't reflected in the ordering? Would an engineer hit a blocker mid-task because a prerequisite wasn't completed?
4. Does the task ordering minimize context-switching? Are related changes grouped together?

### Loop Protocol

1. Run BOTH checklists above
2. Log findings in the Review Log table
3. **Present findings to the user BEFORE making changes** — share what you found, what you plan to fix, and ask if the user sees additional gaps. Do NOT silently self-fix and move on. The review loop is a collaborative checkpoint, not a self-assessment.
4. Use AskUserQuestion if findings need user input
5. Fix issues inline — do NOT create a new file
6. Commit: `git commit -m "docs: plan review loop N for <feature>"`

### Exit Criteria (ALL must be true)

- Every spec section / FR-ID maps to a task (zero gaps)
- Decision log has 3+ entries with rationale
- No placeholder language exists anywhere
- Every task has inline verification with exact commands
- Final verification task includes all applicable items
- Last loop found only cosmetic issues
- **User has confirmed they have no further concerns** (do not self-declare exit)

---

## Phase 4: Final Review

Run one final improvement pass:

1. **Spec coverage** — Re-read the spec. Is EVERYTHING mentioned covered? List gaps.
2. **Conciseness** — Can sections be tightened without losing information?
3. **Missing standard sections** — Prerequisites? File map? Decision log? Risks? Rollback? Review log?
4. **Coherence** — Any conflicting tasks, circular dependencies, or steps that assume work not yet done?
5. **Blind spots** — What would an engineer struggle with? What implicit knowledge does the plan assume?

**Share your analysis with the user BEFORE modifying anything.** Ask for confirmation on what to fix. Do NOT declare the plan complete until the user confirms.

After final fixes, commit:
```
git add docs/plans/<file>
git commit -m "docs: add implementation plan for <feature>"
```

Report to user:
- Plan location
- Task count
- Key decisions (top 3 from decision log)
- Open risks flagged

Then offer execution choice:

> **"Plan complete and saved. Two execution options:**
>
> **1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. Uses `superpowers:subagent-driven-development`.
>
> **2. Inline Execution** — Execute tasks in this session with checkpoints for review. Uses `superpowers:executing-plans`.
>
> **Which approach?"**

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
