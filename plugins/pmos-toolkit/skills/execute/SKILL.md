---
name: execute
description: Execute an implementation plan end-to-end — task-by-task TDD implementation with deploy verification, frontend testing, and manual spot checks. Supports git worktree isolation. Use when the user says "implement the plan", "start building", "execute this", "code this up", or has a plan doc ready for implementation.
user-invocable: true
argument-hint: "<path-to-plan-doc>"
---

# Plan Executor

Execute an implementation plan end-to-end with strict verification. Supports git worktree isolation when available, but works without it.

If `superpowers:subagent-driven-development` or `superpowers:executing-plans` are available, use them. Otherwise, follow the inline instructions below — they are self-contained.

**Announce at start:** "Using the execute skill to implement the plan in an isolated worktree."

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No `AskUserQuestion`:** State your assumption, document it in the output, and proceed. The user reviews after completion.
- **No subagents:** Perform research and analysis sequentially as a single agent.
- **No `superpowers:` skills:** Follow the inline instructions in this skill directly.
- **No Playwright MCP:** Note browser-based verification as a manual step for the user.

---

## Phase 0: Setup

1. **Locate the plan.** If the user passed an argument, use it. Otherwise check `docs/plans/` for the most recent file. If nothing found, ask.
2. **Read the plan and its upstream spec end-to-end.** Understand the "Done when" criteria and final verification task.
3. **Isolate the work (if possible):**
   - If `superpowers:using-git-worktrees` is available: create an isolated worktree.
   - Otherwise: create a feature branch (`git checkout -b feature/<name>`).
4. **Check for environment conflicts.** If using Docker with parallel stacks, ensure ports and project names don't collide.

---

## Phase 1: Execute Tasks

Work through the plan's tasks in order. For each task:

1. **Read the task** — understand goal, files, spec refs, and steps.
2. **Follow TDD** — write failing test, verify it fails, implement, verify it passes.
3. **Run inline verification** — execute the exact commands listed in the task's verification section.
4. **Commit** — small, focused commit per task. Not one giant commit at the end.
5. **Move to next task** — do not proceed if verification fails.

If subagents are available (e.g., `superpowers:subagent-driven-development`), dispatch independent tasks in parallel. Otherwise, execute sequentially.

### Execution Rules

- **Test in smaller chunks.** Verify after each task. Do NOT batch all testing to the end.
- **Update documentation** as part of relevant tasks (CLAUDE.md, changelogs, etc.).
- **Ask for clarification** if any ambiguity arises during execution.

---

## Phase 2: Deploy & Verify

After all tasks are complete, run the plan's final verification task. If the plan doesn't have one, construct it from this checklist:

### Verification Checklist

Run every applicable item. Do NOT skip verification steps. Do NOT rely solely on tests passing.

- [ ] **Lint & format:** `ruff check . && ruff format --check .`
- [ ] **Full test suite:** `pytest` — expect no regressions
- [ ] **Database migrations:** `alembic upgrade head` (if migrations added)
- [ ] **Docker deploy to worktree stack:**
  ```bash
  cd .worktrees/<branch>
  docker compose -f docker-compose.worktree.yml -p <project> up --build -d
  ```
  Ensure port offsets don't collide with other running stacks.
- [ ] **API verification:** Use `curl` or CLI commands to verify every new/modified endpoint returns the expected payload shape as defined in the spec.
- [ ] **Frontend verification (Playwright MCP):**
  1. Authenticate first (if auth is enabled)
  2. Navigate to each affected page
  3. Walk through every user journey from the spec
  4. Verify UI elements render correctly
  5. Check for console warnings/errors
  6. Take screenshots for documentation
- [ ] **Manual spot check:** Run actual scenarios in the development environment. Verify functionality by interacting with the system as a user would. Do NOT only rely on automated tests.
- [ ] **Seed data:** Re-seed if data files changed: `python scripts/seed_sop_db.py --reset`

### Verification Failures

When verification reveals issues:
1. Fix the issue
2. Add a test that would have caught it (expand the automated test suite)
3. Re-run the relevant verification steps
4. Continue until all checks pass

---

## Phase 3: Spec Compliance Review

After verification passes, do a final compliance check:

1. **Re-read the spec.** Go through every section and FR-ID. Confirm each requirement is implemented and verified.
2. **Re-read the plan.** Check every task's "Done when" criteria. Confirm nothing was skipped.
3. **List any gaps** between the spec/plan and the final implementation. If gaps exist, fix them before proceeding.

---

## Phase 4: Commit & Report

1. **Commit all changes** with a clear commit message referencing the plan.
2. **Report to the user:**
   - What was implemented (task summary)
   - Verification results (which checks passed)
   - Any gaps found and how they were resolved
   - Any new tests added from discovered issues
   - Worktree location and Docker stack status

Do NOT tear down the worktree stack — the user may want to inspect it. Remind them to clean up when done:
```bash
docker compose -f docker-compose.worktree.yml -p <project> down
```

---

## Anti-Patterns (DO NOT)

- Do NOT claim implementation is complete without running ALL verification steps
- Do NOT rely only on tests passing — manual verification is mandatory
- Do NOT skip Playwright MCP frontend testing when there are UI changes
- Do NOT deploy to the main Docker stack — use the worktree's isolated stack
- Do NOT leave discovered issues as "known gaps" — fix them and add tests
- Do NOT make one giant commit at the end — commit after each task
- Do NOT stop at the first passing test run — re-read the spec for completeness
