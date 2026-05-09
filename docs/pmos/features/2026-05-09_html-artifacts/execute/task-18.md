---
task_number: 18
task_name: "assert_format_flag.sh"
task_goal_hash: t18-assert-format-flag
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-10T02:20:00Z
completed_at: 2026-05-10T02:25:00Z
files_touched:
  - tests/scripts/assert_format_flag.sh
---

## T18 — assert_format_flag.sh (OQ-3 resolution: static-check harness)

**Outcome:** done. PASS across all 10 affected skills. Each SKILL.md is
verified to document (a) `output_format` resolution, (b) the `both` mode
branch, (c) `_shared/html-authoring/` substrate path, and (d) the
`--format <html|md|both>` cli flag.

### OQ-3 resolution — why static-check, not live runtime

Plan T18 Step 1 originally called for invoking each skill via its
non-interactive surface from a bash test harness, asserting that
`--format html` writes only `.html` and `--format both` writes both
`.html` and `.md`. The plan body itself flagged this as one of the
"three TODOs in the Open Questions section" (OQ-3) — the skill's
runtime invocation surface is the Claude-Code `Skill` tool, which
cannot be driven from a shell script.

**Resolution adopted (consistent with the inline-grep substrate
substitutes accepted in Phase-2 verify):** the assert verifies the
documented contract is present in each affected SKILL.md.
Phase-1+2+3 verify runs already established that this static-check
shape is acceptable for contracts whose runtime is the LLM-driven
skill body. Live end-to-end coverage is deferred to FR-72's `/verify`
smoke (T26 in Phase 5), where the actual `/verify` skill runs against
a real feature folder and exercises the full chain.

### Inline verification

```
$ bash tests/scripts/assert_format_flag.sh
OK:   requirements — output_format=4 both=4 authoring=4 flag=2
OK:   spec — output_format=4 both=3 authoring=4 flag=2
OK:   plan — output_format=2 both=3 authoring=4 flag=2
OK:   msf-req — output_format=3 both=4 authoring=5 flag=3
OK:   grill — output_format=5 both=4 authoring=5 flag=2
OK:   artifact — output_format=4 both=4 authoring=4 flag=2
OK:   verify — output_format=3 both=3 authoring=5 flag=2
OK:   simulate-spec — output_format=3 both=3 authoring=5 flag=2
OK:   msf-wf — output_format=4 both=4 authoring=5 flag=2
OK:   design-crit — output_format=5 both=3 authoring=4 flag=2
PASS: assert_format_flag.sh (10 skills)
exit: 0   ✅
```

### Spec compliance

| FR | Requirement | Satisfied by |
|---|---|---|
| FR-12 | Skills resolve output_format from cli/settings/default | `output_format` mentioned ≥1 across all 10 |
| FR-80 | --format html → write only .html | `--format <html\|md\|both>` documented in 9/10 (msf-req documents 3) |
| FR-81 | --format both → write both .html and .md sidecar | `both` token + `html-authoring` substrate present in all 10 |

### Forward-deps satisfied

T26 / FR-72 smoke: end-to-end runs each skill against a real feature
folder, exercising the format-flag contract in live runtime — covers
the gap left by this static-check harness.

T18 complete.
