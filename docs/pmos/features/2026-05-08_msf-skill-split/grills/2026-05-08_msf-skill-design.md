# Grill Report — /msf skill design

**Depth:** standard  •  **Questions asked:** 5  •  **Date:** 2026-05-08

## Resolved

- **Mode split** → Split into `/msf-req` (recommendations-only on req docs) and `/msf-wf` (grounded analysis on wireframe folders), with shared MSF heuristics in `_shared/`. Removes the `--wireframes` / `--skip-psych` / `--default-scope` flag soup.
- **Write authority** → Standalone runs are recommendations-only (terminal state = findings doc, like /grill). Writes to source artifacts allowed only when invoked by a parent skill (/requirements, /wireframes, /prototype) that owns the artifact and can re-validate.
- **Output volume** → Two-tier output: full persona × scenario × journey × consideration matrix saved uncapped to canonical findings doc; chat output is an executive summary (top friction, danger-zone screens, prioritized recommendations). Drop the 300-line cap on saved doc; keep on chat.
- **Save path** → Co-locate at `NN_<slug>/msf-findings.md` inside the pipeline feature dir, matching how /grill saves to `NN_<slug>/grills/`. Drop `docs/msf/`. For ad-hoc invocations outside a feature dir, fall back to `~/.pmos/msf/`.
- **PSYCH ownership** → Move PSYCH out of /wireframes Phase 6 into `/msf-wf`. /wireframes keeps its UX-rubric self-eval only. Eliminates duplication and the `--skip-psych` semantics entirely.

## Open / Deferred

- **Tier gating** — description claims "Tier 3 enhancer" but neither skill enforces it. Decide whether `/msf-req` should auto-skip / warn for Tier 1–2 requirements, or stay metadata-only.
- **PSYCH calibration** — 60/40/25 starting scores and `<20` / `<0` thresholds are admitted "not scientific" but emit hard warnings. Either calibrate against real examples or soften the threshold language to "directional."
- **Persona/journey caps** — Phase 1 says max 5 personas × 2 scenarios; Phase 2 has no journey cap. Consider a soft cap on journeys (e.g., 4) with "elaborate to add more" to keep matrix bounded.
- **Subagent serialization warning** — becomes moot under recommendations-only standalone mode. Keep only in `/msf-wf` parent-invoked write path.

## Gaps surfaced

- **`/msf-req` → /spec handoff contract** — define exactly what /spec reads from `msf-findings.md` (recommendations table format, severity field schema). Without a contract, /spec consumption is ad-hoc.
- **No "no-friction-found" exit** — current Phase 4 forces Must/Should/Nice grouping. Add explicit "no actionable findings" terminal state so a clean design isn't forced into manufactured recommendations.
- **`/msf-wf` PSYCH vs. /wireframes regenerate loop** — if /msf-wf surfaces danger-zone screens and triggers a /wireframes re-run, define whether /msf-wf re-runs after, and how to avoid infinite loops.
- **Description trigger phrases overlap with /wireframes Phase 7** — after the split, both skills' descriptions need disambiguation so triggering accuracy doesn't degrade.

## Recommended next step

1. Write a short ADR capturing the 5 resolutions above before touching code.
2. Sketch the `/msf-req` and `/msf-wf` SKILL.md structures and the shared `_shared/msf-heuristics.md`.
3. Coordinate with /wireframes to extract PSYCH (Phase 6 changes) — that's a coupled edit.
4. Run `/grill` again on the `/msf-wf` design once it's drafted; the /wireframes-coupling has its own decision tree.
