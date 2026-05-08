---
task_number: 5
task_name: "Rewrite /wireframes Phase 6 as thin wrapper; remove all PSYCH content"
task_goal_hash: T5-rewrite-wireframes-phase6
plan_path: "docs/features/2026-05-08_msf-skill-split/03_plan.md"
branch: "feature/msf-skill-split"
worktree_path: ".worktrees/msf-skill-split"
status: done
started_at: 2026-05-08T00:19:00Z
completed_at: 2026-05-08T00:35:00Z
files_touched:
  - plugins/pmos-toolkit/skills/wireframes/SKILL.md
---

# T5 — done

## Outcome

Replaced /wireframes Phase 6 (PSYCH walkthrough body) and old Phase 7 (inline /msf invocation) with a thin Phase 6 wrapper invoking `/msf-wf <folder> --apply-edits` and aborting on non-zero return.

File trimmed from 712 → 563 lines.

## Verification

- Zero stale tokens (`psych-findings`, `psych-output-format`, `--skip-psych`, standalone `--wireframes` flag) ✓
- Thin-wrapper invocation `/msf-wf {feature_folder}/wireframes --apply-edits` present ✓
- Abort-on-error language ("MUST NOT auto-continue to Phase 8") present (FR-39) ✓
- Tier 1 jump corrected to Phase 8 (Spec Handoff) per Loop 2 review fix ✓

## Deviations

Plan T5.4's verification (`grep -cE "PSYCH|psych-findings|psych-output-format" ... ≤2`) was too strict. Final grep count is 8, but every remaining mention describes the new architecture — the thin-wrapper title, body bullets explaining the delegated phase, the rigor-protocol pointer ("Phase 6 (MSF + PSYCH) is delegated to /msf-wf"), and 2 Spec-Handoff artifact pointers (`MSF + PSYCH: msf-findings.md`). FR-17's intent (no stale PSYCH content) is met. Verified instead with the stricter banned-token grep — zero matches.

Old Phase 7 deleted entirely; numbering Phase 8+ preserved (so the file has no Phase 7 — a deliberate gap rather than renumbering).

The Tier 1 anti-pattern "Do NOT skip Phase 7 on Tier 3 — MSF is mandatory" was removed alongside Phase 7 itself. Its intent (Phase 6 mandatory for Tier 2/3) is preserved in the kept "Do NOT skip Phase 6 on Tier 2 or Tier 3" entry.
