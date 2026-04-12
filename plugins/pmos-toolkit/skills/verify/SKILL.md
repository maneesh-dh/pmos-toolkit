---
name: verify
description: Post-implementation verification gate — ALWAYS run after /execute completes. Lint, test, deploy, spec compliance, multi-agent code review, manual QA, and regression test hardening. Also run after manual coding or partial work. Works with git commits, no PR required. Use when the user says "check my work", "is this done", "verify the implementation", "did I miss anything", or "review and test everything".
user-invocable: true
argument-hint: "<path-to-spec-doc> (optional — will search {docs_path}/specs/ if omitted)"
---

# Implementation Verification Gate

Systematically verify that an implementation matches its spec, requirements, and plan. This is a **standalone verification gate** — run it anytime after implementation is done, regardless of how the code was written.

This is an **operational workflow** — a structured sequence of verification steps with evidence collection.

**Announce at start:** "Using the verify skill to run post-implementation verification."

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No `AskUserQuestion`:** State your assumption, document it in the output, and proceed. The user reviews after completion.
- **No subagents:** Perform research and analysis sequentially as a single agent.
- **No Playwright MCP:** Note browser-based verification as a manual step for the user.
- **Task tracking:** Use your available task tracking tool (e.g., `TaskCreate`/`TaskUpdate` in Claude Code, `update_plan` in Codex, or equivalent). If none is available, announce phase transitions verbally.

**Create verification tasks** at the start using your available task tracking tool:

1. Gather Context
2. Static Verification (lint, types, tests)
3. Code Quality Review
4. Deploy & Integration Verification
5. Spec Compliance Check
6. Harden Test Suite
7. Final Compliance Pass
8. Commit & Report

Mark each as in-progress when starting and completed when done. Skip tasks that don't apply (e.g., skip deploy if no deployment is involved).

---

## When to Use

- After `/execute` completes (double-check)
- After manual implementation
- After picking up someone else's partial work
- Before claiming a feature is done
- When you suspect gaps between spec and implementation

---

## Phase 0: Load Workstream Context

Before any other work, follow the context loading instructions in `product-context/context-loading.md` (relative to the skills directory). This determines `{docs_path}` and loads workstream context if available. Use workstream context to verify that implementation aligns with product goals, not just spec compliance. Also read `~/.pmos/learnings.md` if it exists. Note any entries under `## /verify` and factor them into your approach for this session.

---

## Phase 1: Gather Context

1. **Locate upstream documents.** Find the spec, requirements, and plan:
   - Check user argument first
   - Then search `{docs_path}/specs/`, `{docs_path}/requirements/`, `{docs_path}/plans/` for the most recent matching files
   - If nothing found, ask the user
2. **Read all three documents** (whichever exist). You need these for the compliance check.
3. **Identify what changed.** Run `git diff main...HEAD --stat` (or appropriate base) to see which files were modified. This scopes the verification.
4. **Check if lint/type/tests were already run.** Ask the user or check recent terminal history. Skip steps already completed — but re-run if you're not confident they were clean.

---

## Phase 2: Static Verification (fast, run first)

Run in this order. Each step must pass before proceeding to the next. If a step fails, fix the issue, then re-run.

### 1a. Lint & Format

```bash
ruff check . && ruff format --check .
```
(Or project-appropriate linter. Check `CLAUDE.md` for the correct commands.)

**If issues found:** Fix them. Re-run. Do not proceed until clean.

### 1b. Type Checks

```bash
# Python: pyright or mypy
# TypeScript: tsc --noEmit
# Frontend: npm run lint (if it includes type checking)
```

**If issues found:** Fix them. Re-run.

### 1c. Unit Tests

```bash
pytest tests/ -v  # or project-appropriate test command
```

**Evidence required:** Paste the summary line showing pass/fail counts. "X passed, 0 failed" is the minimum bar.

**If failures:** Fix them. Do NOT skip failing tests. Do NOT mark tests as `@pytest.mark.skip` to make the suite pass.

### 1d. Frontend Tests & Lint (if applicable)

```bash
cd apps/<frontend-app> && npm run lint && npm test
```

---

## Phase 3: Multi-Agent Code Quality Review

Dispatch parallel subagents to review the diff from multiple angles. This catches code quality issues that static analysis and tests miss. Works against `git diff` — no PR required.

### Setup

```bash
# Get the diff to review
git diff main...HEAD          # if on a feature branch
git diff HEAD~N               # if commits are on main (N = number of commits in this feature)
```

Identify all CLAUDE.md files relevant to the changed directories (root + any directory-level CLAUDE.md files).

### Parallel Review Agents (dispatch simultaneously)

Launch 3-5 subagents depending on the scope of changes:

| Agent | Focus | What to return |
|-------|-------|---------------|
| **CLAUDE.md compliance** | Read the diff + all relevant CLAUDE.md files. Flag any violations of project conventions, naming patterns, code style rules, or architectural constraints. | List of violations with file:line and the specific CLAUDE.md rule. |
| **Bug scan** | Read only the changed lines (shallow scan). Look for obvious bugs: off-by-one errors, null/undefined access, missing error handling at system boundaries, race conditions, resource leaks. Ignore style issues. | List of potential bugs with severity and reasoning. |
| **Git history context** | Run `git blame` and `git log` on modified files. Check if changes break assumptions from previous work — renamed functions still referenced elsewhere, removed code that other modules depend on, changed behavior that tests don't cover. | List of issues with historical context. |
| **Comment compliance** | Read code comments in modified files (TODOs, invariants, "do not change" warnings, API contracts documented in docstrings). Check if the changes violate any guidance in those comments. | List of violated comments with file:line. |
| **Cross-file consistency** | Check that changes are consistent across files — if a function signature changed, are all callers updated? If a type changed, are all usages updated? If a config key was renamed, is it renamed everywhere? | List of inconsistencies. |

### Confidence Scoring

For each issue found, score confidence (0-100):

| Score | Meaning |
|-------|---------|
| 0-25 | Likely false positive — doesn't stand up to scrutiny, or pre-existing issue |
| 25-50 | Might be real but could be a nitpick. Not explicitly called out in CLAUDE.md. |
| 50-75 | Verified real issue but minor — won't happen often in practice |
| 75-100 | Verified real issue, will directly impact functionality, or explicitly violates CLAUDE.md |

**Filter:** Only act on issues scoring 75+. Log issues scoring 50-74 as "noted but not blocking." Discard below 50.

### Fix & Re-verify

For each issue scoring 75+:
1. Fix the issue
2. Re-run the relevant static verification step from Phase 1
3. If the fix changes behavior, add a regression test (Phase 5)

---

## Phase 4: Deploy & Integration Verification

### 3a. Database Migrations (if applicable)

```bash
alembic upgrade head
```

Verify the migration applied cleanly. Check for errors in output.

### 3b. Docker Deployment

Deploy to the appropriate environment (main stack or worktree stack):

```bash
docker compose build <affected-services> && docker compose up -d <affected-services>
```

Wait for services to be healthy. Check logs for startup errors.

### 3c. API Smoke Tests

For every new or modified API endpoint, verify the response shape matches the spec:

```bash
curl -sf <endpoint> | python3 -m json.tool
```

**Evidence required:** Show the actual response and compare it to the spec's API contract. Flag any mismatches.

### 3d. Frontend Verification (Playwright MCP)

For every affected UI flow:

1. **Authenticate first** (if auth is enabled)
2. **Navigate** to each affected page
3. **Walk through** every user journey from the spec
4. **Check** for console errors/warnings
5. **Take screenshots** for evidence
6. **Verify** that UI matches spec's frontend design section

### 3e. Manual Spot Checks

Run actual scenarios in the development environment. Interact with the system as a user would. Specifically:

- Test the happy path end-to-end
- Test at least one error/edge case from the spec
- Test empty states if applicable
- Verify that unrelated flows still work (no regressions)

**Do NOT rely only on automated tests.** Manual verification catches issues that tests miss (rendering glitches, confusing UX, wrong copy, timing issues).

---

## Phase 5: Spec Compliance Check

This is the most important phase. Re-read each upstream document and verify every requirement is implemented.

### 4a. Requirements Compliance

Read `{docs_path}/requirements/<file>`. For every goal, user journey, and acceptance criterion:

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| Goal 1 | [From requirements] | Pass/Fail/Partial | [Test name, screenshot, or curl output] |
| Journey 1, Step 3 | [Specific step] | Pass/Fail | [How verified] |

### 4b. Spec Compliance

Read `{docs_path}/specs/<file>`. For every FR-ID and edge case:

| ID | Requirement | Status | Evidence |
|----|-------------|--------|----------|
| FR-01 | [From spec] | Pass/Fail | [Test name or manual verification] |
| FR-02 | ... | ... | ... |
| E1 | [Edge case] | Pass/Fail | [How verified] |

### 4c. Plan Compliance

Read `{docs_path}/plans/<file>`. For every task:

| Task | Status | Notes |
|------|--------|-------|
| T1: [Name] | Complete/Partial/Missing | [Any issues] |
| T2: ... | ... | ... |

### 4d. Gap Report

List every gap found:

| # | Gap | Severity | Source Doc | Action |
|---|-----|----------|-----------|--------|
| 1 | [What's missing] | Critical/Medium/Low | [Which doc] | [Fix or defer] |

**If critical gaps exist:** Fix them before proceeding. Re-run affected verification steps.

---

## Phase 6: Harden the Test Suite

For every issue discovered during verification:

1. **Write a regression test** that would have caught the issue
2. **Verify red-green:** The test must fail when you revert the fix, and pass with the fix applied
3. **Name descriptively:** `test_<function>_<bug_condition>_<expected_outcome>`

This is not optional. The goal is that the same issue can never ship again.

Also check for coverage gaps:
- Any spec requirement with no corresponding test? Write one.
- Any edge case from the spec that isn't tested? Write one.
- Any user journey that's only verified manually? Consider adding an integration or E2E test.

---

## Phase 7: Final Compliance Pass

One last check before committing:

1. **Re-read the spec one final time.** Is there ANYTHING mentioned that isn't implemented or verified?
2. **Check for TODO/FIXME/HACK** in the changed files. Resolve them or flag them explicitly.
3. **Check for debug logging** or temporary code that should be removed.
4. **Check for hardcoded values** that should be configuration.
5. **Verify documentation is updated** (CLAUDE.md, changelogs, API docs).

---

## Phase 8: Commit & Report

1. **Commit all changes** (fixes, new tests, documentation updates):
   ```bash
   git add <specific-files>
   git commit -m "fix: verification fixes for <feature>"
   ```
   If there are multiple logical changes, use multiple commits.

2. **Report to the user:**
   - Verification summary (which phases passed/failed)
   - Compliance tables (requirements, spec FR-IDs, plan tasks)
   - Gaps found and how they were resolved
   - New tests added (count and what they cover)
   - Any remaining issues that need user decision

---

## Capture Learnings (after commit & report)

Follow the learning capture instructions in `learnings/learnings-capture.md` (relative to the skills directory).

---

## Evidence Standards

Every claim must have evidence. No exceptions:

| Claim | Required Evidence |
|-------|------------------|
| "Tests pass" | Paste the actual output: "34 passed, 0 failed" |
| "Lint is clean" | Paste the actual output: no errors |
| "API returns correct shape" | Show the actual curl output |
| "UI renders correctly" | Screenshot via Playwright MCP |
| "Spec requirement met" | Point to specific test or manual verification |
| "No regressions" | Show full test suite output |

**Never use:** "should pass", "looks correct", "probably fine", "I believe"

---

## Anti-Patterns (DO NOT)

- Do NOT skip manual verification — automated tests miss UX issues, rendering bugs, and timing problems
- Do NOT mark failing tests as skip to make the suite pass
- Do NOT claim "tests pass" without showing the output
- Do NOT skip the spec compliance check — this is the most valuable phase
- Do NOT leave discovered issues as "known gaps" — fix them and add regression tests
- Do NOT commit debug logging, TODOs, or temporary workarounds
- Do NOT verify only the happy path — test at least one error/edge case
- Do NOT assume the previous verification run is still valid — re-run after every fix
- Do NOT skip the hardening phase — converting bugs to tests is what prevents regressions
