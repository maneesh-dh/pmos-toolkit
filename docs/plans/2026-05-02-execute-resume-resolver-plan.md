# /execute Resume Resolver + Phase Boundaries — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Date:** 2026-05-02
**Spec:** `docs/specs/2026-05-02-execute-resume-resolver-design.md`
**Plugin version target:** `pmos-toolkit` 2.13.0

---

## Overview

This plan implements a docs/skill-content change across 5 skill files plus 2 new shared protocol files plus 2 manifest version bumps. There is no application code, no schema, no API. The plan adapts the standard TDD task shape to skill-content work: each task ends with a **grep- or cat-based proof-of-life check** that the patch landed at the intended anchor with the expected content.

**Done when:**
- `_shared/execute-resume.md` exists with §5.3 + §5.4 + §5.5 sections from the spec
- `_shared/phase-boundary-handler.md` exists with §5.6 from the spec
- `execute/SKILL.md` contains: extended argument-hint, new Phase 0.4, Phase 0.5, Phase 1 resume-branching, T<N> commit convention, in-flight log lifecycle, Phase 2.5, two new anti-patterns
- `plan/SKILL.md` documents the optional `## Phase N` convention and adds the small-phase anti-pattern
- `verify/SKILL.md` documents the `--scope phase` invocation mode
- Both manifests bumped to `2.13.0`
- The §9 verification scenarios from the spec pass on a synthetic feature folder

**Execution order:**

```
T1 (write _shared/execute-resume.md)
T2 (write _shared/phase-boundary-handler.md)         [P with T1]
T3 (execute: argument-hint extension)
T4 (execute: insert Phase 0.4 + 0.5)
T5 (execute: Phase 1 resume-branching)
T6 (execute: Phase 2 step 6 + step 7 frontmatter)
T7 (execute: insert Phase 2.5)
T8 (execute: anti-patterns)
T9 (plan: Phase N template + guidance)               [P with T3-T8]
T10 (plan: anti-pattern)                             [seq after T9]
T11 (verify: --scope phase mode)                     [P with T3-T10]
T12 (bump manifests 2.13.0)
T13 (final verification: synthetic feature folder + grep audit)
```

T1, T2, T9, T11 are mutually independent (different files). T3–T8 all touch `execute/SKILL.md` and must be sequential to avoid Edit-anchor collisions. T9 and T10 both touch `plan/SKILL.md` (sequential). T13 must come last.

---

## Decision Log

> Inherits all decisions from the spec (§5 + §10). Plan-specific decisions made during code study below.

| # | Decision | Options | Rationale |
|---|----------|---------|-----------|
| P1 | Save plan to `docs/plans/2026-05-02-execute-resume-resolver-plan.md` | (a) flat `docs/plans/`, (b) feature-folder layout | (a). Repo's actual convention: `docs/plans/YYYY-MM-DD-<slug>-plan.md` matches the spec at `docs/specs/2026-05-02-execute-resume-resolver-design.md`. Same precedent as 9 other plan files. |
| P2 | TDD adaptation: each task uses **anchor-string Edit + grep verification** instead of pytest red/green | (a) grep verify, (b) Bats suite, (c) skip verification | (a). Skill content is markdown; "test fails first, then passes" maps to "grep returns 0 matches before, ≥1 after." A test framework for a 7-skill-file change is over-engineered. Same pattern as `2026-05-02-structured-ask-edge-cases-plan.md`. |
| P3 | Per-section atomic Edits on `execute/SKILL.md` (T3–T8) instead of one big rewrite | (a) atomic per-section, (b) one Write to overwrite | (a). Surgical anchors give per-task git diffs and easy rollback. The file is 263 lines with stable section anchors confirmed by code study. |
| P4 | Defer the Phase 2.5 verify subprocess invocation detail to the implementer | The spec §5.7 says /verify gets a `--scope phase` mode but doesn't specify how /execute *invokes* /verify (skill-call? subagent?) | The host skill harness has multiple ways to invoke another skill; the implementer picks the one that works in the current Claude Code version. Document the contract (inputs, outputs, evidence path), not the call mechanism. |
| P5 | Open Question O1 (compact hard-stop vs advisory) — implement **hard-stop** for v2.13.0 | (a) hard-stop, (b) advisory-continue | (a). Spec §10 names hard-stop as the default. Safer; user can always re-invoke immediately if they want to skip the compact. O1 stays open in the spec for future revisit. |

---

## Code Study Notes

Files read during code-study:

- **`plugins/pmos-toolkit/skills/execute/SKILL.md`** (263 lines)
  - Line 5: `argument-hint: "<path-to-plan-doc> [--feature <slug>] [--backlog <id>]"` — anchor for T3.
  - Lines 38–44: `## Phase 0: Load Workstream Context` (ends with the feature-folder resolution paragraph at line 42, separator `---` at line 44). Insertion point for T4 (Phase 0.4 + 0.5) is between line 44 and line 46 (`## Phase 1: Setup`).
  - Lines 46–72: `## Phase 1: Setup` — modified by T5 to branch on `resume_mode`.
  - Line 87: `6. **Commit** — small, focused commit per task. Not one giant commit at the end.` — anchor for T6 (commit-message convention).
  - Line 88: `7. **Write per-task log** to ...` — anchor for T6 (frontmatter + start-time write).
  - Lines 89–90: steps 8 + 9 of Phase 2 loop. Insertion point for T7 (Phase 2.5) is **after line 90 and before line 92** (`### Verify-Fix Loop (per task)`).
  - Line 255: `## Anti-Patterns (DO NOT)` — anchor for T8.

- **`plugins/pmos-toolkit/skills/plan/SKILL.md`** (456 lines)
  - Line 173: `## Tasks` — currently flat `### TN: ...` template starting line 175.
  - Line 263: `### Task Design Rules` — natural insertion point for the Phase-N convention guidance.
  - Line 440: `## Anti-Patterns (DO NOT)` — anchor for T10.

- **`plugins/pmos-toolkit/skills/verify/SKILL.md`** (509+ lines)
  - Line 5: argument-hint includes `--skip-design-drift`. T11 extends it with `--scope phase --feature <slug> --phase <N>`.
  - Line 73: `## Phase 1: Gather Context` — natural insertion point for documenting the new invocation mode (right after intake).

- **`plugins/pmos-toolkit/skills/_shared/`** — currently contains `feature-folder.md`, `interactive-prompts.md`, `structured-ask-edge-cases.md`. Pattern observed: H1 title with one-line callout, numbered steps, optional `## Consumers` footer listing consuming skills. T1 + T2 follow this pattern.

- **`plugins/pmos-toolkit/.claude-plugin/plugin.json`** — current version `2.11.0` (note: bumped to `2.12.0` in the in-flight `/grill` commit on this branch; T12 takes it to `2.13.0`). Same goes for `.codex-plugin/plugin.json`.

**Pattern observation:** every existing `_shared/` protocol file is consumed by its host skills via `relative-path` reference (e.g., `../../_shared/feature-folder.md`). T1 and T2 use the same form; T4 + T5 + T7 reference them via `../_shared/execute-resume.md` and `../_shared/phase-boundary-handler.md`.

**Constraint:** the `Edit` tool requires unique `old_string` matches. All identified anchors are unique by construction — section headings, version-string lines, and numbered-step prefixes ("6. **Commit**", "7. **Write per-task log**") are all globally unique within their files.

---

## Prerequisites

- Spec at `docs/specs/2026-05-02-execute-resume-resolver-design.md` exists (confirmed by §6 of the spec).
- Working tree on branch `main`. Current state: 1 untracked plan from prior work (`docs/plans/2026-04-23-verify-skill-teeth-plan.md`); this plan adds another untracked plan doc.
- The `/grill` skill commit on `main` (which bumped manifests to `2.12.0`) has landed — T12 takes both files from `2.12.0` → `2.13.0`. If `2.12.0` is not present, adjust T12 anchors accordingly.
- No in-flight `/execute` runs consuming the affected skills (skill-content change only; no runtime risk to current sessions, but new sessions will see the new behavior).

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `plugins/pmos-toolkit/skills/_shared/execute-resume.md` | Resolver protocol (parse plan + scan logs + classify tasks + git-log cross-check + Resume Report rendering + AskUserQuestion confirmation flow). Spec §5.3, §5.4, §5.5. |
| Create | `plugins/pmos-toolkit/skills/_shared/phase-boundary-handler.md` | Phase boundary handler (detect last-task-in-phase, invoke /verify with phase scope, write phase-N.md log, hard-stop on green for /compact). Spec §5.6. |
| Modify | `plugins/pmos-toolkit/skills/execute/SKILL.md` | Argument-hint, 3 new phases (0.4, 0.5, 2.5), Phase 1 branching, commit-message convention, log lifecycle, anti-patterns. |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` | Document optional `## Phase N` template + guidance. Add small-phase anti-pattern. |
| Modify | `plugins/pmos-toolkit/skills/verify/SKILL.md` | Document `--scope phase --feature <slug> --phase <N>` invocation mode + evidence path override. |
| Modify | `plugins/pmos-toolkit/.claude-plugin/plugin.json` | Bump to `2.13.0`. |
| Modify | `plugins/pmos-toolkit/.codex-plugin/plugin.json` | Bump to `2.13.0`. |

---

## Tasks

### T1: Write `_shared/execute-resume.md`

**Goal:** Create the resolver protocol document referenced by /execute Phase 0.4 + 0.5.

**Files:**
- Create: `plugins/pmos-toolkit/skills/_shared/execute-resume.md`

- [ ] **Step 1: Verify file does not yet exist (red phase).**

  Run: `test ! -e plugins/pmos-toolkit/skills/_shared/execute-resume.md && echo "OK: not found"`
  Expected: `OK: not found`

- [ ] **Step 2: Write the file.**

  Use the `Write` tool. Content (transcribed from spec §5.3 + §5.4 + §5.5 — full pseudocode, hash normalization rule, classification states, Resume Report markdown template, AskUserQuestion flow):

  ```markdown
  # Execute Resume Resolver — Shared Protocol

  Single source of truth for the /execute resume resolution algorithm. Consumed by `execute/SKILL.md` Phase 0.4 (Feature Disambiguation) and Phase 0.5 (Resume Resolution). See spec `docs/specs/2026-05-02-execute-resume-resolver-design.md` for design rationale.

  ## Hash Normalization Rule

  All `task_goal_hash` and `plan_phase_hash` values use the same normalization to keep them stable under cosmetic edits:

  1. Trim leading and trailing whitespace.
  2. Collapse all internal whitespace runs (including newlines) to a single space.
  3. Lowercase.
  4. SHA-256, hex-encoded.

  Document this rule prominently — silent hash drift from inconsistent normalization is a top spec risk (R1).

  ## Phase 0.4: Feature Disambiguation

  [Pseudocode + step-by-step from spec §5.4. Keep the pseudocode block verbatim. Add a "Consumers" footer listing `execute/SKILL.md`.]

  ## Phase 0.5: Resume Resolution

  [Pseudocode + step-by-step from spec §5.3. Include the 5-state classification table — `not-started`, `done`, `done-sealed`, `done-but-drifted`, `in-flight`, `failed`, plus the `-with-commits` annotations from the git-log cross-check.]

  ## Resume Report Rendering

  [Markdown table template from spec §5.5 + AskUserQuestion option list, including the destructive-confirmation requirement on Restart.]

  ## Edge Cases

  [Reference to spec §7 table E1–E16. Inline the most-important 6 (E3, E4, E6, E8, E10, E15) so implementers do not need to flip back to the spec.]

  ## Consumers

  - `plugins/pmos-toolkit/skills/execute/SKILL.md` — Phase 0.4 + Phase 0.5
  ```

  Write the actual content (not the bracketed placeholders) by transcribing from the spec verbatim. Length target: 200–280 lines.

- [ ] **Step 3: Verify file exists with required sections (green phase).**

  Run:
  ```bash
  grep -cE "^## (Hash Normalization Rule|Phase 0\.4|Phase 0\.5|Resume Report Rendering|Edge Cases|Consumers)" plugins/pmos-toolkit/skills/_shared/execute-resume.md
  ```
  Expected: `6`

- [ ] **Step 4: Verify pseudocode blocks present.**

  Run:
  ```bash
  grep -cE "^function (resolve_resume|disambiguate_feature)" plugins/pmos-toolkit/skills/_shared/execute-resume.md
  ```
  Expected: `2`

- [ ] **Step 5: Commit.**

  ```bash
  git add plugins/pmos-toolkit/skills/_shared/execute-resume.md
  git commit -m "feat(_shared): T1 add execute-resume resolver protocol"
  ```

---

### T2: Write `_shared/phase-boundary-handler.md`

**Goal:** Create the phase-boundary-handler protocol document referenced by /execute Phase 2.5.

**Files:**
- Create: `plugins/pmos-toolkit/skills/_shared/phase-boundary-handler.md`

- [ ] **Step 1: Verify file does not yet exist.**

  Run: `test ! -e plugins/pmos-toolkit/skills/_shared/phase-boundary-handler.md && echo "OK: not found"`
  Expected: `OK: not found`

- [ ] **Step 2: Write the file.**

  Use the `Write` tool. Content (transcribed from spec §5.6 verbatim):

  ```markdown
  # Phase Boundary Handler — Shared Protocol

  Invoked from `execute/SKILL.md` Phase 2.5 after each task's `done` log is written. See spec `docs/specs/2026-05-02-execute-resume-resolver-design.md` §5.6.

  ## When to Fire

  After step 9 of /execute Phase 2 (task fully done, log status=done written). Skip if:
  - The plan has no `## Phase N` headings (flat plan).
  - The just-completed task is not the last task in its phase.

  ## Algorithm

  ```
  function handle_phase_boundary(completed_task, plan, feature_folder):
      phase = plan.phase_containing(completed_task.number)
      if phase is None: return CONTINUE
      if completed_task.number != phase.task_numbers[-1]: return CONTINUE

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
          return ESCALATE(verify_result.failures)

      # 3. Hard-stop and instruct user to /compact + re-invoke
      return HALT_FOR_COMPACT(
          message = f"Phase {phase.number} verified green. "
                    f"Run `/compact` to clear context, then re-invoke "
                    f"`/execute --resume` to continue with phase {phase.number + 1}."
      )
  ```

  ## Phase Log Frontmatter

  [Transcribe spec §5.2 frontmatter block verbatim including the `## Verify Summary` body section.]

  ## Verify Invocation Contract

  How /execute invokes /verify is left to the implementer (skill-call vs subagent vs other harness mechanism). The contract is fixed:

  | Input | Value |
  |-------|-------|
  | scope | `"phase"` |
  | feature | feature folder path |
  | phase_number | integer |
  | evidence_dir | `{feature_folder}/verify/{YYYY-MM-DD}-phase-{N}/` |

  | Output | Type |
  |--------|------|
  | ok | bool |
  | evidence_dir | path (echo of input) |
  | failures | list of failure descriptors (when ok == false) |

  ## Compact Behavior

  Default (per spec O1): hard-stop. Skill emits the HALT_FOR_COMPACT message and ends the /execute turn. The user runs `/compact`, then re-invokes `/execute --resume`. The resolver picks up at the next phase's first task by reading the freshly-written `phase-N.md`.

  ## Consumers

  - `plugins/pmos-toolkit/skills/execute/SKILL.md` — Phase 2.5
  ```

  Length target: 100–150 lines.

- [ ] **Step 3: Verify required sections.**

  Run:
  ```bash
  grep -cE "^## (When to Fire|Algorithm|Phase Log Frontmatter|Verify Invocation Contract|Compact Behavior|Consumers)" plugins/pmos-toolkit/skills/_shared/phase-boundary-handler.md
  ```
  Expected: `6`

- [ ] **Step 4: Verify pseudocode + halt sentinel present.**

  Run:
  ```bash
  grep -cE "HALT_FOR_COMPACT|handle_phase_boundary" plugins/pmos-toolkit/skills/_shared/phase-boundary-handler.md
  ```
  Expected: `>= 2`

- [ ] **Step 5: Commit.**

  ```bash
  git add plugins/pmos-toolkit/skills/_shared/phase-boundary-handler.md
  git commit -m "feat(_shared): T2 add phase-boundary-handler protocol"
  ```

---

### T3: execute/SKILL.md — extend argument-hint

**Goal:** Add `--resume | --restart | --from T<N>` to the argument-hint.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/execute/SKILL.md:5`

- [ ] **Step 1: Confirm anchor is unchanged (red phase).**

  Run:
  ```bash
  grep -c '^argument-hint: "<path-to-plan-doc> \[--feature <slug>\] \[--backlog <id>\]"$' plugins/pmos-toolkit/skills/execute/SKILL.md
  ```
  Expected: `1`

- [ ] **Step 2: Edit the line.**

  Use the `Edit` tool:
  - `old_string`: `argument-hint: "<path-to-plan-doc> [--feature <slug>] [--backlog <id>]"`
  - `new_string`: `argument-hint: "<path-to-plan-doc> [--feature <slug>] [--backlog <id>] [--resume | --restart | --from T<N>]"`

- [ ] **Step 3: Verify (green).**

  Run:
  ```bash
  grep -c -- '--resume | --restart | --from T<N>' plugins/pmos-toolkit/skills/execute/SKILL.md
  ```
  Expected: `1`

- [ ] **Step 4: Commit.**

  ```bash
  git add plugins/pmos-toolkit/skills/execute/SKILL.md
  git commit -m "feat(execute): T3 extend argument-hint with resume flags"
  ```

---

### T4: execute/SKILL.md — insert Phase 0.4 + Phase 0.5

**Goal:** Add Phase 0.4 (Feature Disambiguation) and Phase 0.5 (Resume Resolution) between Phase 0 and Phase 1.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/execute/SKILL.md` — insert after line 44 (the `---` separator after Phase 0).

- [ ] **Step 1: Confirm anchor.**

  Run:
  ```bash
  awk 'NR==42,NR==46' plugins/pmos-toolkit/skills/execute/SKILL.md
  ```
  Expected (line 42 ends Phase 0, line 44 is `---`, line 46 is `## Phase 1: Setup`).

- [ ] **Step 2: Edit — insert two new phases.**

  Use the `Edit` tool:
  - `old_string`:
    ```
    **Resolve feature folder.** Follow `../_shared/feature-folder.md` with `skill_name=execute`, `feature_arg=<--feature value or empty>`, and `feature_hint=<topic if provided>`. Use the returned folder path as `{feature_folder}`. This skill consumes `03_plan.md` (via resolve-input.md) and writes per-task logs under `{feature_folder}/execute/`.

    ---

    ## Phase 1: Setup
    ```
  - `new_string`:
    ```
    **Resolve feature folder.** Follow `../_shared/feature-folder.md` with `skill_name=execute`, `feature_arg=<--feature value or empty>`, and `feature_hint=<topic if provided>`. Use the returned folder path as `{feature_folder}`. This skill consumes `03_plan.md` (via resolve-input.md) and writes per-task logs under `{feature_folder}/execute/`.

    ---

    ## Phase 0.4: Feature Disambiguation

    If no `<path-to-plan-doc>` and no `--feature` were provided, follow `../_shared/execute-resume.md` Phase 0.4 to scan the repo for in-flight features (folders under `{docs_path}/` with non-`done` task logs in their `execute/` subdir). If multiple candidates exist, present them via `AskUserQuestion` and let the user pick. If exactly one, use it. If none, error out — there is nothing to resume and no plan to execute.

    Skip this phase entirely if `--restart` was passed (user explicitly wants a fresh start) or if the plan path was given (no ambiguity).

    ---

    ## Phase 0.5: Resume Resolution

    Follow `../_shared/execute-resume.md` Phase 0.5 to:

    1. Parse the plan, extract `[T1...TN]` with their `Goal:` lines and any `## Phase N` groupings.
    2. Scan `{feature_folder}/execute/task-*.md` and `phase-*.md`, parse frontmatter.
    3. Classify each task: `not-started` | `done` | `done-sealed` | `done-but-drifted` | `in-flight` | `failed`, plus `-with-commits` annotation from the git-log cross-check.
    4. Pick the resume point: lowest-N task whose state is not `done` and not `done-sealed`.
    5. Check worktree liveness — present, recreate-from-branch, or fresh-start.
    6. Render the **Resume Report** to chat (markdown table from `../_shared/execute-resume.md` "Resume Report Rendering"), then confirm via `AskUserQuestion` (Resume / Restart task / Jump to specific / Restart from T1 / Cancel).
    7. Set `resume_mode = (mode, resume_task_index)` for Phase 1.

    **Skip this phase entirely** if `--restart` was passed, or if no logs exist under `{feature_folder}/execute/` (fresh execution). If `--from T<N>` was passed, skip the resolver and set `resume_mode = ("manual", N)` directly. If `--resume` was passed, force this phase even if the resolver would otherwise skip.

    ---

    ## Phase 1: Setup
    ```

- [ ] **Step 3: Verify both phases inserted.**

  Run:
  ```bash
  grep -cE "^## Phase 0\.(4|5):" plugins/pmos-toolkit/skills/execute/SKILL.md
  ```
  Expected: `2`

- [ ] **Step 4: Verify the references to the shared file.**

  Run:
  ```bash
  grep -c '_shared/execute-resume.md' plugins/pmos-toolkit/skills/execute/SKILL.md
  ```
  Expected: `>= 2`

- [ ] **Step 5: Commit.**

  ```bash
  git add plugins/pmos-toolkit/skills/execute/SKILL.md
  git commit -m "feat(execute): T4 add Phase 0.4 (Feature Disambiguation) and Phase 0.5 (Resume Resolution)"
  ```

---

### T5: execute/SKILL.md — Phase 1 resume-branching

**Goal:** Make Phase 1 branch on `resume_mode`. If resuming, skip worktree creation + baseline test run.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/execute/SKILL.md` — Phase 1 (lines 46–72).

- [ ] **Step 1: Confirm anchor.**

  Run:
  ```bash
  sed -n '46,49p' plugins/pmos-toolkit/skills/execute/SKILL.md
  ```
  Expected: Phase 1 header + opening sentence.

- [ ] **Step 2: Edit — add a branching preamble at the top of Phase 1.**

  Use the `Edit` tool:
  - `old_string`:
    ```
    ## Phase 1: Setup

    1. **Locate the plan.** Follow `../.shared/resolve-input.md` with `phase=plan`, `label="plan"`.
    ```
  - `new_string`:
    ```
    ## Phase 1: Setup

    **Branch on `resume_mode` from Phase 0.5:**
    - **Fresh start** (`resume_mode` unset, or mode == `"restart"`): run all steps below.
    - **Resume** (mode in `{"resume", "manual"}`): skip steps 3, 4, and the baseline test run inside step 3. Worktree must be present (Phase 0.5 verified or recreated it). Cd into the worktree from the previous session's logs (`worktree_path` field). Skip directly to step 5 (verify verification tooling) — it must re-run, since dev servers / Playwright / type-checkers may not be running in this fresh shell.

    1. **Locate the plan.** Follow `../.shared/resolve-input.md` with `phase=plan`, `label="plan"`.
    ```

- [ ] **Step 3: Verify branching preamble.**

  Run:
  ```bash
  grep -c "Branch on .resume_mode. from Phase 0\.5" plugins/pmos-toolkit/skills/execute/SKILL.md
  ```
  Expected: `1`

- [ ] **Step 4: Commit.**

  ```bash
  git add plugins/pmos-toolkit/skills/execute/SKILL.md
  git commit -m "feat(execute): T5 add Phase 1 resume-mode branching"
  ```

---

### T6: execute/SKILL.md — commit message convention + log frontmatter lifecycle

**Goal:** (a) Codify `T<N>` in commit messages; (b) write log on task **start** with `status: in-flight`, update to `done` on completion; (c) document the new frontmatter shape.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/execute/SKILL.md:87` (step 6) and `:88` (step 7).

- [ ] **Step 1: Confirm anchors.**

  Run:
  ```bash
  sed -n '87,88p' plugins/pmos-toolkit/skills/execute/SKILL.md
  ```
  Expected: lines 87 (Commit) and 88 (Write per-task log).

- [ ] **Step 2: Edit step 6 (commit message convention).**

  Use the `Edit` tool:
  - `old_string`: `6. **Commit** — small, focused commit per task. Not one giant commit at the end.`
  - `new_string`: `6. **Commit** — small, focused commit per task. Not one giant commit at the end. **Commit subject MUST contain the task number in the form `T<N>`** (e.g., `feat(T5): add SOP migration` or `T5: add SOP migration`). The Phase 0.5 resolver greps `\bT[0-9]+\b` from `git log` to detect mid-task interruption — without `T<N>` in the subject, in-flight detection degrades.`

- [ ] **Step 3: Edit step 7 (log lifecycle + frontmatter).**

  Use the `Edit` tool:
  - `old_string`: `7. **Write per-task log** to `{feature_folder}/execute/task-{NN}.md` where `NN` matches the task number from the plan (zero-padded 2 digits, e.g. `task-01.md`, `task-12.md`). Capture: task name/number, files touched, key decisions, deviations, runtime evidence, and verification outcome. Overwrite if a re-run hits the same task.`
  - `new_string`:
    ````
    7. **Maintain the per-task log** at `{feature_folder}/execute/task-{NN}.md` (zero-padded 2 digits). The log has a structured frontmatter and a free-form body. Lifecycle:

       - **At task start** (before TDD work begins): write the file with `status: in-flight`, populated frontmatter (see schema below), and an empty body. This is the "in-flight marker" that resume detects if the session crashes.
       - **As files are touched:** append paths to `files_touched` in the frontmatter (used by phase-scoped /verify in Phase 2.5).
       - **At task completion** (verify-fix loop passed AND runtime evidence produced): update `status: done`, set `completed_at`, and write the body (key decisions, deviations, runtime evidence, verification outcome).
       - **At task failure** (3-attempt budget exhausted): update `status: failed`, set `completed_at`, write the body with the failure mode.

       **Frontmatter schema:**

       ```yaml
       ---
       task_number: 5
       task_name: "Add SOP migration"
       task_goal_hash: <sha256 of plan T<N> Goal: line, normalized — see _shared/execute-resume.md "Hash Normalization Rule">
       plan_path: "{feature_folder}/03_plan.md"
       branch: "feature/sop-editor"
       worktree_path: ".worktrees/sop-editor"
       status: in-flight | done | failed
       started_at: 2026-05-02T14:32:11Z
       completed_at: 2026-05-02T14:48:30Z   # only when status != in-flight
       files_touched:
         - src/sop/migrations/0042_add_remediation.py
         - tests/sop/test_migration_0042.py
       ---
       ```

       Overwrite the file's body on a re-run; preserve `started_at` from the first attempt.
    ````

- [ ] **Step 4: Verify the changes.**

  Run:
  ```bash
  grep -c "Commit subject MUST contain the task number" plugins/pmos-toolkit/skills/execute/SKILL.md
  ```
  Expected: `1`
  Run:
  ```bash
  grep -c "task_goal_hash:" plugins/pmos-toolkit/skills/execute/SKILL.md
  ```
  Expected: `1`
  Run:
  ```bash
  grep -c "in-flight marker" plugins/pmos-toolkit/skills/execute/SKILL.md
  ```
  Expected: `1`

- [ ] **Step 5: Commit.**

  ```bash
  git add plugins/pmos-toolkit/skills/execute/SKILL.md
  git commit -m "feat(execute): T6 add T<N> commit convention and in-flight log lifecycle"
  ```

---

### T7: execute/SKILL.md — insert Phase 2.5 (Phase Boundary Check)

**Goal:** Add Phase 2.5 between Phase 2's task loop (ends step 9, line 90) and the Verify-Fix Loop subsection (line 92).

**Files:**
- Modify: `plugins/pmos-toolkit/skills/execute/SKILL.md` — insert after line 90.

- [ ] **Step 1: Confirm anchor.**

  Run:
  ```bash
  sed -n '90,92p' plugins/pmos-toolkit/skills/execute/SKILL.md
  ```
  Expected: line 90 = step 9 of the loop, line 92 = `### Verify-Fix Loop (per task)`.

- [ ] **Step 2: Edit — insert Phase 2.5.**

  Use the `Edit` tool:
  - `old_string`:
    ```
    9. **Move to next task** — only after verification passes, evidence is produced, and task is marked complete.

    ### Verify-Fix Loop (per task)
    ```
  - `new_string`:
    ```
    9. **Move to next task** — only after verification passes, evidence is produced, and task is marked complete. Before moving on, run **Phase 2.5: Phase Boundary Check** (below) — it may halt the session.

    ### Phase 2.5: Phase Boundary Check

    Skip this phase entirely if the plan has no `## Phase N` headings (flat plan). Otherwise, after each task's done-log is written, follow `../_shared/phase-boundary-handler.md`:

    1. Determine whether the just-completed task is the last in its `## Phase N` group.
    2. If yes: invoke /verify with `--scope phase --feature <slug> --phase <N>` (see `verify/SKILL.md` for the invocation contract). Evidence is written to `{feature_folder}/verify/<YYYY-MM-DD>-phase-<N>/`.
    3. Write `{feature_folder}/execute/phase-N.md` with the phase log frontmatter (schema in `_shared/phase-boundary-handler.md`).
    4. **If verify failed:** do NOT compact, do NOT continue. Escalate to the user with the failure summary. The phase-N.md log is left with `verify_status: failed` so the next session's resolver can pick up at the failed task.
    5. **If verify passed:** emit the `HALT_FOR_COMPACT` message ("Phase N verified green. Run `/compact` to clear context, then re-invoke `/execute --resume` to continue with phase N+1.") and end the /execute turn. The resolver in the next session sees the sealed phase log and picks up at the next phase's first task.

    This is a hard-stop on green by design (spec O1 default). The user can re-invoke immediately if they want to skip the compact.

    ### Verify-Fix Loop (per task)
    ```

- [ ] **Step 3: Verify Phase 2.5 inserted.**

  Run:
  ```bash
  grep -c "^### Phase 2\.5: Phase Boundary Check" plugins/pmos-toolkit/skills/execute/SKILL.md
  ```
  Expected: `1`

- [ ] **Step 4: Verify the shared-file reference.**

  Run:
  ```bash
  grep -c '_shared/phase-boundary-handler.md' plugins/pmos-toolkit/skills/execute/SKILL.md
  ```
  Expected: `1`

- [ ] **Step 5: Commit.**

  ```bash
  git add plugins/pmos-toolkit/skills/execute/SKILL.md
  git commit -m "feat(execute): T7 add Phase 2.5 phase-boundary check"
  ```

---

### T8: execute/SKILL.md — anti-patterns additions

**Goal:** Add two new anti-pattern bullets.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/execute/SKILL.md:255+` (Anti-Patterns section).

- [ ] **Step 1: Confirm anchor (the last existing anti-pattern bullet).**

  Run:
  ```bash
  grep -n "Do NOT stop at the first passing test run" plugins/pmos-toolkit/skills/execute/SKILL.md
  ```
  Expected: one match.

- [ ] **Step 2: Edit — append two new bullets.**

  Use the `Edit` tool:
  - `old_string`: `- Do NOT stop at the first passing test run — re-read the spec for completeness`
  - `new_string`:
    ```
    - Do NOT stop at the first passing test run — re-read the spec for completeness
    - Do NOT silently re-do tasks marked `done` in `task-NN.md` without checking the `task_goal_hash` against the current plan — drift detection exists for a reason; surface `done-but-drifted` to the user instead of either skipping or quietly redoing
    - Do NOT skip the Phase 2.5 Phase Boundary Check when the plan has `## Phase N` headings — full /verify at boundaries is the design's purpose; suppressing it defeats the cross-session compact handshake
    ```

- [ ] **Step 3: Verify both new anti-patterns present.**

  Run:
  ```bash
  grep -cE "(silently re-do tasks marked|skip the Phase 2\.5 Phase Boundary Check)" plugins/pmos-toolkit/skills/execute/SKILL.md
  ```
  Expected: `2`

- [ ] **Step 4: Commit.**

  ```bash
  git add plugins/pmos-toolkit/skills/execute/SKILL.md
  git commit -m "feat(execute): T8 add resume + phase-boundary anti-patterns"
  ```

---

### T9: plan/SKILL.md — optional `## Phase N` template + guidance

**Goal:** Document the optional phase-grouping convention in /plan's Phase 3 template area, with explicit guidance on when to use it.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/plan/SKILL.md` — insert in the `### Task Design Rules` section starting at line 263.

- [ ] **Step 1: Confirm anchor.**

  Run:
  ```bash
  grep -n "^### Task Design Rules$" plugins/pmos-toolkit/skills/plan/SKILL.md
  ```
  Expected: one match at line 263.

- [ ] **Step 2: Edit — append a new subsection below `### Task Design Rules`.**

  Use the `Edit` tool. Anchor on the existing subsection heading:
  - `old_string`: `### Task Design Rules`
  - `new_string`:
    ````
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
    ````

- [ ] **Step 3: Verify the new subsection.**

  Run:
  ```bash
  grep -c "^#### Optional: .## Phase N. Groupings" plugins/pmos-toolkit/skills/plan/SKILL.md
  ```
  Expected: `1`
  Run:
  ```bash
  grep -c "deployable slice" plugins/pmos-toolkit/skills/plan/SKILL.md
  ```
  Expected: `>= 1`

- [ ] **Step 4: Commit.**

  ```bash
  git add plugins/pmos-toolkit/skills/plan/SKILL.md
  git commit -m "feat(plan): T9 document optional ## Phase N grouping convention"
  ```

---

### T10: plan/SKILL.md — anti-pattern: tiny phases

**Goal:** Add an anti-pattern warning against 1–2 task phases.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/plan/SKILL.md:440+` (Anti-Patterns).

- [ ] **Step 1: Confirm anchor (last existing anti-pattern in plan/SKILL.md).**

  Run:
  ```bash
  tail -30 plugins/pmos-toolkit/skills/plan/SKILL.md | grep "^- Do NOT"
  ```
  Expected: at least one bullet (use the last one as the anchor).

- [ ] **Step 2: Edit — find the last `- Do NOT` bullet in the Anti-Patterns section and append the new one after it.**

  Read the last anti-pattern line first:
  ```bash
  awk '/^## Anti-Patterns/,0' plugins/pmos-toolkit/skills/plan/SKILL.md | tail -10
  ```
  Then use `Edit` with the exact last-bullet text as `old_string` and append:
  ```
  - Do NOT create `## Phase N` groupings of 1–2 tasks — each phase boundary triggers full /verify (multi-agent code review + interactive QA), which dwarfs the implementation cost of a tiny phase. Target 5–10 tasks per phase, or skip phases entirely for small plans.
  ```

- [ ] **Step 3: Verify.**

  Run:
  ```bash
  grep -c 'Do NOT create .## Phase N. groupings of 1' plugins/pmos-toolkit/skills/plan/SKILL.md
  ```
  Expected: `1`

- [ ] **Step 4: Commit.**

  ```bash
  git add plugins/pmos-toolkit/skills/plan/SKILL.md
  git commit -m "feat(plan): T10 add tiny-phase anti-pattern"
  ```

---

### T11: verify/SKILL.md — document `--scope phase` invocation mode

**Goal:** Extend argument-hint and document the phase-scoped invocation mode (called from /execute Phase 2.5).

**Files:**
- Modify: `plugins/pmos-toolkit/skills/verify/SKILL.md:5` (argument-hint) and `:73+` (Phase 1 area).

- [ ] **Step 1: Confirm anchors.**

  Run:
  ```bash
  sed -n '5p;73p' plugins/pmos-toolkit/skills/verify/SKILL.md
  ```
  Expected: line 5 = argument-hint, line 73 = `## Phase 1: Gather Context`.

- [ ] **Step 2: Edit argument-hint.**

  Use the `Edit` tool:
  - `old_string`: `argument-hint: "<path-to-spec-doc> (optional — will search {docs_path}/specs/ if omitted) [--feature <slug>] [--backlog <id>] [--skip-design-drift]"`
  - `new_string`: `argument-hint: "<path-to-spec-doc> (optional — will search {docs_path}/specs/ if omitted) [--feature <slug>] [--backlog <id>] [--skip-design-drift] [--scope phase --phase <N>]"`

- [ ] **Step 3: Insert a new subsection at the top of Phase 1 documenting the phase-scoped mode.**

  Use the `Edit` tool. Anchor on the Phase 1 heading:
  - `old_string`: `## Phase 1: Gather Context`
  - `new_string`:
    ```
    ## Phase 1: Gather Context

    ### Invocation Mode: Phase-Scoped (called from /execute)

    When invoked with `--scope phase --feature <slug> --phase <N>`, /verify runs the full checklist (Phases 2–7) but with two changes:

    1. **Changed-files set is restricted to files touched by tasks in the named phase only.** Read `{feature_folder}/execute/task-NN.md` for each `T<N>` listed in the plan's `## Phase <N>` group; union their `files_touched` frontmatter lists.
    2. **Evidence path is `{feature_folder}/verify/<YYYY-MM-DD>-phase-<N>/`** (not the default `{feature_folder}/verify/<YYYY-MM-DD>/`). Multiple phase-verify runs on the same day are namespaced by phase number, so they do not collide.

    On completion, return a structured pass/fail result to the calling skill (/execute Phase 2.5):
    - `ok: true|false`
    - `evidence_dir: <path>`
    - `failures: [...]` (when `ok == false`)

    All other Phase 1+ behavior is unchanged. Standalone /verify invocations (without `--scope phase`) work exactly as before.
    ```

- [ ] **Step 4: Verify both edits.**

  Run:
  ```bash
  grep -c '\-\-scope phase' plugins/pmos-toolkit/skills/verify/SKILL.md
  ```
  Expected: `>= 2`
  Run:
  ```bash
  grep -c "^### Invocation Mode: Phase-Scoped" plugins/pmos-toolkit/skills/verify/SKILL.md
  ```
  Expected: `1`

- [ ] **Step 5: Commit.**

  ```bash
  git add plugins/pmos-toolkit/skills/verify/SKILL.md
  git commit -m "feat(verify): T11 document --scope phase invocation mode"
  ```

---

### T12: Bump manifests to 2.13.0

**Goal:** Bump both Claude and Codex plugin manifests.

**Files:**
- Modify: `plugins/pmos-toolkit/.claude-plugin/plugin.json:3`
- Modify: `plugins/pmos-toolkit/.codex-plugin/plugin.json:3`

- [ ] **Step 1: Confirm both files are at 2.12.0.**

  Run:
  ```bash
  grep -c '"version": "2\.12\.0"' plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json
  ```
  Expected (combined output): each file shows `1`.

- [ ] **Step 2: Edit Claude manifest.**

  Use the `Edit` tool on `plugins/pmos-toolkit/.claude-plugin/plugin.json`:
  - `old_string`: `"version": "2.12.0",`
  - `new_string`: `"version": "2.13.0",`

- [ ] **Step 3: Edit Codex manifest.**

  Use the `Edit` tool on `plugins/pmos-toolkit/.codex-plugin/plugin.json`:
  - `old_string`: `"version": "2.12.0",`
  - `new_string`: `"version": "2.13.0",`

- [ ] **Step 4: Verify.**

  Run:
  ```bash
  grep -c '"version": "2\.13\.0"' plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json
  ```
  Expected: each shows `1`.

- [ ] **Step 5: Commit.**

  ```bash
  git add plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json
  git commit -m "chore(pmos-toolkit): T12 bump to 2.13.0 — execute resume resolver"
  ```

---

### T13: Final Verification

**Goal:** Prove the full set of changes landed and run the §9 spec verification scenarios.

**Files:**
- Read-only verification.

- [ ] **Step 1: Structural audit — all required new sections / files present.**

  Run:
  ```bash
  test -f plugins/pmos-toolkit/skills/_shared/execute-resume.md && echo "OK: execute-resume.md"
  test -f plugins/pmos-toolkit/skills/_shared/phase-boundary-handler.md && echo "OK: phase-boundary-handler.md"
  grep -cE '^## Phase 0\.(4|5):' plugins/pmos-toolkit/skills/execute/SKILL.md   # expect 2
  grep -c '^### Phase 2\.5: Phase Boundary Check' plugins/pmos-toolkit/skills/execute/SKILL.md  # expect 1
  grep -c "Branch on .resume_mode. from Phase 0\.5" plugins/pmos-toolkit/skills/execute/SKILL.md  # expect 1
  grep -c 'task_goal_hash:' plugins/pmos-toolkit/skills/execute/SKILL.md  # expect 1
  grep -c '#### Optional: .## Phase N. Groupings' plugins/pmos-toolkit/skills/plan/SKILL.md  # expect 1
  grep -c '^### Invocation Mode: Phase-Scoped' plugins/pmos-toolkit/skills/verify/SKILL.md  # expect 1
  grep -c '"version": "2\.13\.0"' plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json  # expect 1 per file
  ```

  All checks must pass. If any fail, fix the corresponding task before proceeding.

- [ ] **Step 2: Cross-reference audit — `_shared/` references are reachable.**

  Run:
  ```bash
  for ref in $(grep -oE '_shared/(execute-resume|phase-boundary-handler)\.md' plugins/pmos-toolkit/skills/execute/SKILL.md | sort -u); do
    test -f "plugins/pmos-toolkit/skills/$ref" && echo "OK: $ref" || echo "BROKEN: $ref"
  done
  ```
  Expected: all `OK`, no `BROKEN`.

- [ ] **Step 3: Synthetic feature folder smoke test (spec §9 scenario 1 — fresh start unchanged).**

  Create an empty test feature folder and verify /execute would behave identically to today:
  ```bash
  TMPDIR=$(mktemp -d)
  mkdir -p "$TMPDIR/execute"
  ls "$TMPDIR/execute"  # expected: empty
  ```
  Inspect Phase 0.5 in the updated `execute/SKILL.md`: confirm the prose says "Skip this phase entirely if no logs exist under `{feature_folder}/execute/`". This is the contract.

- [ ] **Step 4: Synthetic feature folder smoke test (§9 scenario 4 — drift detection).**

  Inspect `_shared/execute-resume.md` Phase 0.5 pseudocode: confirm classification logic includes `done-but-drifted` and the hash comparison branch. This is a doc-level proof; runtime behavior is exercised the first time a real /execute session runs.

- [ ] **Step 5: Manifest sanity check.**

  Run:
  ```bash
  python3 -c "import json; [print(f'{f}: {json.load(open(f))[\"version\"]}') for f in ['plugins/pmos-toolkit/.claude-plugin/plugin.json', 'plugins/pmos-toolkit/.codex-plugin/plugin.json']]"
  ```
  Expected:
  ```
  plugins/pmos-toolkit/.claude-plugin/plugin.json: 2.13.0
  plugins/pmos-toolkit/.codex-plugin/plugin.json: 2.13.0
  ```

- [ ] **Step 6: Final summary.**

  Report to the user:
  - Files created: 2 (`_shared/execute-resume.md`, `_shared/phase-boundary-handler.md`)
  - Files modified: 5 (`execute/SKILL.md`, `plan/SKILL.md`, `verify/SKILL.md`, both manifests)
  - Tasks completed: T1–T12
  - Verification scenarios from spec §9: structural audit passed; runtime scenarios (1–9) deferred to first real /execute session post-merge — no live test feature folder exists in this repo.
  - Open questions remaining (from spec §10): O1 (compact hard-stop default — implemented; revisit after first real-world use), O2 (phase verify code-review scope — implemented as phase-files-only per spec default), O3 (Resume Report file vs chat — chat-only per spec default), O4 (`--from T<N>` skipping phase checks — implemented per spec default).

- [ ] **Step 7: No commit needed for verification-only step.** All commits already landed in T1–T12.

---

## Done When

- All 12 implementation tasks (T1–T12) committed.
- T13 structural audit passes 9/9 grep checks.
- Both manifests at `2.13.0`.
- Anti-pattern bullets, new phases, and shared protocol files all present at their named anchors.
- No regressions in the existing `/execute` flow — the plan is purely additive (new phases inserted, existing phases extended with branches, no existing behavior removed).
