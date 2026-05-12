---
task_number: 12
task_name: "Linear renumber + insert Phases 0c, 0d, 6a + mode-condition the gates + the compact-checkpoint rule"
status: done
started_at: 2026-05-12T00:00:00Z
completed_at: 2026-05-12T00:00:00Z
files_touched:
  - plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md
  - plugins/pmos-toolkit/skills/feature-sdlc/reference/compact-checkpoint.md
tdd: "no — prose rewrite; binding check is the `^## Phase` sequence + audit-recommended"
---

## What changed

### `plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md`

- **FR-85 linear renumber** — `^## Phase` headings are now exactly, in order: `0, 0a, 0b, 0c, 0d, 1, 2, 2a, 3, 3a, 3b, 3c, 4, 5, 6, 6a, 7, 8, 8a, 9, 10` (21 lines). Old dotted forms (`0.a`, `3.b`, `4.b`, `4.c`, `4.d`) and the gaps (7/8/9/10/11/12/13) are gone. Every in-body cross-reference to a phase number updated to the new scheme (incl. Platform Adaptation bullets, Anti-Patterns, Tier-resolution, `--minimal`, retro→Phase 9, etc.). The retro-gate section was moved to its runtime position (after Phase 8 /complete-dev, before Phase 9 final-summary) so file order == runtime order.
- **Phase 2 (compact checkpoint) → un-numbered** `## Compact checkpoint (recurring micro-phase)`. Firing rule rewritten (FR-40 / E8): feature mode → before 3b/3c/6/7; skill modes → before 6/7 only (3b/3c suppressed; not before 6a — scoring is light).
- **NEW `## Phase 0c: /feedback-triage (skill-feedback only)`** (hard) — FR-20..27: parse feedback (retro-parser.md verbatim / read-then-detect / LLM-extract) → resolve in-scope skills (AskUserQuestion to disambiguate; zero findings/skills → exit clean, no artifacts) → per-finding critique (already_handled/classification/recommendation/scope_hint) → Findings-Presentation-Protocol keep/drop approval (one prompt/finding, ≤4/batch, >20 → filter prompt; platform fallback = numbered table) → persist `{feature_folder}/0c_feedback_triage.html` via the HTML substrate reusing triage-doc-template.md structure → seed Phase 2 /requirements from seed-requirements-template.md (self-contained per-skill → one combined `01_requirements` with a per-skill section).
- **NEW `## Phase 0d: /skill-tier-resolve (skill modes only)`** (infra) — FR-30..34: one repo-shape pass → tier (skill-tier-matrix.md; per-skill tier + run-tier=max in skill-feedback; `--tier N` overrides, logs E19 divergence) · skill location (repo-shape-detection.md four-rung chain; multi-plugin → AskUserQuestion) · target_platform (claude-code/codex/generic). One consolidated confirmation AskUserQuestion (Confirm all / Edit tier / Edit location / Edit platform). `{tier}` → `/requirements`/`/spec`/`/plan` passthrough.
- **NEW `## Phase 6a: /skill-eval (skill modes only)`** (hard, after Phase 6, before Phase 7) — FR-40..49 + §6.2 control flow: per-iteration `pre_ref` bookkeeping (FR-41); deterministic half = `feature-sdlc/tools/skill-eval-check.sh --target <p> <skill_dir>` (exit 0/1/2; on exit 2 / no-bash / missing-dep → those [D] checks fall back to LLM-judge with the logged note — FR-42/E7); LLM-judge half = reviewer subagent (raw SKILL.md + each reference/ file path-labelled + the [J] list from skill-eval.md → JSON array, exact check_id set, `{check_id,verdict,fix_note,quote≥40}`, `temperature: 0`, reviewer makes NO edits per D10, fail-with-empty/unverifiable-quote → pass — FR-43); orchestrator-side validation (FR-44 hard-fail messages `reviewer returned check_ids that do not match …` / `reviewer quote not found in <file>: …` → soft-phase failure dialog on miss); net-worse guard (FR-45) → adds "Restore iteration 1" to the post-cap dialog; remediation loop (FR-46) — append `## Eval-remediation — iteration N` tasks to `03_plan`, re-run Phase 6 /execute, re-score; cap = 2 (FR-47) → AskUserQuestion: Accept residuals as known risk (→ `accepted_residuals[]` → /verify) / Iterate manually / Restore iteration 1 (if net-worse) / Abort — no silent pass; all-pass at any iteration → complete, `accepted_residuals[]` empty (FR-49); per-iteration `skill-eval iteration N: <p> passed, <f> failed [<ids>]` log (NFR-07). Includes an inline ASCII paraphrase of the §6.2 control flow.
- **Mode-conditioned the enhancement gates** — new `## Phase 3: Enhancement gates` container heading explains: 3a (/creativity, all modes) presented always; 3b (/wireframes) + 3c (/prototype) presented in **feature mode only** — in skill modes the orchestrator logs `[orchestrator] skill-mode: 3b/3c suppressed (no UI)` and proceeds to Phase 4. Prose explicitly frames this (and 0c being skill-feedback-only, 0d/6a being skill-modes-only) as a **mode-conditional by-design non-presentation keyed off `pipeline_mode`** — not a silent skip of a presented gate (Anti-Pattern #4 amended to say so).
- **Phase 0b resume detection** — schema check now covers v3→v4 (FR-13 migration chain: v1→v2→v3→v4, pre-2.34.0 elision before the v4 step, `pipeline_mode: feature` default-on-read, the `migration: state.schema v3 → v4 …` log line); resume-cursor note made mode-agnostic (`phases[]` is mode-conditional per FR-11; `pipeline_mode` read back from state, not re-derived — FR-05). The missing-artifact `AskUserQuestion` now carries an adjacent `<!-- defer-only: ambiguous -->` tag.
- **Phase 1 init** — `schema_version: 4`, top-level `pipeline_mode`, `tier` source noted (Phase 0d in skill modes), `current_phase` = first phase of this mode's `phases[]`, `phases[]` membership mode-conditional per FR-11.
- **Phase 2 /requirements** — seed differs by mode (initial-context / `skill <description>` / the combined per-skill seed from 0c); skill-modes prepend the `skill-patterns.md §A–§F` acceptance-criteria citation (fuller wiring lands in T13).
- **Phase 6 /execute** — note that in skill modes /execute is the sole writer of the skill (the Phase-6a reviewer never edits, D10); the skill is written to the `skill_location` from Phase 0d; its task-level resume also covers Phase-6a remediation addenda.
- **Phase 7 /verify** — note that in skill modes /verify re-runs `skill-eval.md` fresh and reconciles `accepted_residuals[]` (fuller wiring in T13).

### `plugins/pmos-toolkit/skills/feature-sdlc/reference/compact-checkpoint.md`

- "When the checkpoint fires" rewritten to the mode-dependent rule (feature: before 3b/3c/6/7; skill modes: before 6/7 only). Stale `simulate-spec` trigger demoted to a historical note. `Phase 0.b`→`Phase 0b`, `Phase 11`/`Phase-11`→`Phase 9`/`Phase-9`.

### Audit-recommended cleanup (deviation from the plan's literal "exit 0", now satisfied)

`bash plugins/pmos-toolkit/tools/audit-recommended.sh plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md` **now exits 0** (`12 calls, 5 Recommended, 7 defer-only, 0 unmarked`). Getting there required, beyond tagging every new AskUserQuestion call (`<!-- defer-only: ambiguous -->` adjacent to each of the new Phase-0c/0d/6a/0b calls), fixing **pre-existing false positives** in the released 2.36.0 skill (which itself failed this audit with 10 unmarked): (a) collapsing the blank line between `` `AskUserQuestion`: `` and the following fenced `question:/options:` block in the slug-confirm, creativity, prototype, and retro gates so the `(Recommended)` inside the fence is detected; (b) rewording four *prose mentions* of the literal token `AskUserQuestion` (in the `--minimal` paragraph, the retro auto-skip line, the Phase-6a control-flow ASCII diagram, and Anti-Patterns #4 & #5) to "gate prompt" / "structured prompt" / "user prompt" so the awk extractor stops treating them as untagged call sites; (c) rewording the `[if multiple plugins → the AskUserQuestion below]` mention to "the prompt below". No behavioural change — these are doc-text adjustments to a static-analysis script's input.

## Preserve regions — byte-identical (verified by md5 against HEAD)

- `<!-- non-interactive-block:start --> … :end -->` (incl. the awk extractor) — IDENTICAL.
- `### \`list\` logic` subsection (steps 1–7 through `Exit 0 after table emission.`) — IDENTICAL.

## Verification

- `grep '^## Phase' SKILL.md` → `0 0a 0b 0c 0d 1 2 2a 3 3a 3b 3c 4 5 6 6a 7 8 8a 9 10` (21 lines, exact match to the Done-when target).
- `grep -c '## Phase 0c\|## Phase 0d\|## Phase 6a' SKILL.md` → 3.
- All six new/moved ref+tool files cited at their `feature-sdlc/reference/` or `feature-sdlc/tools/` paths.
- `grep -i 'Eval-remediation — iteration\|accepted_residuals\|iterations\[' SKILL.md` → 9 hits.
- Both FR-44 hard-fail strings present.
- D13 mode-condition prose present (4 hits); compact-checkpoint firing rule present.
- `bash plugins/pmos-toolkit/tools/audit-recommended.sh …/SKILL.md` → exit 0.
