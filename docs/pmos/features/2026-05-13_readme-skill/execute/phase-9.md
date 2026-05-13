---
phase_number: 9
phase_name: "Integration tests + dogfood (T25-T26)"
tasks_in_phase: [25, 26]
plan_path: "docs/pmos/features/2026-05-13_readme-skill/03_plan.html"
branch: "feat/readme-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-readme-skill"
status: sealed
started_at: 2026-05-13T15:00:00Z
completed_at: 2026-05-13T15:43:47Z
verify_status: PASS_WITH_RESIDUALS
verify_reports:
  - "docs/pmos/features/2026-05-13_readme-skill/verify/2026-05-13-phase-9/report.md"
commits:
  - 0a8f1ce  # T25 integration suite + monorepo + 21st workspace fixture
  - 8aadce7  # T25 log
  - 886f588  # T26 dogfood orchestrator + reference/cross-file-rules.md anchor (closes phase-7-r1)
  - a8373a6  # T26 log
recommendation: PROCEED_TO_PHASE_6A
waves:
  - wave: 1
    tasks: [25]
    parallel: false
    review_style: "combined per-task + phase-boundary (solo sequential; tests-only; SKILL.md untouched)"
  - wave: 2
    tasks: [26]
    parallel: false
    review_style: "combined per-task + phase-boundary (solo sequential; dogfood orchestrator + pure-add anchor in ref doc; SKILL.md untouched per P11)"
residuals:
  - "[phase-9-r1] Dogfood G1 (73%) and G3 (0 findings) ADVISORY_FAIL on host repo: only 1 plugin exists and it has no top-level README.md; the 6-target plan-spec set is unattainable on today's repo. Per /plan Loop-1 F2 ADVISORY contract — script exits 0; /verify Phase 7 owns the gate via accepted_residuals[]."
---

## Summary

Phase 9 lands the empirical regression layer for `/readme`. T25 (Wave 1
solo) authored 7 integration scripts per spec §13.2 plus the
`tests/run-all.sh` aggregator, a new `monorepo-mixed-readmes` fixture, the
21st workspace fixture (`overlap-secondary-negative`), and a targeted
rubric fixture for the `badges-not-stale` check. Run-all exits 0 with 4
substrate `--selftest`s + 9 integration tests = 13/13 passing. T25 closed
three carried residuals: `phase-2-r3`, `phase-3-r4`, `phase-5-r2`.

T26 (Wave 2 solo) authored
`plugins/pmos-toolkit/skills/readme/tests/dogfood/run-dogfood.sh` — the
G1 / G3 dogfood orchestrator over this repo's READMEs. Per /plan Loop-1 F2,
the script is **advisory: always exits 0**. On today's repo it reports
ADVISORY_FAIL on both gates (G1 73%, G3 0 findings) because the repo has
only one plugin (`pmos-toolkit`) and that plugin has no top-level README.md.
This is the planned signal: the residual (logged as `phase-9-r1`) is queued
for /verify Phase 7 `accepted_residuals[]` reconciliation. T26 also closed
`phase-7-r1` — the R3 forward-cite anchor mismatch — via a P11-safe
**pure-add** of `<a id="r3-install-contributing-license-root-only"></a>` to
`reference/cross-file-rules.md` (Option A in the controller brief was an
in-place SKILL.md substring edit that would have produced a `-1/+1` git
diff; P11 strictly disallows mid-subsection rewrites, so the alternate
pure-add path was taken — see T26 task log for the full rationale).

**P11 across Phase 9: 0 deletions on SKILL.md, 0 deletions on
`reference/cross-file-rules.md`.** SKILL.md remains at 477/480 lines.

## Demoability

**PARTIAL by design (P9 / spec §13.5 precedent).** Phase 9's empirical
surface is the run-all suite (live, deterministic, 13/13 PASS) plus the
dogfood orchestrator (live, ADVISORY-only). Full E2E demoability of the
`/readme` slash-command — LLM-driven mode resolution + Task-dispatched
simulated-reader subagents — is unmockable from bash and is not in scope
of any phase per the plan's allowed-deviations clause; T25's seven
integration scripts substitute contract-level checks against the bundled
substrates and SKILL.md text. Dogfood is the genuine empirical regression
gate, advisory by /plan Loop-1 F2 design.

## Deviations declared in waves

**Wave 2 (T26) — P11 path swap.** Plan and controller brief named Option A
(in-place SKILL.md anchor-fragment edit) as the recommended phase-7-r1
fix. On re-read, P11 ("No mid-subsection rewrites of prior tasks'
content") and the Phase 7 verify report (which framed the fix as
preserving "Phase 7 P11 append-only across **both SKILL.md and ref doc**")
together rule out the substring edit's `-1/+1` git diff. T26 selected the
controller's authorized alternate: a pure-add `<a id>` anchor in the ref
doc. Outcome: SKILL.md untouched in Phase 9; ref doc gains 1 line, deletes
0. Documented in T26 task log §Deviations.

**Wave 2 (T26) — Dogfood target-set shortfall.** Plan spec is "6 targets
(root + pmos-toolkit + 4 more plugins)". Today's repo has 1 plugin and no
top-level pmos-toolkit README.md. The script handles this case (logs the
shortfall, proceeds with what exists, treats missing G3 target as 0
findings). Both G1 and G3 land ADVISORY_FAIL — the planned ADVISORY-only
outcome surface for /verify Phase 7.

## Residuals closed

- `phase-2-r3` (T25) — badges-not-stale targeted fixture added.
- `phase-3-r4` (T25) — 21st alias workspace fixture
  `overlap-secondary-negative` added; `workspace-discovery.sh --selftest`
  now 21/21.
- `phase-5-r2` (T25) — `compose_audit_scaffold.sh` exercises the FR-MODE-2
  mutex + FR-MODE-3 composition contract at runtime.
- `phase-7-r1` (T26) — R3 forward-cite anchor resolves via pure-add
  `<a id>` in `reference/cross-file-rules.md` line 66.

## Residuals added

- `phase-9-r1` — Dogfood G1 (73%) and G3 (0 findings) ADVISORY_FAIL on
  host repo (1 plugin, missing pmos-toolkit README.md). Queued for /verify
  Phase 7 `accepted_residuals[]`.

## Next phase

**Phase 6a — `/skill-eval`.** Binary rubric scoring against
`plugins/pmos-toolkit/skills/readme/` per
`plugins/pmos-toolkit/skills/feature-sdlc/reference/skill-eval.md`; ≤2
iterations; the [D] checks should pass deterministically (TN target), the
[J] checks score by reviewer-subagent. Carried residuals (8 entries) are
out-of-scope for skill-eval and belong to /verify Phase 7 reconciliation.
