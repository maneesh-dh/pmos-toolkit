# Task T18 — Update-mode flow + FR-UP-3 patch-fail guard

**Status:** ✅ Sealed
**Commit (T18):** `06b9357`
**Phase:** 6
**Files touched:** `plugins/pmos-toolkit/skills/readme/SKILL.md` (only)
**Lines:** 335 → 376 (+43 insertions / -2 deletions)

## What was done

### (a) §7: Update-mode flow appended

Appended a new `### §7: Update-mode flow` subsection to `## Implementation`, positioned between §6 (Scaffold flow) and `## Anti-Patterns`. The section codifies the 6-step update-mode runtime per FR-UP-1/UP-2/UP-3 and the E12/E13 edge paths:

1. Classify the commit range via `scripts/commit-classifier.sh` (T17).
2. Per-section `AskUserQuestion` (Apply / Modify / Skip / Defer; ≤4 batch).
3. Stage patches in working tree (no `git add`).
4. Re-run rubric on patched README (§1).
5. **FR-UP-3 patch-fail guard** — on any blocker fail: revert working tree, JSONL-append to `.pmos/readme/update.log`, emit /retro finding, release proceeds unpatched.
6. On rubric pass: file remains on disk; staging deferred to §8.

E12 (no conventional-commit subjects) and E13 (empty range) short-circuit with chat warn + exit 0.

### (b) Phase-5-r3 cosmetic anchor fix (declared deviation)

Replaced TWO occurrences of broken GitHub-auto-slug anchor `(#1-single-file-audit-flow)` with the correct slug `(#single-file-audit-flow)`:

- Line 244 (§4 → §1 cross-ref)
- Line 325 (§6 → §1 cross-ref)

GitHub's markdown anchor auto-slug strips the leading `§N: ` prefix (and digits) before applying its slug algorithm; `### §1: Single-file audit flow` produces slug `single-file-audit-flow`, not `1-single-file-audit-flow`. The two pre-existing links pointed to a non-existent target.

## P11 append-only — declared deviation

**The 2-line anchor fix is the only modification to existing §1-§6 content.** It is:

- Cosmetic — does not change any substantive content of §1-§6.
- Surgical — touches exactly 2 link targets (8 characters each: `1-` prefix removed).
- A bug fix — restores intra-document navigation that was broken at the spec-text level.

Verification of P11 footprint:

```
$ git diff 0b8c5cc -- SKILL.md | grep '^-' | grep -v '^---' | wc -l
2
```

The two `-` lines are paired with `+` lines that differ only in the anchor slug. All other diff hunks are pure additions (§7 content).

This is declared as a **deviation, not a P11 violation** — P11's intent is "stable content of sealed sections"; an anchor that points to nowhere is not stable navigation in any meaningful sense.

## Verification

```
$ wc -l plugins/pmos-toolkit/skills/readme/SKILL.md
376  # ≤ 480 cap

$ grep -c "#1-single-file-audit-flow" SKILL.md
0    # broken anchor eliminated

$ grep -c "#single-file-audit-flow" SKILL.md
3    # 2 fixed + 1 new §7 self-ref

$ grep -c "FR-UP-3\|patch_dropped\|update.log" SKILL.md
4    # ≥ 3 required by plan grep
```

Inlined non-interactive-block and pipeline-setup-block: untouched.

## Deviations

1. **2-line anchor fix in §4 and §6 cross-refs.** Cosmetic; restores broken intra-document navigation; declared above. Not a content change.

No other deviations.
