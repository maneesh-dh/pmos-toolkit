---
task_id: 24
status: done
commits: [9f7e7e457dea2100de578f21092401950b1b7352]
verify_status: PASS
---

# T24 — SKILL.md §11 Voice delegation

## Summary

Appended `### §11: Voice delegation` to `plugins/pmos-toolkit/skills/readme/SKILL.md` (inserted between §10 and `## Anti-Patterns`). Covers:

- **FR-V-2** — non-blocking `Suggest: /polish ...` chat line on every successful audit/scaffold/update run (§6, §7).
- **FR-V-3** — voice-drift gate on /polish round-trip via `scripts/voice-diff.sh` (forward-cite: ships in T23, parallel Wave 1). Thresholds: `sentence_len_delta_pct < 15` AND `jaccard_new_tokens >= 0.7`. On fail: chat warn + AskUserQuestion prefixed `<!-- defer-only: ambiguous -->` (Accept/Reject/Show diff).
- **FR-V-4** — substrate-absent graceful warn: if /polish substrate missing, voice-diff.sh falls back to built-in tokenizer with stderr warn; gate never blocks on missing substrate.
- Worked example (single-line compact format) + cross-cites to §6/§7.

Append-only edit (R9/P11 invariant): zero existing lines removed.

## Verification

```
=== wc -l ===
477
=== FR-V-[234] count ===
4
=== voice-diff/polish count ===
9
=== §11 H3 count ===
1
=== §11 H3 line ===
457:### §11: Voice delegation
=== §11 range ===
457-468
=== P11 removed lines ===
       0
```

All gates green: wc=477 ≤ 480 cap; FR-V-[234]=4 ≥ 3; voice-diff.sh|/polish=9 ≥ 3; §11 H3 exactly once; P11 removed-lines = 0 (append-only).

Pre-edit SHA: `d482f7141bdbec7ed42524c44ad1763d62aa108a`
Post-edit commit: `9f7e7e457dea2100de578f21092401950b1b7352`

## Residuals / Deviations

- **Forward-cite to T23** — §11 references `scripts/voice-diff.sh`, which lands in T23 (parallel Wave 1, sibling task). Dangling-until-T23-lands per the established Phase 5/Phase 7 forward-cite pattern; resolves at Wave 1 boundary review when both T23 + T24 commits are in.
