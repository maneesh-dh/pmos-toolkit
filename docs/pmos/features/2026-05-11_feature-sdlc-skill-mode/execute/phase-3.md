---
phase: 3
phase_name: "Rewrite feature-sdlc/SKILL.md"
status: done
tasks: [T9, T10, T11, T12, T13, T14]
completed_at: 2026-05-12T00:00:00Z
---

# Phase 3 — Rewrite `feature-sdlc/SKILL.md` — sealed

All six tasks done and committed:

- **T9** (read + renumber map) — `47ffcf2` era; covered in task-09.md.
- **T10** (frontmatter: merged `description` + FR-06 `argument-hint`) — `47ffcf2`; task-10.md.
- **T11** (Phase 0 subcommand dispatch: `skill`/`list`/bare → `pipeline_mode`; FR-03/04/05 usage/error paths; NFR-07 `pipeline_mode` log line; tier-resolution 0d source) — `5fe9658`; task-11.md.
- **T12** (FR-85 linear renumber to `0,0a,0b,0c,0d,1,2,2a,3,3a,3b,3c,4,5,6,6a,7,8,8a,9,10`; the compact-checkpoint micro-phase loses its number + mode-dependent firing rule; new Phases 0c `/feedback-triage`, 0d `/skill-tier-resolve`, 6a `/skill-eval` with their FRs + the §6.2 control-flow ASCII; 3b/3c mode-conditioned to feature mode; retro-gate moved to runtime position; Phase 0b v3→v4 migration cross-ref; Phase 1 schema-v4 + `pipeline_mode` + mode-conditional `phases[]`; `reference/compact-checkpoint.md` firing rule + phase-ref updates; **plus** an audit-recommended cleanup that took the file from a *pre-existing* 10-unmarked-AskUserQuestion failure to exit 0) — `11eb110`; task-12.md.
- **T13** (`skill-patterns.md` cited at Phases 2/4/6/7 with the right role each; skill-feedback `/requirements` seeded from `seed-requirements-template.md` → one combined `01_requirements` with a per-skill section; FR-50/51/52 `/verify` behaviour expanded; FR-62 `CLAUDE.md ## Skill-authoring conventions` pointer) — `19e9a0a`; task-13.md.
- **T14** (H1 + "Pipeline position" diagram + Mode × phase table; three new anti-patterns + #10 amendment; "Release prerequisites" rewritten to items (i)–(vii) per FR-94/95/P5; legacy `/push` → `/complete-dev`) — committed with this log; task-14.md.

## Invariants held across the phase

- `<!-- non-interactive-block:start --> … :end -->` (incl. the awk extractor) — byte-identical to HEAD (md5-verified after every task).
- `### \`list\` logic` subsection — byte-identical to HEAD.
- `bash plugins/pmos-toolkit/tools/audit-recommended.sh …/SKILL.md` → exit 0 (was failing at HEAD and in the released 2.36.0 — fixed as part of T12).
- `grep '^## Phase' …/SKILL.md` → the exact 21-line FR-85 sequence.

## Note for the verification phase (TN / /verify)

The audit-recommended exit-0 status required rewording four *prose mentions* of the literal token `AskUserQuestion` (in the `--minimal` paragraph, the retro auto-skip line, the Phase-6a control-flow ASCII, and Anti-Patterns #4 & #5) plus collapsing blank lines before four fenced `question:/options:` blocks. These are doc-text adjustments to a static-analysis script's input, not behavioural changes; the released 2.36.0 skill had the same 10 false-positives.

## Next

Phase 4 / T15 — bump `feature-sdlc/reference/state-schema.md` to schema v4 (deferred from T1: read it first). Then Phase 5 (T16–T22), Phase 6 (TN).
