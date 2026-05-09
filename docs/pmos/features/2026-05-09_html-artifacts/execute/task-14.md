---
task_number: 14
task_name: "/diagram blocking Task-subagent invocation pattern in /spec + /plan"
task_goal_hash: t14-diagram-subagent-pattern
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-10T01:10:00Z
completed_at: 2026-05-10T01:15:00Z
files_touched:
  - plugins/pmos-toolkit/skills/spec/SKILL.md
  - plugins/pmos-toolkit/skills/plan/SKILL.md
---

## T14 — /diagram subagent pattern

**Outcome:** done. Canonical `/diagram` blocking-Task-subagent invocation
pattern documented in /spec (full block, ~28 lines, in Phase 5 Write the
Spec section between Heading IDs and Tier 1 Template). Cross-referenced
shorthand in /plan (Execution-order section, after the FR-25 Mermaid
block instructions).

### Edits applied

**`/spec/SKILL.md` Phase 5:** new `### Diagram Emission via /diagram
Subagent (FR-60..FR-65, D2)` subsection covering:
- Per-diagram dispatch (Task tool, blocking, 300s timeout, args block)
- Retry loop (2 retries, 3 attempts total)
- Inline-SVG fallback after 3 failures
- Wall-clock cap (1800s = 30 min) via `diagram_subagent_state` accumulator
  with fields `{elapsed_s, attempts, cap_hit}`; resets per /spec invocation
- Provenance: 3 figcaption variants (subagent-success / inline-fallback /
  cap-hit-fallback)

**`/plan/SKILL.md` Execution-order section:** 1-paragraph cross-reference
pointing to /spec's canonical block (per plan task description, /plan
edits are "minimal — /plan rarely emits diagrams"). Cites same FRs and
the wall-clock-cap accumulator.

### Inline verification

```
$ grep -c "300s" /spec/SKILL.md      # 1   ✅ (plan: ≥1)
$ grep -c "300s" /plan/SKILL.md      # 1   ✅
$ grep -c "inline-SVG" /spec        # 1   ✅
$ grep -c "inline-SVG" /plan        # 1   ✅
$ grep -c "30 min\|30-min\|1800" /spec  # 2   ✅
$ grep -c "30 min\|30-min" /plan        # 1   ✅
$ grep -c "diagram_subagent_state" /spec /plan  # 1 each   ✅
$ grep -c "<figcaption>" /spec      # 4   ✅ (3 provenance variants + figure example)
$ python3 plugins/pmos-toolkit/skills/diagram/tests/run.py
  ... PASS — all fixtures match snapshots and defect expectations
  exit: 0   ✅ (plan target: /pmos-toolkit:diagram --selftest exit 0)
```

### Spec compliance

| FR | Requirement | Satisfied by |
|---|---|---|
| FR-60 | /diagram dispatched as blocking Task subagent | /spec block: "blocking: true" + "blocking Task subagent" prose |
| FR-61 | Args: --theme technical --rigor medium --out ... --on-failure exit-nonzero | Verbatim args block in /spec |
| FR-62 | Per-call 300s timeout + 2 retries (3 attempts) | "Retry loop" paragraph |
| FR-63 | Inline-SVG fallback after 3 failures | "Inline-SVG fallback" paragraph |
| FR-64 | Per-skill-run 30min wall-clock cap with accumulator | "Wall-clock cap" paragraph + diagram_subagent_state schema |
| FR-65 | <figcaption> provenance | 3 figcaption variants documented |
| D2 | Blocking subagent (vs fire-and-forget) | "Per spec D2 the blocking-subagent shape (vs. fire-and-forget) is required..." |

### Plan-Phase 3 status

T12 ✅ T13a ✅ T13b ✅ T14 ✅ — Plan-Phase 3 (Reviewer + /diagram migration)
4/4 COMPLETE. Phase 2.5 boundary fires next: /verify --scope phase
--feature 2026-05-09_html-artifacts --phase 3.

T14 complete.
