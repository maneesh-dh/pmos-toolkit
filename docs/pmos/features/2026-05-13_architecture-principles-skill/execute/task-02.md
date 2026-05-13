---
task_number: 2
task_name: "principles.yaml schema + plugin L1+L2 file"
task_goal_hash: "sha256:t2-plugin-principles-yaml-18-rules-u001-u010-ts001-ts004-py001-py004"
plan_path: "docs/pmos/features/2026-05-13_architecture-principles-skill/03_plan.html"
branch: "feat/architecture-principles-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-architecture-principles-skill"
status: done
started_at: 2026-05-13T00:01:00Z
completed_at: 2026-05-13T00:01:30Z
files_touched:
  - plugins/pmos-toolkit/skills/architecture/principles.yaml
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/schema-valid/principles.yaml
  - plugins/pmos-toolkit/skills/architecture/tools/run-audit.sh
commit: 92429c6
---

## Summary

Plugin-owned `principles.yaml` shipped with all 18 rules from spec §7.4: 10 L1 universal (U001–U010), 4 L2 ts (TS001–TS004 → dependency-cruiser), 4 L2 py (PY001–PY004 → ruff). Every rule satisfies the FR-12 shape with non-empty `source:` (D9). Fixture copy at `tests/fixtures/schema-valid/principles.yaml`. `run-audit.sh` gained a yaml-parse validator stub (T3 wires the real loader).

## TDD red → green

- **Red:** `test -f principles.yaml` → absent.
- **Green:** Authored 18 rules; 6 inline assertions PASS (total=18, L1=10, L2-ts=4, L2-py=4, all required fields present, all sources non-empty).

## Runtime evidence

- `python3 -c "import yaml; rs=yaml.safe_load(open('plugins/pmos-toolkit/skills/architecture/principles.yaml'))['rules']; print(len(rs))"` → `18` ✓
- L1 count: 10 ✓ (cap 15 satisfied per FR-21)
- L2/ts count: 4 ✓
- L2/py count: 4 ✓
- All sources non-empty: ✓
- All FR-12 fields present on every rule: ✓
- Validator stub passes on shipped file: `run-audit.sh tests/fixtures/tracer/` exit 0, 1 finding.
- Validator stub fails on malformed YAML: `RUN_AUDIT_PLUGIN_YAML=/tmp/bad.yaml run-audit.sh ...` → exit 64, stderr `ERROR: plugin principles.yaml at /tmp/bad.yaml failed to parse: <parser-error>`.

## Decisions / deviations

- **`check:` field uses a compact pseudo-DSL** (`regex:...`, `function_loc_gt:100`, `depcruise:no-circular`, `ruff:F401`) rather than embedding full executable code. The scanner phases (T5–T8) and tool-delegation phases (T9–T11) parse this DSL — keeps `principles.yaml` readable and tool-agnostic. Spec FR-12 says only "<tool-specific config or regex>", so the DSL is in-contract.
- **U005 git-blame age** encoded as `regex:TODO|FIXME|XXX;blame_older_than_days:90` — the regex finds candidate lines; T6 (debug/hygiene grep batch) will run `git blame --porcelain -L <line>,<line>` on each hit and filter by author-time. Captured as a follow-up detail; no behavioural divergence from spec.
- **Added python3 gate at the top of `run-audit.sh`** alongside the existing jq gate (R2 / FR-23 spirit). The loader (T3) requires `python3 + yaml`; surfacing the dependency early keeps later phases simpler.
- **Removed `requirements.txt`-glob trick** from the gate — kept the simple `command -v python3` check; PyYAML availability is asserted indirectly by the first `yaml.safe_load` call.

## Verification outcome

PASS. Schema validates; L1 cap satisfied; validator stub red/green confirmed; commit `92429c6` lands cleanly.
