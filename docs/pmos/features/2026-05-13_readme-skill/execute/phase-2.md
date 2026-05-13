---
phase_number: 2
phase_name: "Full rubric & section schema"
tasks_in_phase: [4, 5, 6, 7]
plan_path: "docs/pmos/features/2026-05-13_readme-skill/03_plan.html"
branch: "feat/readme-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-readme-skill"
status: sealed
started_at: 2026-05-13T13:00:00Z
completed_at: 2026-05-13T13:52:00Z
verify_status: PASS
verify_reports:
  - docs/pmos/features/2026-05-13_readme-skill/verify/2026-05-13-phase-2-wave-1/report.md
  - docs/pmos/features/2026-05-13_readme-skill/verify/2026-05-13-phase-2/report.md
commits:
  - 996af23  # T4 rubric.yaml + rubric-development.md
  - 20d58fe  # T5 section-schema.yaml
  - db44017  # T6 opening-shapes.md
  - 040845c  # execute(phase-2-wave-1) logs
  - 444b7d8  # pipeline status update
  - 66efe39  # T7 rubric widening
recommendation: PROCEED_TO_PHASE_3
waves:
  - wave: 1
    tasks: [4, 5, 6]
    parallel: true
    review_style: "combined spec+quality (declarative configs/docs)"
  - wave: 2
    tasks: [7]
    parallel: false
    review_style: "combined per-task + phase-boundary (single behavioral task)"
residuals:
  - id: phase-2-r1
    severity: minor
    description: "rubric.yaml pass_when doc-impl drift on install-or-quickstart-presence (impl accepts Download; YAML doesn't)"
  - id: phase-2-r2
    severity: minor
    description: "_lib.sh header comment says 'Bash ≥ 4 required' but code is 3.2-safe"
  - id: phase-2-r3
    severity: by-design
    description: "badges-not-stale lacks a slop fixture exercising cacheSeconds=-1"
  - id: phase-2-r4
    severity: by-design
    description: "plugin-manifest-mentioned warn-and-skip — T21 will implement"
---

## Summary

Phase 2 complete. The /readme skill now carries:
- A canonical 15-check rubric encoded in rubric.yaml (4 blocker / 7 friction / 4 nit) with 14 banned phrases and 7 per-repo-type variants.
- A 7-entry section spine + commit_affinity table + augmentations in section-schema.yaml.
- Per-type opening shape documentation (5-block + map+identity) with 7 worked examples.
- A 520-line rubric.sh implementing all 15 checks in Bash 3.2-safe code, with --variant warn-and-skip + --auto-apply (strikethrough mechanization) + --selftest A2 100% agreement gate (well above the 85% spec floor).
- _lib.sh extended append-only with readme::yaml_get (python3+PyYAML).
- 5+5 fixture corpus with each check calibrated by at least one slop pair (except badges-not-stale — T26 dogfood).

## Demoability

- `rubric.sh README.md --variant library` on a library-style README returns 13/15 PASS.
- `rubric.sh README.md --auto-apply` strikes banned phrases and re-running passes `no-banned-phrases`.
- `rubric.sh --selftest` exits 0 with `selftest: PASS (15 checks; A2 agreement 100% on 10 fixtures)`.

## Deviations declared in waves

- **Wave 1 (T4-T6):** combined spec+quality reviewer (1 subagent) instead of per-task two-stage (6 subagents) — declarative configs/docs don't benefit from the bifurcation.
- **Wave 2 (T7):** combined per-task + phase-boundary reviewer (1 subagent) — single-task wave; the boundary verify subsumes the per-task review pass for a heavy behavioral task.

## Next phase

Phase 3 — Workspace discovery (T8-T10): workspace-discovery.sh with 8 manifest types + MS01 multi-stack + 20-fixture self-test ≥19/20. Plan rationale: parallel-safe with Phase 2 (touches disjoint files); demoable when T10 lands. T7 already exhausted the SKILL.md / rubric.sh / fixtures touch surface; T8-T10 work in a new directory.

Autonomous loop continues. Next turn: dispatch Phase 3 implementer subagents.
