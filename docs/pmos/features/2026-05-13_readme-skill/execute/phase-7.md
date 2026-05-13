---
phase_number: 7
phase_name: "Cross-file rules"
tasks_in_phase: [20, 21, 22]
plan_path: "docs/pmos/features/2026-05-13_readme-skill/03_plan.html"
branch: "feat/readme-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-readme-skill"
status: sealed
started_at: 2026-05-13T20:30:00Z
completed_at: 2026-05-13T22:30:00Z
verify_status: PASS_WITH_RESIDUALS
verify_reports:
  - "docs/pmos/features/2026-05-13_readme-skill/verify/2026-05-13-phase-7/report.md"
commits:
  - f63fa52  # T20 feat — cross-file-rules.md R1-R4 + A9 design-time results
  - 88732e9  # T20-log
  - 374de27  # T21 feat — SKILL.md §9 cross-file rules table
  - 07ef891  # T21-log
  - d482f71  # T22 feat — SKILL.md §10 monorepo audit-all flow + FR-OUT-1 + D15
  - 403e361  # T22-log
recommendation: PROCEED_TO_PHASE_8
waves:
  - wave: 1
    tasks: [20, 21]
    parallel: true
    review_style: "combined per-task + phase-boundary (disjoint files: reference/cross-file-rules.md vs SKILL.md)"
  - wave: 2
    tasks: [22]
    parallel: false
    review_style: "combined per-task + phase-boundary (single-task SKILL.md wave)"
residuals:
  - "[phase-7-r1] R3 forward-cite anchor mismatch (cosmetic; deferred to T26 polish)"
---

## Summary

Phase 7 closes the cross-file rules + monorepo composition vertical:

- **T20** lands `reference/cross-file-rules.md` (177 lines) — R1-R4 detection / auto-fix / clarity-test per FR-CF-1..4 + A9 methodology + summary table. R1/R2/R4 binary PASS; R3 3-valued PASS via package_variance override.
- **T21** lands `### §9: Cross-file rules (monorepo)` — 4-row rule table (scope / detection / auto-fix path) with forward-cites to cross-file-rules.md anchors. P11 strict: 0 deletions.
- **T22** lands `### §10: Monorepo audit-all flow` — full FR-OUT-1 + D15 envelope: `--scope` argv parsing → workspace-scope AskUserQuestion → per-pkg iteration → roll-up → unified diff with `=== package: <name> (audit|scaffold) ===` headers → atomic multi-write rollback → final user approval. P11 strict: 0 deletions.

SKILL.md at 465 / 480 lines (plan target met). P11 append-only verified across both waves: 0 deletions on either T20→T21 or T21→T22 SKILL.md diffs.

## Demoability

Cross-file rules are now contract-complete at the doc-and-table layer. The `--scope` argv path is plumbed through §10 with the full audit-all composition that wires per-pkg iteration through §1 (audit) + §3 (scaffold) + §7 (update) + §9 (cross-file). The D15 unified-diff envelope previews all changes before any write; atomic multi-write rollback preserves repo integrity on partial-apply failure.

Live end-to-end runtime exercise of `/readme --scope all` against a real monorepo lands at T25 (integration tests) and T26 (dogfood). Phase 7's contract-level closures (phase-3-r2 / phase-4-r1 / phase-4-r2 / phase-5-r1 / phase-5-r4) honor the by-design P9 envelope — the live Task-tool + AskUserQuestion + repo-miner dispatches are now composed through §10, with runtime validation deferred to T25/T26.

## Deviations declared in waves

- **Wave 1 (T20)**: None. Clean ref-doc creation; no SKILL.md touch.
- **Wave 1 (T21)**: One cosmetic anchor-drift: the R3 forward-cite `#r3-install-contributing-license-root-only` misses the `-warn-with-override` tail that GitHub auto-generates from the T20 H2 header `## §R3 Install/Contributing/License root-only (warn-with-override)`. Cite still navigates to the doc (just lands at the page-top rather than the §R3 section). Logged as **phase-7-r1** and deferred to T26 dogfood polish pass — fix is 1 line on either side, but applying it now would either (a) edit a sealed Phase 7 commit retroactively (T20) or (b) consume a Phase 7 commit slot for an 8-char cosmetic edit. T26 batches all cosmetic README polish.
- **Wave 2 (T22)**: None. Clean SKILL.md append.
- Review style: Wave 1 disjoint-files (T20 in `reference/`; T21 in SKILL.md) → combined per-task + phase-boundary reviewer per wave. Wave 2 single-task SKILL.md → same combined style.

## Next phase

**Phase 8 — Voice delegation (T23 / T24).** T23 lands the `scripts/voice-diff.sh` voice-vs-content separator (FR-V-1) with `--selftest`. T24 lands `### §11: Voice delegation` SKILL.md flow (FR-V-2/3) — handoff to `/polish` for hero/tagline copy with the "no auto-fix on voice-sensitive findings" R4 contract feeding the friction-only surface. Closes the FR-V-* envelope before T25 (integration tests) + T26 (21-alias dogfood).
