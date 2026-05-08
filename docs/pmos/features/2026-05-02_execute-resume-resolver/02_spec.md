# /execute Resume Resolver + Phase Boundaries — Spec

**Date:** 2026-05-02
**Status:** Draft
**Tier:** 2 — Enhancement
**Source:** User request — "make it easy for /execute to figure out resume by building a good resolver"
**Affected skills:** `execute`, `plan`, `verify`, plus two new shared protocol files
**Plugin version target:** `pmos-toolkit` 2.13.0

---

## 1. Problem Statement

When a /execute session is too large to complete in one sitting, /execute today recommends pausing and resuming in a fresh session — but there is no machinery to make resume safe or fast:

1. **No structured "where did we leave off" signal.** Per-task logs (`{feature_folder}/execute/task-NN.md`) exist but have no frontmatter, no status field, and no plan-task identity binding. The in-session task tracker is ephemeral — it dies with the session.
2. **No way to detect mid-task interruption.** If a session crashes after committing partial work for T5 but before writing T5's done-log, a fresh /execute session has no way to know T5 is half-done.
3. **No plan-drift detection.** If the user edits the plan between sessions (renames T5, splits it, renumbers), the resolver has no way to know whether the prior T5 done-log still applies.
4. **No cross-session compact discipline.** Long plans accumulate context and force pauses, but there's no formalized verify+compact handshake at logical boundaries.
5. **No multi-feature awareness.** When two features are in flight in parallel worktrees, re-invoking /execute without arguments has no way to disambiguate which feature to resume.

**Primary success metric:** in the next "big plan, multiple sessions" run, the agent re-invokes /execute, gets a Resume Report identifying the next task within ~1–2 seconds, and continues without human intervention beyond confirming the report.

---

## 2. Goals

| # | Goal | Success Metric |
|---|------|---------------|
| G1 | /execute can resume a partially-completed plan from the next non-`done` task | Cold-start /execute on an existing `{feature_folder}` produces a Resume Report and continues from the correct task with no manual `--from` |
| G2 | Crashed mid-task work is detected, not silently overwritten | An `in-flight` log left behind by a previous crashed session surfaces in the Resume Report with `in-flight-with-commits` annotation |
| G3 | Plan edits between sessions are flagged, not silently applied | A renamed/rewritten task whose `task_goal_hash` no longer matches surfaces as `done-but-drifted` and forces a user decision |
| G4 | Logical phase boundaries trigger full /verify + compact when verify is green | A plan with `## Phase N` headings runs full /verify at each boundary; on green, compact fires before the next phase's first task |
| G5 | Parallel features in flight (multiple worktrees) are disambiguated, not collided | Re-invoking /execute with no plan path lists candidate features and asks which to resume |
| G6 | Resume costs nothing for plans that don't need it | Plans without prior logs run the existing fresh-start flow with no added latency |

---

## 3. Non-Goals

- NOT building a `STATE.md` cache — because logs are already written per-task and reconstruction from logs is fast enough; a cache adds drift risk for marginal speed.
- NOT making "phases" mandatory in /plan — because flat T1...TN plans must continue to work; phases are an opt-in convention for large plans.
- NOT introducing context-window monitoring or auto-compact heuristics — because plan-author-controlled phase boundaries are predictable and the chosen mechanism; auto-compact is rejected scope.
- NOT building a phase-scoped lighter verify — because the user explicitly chose full /verify at phase boundaries; the rigor is the point.
- NOT auto-resolving plan drift — because silent re-mapping of completed work to a changed plan is dangerous; the resolver flags drift and the user decides.
- NOT modifying /verify's existing standalone behavior — because /verify must continue to work as today when invoked directly; only its phase-scoped invocation mode is added.

---

## 4. High-Level Design

```
                 ┌──────────────────────────────────────────────┐
                 │ /execute invocation                         │
                 │ (path-to-plan or no args)                   │
                 └───────────────────┬──────────────────────────┘
                                     │
            ┌────────────────────────▼─────────────────────────┐
            │ Phase 0: Workstream + feature folder resolution  │
            │ (existing)                                       │
            └────────────────────────┬─────────────────────────┘
                                     │
            ┌────────────────────────▼─────────────────────────┐
            │ Phase 0.4: Feature Disambiguation (NEW)          │
            │ If multiple features have non-`done` logs in     │
            │ this repo, list and AskUserQuestion to pick.     │
            └────────────────────────┬─────────────────────────┘
                                     │
            ┌────────────────────────▼─────────────────────────┐
            │ Phase 0.5: Resume Resolution (NEW)               │
            │ Read plan + scan logs + diff git log + classify  │
            │ each task. Build Resume Report. Confirm via      │
            │ AskUserQuestion. Decide resume_task_index.       │
            └────────────────────────┬─────────────────────────┘
                                     │
            ┌────────────────────────▼─────────────────────────┐
            │ Phase 1: Setup (existing, possibly skipped)      │
            │ - If resuming: cd into existing worktree (or     │
            │   recreate from branch). Skip baseline test run. │
            │ - If fresh: existing setup.                      │
            └────────────────────────┬─────────────────────────┘
                                     │
                ┌────────────────────▼────────────────────┐
                │ Phase 2: Execute Tasks (modified loop)  │
                │   For each task starting from           │
                │   resume_task_index:                    │
                │     1. Mark task in-flight (write log   │
                │        with status=in-flight)           │
                │     2. TDD + verify-fix loop (existing) │
                │     3. Commit (T<N> in message)         │
                │     4. Update log: status=done          │
                │     5. Phase Boundary Check (NEW) ──┐   │
                └─────────────────────────────────────┼───┘
                                                     │
            ┌────────────────────────────────────────▼─────────┐
            │ Phase 2.5: Phase Boundary Handler (NEW)          │
            │ If this task closed a `## Phase N` group:        │
            │   a. Invoke full /verify (phase-scoped mode)     │
            │   b. If pass: write phase-N.md (passed),         │
            │      then trigger compact, continue              │
            │   c. If fail: write phase-N.md (failed), do      │
            │      NOT compact, escalate to user.              │
            └────────────────────────┬─────────────────────────┘
                                     │
                                  (continue loop)
                                     │
                  Phases 3–7 (existing): final verify, compliance,
                  commit, workstream enrichment, learnings.
```

---

## 5. Detailed Design

### 5.1 Per-Task Log Frontmatter (NEW format)

`{feature_folder}/execute/task-NN.md` gains structured frontmatter. The body of the log (decisions, deviations, evidence) keeps its current free-form shape.

```yaml
---
task_number: 5
task_name: "Add SOP migration"
task_goal_hash: <sha256(plan_T5_goal_line)>
plan_path: "{feature_folder}/03_plan.md"
branch: "feature/sop-editor"
worktree_path: ".worktrees/sop-editor"
status: in-flight | done | failed
started_at: 2026-05-02T14:32:11Z
completed_at: 2026-05-02T14:48:30Z   # only when status == done
files_touched:
  - src/sop/migrations/0042_add_remediation.py
  - tests/sop/test_migration_0042.py
---
```

**Lifecycle:**
- `started_at` + `status: in-flight` written when /execute marks the task as started (before TDD work begins).
- `status: done` + `completed_at` set after the verify-fix loop passes AND runtime evidence is produced.
- `status: failed` set when the 3-attempt retry budget is exhausted (existing escalation path).
- `files_touched` populated incrementally as the task touches files (used by §5.7 for phase-scoped verify and by future audit needs).

**Hash function:** `task_goal_hash = sha256(plan_T<N>_goal_sentence_normalized)` where `_normalized` means: trim, collapse whitespace, lowercase. Stored as hex string. Insensitive to formatting tweaks; sensitive to semantic changes.

### 5.2 Phase Log Frontmatter (NEW)

`{feature_folder}/execute/phase-N.md` written only when the plan has `## Phase N` headings AND a phase boundary fires.

```yaml
---
phase_number: 1
phase_name: "Schema + migration"
tasks_in_phase: [T1, T2, T3]
verify_status: passed | failed
verify_evidence_paths: ["{feature_folder}/verify/2026-05-02-phase-1/"]
plan_path: "{feature_folder}/03_plan.md"
plan_phase_hash: <sha256(phase_heading + concatenated_task_goal_lines)>
completed_at: 2026-05-02T15:14:00Z
---

## Verify Summary
[Brief: which checks ran, key results, links to evidence]
```

**`plan_phase_hash`:** sha256 of the phase heading text plus all `Goal:` lines of tasks in the phase, normalized as in 5.1. Lets the resolver detect phase-level drift in one comparison instead of N task-level comparisons.

### 5.3 Resolver Algorithm (`_shared/execute-resume.md`)

Pseudocode:

```
function resolve_resume(plan_path, feature_folder):
    plan = parse_plan(plan_path)
    # plan.tasks: [{number, name, goal, phase_number_or_null}, ...]
    # plan.phases: [{number, name, task_numbers}, ...] or []

    log_dir = f"{feature_folder}/execute/"
    task_logs = scan_task_logs(log_dir)       # parse each task-NN.md frontmatter
    phase_logs = scan_phase_logs(log_dir)     # parse each phase-N.md frontmatter

    # 1. Sealed phases first — trust phase-level assertion
    sealed_task_numbers = set()
    drifted_phases = []
    for plog in phase_logs where plog.verify_status == "passed":
        current_phase = plan.phases[plog.phase_number]
        if hash(current_phase) == plog.plan_phase_hash:
            sealed_task_numbers |= set(current_phase.task_numbers)
        else:
            drifted_phases.append(plog.phase_number)

    # 2. Per-task classification for the rest
    classification = {}  # task_number -> state
    for task in plan.tasks:
        if task.number in sealed_task_numbers:
            classification[task.number] = "done-sealed"
            continue
        log = task_logs.get(task.number)
        if log is None:
            classification[task.number] = "not-started"
        elif log.status == "done" and log.task_goal_hash == hash(task.goal):
            classification[task.number] = "done"
        elif log.status == "done":
            classification[task.number] = "done-but-drifted"
        elif log.status == "in-flight":
            classification[task.number] = "in-flight"
        elif log.status == "failed":
            classification[task.number] = "failed"

    # 3. Cross-check git commits on the branch
    branch = infer_branch(task_logs, phase_logs)   # take from any log; all must agree
    commit_task_refs = parse_git_log(branch)       # extract T<N> from messages
    for task_number in commit_task_refs:
        if classification.get(task_number) in ["not-started", "in-flight"]:
            classification[task_number] += "-with-commits"

    # 4. Pick resume point: lowest-N task whose state != "done" and != "done-sealed"
    resume_task_index = min(
        t.number for t in plan.tasks
        if classification[t.number] not in ["done", "done-sealed"]
    )

    # 5. Worktree liveness
    worktree_status = check_worktree(branch)
    # → "present" | "missing-but-branch-exists" | "both-gone"

    return ResumeReport(plan_path, branch, worktree_status, classification,
                        resume_task_index, drifted_phases)
```

**Output rendered to chat as the Resume Report table** (see §5.5). Confirmation flows through `AskUserQuestion`.

### 5.4 Feature Disambiguation (Phase 0.4)

```
function disambiguate_feature(plan_path_arg, feature_arg, repo_root):
    if plan_path_arg is given:
        return derive_feature_folder(plan_path_arg)
    if feature_arg is given:
        return f"{repo_root}/{docs_path}/{feature_arg}"

    # Neither given — scan for in-flight features
    candidates = []
    for folder in glob("{repo_root}/{docs_path}/*/"):
        log_dir = f"{folder}/execute/"
        if not exists(log_dir): continue
        non_done = count_logs_with_status(log_dir, status != "done")
        if non_done > 0:
            candidates.append((folder, non_done, last_modified(log_dir)))

    if len(candidates) == 0: error "no plan path given and no in-flight features found"
    if len(candidates) == 1: return candidates[0].folder
    # Multiple — AskUserQuestion with feature names + last-modified
    return ask_user_to_pick(candidates)
```

### 5.5 Resume Report (chat output, no file written)

```markdown
# Execute Resume Report
Plan: docs/sop-editor/03_plan.md
Branch: feature/sop-editor  (worktree: .worktrees/sop-editor — present)

| T# | Phase | Name           | State                       | Notes |
|----|-------|----------------|-----------------------------|-------|
| T1 | P1    | Schema         | done-sealed                 |       |
| T2 | P1    | Migration      | done-sealed                 |       |
| T3 | P2    | API endpoint   | done-but-drifted            | Goal text changed since completion |
| T4 | P2    | UI form        | in-flight-with-commits      | log left open from previous session, 2 commits on branch |
| T5 | P2    | E2E test       | not-started                 |       |

Drifted phases: none.
Recommended resume point: T4 (re-validate, then continue).
```

Followed by `AskUserQuestion`:
- **Resume from T4 (re-validate first)** — Recommended
- Restart T4 from scratch (revert commits)
- Jump to specific task (free-form follow-up)
- Restart from T1 (destructive, double-confirm)
- Cancel

### 5.6 Phase Boundary Handler (`_shared/phase-boundary-handler.md`)

Invoked from /execute Phase 2.5 after each task's `done` log is written.

```
function handle_phase_boundary(completed_task, plan, feature_folder):
    phase = plan.phase_containing(completed_task.number)
    if phase is None: return CONTINUE
    if completed_task.number != phase.task_numbers[-1]: return CONTINUE  # not the last task

    # 1. Full /verify, scoped to this phase
    verify_result = invoke_verify(
        scope = "phase",
        feature = feature_folder,
        phase_number = phase.number,
        evidence_dir = f"{feature_folder}/verify/{today}-phase-{phase.number}/"
    )

    # 2. Write phase log
    write_phase_log(
        feature_folder, phase,
        verify_status = "passed" if verify_result.ok else "failed",
        verify_evidence_paths = [verify_result.evidence_dir]
    )

    if not verify_result.ok:
        # 3a. Failure path: do NOT compact, escalate
        return ESCALATE(verify_result.failures)

    # 3b. Success path: hard-stop and instruct user to /compact + re-invoke --resume
    # (per O1 default; advisory-continue is the alternative pending O1 resolution)
    return HALT_FOR_COMPACT(
        message = f"Phase {phase.number} verified green. "
                  f"Run `/compact` to clear context, then re-invoke "
                  f"`/execute --resume` to continue with phase {phase.number + 1}."
    )
```

**Compact trigger:** the skill cannot programmatically compact — `/compact` is a Claude Code built-in that requires user invocation. Default behavior (per Open Question O1) is **hard-stop**: emit the HALT_FOR_COMPACT message and end the /execute turn. The user runs `/compact`, then re-invokes `/execute --resume`. The Phase 0.5 resolver will see the sealed phase log and pick up at the next phase's first task.

Alternative (pending O1 resolution): advisory-continue — emit the same message but keep executing. Cheaper for the user but defeats the compact purpose.

### 5.7 /verify Phase-Scoped Invocation Mode

`/verify` gains an opt-in mode triggered by /execute. When invoked with `--scope phase --feature <slug> --phase <N>`:
- Reads the phase's task numbers from `phase-N.md` (or from the plan if no log yet).
- Runs the **full /verify checklist** but treats "changed files" as "files touched by tasks in this phase only" (computed from per-task log frontmatter `files_touched` — see §5.1).
- Writes evidence to `{feature_folder}/verify/<date>-phase-N/` instead of the default location.
- Returns a structured pass/fail result so /execute can branch.

Existing standalone /verify behavior is unchanged.

### 5.8 /plan Convention Update (`## Phase N` Headings — Optional)

`/plan` skill gets a new optional template element documented in Phase 3:

```markdown
## Tasks

## Phase 1: Schema and Migration
[Phase rationale: 1-2 sentences on why these tasks group as a deployable slice.]

### T1: ...
### T2: ...
### T3: ...

## Phase 2: API Layer
...
```

**Guidance added to /plan:**
- Phases are **optional**. Small plans (≤8 tasks) should skip them.
- Each phase boundary triggers **full /verify** (slow — multi-agent code review + interactive QA). Make phases meaningfully large (target 5–10 tasks) and deployable as a slice.
- Phase 1 always starts at T1; phases are contiguous (no gaps); a task belongs to at most one phase.

### 5.9 CLI Surface

`argument-hint` for /execute:
```
<path-to-plan-doc> [--feature <slug>] [--backlog <id>] [--resume | --restart | --from T<N>]
```

| Flag | Behavior |
|------|----------|
| (no resume flag) | If logs exist for this feature → run resolver, show Report. If no logs → fresh start. |
| `--resume` | Force resolver path even if it would skip. |
| `--restart` | Ignore existing state, fresh start. AskUserQuestion confirmation required (destructive). |
| `--from T<N>` | Skip resolver, set resume point to T<N> manually. Use when user knows the answer. |

### 5.10 Commit Message Convention

Per-task commits **must** include the task number in the form `T<N>` somewhere in the subject line. Acceptable shapes:
- `feat(T5): add SOP migration`
- `T5: add SOP migration`
- `fix: T5 retry handler`

The resolver greps `\bT[0-9]+\b` from `git log <branch> --oneline`. Existing /execute prose already implies "commit per task" — this codifies the format so the resolver can rely on it.

---

## 6. File Changes

### NEW
- `plugins/pmos-toolkit/skills/_shared/execute-resume.md` — resolver protocol (§5.3 + §5.4 + §5.5).
- `plugins/pmos-toolkit/skills/_shared/phase-boundary-handler.md` — §5.6 protocol.

### MODIFIED — `plugins/pmos-toolkit/skills/execute/SKILL.md`
- Argument-hint: add `[--resume | --restart | --from T<N>]`.
- Insert **Phase 0.4: Feature Disambiguation** between Phase 0 and Phase 1 (references `_shared/execute-resume.md`).
- Insert **Phase 0.5: Resume Resolution** after Phase 0.4 (references `_shared/execute-resume.md`).
- Phase 1: branch on resume vs fresh — skip worktree creation + baseline test if resuming.
- Phase 2 step 6: commit message MUST include `T<N>`.
- Phase 2 step 7: write log on task **start** (status=in-flight); update on done with new frontmatter (§5.1).
- Insert **Phase 2.5: Phase Boundary Check** after step 9 of Phase 2 (references `_shared/phase-boundary-handler.md`).
- Anti-Patterns: add "Do NOT silently re-do tasks marked `done` without checking drift." and "Do NOT skip the Phase Boundary Check when the plan has `## Phase N` headings."

### MODIFIED — `plugins/pmos-toolkit/skills/plan/SKILL.md`
- Phase 3 template: document optional `## Phase N` heading convention (§5.8).
- Add guidance bullet: "Phase boundaries trigger full /verify in /execute. Make them deployable slices (5–10 tasks), not arbitrary chunks."
- Anti-Patterns: add "Do NOT create phases of 1–2 tasks — the verify cost dwarfs the work."

### MODIFIED — `plugins/pmos-toolkit/skills/verify/SKILL.md`
- Document `--scope phase --feature <slug> --phase <N>` invocation mode (§5.7).
- Specify evidence path override (`{feature_folder}/verify/<date>-phase-N/`).
- Note: existing standalone behavior unchanged.

### MODIFIED — manifests
- `plugins/pmos-toolkit/.claude-plugin/plugin.json` → `2.13.0`
- `plugins/pmos-toolkit/.codex-plugin/plugin.json` → `2.13.0`

---

## 7. Edge Cases

| # | Scenario | Resolver behavior |
|---|----------|-------------------|
| E1 | No logs exist for the feature | Fresh start, no Report shown. |
| E2 | All logs are `done` and no drift | Report says "all tasks done"; AskUserQuestion: "Re-run final verify? / Cancel". |
| E3 | Log exists with `status: in-flight`, no commits on branch | Classify as `in-flight`. Report flags it. Default action: re-run task from scratch. |
| E4 | Log exists with `status: in-flight`, commits on branch | Classify as `in-flight-with-commits`. Report flags. Default action: prompt "continue from commits / revert and redo". |
| E5 | Log `status: done`, hash matches | Classify as `done`. No action. |
| E6 | Log `status: done`, hash mismatch | Classify as `done-but-drifted`. Report flags. AskUserQuestion: treat as done / redo / mark for review. |
| E7 | `phase-N.md` exists, `verify_status: passed`, hash matches | All tasks in phase classified `done-sealed`. No per-task drift checks. |
| E8 | `phase-N.md` exists, `verify_status: passed`, phase hash mismatch | Phase listed under "Drifted phases". Default: drop sealed status, fall back to per-task classification within the phase. |
| E9 | `phase-N.md` exists, `verify_status: failed` | Phase NOT sealed. Report flags. Default action: resume from first non-done task in phase. |
| E10 | Worktree gone, branch exists | Recreate worktree from branch. Note in Report. |
| E11 | Worktree gone, branch gone | Fresh start with loud warning that prior logs may be orphaned. |
| E12 | Multiple features with non-done logs, no plan path arg | Phase 0.4 lists all and asks user to pick. |
| E13 | `--restart` passed | Skip resolver. AskUserQuestion confirmation: "This will discard prior progress logs (X tasks marked done). Confirm?" |
| E14 | `--from T5` passed | Skip resolver. Set resume_task_index=5. Trust the user. |
| E15 | Plan path arg points to a different plan than logs reference | Refuse to resume. Error: "Plan path mismatch — logs reference X, you passed Y. Use --restart or fix the path." |
| E16 | Logs reference a branch that no longer exists, but plan does | Treat as E11. |

---

## 8. Open Questions

| # | Question | Default if unresolved |
|---|----------|----------------------|
| O1 | At a green phase boundary, should /execute hard-stop and require the user to `/compact` + re-invoke `--resume`, or should it advise compact and continue? | Hard-stop — safer, more predictable. User can always re-invoke immediately if they want to skip the compact. |
| O2 | When /verify is invoked phase-scoped, does it run multi-agent code review on phase files only, or on the full diff from the branch's base? | Phase files only — keeps phase verify proportional. Final-verify at end of plan covers full-diff. |
| O3 | Should the Resume Report be written to a file (e.g., `{feature_folder}/execute/resume-<date>.md`) for audit, or stay chat-only? | Chat-only — log files already capture state. Report is derived. |
| O4 | If a plan has phases AND `--from T<N>` is passed, do we still run phase boundary checks for phases the user manually skipped past? | No — `--from` is a trust override. Resume from T<N>; phases entirely behind T<N> are treated as sealed for the resolver but no retroactive verify is run. |

---

## 9. Verification Plan

The skill changes are testable against a synthetic feature folder. Manual verification scenarios:

1. **Fresh start unchanged.** Empty `{feature_folder}/execute/`, run /execute → behaves identically to today.
2. **Single-session resume after manual interruption.** Run /execute, kill mid-T3, re-run /execute → Resume Report shows T1-T2 done, T3 in-flight, recommends resume from T3.
3. **Cross-session done-only resume.** Complete T1-T5 via simulated logs, edit logs to `done`, re-run /execute → Report shows all done, asks "re-run final verify?".
4. **Drift detection.** Mark T3 done with hash X, edit plan T3 goal, re-run → Report flags T3 as done-but-drifted, asks user.
5. **Phase boundary flow.** Plan with two phases of 3 tasks each. Complete phase 1 → Phase Boundary Check fires, /verify runs, phase-1.md written, compact instruction emitted. Re-run /execute → resolver sees sealed phase 1, recommends T4.
6. **Phase failure.** Same as #5 but force a /verify failure → phase-1.md written with `verify_status: failed`, no compact, escalation prose emitted.
7. **Multi-feature disambiguation.** Two features with in-flight logs in same repo, run /execute with no args → Phase 0.4 lists both.
8. **Worktree recreate.** Manually `git worktree remove` the branch's worktree, re-run /execute --resume → recreates worktree from branch.
9. **Plan-path mismatch (E15).** Logs reference `feature-A`, run /execute with `feature-B`'s plan path → refuses with clear error.

These map to plan tasks in the implementation plan (next stage).

---

## 10. Risks

| # | Risk | Mitigation |
|---|------|-----------|
| R1 | Hash function bikeshed (people add whitespace and trigger drift) | Normalize aggressively (lowercase, collapse whitespace). Document the normalization rule prominently in `_shared/execute-resume.md`. |
| R2 | Phase boundary verify is too slow → users avoid phases entirely | /plan guidance: "phases for plans >12 tasks; otherwise skip." Verify cost is the design's intent — accept it. |
| R3 | Resolver false-positives on `done-but-drifted` due to harmless plan edits | Hash only the `Goal:` line, not the full task body. Goal lines are short and stable; everything else is intentionally ignored. |
| R4 | `--from T<N>` becomes the path of least resistance and the resolver atrophies | Document `--from` as an escape hatch, not the default. No prominent placement. |
| R5 | Commit-message convention not followed by the user → git-log scan misses commits | Resolver treats this as "no commit-level info" and falls back to log-only classification. Worst case: in-flight detection is weaker. Not catastrophic. |
| R6 | Phase log written but compact-instruction ignored → context bloat continues | Out of scope — user controls compact. Document the cost in the boundary message. |

---

## 11. Out of Scope (Explicit)

- Auto-compact based on context-window monitoring.
- Phase-scoped lighter verify (any reduced /verify variant).
- Multi-branch resume (resuming across diverged branches).
- Resume across pmos-toolkit version upgrades (frontmatter schema migrations).
- A standalone `/execute resume-status` query command (could be added later if useful — not now).
- Visual UI for the Resume Report beyond the markdown table.
