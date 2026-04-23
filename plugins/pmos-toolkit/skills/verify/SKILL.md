---
name: verify
description: Post-implementation verification gate — ALWAYS run after /execute completes. Lint, test, deploy, spec compliance, multi-agent code review, interactive QA, and regression test hardening. Also run after manual coding or partial work. Works with git commits, no PR required. Use when the user says "check my work", "is this done", "verify the implementation", "did I miss anything", or "review and test everything".
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
- **No Playwright MCP:** State the specific blocker and the setup the user must complete before browser-based verification can run. Do NOT mark any UI-surface FR verified without either Playwright evidence or an explicitly declared alternative (a specific test file that covers the rendered output). Offloading verification to the user is not a valid completion state — it resolves to `Unverified — action required` on the Phase 5 compliance tables, and Phase 4 stays open.
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

1. **Locate upstream documents.** Resolve each of the three inputs by following `../.shared/resolve-input.md`:
   - Spec: `phase=specs`, `label="spec"` (user argument, if passed, applies to the spec)
   - Requirements: `phase=requirements`, `label="requirements doc"`
   - Plan: `phase=plans`, `label="plan"`
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

### Phase 4 Entry Gate — Enumerate the Verification Surface

Before running any Phase 4 sub-step, enumerate every upstream requirement that has a runtime surface and create one `TodoWrite` task per item. This list is the gate — Phase 4 is not complete until every todo is closed with evidence or explicitly resolved to `Unverified — action required` with a named blocker. A plain bullet list in prose does not substitute for `TodoWrite` todos; the todos are the structural enforcement.

**How to build the list:**

1. Read the spec's FR-IDs and edge cases. For each, classify the runtime surface:
   - **UI surface** (user sees, clicks, enters something) → todo required
   - **API surface** (new or modified endpoint) → todo required
   - **Data surface** (migration, schema change, background job output) → todo required
   - **Pure internal logic** (algorithm verified by unit test only) → NOT on the list; cite the test in Phase 5 compliance instead
2. Read the requirements doc's user journeys. Every end-to-end journey with UI or API touchpoints gets one todo.
3. For each enumerated item, create a `TodoWrite` task formatted as:
   `Verify <FR-ID or Journey-ID>: <one-line description> [evidence: <type from table below>]`

**Evidence-type allowlist by sub-step:**

| Sub-step | Acceptable evidence |
|----------|--------------------|
| 3a. Database Migrations | Migration command output + DB schema query confirming the new shape |
| 3b. Docker Deployment | Service health check output + startup log snippet showing no errors |
| 3c. API Smoke Tests | `curl` response body compared row-by-row to the spec's API contract |
| 3d. Frontend Verification | Playwright MCP screenshot, `browser_evaluate` DOM assertion, or a specific test file covering the rendered output |
| 3e. Interactive Spot Checks | Playwright MCP interaction trace covering a user journey end-to-end, including at least one error/edge path |

**Every enumerated todo resolves to exactly one of three outcomes:**

1. **Verified** — evidence produced and cited. The evidence type must match the allowlist row for the sub-step. Close the todo.
2. **NA — alternative evidence cited** — the runtime surface doesn't exist for this item (e.g., FR is a pure calculation change). Cite the alternative (e.g., `test_pricing.py::test_discount_applied`) or the specific reason tied to the FR text. Bare "NA" is not valid. Close the todo with the alternative recorded.
3. **Unverified — action required** — you attempted verification and were blocked. State the specific blocker and the user action needed (e.g., "user must run `make seed-dev-db` before 3e can proceed"). Leave the todo OPEN and surface it in the Phase 8 final report.

**Setup is part of Phase 4, not a prerequisite.** Starting the dev server, seeding the DB, running migrations, authenticating — all Phase 4 work. If setup is complex, write down the exact commands, execute them, and proceed. Only escalate to the user when a genuine decision is required (e.g., "which dev DB to use"), not to offload execution. "Setup would take too long" is a Phase 4 red flag, not a reason.

### Phase 4 Red Flags — rationalizations that mean you're about to skip

If any of these thoughts surface during Phase 4, stop and re-read the entry gate. Each is a rationalization the skill has seen and named:

| Thought | Reality |
|---------|---------|
| "Automated tests already pass — good enough" | Automated tests miss UX, rendering, timing, and copy issues. The entry gate still applies. Every enumerated todo still needs evidence. |
| "This is out of scope for /verify" | Phase 4 is a numbered phase in this skill. Verification cannot be out of scope for the verification skill. |
| "The user can verify this at their desk" | Playwright MCP, `curl`, and DB queries are agent-owned tools. Offloading interactive verification to the user resolves to `Unverified — action required`, not `Verified`. |
| "Setup would take too long" | Setup is Phase 4 work. If you have time to write the final report, you have time to start the server. |
| "The happy path worked; good enough" | The spec's edge cases are explicit. Test at least one error/edge path per affected flow — the entry gate names this in 3e's evidence row. |
| "I'll note it as a gap" | A gap you could have verified but didn't is not a gap — it's a skip. Either produce evidence (close as Verified), cite alternative evidence (close as NA), or name the blocker (leave open as Unverified-action-required). There is no fourth state. |

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

### 3e. Interactive Spot Checks

Run actual scenarios in the development environment. Interact with the system as a user would. Specifically:

- Test the happy path end-to-end
- Test at least one error/edge case from the spec
- Test empty states if applicable
- Verify that unrelated flows still work (no regressions)

**Do NOT rely only on automated tests.** Interactive verification (Playwright MCP driving real user journeys) catches issues that tests miss: rendering glitches, confusing UX, wrong copy, timing issues. "Interactive" means you operate the browser via MCP — not that a human operates it for you.

---

## Phase 5: Spec Compliance Check

This is the most important phase. Re-read each upstream document and verify every requirement is implemented.

**Three-state outcome model (applies to 4a, 4b, 4c):**

Every row in every compliance table resolves to exactly one of three outcomes. Bare "Pass", "Fail", "Complete", or "Partial" are not valid — they collapse into the three below, and every row's `Evidence` column must cite a concrete artifact.

| Outcome | Meaning | Required in Evidence column |
|---------|---------|----------------------------|
| **Verified** | Requirement/task met; evidence produced during Phase 2–4. | Test file + function, screenshot path, `curl` output excerpt, DB query result, or commit SHA. The evidence type must match what was declared in the Phase 4 entry gate allowlist if the row has a runtime surface. |
| **NA (alt-evidence)** | No runtime surface for this row, OR the row was intentionally out of scope and covered indirectly. | Named alternative: e.g., "covered by `test_pricing.py::test_discount_applied`", or the specific reason tied to the requirement text (e.g., "FR narrative change only — no code path"). Bare "NA" or "N/A" is not valid. |
| **Unverified — action required** | Verification was attempted and blocked. The row is NOT resolved. | The specific blocker and the user action needed to unblock (e.g., "Playwright MCP unavailable in this environment — user must install; re-run 3d after"). Unverified rows must also appear in the Phase 8 final report as open items. |

Every row also cross-references the todo it closed (or left open) from the Phase 4 entry gate, if applicable. If no Phase 4 todo was created (pure internal logic), the Evidence column names the unit test that covered it.

### 4a. Requirements Compliance

Read `{docs_path}/requirements/<file>`. For every goal, user journey, and acceptance criterion:

| # | Requirement | Outcome | Evidence |
|---|-------------|---------|----------|
| Goal 1 | [From requirements] | Verified / NA / Unverified | [Per the three-state model: test file, screenshot path, curl excerpt, DB query, alt-evidence citation, or blocker + user action] |
| Journey 1, Step 3 | [Specific step] | Verified / NA / Unverified | [e.g., `screenshots/j1-s3.png` from Phase 4 3d, or `Unverified — dev server wouldn't start; user must run docker compose up`] |

### 4b. Spec Compliance

Read `{docs_path}/specs/<file>`. For every FR-ID and edge case:

| ID | Requirement | Outcome | Evidence |
|----|-------------|---------|----------|
| FR-01 | [From spec] | Verified / NA / Unverified | [Per the three-state model — e.g., `test_orders.py::test_checkout_flow`, or `screenshots/fr-01-checkout.png`, or `Unverified — Stripe webhook endpoint requires live deploy`] |
| FR-02 | ... | ... | ... |
| E1 | [Edge case] | Verified / NA / Unverified | [Evidence for the edge case specifically, not the happy path] |

### 4c. Plan Compliance

Read `{docs_path}/plans/<file>`. For every task:

| Task | Outcome | Evidence |
|------|---------|----------|
| T1: [Name] | Verified-complete / NA-skipped-with-reason / Unverified | [Commit SHA(s) implementing the task + at least one test or Phase 4 verification artifact; OR the decision record for an intentional skip (e.g., "merged into T3 during execution"); OR the blocker + user action] |
| T2: ... | ... | ... |

**For plan-task outcomes:**
- `Verified-complete` requires BOTH a commit reference AND a verification artifact (test, screenshot, curl excerpt). A commit alone is not evidence of correctness — only of existence.
- `NA-skipped-with-reason` requires naming the decision AND where it was recorded (plan update, session log, commit message). "NA" without a reason is not valid.
- `Unverified` means the task was claimed done but the verification couldn't be produced. This is a gap — surface it in the 4d Gap Report.

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

## Phase 9: Workstream Enrichment

**Skip if no workstream was loaded in Phase 0.** Otherwise, follow the enrichment instructions in `product-context/context-loading.md` Step 4. For this skill, the signals to look for are:

- Implementation gaps discovered vs spec → workstream `## Key Decisions`
- New constraints or scars uncovered during verification → workstream `## Constraints & Scars`

This phase is mandatory whenever Phase 0 loaded a workstream — do not skip it just because the core deliverable is complete.

---

## Phase 10: Capture Learnings

**This skill is not complete until the learnings-capture process has run.** Read and follow `learnings/learnings-capture.md` (relative to the skills directory) now. Reflect on whether this session surfaced anything worth capturing — surprising behaviors, repeated corrections, non-obvious decisions. Proposing zero learnings is a valid outcome for a smooth session; the gate is that the reflection happens, not that an entry is written.

---

## Evidence Standards

Every claim must have evidence. No exceptions:

| Claim | Required Evidence |
|-------|------------------|
| "Tests pass" | Paste the actual output: "34 passed, 0 failed" |
| "Lint is clean" | Paste the actual output: no errors |
| "API returns correct shape" | Show the actual curl output |
| "UI renders correctly" | Screenshot via Playwright MCP |
| "Spec requirement met" | Point to specific test or interactive verification artifact |
| "No regressions" | Show full test suite output |

**Never use:** "should pass", "looks correct", "probably fine", "I believe"

---

## Anti-Patterns (DO NOT)

For Phase 4 skip rationalizations specifically, see the **Phase 4 Red Flags** table — those six thoughts are the most common skips and are named individually there. This section covers general-purpose anti-patterns that apply across phases.

- Do NOT mark failing tests as skip to make the suite pass
- Do NOT claim "tests pass" without showing the output
- Do NOT skip the Phase 5 spec compliance check — this is the most valuable phase
- Do NOT leave discovered issues as "known gaps" — every item resolves to one of the three Phase 5 states (Verified, NA-with-alt-evidence, or Unverified-action-required with a named blocker). There is no fourth state.
- Do NOT commit debug logging, TODOs, or temporary workarounds
- Do NOT verify only the happy path — every affected flow gets at least one error/edge case per the Phase 4 entry gate's 3e evidence row
- Do NOT assume the previous verification run is still valid — re-run after every fix
- Do NOT skip the Phase 6 hardening phase — converting bugs to tests is what prevents regressions
