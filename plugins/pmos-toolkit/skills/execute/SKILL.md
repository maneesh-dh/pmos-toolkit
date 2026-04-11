---
name: execute
description: Execute an implementation plan end-to-end — task-by-task TDD implementation with deploy verification, frontend testing, and manual spot checks. Supports git worktree isolation. Use when the user says "implement the plan", "start building", "execute this", "code this up", or has a plan doc ready for implementation.
user-invocable: true
argument-hint: "<path-to-plan-doc>"
---

# Plan Executor

Execute an implementation plan end-to-end with strict verification. Supports git worktree isolation when available, but works without it.

Follow the inline instructions below — they are self-contained.

**Announce at start:** "Using the execute skill to implement the plan in an isolated worktree."

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No `AskUserQuestion`:** State your assumption, document it in the output, and proceed. The user reviews after completion.
- **No subagents:** Perform research and analysis sequentially as a single agent.
- **No Playwright MCP:** Note browser-based verification as a manual step for the user.
- **Task tracking:** Use your available task tracking tool (e.g., `TaskCreate`/`TaskUpdate` in Claude Code, `update_plan` in Codex, or equivalent). If none is available, track progress via commit messages and report status verbally.

---

## Phase 0: Load Workstream Context

Before any other work, follow the context loading instructions in `context/context-loading.md` (relative to the skills directory). This determines `{docs_path}` and loads workstream context if available. Use workstream context passively — it informs implementation decisions and deviation assessments.

---

## Phase 1: Setup

1. **Locate the plan.** If the user passed an argument, use it. Otherwise check `{docs_path}/plans/` for the most recent file. If nothing found, ask.
2. **Read the plan and its upstream spec end-to-end.** Understand the "Done when" criteria and final verification task.
3. **Isolate the work:**
   - **Worktree (preferred):** Check for existing `.worktrees/` or `worktrees/` directory. If neither exists, create `.worktrees/`. Verify the directory is gitignored (`git check-ignore -q .worktrees`); if not, add it to `.gitignore` and commit. Then:
     ```bash
     git worktree add .worktrees/<branch-name> -b <branch-name>
     cd .worktrees/<branch-name>
     ```
   - **Fallback:** `git checkout -b feature/<name>` if worktrees aren't practical.
   - **Setup:** Auto-detect and install dependencies (`npm install`, `pip install -r requirements.txt`, `cargo build`, etc.). Run the test suite to establish a clean baseline before starting work.
4. **Check for environment conflicts.** If using Docker with parallel stacks, ensure ports and project names don't collide.
5. **Verify verification tooling (hard gate).** Before starting Task 1, produce evidence that your verification tools work:
   - If the plan has backend API tasks: start the dev server, run a request, paste the output.
   - If the plan has frontend tasks: open a page via Playwright MCP, paste the screenshot. If Playwright fails, establish the fallback now and paste its output instead (build check, type check, curl).
   - If any tool is unavailable, document the failure and the alternative.

   Do NOT proceed to Task 1 without this evidence. This is a gate, not a checklist item.
6. **Create task list.** Extract every task from the plan and create a tracked task for each, using your available task tracking tool. Include:
   - Task name and number from the plan
   - Key files to be modified
   - Dependencies on other tasks (if any)
   - The task's verification criteria as its "done" signal

   This gives the user (and you) a live progress view throughout execution.

---

## Phase 2: Execute Tasks

Work through the plan's tasks in order. For each task:

1. **Mark task as in-progress** in your task tracker.
2. **Read the task** — understand goal, files, spec refs, and steps.
3. **Follow TDD** — write failing test, verify it fails, implement, verify it passes.
4. **Run the verify-fix loop** (see below).
5. **Produce runtime evidence before committing:**
   - **API tasks:** curl every new/modified endpoint against the running dev server. Paste the output.
   - **UI tasks:** open the affected page in Playwright MCP (or fallback). Paste screenshot or programmatic output.
   - If you cannot produce runtime evidence for an API or UI task, the task is not done. Do not commit.
6. **Commit** — small, focused commit per task. Not one giant commit at the end.
7. **Mark task as completed** in your task tracker.
8. **Move to next task** — only after verification passes, evidence is produced, and task is marked complete.

### Verify-Fix Loop (per task)

Do not move to the next task until the current task's verification passes. This is a bounded loop, not a hope:

```
attempt = 0
while verification fails AND attempt < 3:
    1. Read the failure output carefully
    2. Diagnose root cause (not symptoms)
    3. Fix
    4. Re-run the FULL verification (not just the part that failed)
    attempt += 1

if still failing after 3 attempts:
    STOP — escalate to user with:
    - What the task requires
    - What verification command fails
    - What you tried and why it didn't work
    - Your best guess at the underlying issue
```

**Rules:**
- Each retry must change something — never re-run the same code hoping for a different result.
- Re-run the full task verification, not just the failing subset. A fix in one place can break another.
- The bound (3 attempts) prevents thrashing. If you can't fix it in 3 tries, a human needs to look.

### Subagent Execution (when Agent tool is available)

Dispatch a fresh subagent per task. Fresh context prevents confusion from accumulated state. After each task, run a **two-stage review**:

1. **Spec compliance review** — dispatch a reviewer subagent with the task's spec requirements and the implementer's diff. Question: does the code match the spec? Flag missing requirements or scope creep.
2. **Code quality review** — dispatch a second reviewer with the diff and project conventions (CLAUDE.md). Question: is the code well-built? Flag bugs, inconsistencies, convention violations.

If either reviewer finds issues, the implementer fixes them and the reviewer re-reviews. Do not proceed to the next task with open issues.

**Handling implementer status:**
- **Done** — proceed to review.
- **Needs context** — provide the missing information and re-dispatch.
- **Blocked** — assess: provide more context, use a more capable model, break the task smaller, or escalate to the user. Never retry without changing something.

### Sequential Execution (no subagents)

Execute tasks in order. After each task, self-review against the spec before proceeding.

### Execution Rules

- **Test in smaller chunks.** Verify after each task. Do NOT batch all testing to the end.
- **Update documentation** as part of relevant tasks (CLAUDE.md, changelogs, etc.).
- **Log plan deviations.** When the actual codebase differs from what the plan assumes (e.g., model fields don't exist, method signatures differ, enum values are different), log it inline: `DEVIATION: Plan assumes X, actual codebase has Y`. Adapt the implementation to reality but do NOT silently adjust — the deviation log helps catch plan quality issues for future sessions.

---

## Phase 3: Deploy & Verify

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
- [ ] **Frontend verification** (fallback ladder — use the first level that works):
  1. **Playwright MCP** (preferred): authenticate, navigate to each affected page, walk through every user journey from the spec, check for console errors, take screenshots.
  2. **If Playwright fails**: attempt recovery once (clear cache, new tab). If still dead, move to level 3.
  3. **Programmatic fallback**: `curl` the dev server routes (expect 200), verify the JS bundle contains expected component imports (`curl <bundle-url> | grep`), run type checks (`vue-tsc`, `tsc --noEmit`) and build (`npm run build`).
  4. **Suggest tooling fix**: propose concrete commands to restore browser testing. Do NOT ask the user to manually test features — that defeats the purpose of automated verification.

  Never skip frontend verification entirely. Never fall back to "please check manually."
- [ ] **Manual spot check:** Run actual scenarios in the development environment. Verify functionality by interacting with the system as a user would. Do NOT only rely on automated tests.
- [ ] **Seed data:** Re-seed if data files changed: `python scripts/seed_sop_db.py --reset`

### Verification Failures

When verification reveals issues:
1. Fix the issue
2. Add a test that would have caught it (expand the automated test suite)
3. Re-run the relevant verification steps
4. Continue until all checks pass

---

## Phase 4: Spec Compliance Review

After verification passes, do a final compliance check:

1. **Re-read the spec.** Go through every section and FR-ID. Confirm each requirement is implemented and verified.
2. **Re-read the plan.** Check every task's "Done when" criteria. Confirm nothing was skipped.
3. **List any gaps** between the spec/plan and the final implementation. If gaps exist, fix them before proceeding.

---

## Phase 5: Commit & Report

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

3. **Invoke `/pmos-toolkit:verify`** to run the full post-implementation verification gate. This is the next pipeline stage (`/execute → /verify`). Do NOT consider execution complete until /verify has run.

---

## Evidence Before Claims

Every verification claim must have fresh evidence. Run the command, read the output, THEN make the claim.

| Claim | Required | Not Sufficient |
|-------|----------|----------------|
| "Tests pass" | Test output: "X passed, 0 failed" | Previous run, "should pass" |
| "Lint clean" | Linter output: 0 errors | "I didn't change style" |
| "Build succeeds" | Build output: exit 0 | "Linter passed" |
| "Bug fixed" | Test original symptom: passes | "Code changed, assumed fixed" |

**Never use:** "should pass", "looks correct", "probably fine". If you haven't run the command in this step, you cannot claim the result.

---

## When to Stop

**Stop executing and escalate immediately when:**
- A dependency is missing or unavailable
- A test fails repeatedly after attempted fixes
- An instruction in the plan is unclear or contradictory
- Verification fails in a way you can't diagnose
- The plan itself appears to have a bug (e.g., task references a file that doesn't exist)

**Ask rather than guess.** A wrong guess costs more than a pause for clarification.

---

## Workstream Enrichment (after commit & report)

If a workstream was loaded in Phase 0, follow the enrichment instructions in `context/context-loading.md` Step 4. For this skill, the signals to look for are:

- Key implementation decisions → workstream `## Key Decisions`

---

## Anti-Patterns (DO NOT)

- Do NOT claim implementation is complete without running ALL verification steps
- Do NOT rely only on tests passing — manual verification is mandatory
- Do NOT skip Playwright MCP frontend testing when there are UI changes
- Do NOT deploy to the main Docker stack — use the worktree's isolated stack
- Do NOT leave discovered issues as "known gaps" — fix them and add tests
- Do NOT make one giant commit at the end — commit after each task
- Do NOT stop at the first passing test run — re-read the spec for completeness
