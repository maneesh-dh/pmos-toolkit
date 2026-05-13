---
tier: 2
type: enhancement
feature: execute-subagent-mode
date: 2026-05-13
status: Draft
requirements_ref: 01_requirements.md
---

# /execute — parallel subagent-driven execution mode — Technical Spec

Scope: edits to three SKILL.md files + one new reference file. No new schema, no code.
Acceptance baseline: `plugins/pmos-toolkit/skills/feature-sdlc/reference/skill-patterns.md §A–§F`.

## FR-1 — `/execute` flags

- `argument-hint` adds `[--subagent-driven | --inline]` (placed before `[--non-interactive | --interactive]`).
- Parsing: `--subagent-driven` and `--inline` are mutually exclusive; **last flag wins** on
  conflict; neither present ⇒ `execution_strategy = inline`. Record the resolved value and
  log to stderr once at Phase 0: `execution_strategy: <inline|subagent-driven> (source: cli|default)`.
- When `--subagent-driven` resolves but no Agent/subagent tool is available on the platform:
  emit `WARNING: --subagent-driven requested but no subagent tool available; running inline.`
  to stderr and set `execution_strategy = inline`. (Never error.)

## FR-2 — `/execute` Phase 2 strategy branch

Insert a "Phase 2 — Execution Strategy" preface that branches on `execution_strategy`:

- `inline` ⇒ the existing per-task single-agent loop (unchanged) plus the existing
  "Subagent Execution (when Agent tool is available)" *optional* sequential-subagent note,
  retained verbatim as a sub-option of inline mode.
- `subagent-driven` ⇒ the new **Parallel Subagent-Driven Execution** section (FR-3..FR-7).

All cross-cutting machinery applies in BOTH branches: Phase 0/0.4/0.5 setup + resume, Phase 1
worktree/tooling-gate/task-list, Phase 2.5 phase-boundary `/verify` + `--no-halt` /
`continue_through_phases`, the runtime-evidence gate, `task-NN.md` / `phase-N.md` logs,
Phases 3–7.

## FR-3 — Wave planning (deterministic)

Before dispatching, build the wave plan:

1. Parse all tasks from the plan (the existing Phase 0.5 parse already does this).
2. Build directed edges: for each task `T`, an edge `dep → T` for every id in `T`'s
   `**Depends on:**` and `**Requires state from:**`. (Absent fields ⇒ no edges, but see step 4.)
3. Build a *conflict* (undirected, same-wave-forbidden) relation: tasks `A` and `B` conflict
   if their `**Files:**` path sets intersect (compare normalized paths; `Create`/`Modify`/`Test`
   entries all count). Conflicting tasks may not share a wave even with no dependency edge.
4. Compute waves by Kahn's algorithm over the dependency edges, then within each topological
   layer greedily split into sub-waves so that no sub-wave contains two conflicting tasks
   (each conflicting pair lands in different sub-waves; order within a layer = task index).
5. Degenerate cases: a dependency cycle, a task that references an unknown dep id, or a plan
   whose tasks lack the v2 per-task fields entirely ⇒ fall back to **all-singleton waves**
   (i.e., fully sequential), and emit a one-line note: `[/execute] subagent-driven: wave
   planning fell back to sequential (<reason>).`
6. Already-`done` / `done-sealed` tasks (from the resume resolver) are excluded from all waves;
   if every remaining task is excluded, /execute is a no-op resume (report and stop).
7. Print the wave plan to chat before starting: `Wave 1: T1, T3, T4 | Wave 2: T2 | Wave 3: T5, T6`.

## FR-4 — Per-wave execution loop

For each wave in order:

1. **Dispatch implementer subagents in parallel** — one Agent call per task in the wave, all
   in a single assistant message (the `dispatching-parallel-agents` pattern). Each gets the
   implementer prompt template (FR-6 / `subagent-driven.md`) populated with: the task's full
   text from the plan (do NOT make the subagent read the plan file), scene-setting context
   (where it fits, what upstream tasks produced), the worktree path, and the explicit rule
   **"implement and test, but DO NOT `git commit` — leave your changes in the working tree and
   report the exact files you changed."**
2. **Collect results.** Handle each implementer status:
   - `DONE` / `DONE_WITH_CONCERNS` ⇒ proceed (read concerns first; if a concern is about
     correctness/scope, resolve before review).
   - `NEEDS_CONTEXT` ⇒ provide context, re-dispatch that one subagent.
   - `BLOCKED` ⇒ assess (more context / more capable model / smaller split / escalate to user).
     Never re-dispatch the same model unchanged. A blocked task stalls only its dependents;
     other waves' tasks already done remain done.
   - On a subagent stall (no return / timeout) ⇒ re-dispatch that single task focused (per the
     `/feature-sdlc` learning: focused single-file re-dispatches recover fast). If a wave task
     touches both "desktop and mobile"-style multi-output work, prefer splitting into two
     subagents from the start.
3. **Per task, in task-index order, the CONTROLLER (not subagents):**
   a. `git add` the task's reported file-set and `git commit` with a `T<N>`-bearing subject
      (e.g., `feat(T5): …`) — honoring the plan's `commit_cadence` (`per-task` default;
      `per-phase` ⇒ stage now, commit at phase boundary; `manual` ⇒ skip commit).
   b. Write/update `{feature_folder}/execute/task-NN.md` (status `done`, `files_touched`,
      body with decisions/deviations/evidence) per the existing schema.
   c. **Two-stage review (in order, no skipping):**
      i. Dispatch a **spec-compliance reviewer subagent** (FR-6) with the task requirements +
         the implementer's claims + the diff (`git show` / SHAs). On `❌` ⇒ re-dispatch the
         *same implementer* subagent with the reviewer's findings to fix; then re-review.
         Loop until `✅`.
      ii. Only after spec `✅`: dispatch a **code-quality reviewer subagent** (FR-6) with the
          diff + `CLAUDE.md` conventions. On findings (Critical/Important) ⇒ implementer fixes
          ⇒ re-review. Loop until approved. (Minor findings: note, proceed.)
      - Reviewer subagents are read-only and may be dispatched concurrently across the wave's
        tasks if convenient, but the spec→quality ORDER per task is mandatory.
      - Fixes that the reviewer triggers ARE committed by the controller as follow-up commits
        (`T<N>` subject, e.g., `fix(T5): address spec-review gap`).
   d. Mark the task complete in the task tracker.
4. **Phase 2.5 phase-boundary check** — if the wave's last task completes a `## Phase N`
   group, run the existing Phase 2.5 (`/verify --scope phase`, `phase-N.md` log, HALT-for-compact
   unless `--no-halt`/sticky flag). Unchanged.
5. Proceed to the next wave.

## FR-5 — Final review

After the last wave: dispatch one **whole-implementation reviewer subagent** with the full diff
range (base SHA → HEAD) and the spec; treat its output as Phase 4's compliance pass. Then run
Phases 3 (deploy & verify) and 5 (commit & report) as today, and Phase 5 still ends by invoking
`/pmos-toolkit:verify`.

## FR-6 — Self-contained prompt templates

New file `plugins/pmos-toolkit/skills/execute/subagent-driven.md` containing four templates:
`implementer`, `spec-reviewer`, `code-quality-reviewer`, `final-reviewer`. Adapted from the
`superpowers:subagent-driven-development` templates but **self-contained** — no `superpowers:*`
or `../_shared/*` references inside the subagent-driven path; the templates inline the TDD
discipline, the self-review checklist, the four-status report format, the "do not commit" rule,
and the "do not trust the report — verify by reading code" rule. SKILL.md references this file
by relative path (`subagent-driven.md`, sibling to `SKILL.md`) — a within-skill reference, not
an external dependency. Model-selection guidance (cheap for mechanical 1–2-file tasks, standard
for integration, most-capable for design/review) is included.

## FR-7 — Platform adaptation

`/execute`'s "Platform Adaptation" section gains a line: on platforms with no subagent tool,
`--subagent-driven` ⇒ logged warning + inline execution (per FR-1). `subagent-driven.md` notes
the same. No other platform-specific behavior.

## FR-8 — `/plan` execution-mode selection

In `/plan`'s closing phase, **before** the platform-aware "closing offer":

- Issue one `AskUserQuestion`:
  - **Inline execution (Recommended)** — desc: "one agent works the plan task-by-task in this
    session — simplest, lowest token cost."
  - **Subagent-driven execution** — desc: "a fresh subagent per task; independent tasks run in
    parallel waves; each task gets a spec + code-quality review — faster on wide plans, higher
    token cost."
  - Non-interactive: Recommended ⇒ `inline` (the existing non-interactive classifier handles this).
- Add `execution_mode: inline | subagent-driven` to the Plan Document Structure frontmatter
  (after `contract_version`). Write the chosen value.
- The closing-offer `/execute` invocation string appends `--subagent-driven` when chosen
  (e.g., `Run /pmos-toolkit:execute --subagent-driven to implement it, or review the plan first?`).
- Add an Anti-Pattern line: do NOT skip the execution-mode question; the recorded value is what
  `/feature-sdlc` Phase 6 reads.

## FR-9 — `/feature-sdlc` Phase 6 honors `execution_mode`

Phase 6 (`/execute`) gains: "Read `execution_mode` from the `03_plan.{html,md}` frontmatter
(written by Phase 5's `/plan`). If `subagent-driven`, append `--subagent-driven` to the
`/execute` invocation. If absent (a legacy plan or `/plan` skipped the prompt) ⇒ no flag
(inline) — do not re-prompt." (One paragraph; no schema changes — `execution_mode` is read
opportunistically, like the existing `commit_cadence` read in `/execute`.)

## Verification plan (for /verify)

- `argument-hint` of `/execute` includes `--subagent-driven | --inline`; mutual-exclusion +
  last-wins + absent-default documented.
- A reader of `/execute` SKILL.md can execute the parallel-wave loop from the text alone — no
  external skill needed; `subagent-driven.md` exists and contains all four templates with no
  `superpowers:`/`_shared/` refs in the subagent path.
- Wave algorithm is deterministic and covers: deps, file-conflict edges, cycle/unknown-dep/
  v1-plan fallback to sequential, resume exclusion of done tasks.
- Controller-commits-post-wave: implementer prompt says "do not commit"; controller step
  commits with `T<N>` subjects honoring `commit_cadence`.
- Two-stage review order (spec → quality) is mandatory and loops to clean.
- `--subagent-driven` on a no-subagent platform ⇒ warning + inline, not error.
- `/plan` asks the question, writes `execution_mode` frontmatter, and reflects the flag in the
  closing offer; Anti-Pattern line added.
- `/feature-sdlc` Phase 6 paragraph reads `execution_mode` and conditionally passes the flag.
- Conforms to `skill-patterns.md §A–§F` (the `/skill-eval` rubric is the binary gate).
- Release prereqs: manifest minor bump in both `plugin.json` files (in sync), README touch if
  warranted, changelog entry.
