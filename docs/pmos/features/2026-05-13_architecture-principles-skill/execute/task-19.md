---
task_number: 19
task_name: "Gate tools — check-citations.sh, check-gap-map.sh, check-determinism.sh"
task_goal_hash: t19-gate-tools-fr24-fr34-nfr02
plan_path: "docs/pmos/features/2026-05-13_architecture-principles-skill/03_plan.html"
branch: "feat/architecture-principles-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-architecture-principles-skill"
status: done
started_at: 2026-05-13T00:35:00Z
completed_at: 2026-05-13T00:38:00Z
files_touched:
  - plugins/pmos-toolkit/skills/architecture/tools/check-citations.sh
  - plugins/pmos-toolkit/skills/architecture/tools/check-gap-map.sh
  - plugins/pmos-toolkit/skills/architecture/tools/check-determinism.sh
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/citations-missing/principles.yaml
---

## Outcome

3 gate scripts authored + 1 negative fixture for the citations gate.

- `tools/check-citations.sh [yaml]` — exit 0 if every rule has non-empty `source:`, exit 1 + offender list to stderr otherwise. Exit 64 on usage error.
- `tools/check-gap-map.sh [yaml]` — computes `delegated_pct = (rules with delegate_to != grep) / total`. Exits 0 always (report-only; G2 stretch framing per spec §7.4 / D13).
- `tools/check-determinism.sh <scan-root>` — runs `tools/run-audit.sh` twice (with 1s gap), strips ephemeral run fields (id, started_at, finished_at, duration_ms), and diffs. Exit 0 if byte-identical; exit 1 + diff on stderr otherwise.

All three scripts: exit 0 = pass, exit 1 = fail, exit 64 = usage (per FR-84).

## Verification

```
shipped principles.yaml         → check-citations: OK: all 18 rules cite a source. exit=0
citations-missing fixture       → check-citations: FAIL 1 rule(s) missing... U001 listed. exit=1
shipped principles.yaml         → check-gap-map: 8/18 delegated, ratio=0.444 (G2 stretch). exit=0
tracer/src fixture              → check-determinism: byte-identical across 2 runs. exit=0
```

All four lines pass — failing-test → passing-test cycle observed (citations fails against the negative fixture, passes against shipped).

## Decisions

- `delegated_pct` excludes `grep` and empty/None delegates. Counts third-party linters (dep-cruiser, ruff) only.
- Determinism strips `run.id`, `run.started_at`, `run.finished_at`, `run.duration_ms` only — these are the four ephemeral fields documented in the run-audit.sh report-emitter (T16). Findings are sorted by (file, line, rule_id) per FR-73 so the rest is deterministic by construction.
- 1s sleep between runs makes wall-clock divergence observable; without it the two runs might share a started_at second and the strip would mask a real bug.
