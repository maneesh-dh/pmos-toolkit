---
tier: 2
type: enhancement
feature: execute-subagent-mode
date: 2026-05-13
status: Draft
skill_target: plugins/pmos-toolkit/skills/execute/
target_platform: generic
acceptance_criteria_ref: plugins/pmos-toolkit/skills/feature-sdlc/reference/skill-patterns.md §A–§F
---

# /execute — parallel subagent-driven execution mode — Requirements

## Problem

`/execute` today runs an implementation plan task-by-task as a single agent ("inline"
execution). It already has a "Subagent Execution (when Agent tool is available)" section,
but that path is (a) under-specified, (b) strictly *sequential* — one implementer subagent
at a time — and (c) not exposed as a deliberate user choice. There is no way to ask
`/execute` to fan independent tasks out across subagents in parallel, and there is no
self-contained, prescriptive recipe for the subagent + two-stage-review loop comparable to
the `superpowers:subagent-driven-development` skill.

We want `/execute` to be able to run a plan via **parallel subagent-driven development**:
a fresh implementer subagent per task, independent tasks dispatched concurrently in "waves",
each completed task put through a two-stage review (spec compliance → code quality), all
**encompassed inside `/execute` itself** — no runtime dependency on any external skill.

## Constraints (from the user, verbatim intent)

1. **No external-skill dependency.** All the subagent-driven logic — wave planning, prompt
   templates, review loop, failure handling — lives in `/execute`'s own directory
   (`SKILL.md` + at most one sibling reference file under `plugins/pmos-toolkit/skills/execute/`).
   `superpowers:subagent-driven-development` may be *referenced as inspiration* in prose, but
   `/execute` must function with it absent.
2. **Mode is a flag.** `/execute` gains `--subagent-driven` (and its explicit opposite
   `--inline`). Default behavior is unchanged (= inline). The flag selects the execution path.
3. **The choice is offered post-`/plan`.** After `/plan` finishes, the user is asked — with a
   one-line description of each option — whether they want subagent-driven or inline execution.
   `/plan` records the choice and emits the recommended `/execute …` invocation with the
   appropriate flag; under `/feature-sdlc` the orchestrator reads the recorded choice and
   passes the flag to its Phase 6 `/execute` call.

## Solution direction

### A. `/execute` — new `--subagent-driven` execution path

- New flags in `argument-hint`: `--subagent-driven` | `--inline` (mutually exclusive; last
  wins; absent ⇒ inline).
- A new section **"Phase 2 — execution strategy"** that branches: `inline` ⇒ today's
  per-task single-agent loop; `subagent-driven` ⇒ the parallel-wave loop below.
- **Wave planning.** Build a task DAG from each task's `**Depends on:**` and
  `**Requires state from:**` fields plus a *file-overlap* edge (two tasks whose `**Files:**`
  sets intersect are NOT parallel-eligible — concurrent edits/commits to the same file race).
  Topo-sort into waves: wave *k* = all not-yet-done tasks whose dependencies are all in waves
  `< k` and which are pairwise file-disjoint within the wave. Tasks with cycles or missing
  fields fall back to a singleton wave (sequential), with a logged note.
- **Per-wave loop.** For each wave: dispatch one implementer subagent per task **in parallel**
  (single message, multiple Agent calls — `superpowers:dispatching-parallel-agents` pattern,
  inlined). Implementer subagents implement + test but **do not commit** (the controller
  serializes commits post-wave to keep `T<N>` commit subjects and avoid `.git/index` races).
  When all wave subagents return: for each task, the controller commits the task's file-set
  with a `T<N>` subject, writes the `task-NN.md` log, then runs the **two-stage review**:
  (1) spec-compliance reviewer subagent; on ❌ → implementer fixes → re-review; then
  (2) code-quality reviewer subagent; on findings → implementer fixes → re-review. Only when
  both reviews are clean is the task marked `done`. Then move to wave *k+1*.
- **Implementer status handling** — DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED,
  handled per the `subagent-driven-development` contract (re-dispatch with context / more
  capable model / smaller split / escalate). Never retry the same model with no change.
- **Final review.** After the last wave, dispatch one whole-implementation reviewer subagent
  (same as today's Phase 4 spirit, but as a subagent).
- **Compatibility.** All existing `/execute` machinery is preserved in both modes: TDD per
  task, the 3-attempt verify-fix loop (now run *inside* each implementer subagent), the
  `task-NN.md` / `phase-N.md` logs and resume resolver, Phase 2.5 phase-boundary `/verify` +
  `--no-halt`/`continue_through_phases`, the runtime-evidence gate, `--restart`/`--resume`/
  `--from`. The resume resolver keys off `T<N>` commit subjects exactly as before — the
  controller still produces those.
- **Self-contained prompt templates.** Implementer / spec-reviewer / code-quality-reviewer /
  final-reviewer prompt templates live in a new `plugins/pmos-toolkit/skills/execute/subagent-driven.md`
  reference file (or inline in SKILL.md). No `../_shared/` or external-skill dependency for the
  subagent-driven path.
- **Platform adaptation.** When the Agent/subagent tool is unavailable (Codex, Gemini, no
  subagents), `--subagent-driven` degrades to a logged warning + inline execution — never an
  error.

### B. `/plan` — execution-mode selection at close

- In `/plan`'s closing phase, before the "closing offer", issue one `AskUserQuestion`:
  - **Inline execution (Recommended)** — "one agent works the plan task-by-task in this
    session; simplest, lowest token cost."
  - **Subagent-driven execution** — "a fresh subagent per task, independent tasks run in
    parallel waves, each task gets a spec + code-quality review; faster on wide plans, higher
    token cost."
- Record the choice as `execution_mode: inline | subagent-driven` in the plan doc frontmatter.
- The closing offer's `/execute` invocation string includes `--subagent-driven` when chosen
  (else no flag).
- Non-interactive: Recommended ⇒ `inline`.

### C. `/feature-sdlc` — Phase 6 honors the recorded mode

- Phase 6 (`/execute`) reads `execution_mode` from the `03_plan` frontmatter. If
  `subagent-driven` ⇒ append `--subagent-driven` to the `/execute` invocation. If absent
  (legacy plan) ⇒ no flag (inline), no prompt.

## Out of scope

- Multi-worktree-per-task isolation (one branch / one working tree is retained; parallelism is
  bounded by file-disjointness).
- Changing the resume-resolver contract, the plan/spec doc schemas beyond the additive
  `execution_mode` frontmatter key, or `/verify`.
- A standalone `/subagent-driven-development` skill in this repo.

## Users / journeys

- **PM-engineer running the pipeline** — finishes `/plan`, is asked once how to execute, picks
  subagent-driven for a 20-task plan, watches waves complete with reviews; or picks inline for
  a 3-task fix.
- **Engineer resuming** — `--resume` works identically; the resolver sees `T<N>` commits the
  controller produced; resumes at the first wave with an unfinished task.
- **Skill author on Codex** — `--subagent-driven` is accepted but logs "no subagents — running
  inline" and proceeds.

## Acceptance criteria

The change must conform to `skill-patterns.md §A–§F` (frontmatter, description/triggering,
structure/progressive disclosure, body/content, scripts/tooling, platform-conditional
frontmatter). Specifically: updated `argument-hint`; the new path documented with explicit
prompt templates and a deterministic wave algorithm; no dangling reference to a non-bundled
skill; `--subagent-driven` degradation documented; `/plan` + `/feature-sdlc` edits are
surgical and consistent with the rest of those skills.
