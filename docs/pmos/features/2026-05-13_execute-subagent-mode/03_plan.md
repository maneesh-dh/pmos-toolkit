---
tier: 2
type: enhancement
feature: execute-subagent-mode
spec_ref: 02_spec.md
requirements_ref: 01_requirements.md
date: 2026-05-13
status: Draft
commit_cadence: per-task
contract_version: 1
execution_mode: inline
---

# /execute — parallel subagent-driven execution mode — Implementation Plan

## Overview

Edits to three SKILL.md files plus one new reference file. No code, no tests in the
conventional sense — verification is "re-read the changed text against the spec FRs" plus the
`/skill-eval` binary rubric plus `/verify`. TDD does not apply (skill-authoring change);
each task states that.

**Done when:** `/execute` accepts `--subagent-driven | --inline`, documents a deterministic
parallel-wave loop with self-contained prompt templates in `subagent-driven.md` (no
`superpowers:`/`_shared/` refs in the subagent path), degrades to inline on no-subagent
platforms; `/plan` asks the execution-mode question and records `execution_mode` frontmatter +
flagged closing offer; `/feature-sdlc` Phase 6 reads `execution_mode` and conditionally passes
the flag; `/skill-eval` passes; `/verify` passes; both `plugin.json` manifests bumped in sync;
changelog updated.

## Tasks

### T1: `/execute` — flags, parsing, stderr log, platform-adaptation line

**Goal:** Add `--subagent-driven | --inline` to `/execute` and the resolution + degradation rules.
**Spec refs:** FR-1, FR-7
**Depends on:** none
**Idempotent:** yes
**TDD:** no — skill-authoring change; verify by re-reading against FR-1/FR-7.
**Files:**
- Modify: `plugins/pmos-toolkit/skills/execute/SKILL.md` (frontmatter `argument-hint`; Platform Adaptation section; Phase 0 add a one-line `execution_strategy` resolution + stderr log)

**Steps:**
- [ ] Update `argument-hint` to include `[--subagent-driven | --inline]` before `[--non-interactive | --interactive]`.
- [ ] In "Platform Adaptation", under "No subagents", add: `--subagent-driven` ⇒ logged warning + inline execution (never error).
- [ ] In Phase 0 (after mode resolution), add: resolve `execution_strategy` (`--subagent-driven`/`--inline`, last wins, absent ⇒ inline; no-subagent platform ⇒ warn + inline); stderr `execution_strategy: <v> (source: cli|default)`.
- [ ] Commit `T1: …`.

### T2: `/execute` — Phase 2 execution-strategy branch preface

**Goal:** Make Phase 2 branch on `execution_strategy`; keep all cross-cutting machinery in both branches.
**Spec refs:** FR-2
**Depends on:** T1
**Idempotent:** yes
**TDD:** no — skill-authoring change.
**Files:**
- Modify: `plugins/pmos-toolkit/skills/execute/SKILL.md` (top of Phase 2: "Phase 2 — Execution Strategy" preface; demote the existing "Subagent Execution (when Agent tool is available)" note to a sub-option of `inline`)

**Steps:**
- [ ] Add the preface paragraph: `inline` ⇒ existing per-task loop (+ optional sequential-subagent sub-note, retained verbatim); `subagent-driven` ⇒ jump to the new "Parallel Subagent-Driven Execution" section.
- [ ] Add the "applies in both modes" list (Phase 0/0.4/0.5, Phase 1, Phase 2.5, runtime-evidence gate, task/phase logs, Phases 3–7).
- [ ] Commit `T2: …`.

### T3: `/execute` — "Parallel Subagent-Driven Execution" section

**Goal:** The meat — deterministic wave planning, per-wave loop with controller-commits-post-wave, two-stage review, final review.
**Spec refs:** FR-3, FR-4, FR-5
**Depends on:** T2
**Requires state from:** T4 (the section references `subagent-driven.md`; create T4 before or alongside)
**Idempotent:** yes
**TDD:** no — skill-authoring change; verify against FR-3/FR-4/FR-5 line by line.
**Files:**
- Modify: `plugins/pmos-toolkit/skills/execute/SKILL.md` (new section after "Sequential Execution (no subagents)")

**Steps:**
- [ ] Write **Wave planning** subsection: parse tasks → dependency edges from `Depends on`/`Requires state from` → file-conflict relation from `Files:` → Kahn layering + greedy conflict-free sub-waves → degenerate-case fallback to all-singleton (sequential) with logged reason → exclude resolver-`done` tasks → print the wave plan.
- [ ] Write **Per-wave loop** subsection: parallel implementer dispatch (single message, multiple Agent calls; "implement+test, DO NOT commit, report files"); collect + handle DONE/DONE_WITH_CONCERNS/NEEDS_CONTEXT/BLOCKED/stall; then CONTROLLER per task in index order: git add+commit `T<N>` (honor `commit_cadence`), write `task-NN.md`, two-stage review (spec reviewer subagent → on ❌ implementer re-dispatch to fix → re-review → loop to ✅; THEN code-quality reviewer subagent → fixes → re-review → approved; controller commits review-driven fixes as `fix(T<N>): …`); mark complete; then Phase 2.5 boundary check if wave ends a `## Phase N` group.
- [ ] Write **Final review** subsection: whole-implementation reviewer subagent over base→HEAD; then Phases 3 & 5 as today (Phase 5 still ends with `/pmos-toolkit:verify`).
- [ ] Add a model-selection note (cheap for mechanical 1–2-file tasks; standard for integration; most-capable for design/review) — or point at `subagent-driven.md` for it.
- [ ] Commit `T3: …`.

### T4: new `plugins/pmos-toolkit/skills/execute/subagent-driven.md` — prompt templates

**Goal:** Self-contained implementer / spec-reviewer / code-quality-reviewer / final-reviewer prompt templates + model-selection guidance, no external refs.
**Spec refs:** FR-6
**Depends on:** none
**Idempotent:** yes
**TDD:** no — new reference doc.
**Files:**
- Create: `plugins/pmos-toolkit/skills/execute/subagent-driven.md`

**Steps:**
- [ ] Implementer template: full task text placeholder, scene-setting context, "ask questions first/during", TDD discipline inline, code-organization guidance, "when in over your head → BLOCKED/NEEDS_CONTEXT", self-review checklist, **"DO NOT git commit — leave changes in working tree, report exact files"**, four-status report format.
- [ ] Spec-reviewer template: "do not trust the report — verify by reading code", missing/extra/misunderstanding checks, `✅`/`❌ [file:line]` output.
- [ ] Code-quality-reviewer template: diff + `CLAUDE.md` conventions, one-responsibility-per-file checks, Strengths/Issues(Critical|Important|Minor)/Assessment output.
- [ ] Final-reviewer template: whole base→HEAD diff vs spec, ready-to-merge assessment.
- [ ] Model-selection section.
- [ ] Header note: "self-contained; referenced only by `execute/SKILL.md`; inspired by `superpowers:subagent-driven-development` but has no dependency on it."
- [ ] Commit `T4: …`.

### T5: `/execute` — Anti-Patterns + cross-references

**Goal:** Anti-pattern lines for the new path; ensure no dangling external-skill dependency wording.
**Spec refs:** FR-2, FR-6 (consistency)
**Depends on:** T3, T4
**Idempotent:** yes
**TDD:** no.
**Files:**
- Modify: `plugins/pmos-toolkit/skills/execute/SKILL.md` (Anti-Patterns list; any prose mentioning subagents)

**Steps:**
- [ ] Add: do NOT dispatch parallel implementers for tasks that share a `Files:` entry or have a dep edge (race / wrong order); do NOT let implementer subagents commit in parallel mode (controller commits); do NOT run code-quality review before spec-compliance ✅; do NOT skip the two-stage review in parallel mode.
- [ ] Sanity-grep the SKILL for `superpowers:` / external-skill names in the subagent-driven path — none should be load-bearing.
- [ ] Commit `T5: …`.

### T6: `/plan` — execution-mode question + frontmatter key + closing offer + anti-pattern

**Goal:** Ask the user post-`/plan` and record the choice.
**Spec refs:** FR-8
**Depends on:** none (independent of /execute edits)
**Idempotent:** yes
**TDD:** no.
**Files:**
- Modify: `plugins/pmos-toolkit/skills/plan/SKILL.md` (Plan Document Structure frontmatter; closing phase before "Closing offer"; Anti-Patterns)

**Steps:**
- [ ] Add `execution_mode: inline | subagent-driven` to the Plan Document Structure frontmatter block (after `contract_version`).
- [ ] In the closing phase, before the platform-aware "Closing offer", add the `AskUserQuestion`: Inline (Recommended) / Subagent-driven, each with the one-liner from FR-8. Record the value into the plan doc's frontmatter.
- [ ] Make the closing-offer `/execute` invocation string append `--subagent-driven` when chosen.
- [ ] Add Anti-Pattern: do NOT skip the execution-mode question; the recorded `execution_mode` is what `/feature-sdlc` Phase 6 reads.
- [ ] Commit `T6: …`.

### T7: `/feature-sdlc` — Phase 6 honors `execution_mode`

**Goal:** Orchestrator passes `--subagent-driven` when the plan recorded it.
**Spec refs:** FR-9
**Depends on:** none
**Idempotent:** yes
**TDD:** no.
**Files:**
- Modify: `plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md` (Phase 6: /execute)

**Steps:**
- [ ] Add the paragraph: read `execution_mode` from `03_plan.{html,md}` frontmatter; if `subagent-driven` ⇒ append `--subagent-driven`; if absent ⇒ inline, no re-prompt.
- [ ] Commit `T7: …`.

### T8: Release prereqs (mostly handled by /complete-dev, listed for completeness)

**Goal:** Version bump both manifests in sync; changelog entry; README touch if warranted.
**Depends on:** T1–T7
**Idempotent:** yes
**TDD:** no.
**Files:**
- Modify: `plugins/pmos-toolkit/.claude-plugin/plugin.json`, `plugins/pmos-toolkit/.codex-plugin/plugin.json` (minor bump, in sync)
- Modify: changelog (per `/changelog` / `/complete-dev`)
- Maybe: top-level README (mention `--subagent-driven` if /execute is documented there)

**Steps:**
- [ ] (Deferred to `/complete-dev`.) Verify both manifests carry the same new minor version; add a changelog entry describing the new `/execute` subagent-driven mode + the `/plan` prompt.

## Risks

| Risk | Mitigation |
|---|---|
| SKILL.md bloat — `/execute` is already 488 lines | Put the prompt templates in `subagent-driven.md`; keep the SKILL section to the wave algorithm + loop. |
| Parallel-commit races | Resolved by controller-commits-post-wave (grilled & confirmed). |
| Dangling dependency on `superpowers:subagent-driven-development` (not in this repo) | FR-6: templates are self-contained; the superpowers skill is cited only as inspiration in prose. `/skill-eval` checks for dangling refs. |
| `/plan` and `/feature-sdlc` are large, complex skills — edit collisions | Edits are surgical and additive (one frontmatter key, one question, one paragraph); T6/T7 are independent of the /execute tasks. |
| Resume resolver breakage | Controller still emits `T<N>` commit subjects; resolver contract unchanged. |

## Decision log

- D1: Commit model in parallel waves = **controller commits post-wave** (implementers don't commit). Rationale: avoids `.git/index` races; preserves `T<N>` subjects for the resume resolver. (Grilled, user-confirmed.)
- D2: Scope = `/execute` (meat) + `/plan` (surgical) + `/feature-sdlc` Phase 6 (1 paragraph). (Grilled, user-confirmed.)
- D3: Prompt templates live in a sibling `subagent-driven.md`, not inline in SKILL.md — keeps SKILL.md readable; still "within /execute" so satisfies "no external dependency".
- D4: `--subagent-driven` on a no-subagent platform = warn + inline, not error — consistent with the rest of `/execute`'s graceful platform degradation.
- D5: Default (no flag) = inline = today's behavior — zero-regression.

## Final verification checklist

- [ ] `/execute` `argument-hint` has `--subagent-driven | --inline`; resolution rules in Phase 0.
- [ ] `/execute` Phase 2 branches; both modes keep Phase 0/0.4/0.5/1/2.5 + logs + Phases 3–7.
- [ ] "Parallel Subagent-Driven Execution" section: wave planning (deps + file-conflict + fallback + resume-exclusion + printed plan) + per-wave loop (parallel dispatch, status handling, controller commits `T<N>` honoring `commit_cadence`, two-stage review spec→quality looping to clean, Phase 2.5) + final review.
- [ ] `subagent-driven.md` exists with 4 templates + model-selection; no `superpowers:`/`_shared/` refs in the subagent path; "do not commit" rule present in the implementer template.
- [ ] `/execute` Anti-Patterns updated; no dangling external-skill dependency.
- [ ] `/plan`: `execution_mode` frontmatter key; closing-phase question (Inline Recommended / Subagent-driven, with one-liners); flagged closing offer; Anti-Pattern line.
- [ ] `/feature-sdlc` Phase 6: reads `execution_mode`, conditionally appends `--subagent-driven`, no re-prompt when absent.
- [ ] `/skill-eval` rubric passes (the binary gate).
- [ ] `/verify` passes (re-run skill-eval + release-prereq grading).
- [ ] Both `plugin.json` manifests bumped to the same new minor version; changelog entry added; README touched if warranted.
- [ ] No stray files; the worktree is clean except the intended changes.
