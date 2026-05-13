---
task_number: 12
task_name: "SKILL.md — parallel Task dispatch + FR-SR-3 substring validation"
plan_path: "docs/pmos/features/2026-05-13_readme-skill/03_plan.html"
branch: "feat/readme-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-readme-skill"
status: done
started_at: 2026-05-13T15:10:00Z
completed_at: 2026-05-13T15:20:00Z
commit_sha: d718646
files_touched:
  - plugins/pmos-toolkit/skills/readme/SKILL.md
---

## Outcome

DONE. Appended `### §2: Simulated-reader pass` to `## Implementation` in `plugins/pmos-toolkit/skills/readme/SKILL.md`, BELOW the four `### Subsection N — TBD` placeholders left by T1, and ABOVE `## Anti-Patterns`. The new subsection documents the runtime protocol per FR-SR-1 / FR-SR-2 / FR-SR-3 and decision-log entries D13 + P3:

1. **Parallel dispatch** — 3 `Task` calls in ONE assistant response (one per persona: `evaluator`/`adopter`/`contributor`); per-call body inlines persona prompt from `reference/simulated-reader.md §1`, the un-stripped README markdown, and the return-shape contract from `reference/simulated-reader.md §2`; 120s per-call timeout; timeout → `simulated-reader: persona <name> timed out (120s); skipping` and continue with the survivors (NFR-4).
2. **Substring validation (FR-SR-3)** — for each returned `friction[].quote`: quote-length ≥40 hard-gate; substring-grep against un-stripped README source; persona-label match against dispatched label; each failure hard-fails with the spec-mandated message and pauses with the failure dialog.
3. **Merge + dedupe** — passing entries merge into the rubric stream tagged `source: simulated-reader/<persona>`; dedupe across findings when `abs(line_a-line_b) ≤ 2` AND same section heading (via `reference/section-schema.yaml`), keeping higher severity; ties break in favour of the deterministic `rubric.sh` entry over the probabilistic persona entry.
4. **Cross-reference** — closes with the one-level-deep pointer to `reference/simulated-reader.md` per §C of skill-patterns.md.

## Deviations

- None. T12 is documentation-only inside SKILL.md; no script changes, no test changes (T13 lands the stub-driven contract test next).

## Verification

- `wc -l plugins/pmos-toolkit/skills/readme/SKILL.md` → **197** (≤ 480 budget P8).
- `grep -c 'Task.*parallel\|3 concurrent\|FR-SR-3' plugins/pmos-toolkit/skills/readme/SKILL.md` → **5** (≥ 1 required).
- `git diff HEAD~1 -- plugins/pmos-toolkit/skills/readme/SKILL.md | grep '^-' | grep -v '^---' | wc -l` → **0** removed lines → P11 append-only invariant satisfied.
- Edit lives inside `## Implementation`, after the four TBD placeholders, before `## Anti-Patterns`. §1 (Single-file audit flow), `<!-- pipeline-setup-block -->`, `<!-- non-interactive-block -->`, awk-extractor, and all other sections untouched.

## Residuals (carry to T13+)

1. T13 lands the contract test that exercises the FR-SR-3 hard-fail path against a fixture where the persona returns a fabricated quote.
2. T13's test also asserts the persona-label-mismatch hard-fail path and the <40-char quote hard-fail path.
3. Aggregator dedupe across `rubric.sh` and persona entries is documented in §2 step 4 but exercised end-to-end only once T9/T10 lift `packages` discovery and the §1 audit-mode tracer reaches green.

Commit: `d718646`.
