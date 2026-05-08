# Per-Skill Non-Interactive Rollout — Runbook

> Stub written in T6. Full procedure authored in T15.

## Pilot Findings (T6 on /requirements)

- AskUserQuestion call count from awk extractor: **16** (after inlined-block skip; raw was 20 — 4 false positives inside the canonical block were eliminated)
- Unmarked count after block insertion only (no destructive tagging yet): **16**
- Block size inserted: **62 lines** (after awk-extractor skip-region addition)
- Frontmatter argument-hint extension worked: **yes** (`[--non-interactive | --interactive]` appended)
- Phasing ordering (block goes immediately after pipeline-setup-block): **confirmed**

## Plan deviations surfaced during T6

1. **Refusal-marker grep was too loose.** Both `lint-non-interactive-inline.sh` and `audit-recommended.sh` originally grepped `<!-- non-interactive: refused` anywhere in the SKILL.md. The inlined non-interactive-block contains a prose mention of that exact substring (item 6 of the canonical block), so the grep marked every rolled-out skill as "refused", excluding it from lint and exempting it from audit. **Fix:** tightened grep to `^[[:space:]]*<!-- non-interactive: refused` so only on-its-own-line markers count.

2. **Awk extractor matched its own self-references.** The canonical awk extractor regex `/AskUserQuestion/` matched the literal `AskUserQuestion` substring inside the inlined non-interactive-block (4 occurrences in instructions and the awk extractor's own comments). **Fix:** added skip rules at the top of the awk script for `<!-- non-interactive-block:start -->` / `<!-- non-interactive-block:end -->`, ignoring everything between them. SKILL.md prose outside the inlined block is unchanged.

Both fixes will need to apply to all subsequent per-skill rollouts (T16–T39) and are reflected in the canonical `_shared/non-interactive.md` already.
