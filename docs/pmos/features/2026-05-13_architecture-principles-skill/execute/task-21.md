---
task_number: 21
task_name: "TN — Final verification: fixtures + skill-eval + citations + gap-map + determinism + manual dry-run"
task_goal_hash: t21-tn-final-verification
plan_path: "docs/pmos/features/2026-05-13_architecture-principles-skill/03_plan.html"
branch: "feat/architecture-principles-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-architecture-principles-skill"
status: done
started_at: 2026-05-13T00:44:00Z
completed_at: 2026-05-13T00:55:00Z
files_touched:
  - plugins/pmos-toolkit/skills/architecture/SKILL.md
  - plugins/pmos-toolkit/skills/architecture/reference/l1-rationales.md
  - plugins/pmos-toolkit/skills/architecture/tests/run.sh
  - plugins/pmos-toolkit/skills/architecture/tools/check-determinism.sh
---

## Outcome

All verification gates green except one [D] skill-eval check, which is documented and flows to Phase 6a remediation per the plan's instruction ("flag any failures for /skill-eval to address in Phase 6a").

## Verification stack

| # | Gate | Result |
|---|------|--------|
| 1 | shellcheck on 5 bash scripts (`check-*.sh`, `run.sh`) | **PASS** (0 warnings) |
| 2 | Fixture suite (`tests/run.sh`) | **PASS** — 22 passed, 0 failed |
| 3 | `tools/check-citations.sh` on shipped principles.yaml | **PASS** — all 18 rules cite a source, exit 0 |
| 4 | `tools/check-gap-map.sh` | **PASS** — `delegated_pct = 0.444` (G2 stretch, not enforced; report-only) |
| 5 | `tools/check-determinism.sh` on `ts-circular` fixture | **PASS** — byte-identical across 2 runs (with `--no-adr` to suppress ADR side effects), exit 0 |
| 6 | `skill-eval-check.sh --target generic` | **17/18 [D] checks PASS** — 1 known fail (`c-asset-layout`); flagged for Phase 6a |
| 7 | Canonical-path check (`SKILL.md` at canonical skill dir) | **PASS** |
| 8 | Polish (no real `TODO/FIXME/XXX` outside fixtures + rule defs) | **PASS** |
| 9 | Manual dry-run from clean `/tmp/audit-demo` git repo | **PASS** — exit 0, valid JSON on stdout, U004 finding for `src/a.ts`, stderr summary present |

## Skill-eval [D] gap surfaced for Phase 6a

`c-asset-layout` fails because `package.json` + `package-lock.json` (installed for `npx dependency-cruiser` to find local deps shipped by T9) sit at the skill root rather than under a sub-dir. Moving them would break `npx`'s nearest-`package.json` resolution. Two options for Phase 6a:

1. Accept residual — record `accepted_residuals[]` with the rationale (npx needs root-level `package.json`).
2. Restructure tooling — move dep-cruiser invocation to use an explicit `--package-json` flag pointing at a sub-dir.

Option 1 is the recommended exit (residual is fundamental to the tool wiring; no harm done).

## Self-improvements rolled into T21

Polished a handful of T17/T18/T19 gaps preemptively to give Phase 6a a cleaner start:

- **SKILL.md**: added `## Track Progress` section, `~/.pmos/learnings.md` load line, `## Phase 7: Capture Learnings`. Fixed `docs/adrs/` → `docs/adr/` (matches the actual harness write path). Now 17/18 skill-eval [D] checks pass.
- **reference/l1-rationales.md**: added ToC at top (Convention C `c-reference-toc` was failing).
- **tools/check-determinism.sh**: switched to `--no-adr` so the determinism contract excludes ADR side effects (otherwise ADR-NNNN auto-increments between runs).
- **tests/run.sh**: fixed shellcheck SC2097/SC2098 — used explicit `export` for env passthrough.

## Decisions

- ADR side effects are **not** a determinism violation — they're correct monotonic-NNNN behaviour driven by what's on disk. `check-determinism.sh` uses `--no-adr` to assert pure-findings determinism.
- The `c-asset-layout` failure is genuine but tooling-driven (npx needs the package.json at the resolution root). Documented for Phase 6a accept-as-residual.
- Did NOT touch the SKILL.md description's trigger phrases or the frontmatter — those are stable from T17.

## Done when

All gates green except 1 [D] flagged to Phase 6a → **ready for Phase 6a /skill-eval**.
