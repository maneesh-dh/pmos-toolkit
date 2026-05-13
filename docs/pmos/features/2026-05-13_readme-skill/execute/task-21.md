---
task_number: 21
status: done
commit_sha: 374de278c09b157d41b470aad9edb6652478790c
dangling_cross_refs:
  - "reference/cross-file-rules.md (and #r1-link-existence, #r2-link-up-presence, #r3-install-contributing-license-root-only, #r4-no-duplicate-hero-text anchors) — closes when T20 lands"
deviations: []
inline_verification: PASS
p11_removed_lines: 0
---

Appended `### §9: Cross-file rules (monorepo)` to SKILL.md `## Implementation` (after §8, before `## Anti-Patterns`). 13 inserted lines, 0 removed — P11 append-only honored. SKILL.md now 431 lines (under 480 cap).

Rule shape: compact 4-row table (R1–R4) with scope / detection / auto-fix-path columns, forward-cited to `reference/cross-file-rules.md` per-rule anchors (dangling until T20 merges in this wave). R1 prompt tagged `<!-- defer-only: ambiguous -->`; R3 variance prompt tagged `<!-- defer-only: free-form -->`. R4 is friction-only (no auto-fix — voice-sensitive). Closing paragraph wires the pass into §1 audit + §6 scaffold flows and notes the `package_variance` ledger persists across runs.

Inline verification: `grep -c "R1\|R2\|R3\|R4"` = 5 (≥4 PASS); `grep -c "package_variance"` = 2 (≥1 PASS). No rubric.yaml / rubric.sh / state.yaml / 00_pipeline.html touched.
