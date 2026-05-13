# /verify --scope phase-6 — readme-skill

## Verdict
**PASS_WITH_RESIDUALS**

Combined per-task + phase-boundary review for Phase 6:
- **Wave 1** — T17 (commit-classifier.sh + 3 fixtures + selftest) + T18 (SKILL.md §7 update-mode flow). Disjoint files (scripts/+tests/ vs SKILL.md) → parallel-eligible per R9/P11.
- **Wave 2** — T19 (SKILL.md §8 opt-in dual gate). Single-task SKILL.md wave.

Phase-5-r3 (§1 cross-ref anchor mismatch) closed at T18 via the declared cosmetic 2-line anchor fix.

## Deterministic evidence

```
bash scripts/commit-classifier.sh --selftest 2>&1 | tail -5
  → 01_feat-only PASS (sections=[Features,Usage,Quickstart])
  → 02_no-conv-commit PASS (sections=[])
  → 03_breaking PASS (sections=[Changelog,Troubleshooting,Features,Usage,Quickstart,Migration])
  → 3 passed, 0 failed (of 3)                                ✓ 3/3

shellcheck scripts/commit-classifier.sh                      → SC1091 (info) on `. "$HERE/_lib.sh"` only ✓
wc -l SKILL.md                                               → 418 (≤480 ✓)
grep -c "FR-UP-3|patch_dropped|update.log" SKILL.md          → 4   (≥3 ✓)
grep -c "phase_7_6_hook_enabled|readme_update_hook|FR-UP-4|FR-UP-5" SKILL.md → 12 (≥4 ✓)
grep -c "^### §" SKILL.md                                    → 7   (§2-§8 ✓; §1 keeps T3-era bare header per phase-5-r3 carry — anchor itself now fixed)
```

**Phase-5-r3 closure:**
```
grep -c "#1-single-file-audit-flow" SKILL.md  → 0   ✓ (old broken anchor purged)
grep -c "#single-file-audit-flow"   SKILL.md  → 3   ✓ (lines 244 + 325 + new §7→§1 ref at 366)
```

## T17 / T18 / T19 spec-compliance

**T17 (`2780e86`, scripts/commit-classifier.sh ~165 LOC + 3 fixtures + .gitignore)** — FR-SS-3 commit_affinity wired: parses `<base>..HEAD` ranges, regex-classifies the 11 Conventional-Commit types (with optional `(scope)` + `!` bang-break), detects literal `BREAKING CHANGE:` footer in commit bodies, reads `commit_affinity` from `reference/section-schema.yaml` at runtime (single source of truth — no hardcoded mapping), emits `{range, commits[…], sections[union]}`. FR-UP-2 (E12) covered: no conventional-commit subjects → `{sections:[], warn:"no conventional-commit subjects"}` + stderr warn. Three deterministic fixtures (01_feat-only / 02_no-conv-commit / 03_breaking) with `setup.sh` materialisers, `.git/` gitignored. `--selftest` 3/3 PASS. No drift from FR-SS-3 / FR-UP-2 / §16 E12.

**T18 (`06b9357`, SKILL.md +43 / -2)** — `### §7: Update-mode flow` lands the 6-step runtime: (1) commit-classifier dispatch + JSON parse with E12 + E13 short-circuit; (2) per-section AskUserQuestion (Apply/Modify/Skip/Defer; ≤4 batch); (3) stage in working tree (no `git add`); (4) re-run §1 rubric on patched README; (5) **FR-UP-3 patch-fail guard** — on any blocker fail: `git checkout -- <readme>`, JSONL-append to `.pmos/readme/update.log`, `/retro` finding, release proceeds unpatched, observable chat-log line; (6) on pass, defer staging to §8. E13 (empty range) same as E12. No drift from FR-UP-1/2/3 / §16 E12-E13.

**T19 (`1b1d9a2`, SKILL.md +42 / -0)** — `### §8: Opt-in dual gate` lands FR-UP-4 + FR-UP-5: 2 flag reads (`~/.pmos/readme/config.yaml :: phase_7_6_hook_enabled` + `.pmos/complete-dev.lastrun.yaml :: readme_update_hook`), 6-row truth-table, single-line warn, re-enablement recipes for both flags, "why dual" rationale. FR-UP-5 staging-only contract: `git add` only — no `git commit`, no `git push`. No drift from FR-UP-4 / FR-UP-5.

## Quality

- §7 (6-step list) and §8 (truth-table + dual-flag rationale) read scannably; FR IDs cited at point-of-use.
- Cross-ref anchors verified:
  - `#single-file-audit-flow` (§1) → `### Single-file audit flow` line 132 ✓
  - `#4-mode-resolution` (§4)     → `### §4: Mode resolution` line 211    ✓
  - `#7-update-mode-flow` (§7)    → `### §7: Update-mode flow` line 327   ✓
  - `#8-opt-in-dual-gate` (§8)    → `### §8: Opt-in dual gate` line 368   ✓
- `commit-classifier.sh` shellcheck-clean save SC1091 info on the sibling `_lib.sh` source (same waiver as phase-1-r1).
- **P7 _lib.sh append-only invariant** — `git diff f241459 0f0c749 -- _lib.sh` empty; `git diff 0f0c749 1b1d9a2 -- _lib.sh` empty. ✓

## P11 append-only across Phase 6

| Diff range | Expected | Actual |
|---|---|---|
| T16→T18 SKILL.md deletions | 2 (anchor fix; declared cosmetic) | **2** ✓ both are `#1-single-file-audit-flow` → `#single-file-audit-flow` at L244 + L325 |
| T18→T19 SKILL.md deletions | 0 | **0** ✓ |
| Inlined block markers (4 lines) | byte-identical to T1 | **4** ✓ unchanged since T1 `d070a70` |

T18's 2-deletion exception is **declared in the T18 log as a phase-5-r3 closure** — purely cosmetic anchor surgery (8 chars each, `1-` prefix removal). NOT a P11 violation.

## Phase 6 done-when

Plan rationale: "wire the Phase 7.6 hook flow. commit-classifier.sh parses a commit range → impacted sections via section-schema commit_affinity. SKILL.md adds the update-mode flow + FR-UP-3 patch-fail guard + the dual opt-in gate (FR-UP-4)."

| Done-when clause | Status |
|---|---|
| commit-classifier parses range → sections via commit_affinity | **PASS** (selftest 3/3 + reads section-schema.yaml at runtime) |
| Update-mode flow in SKILL.md | **PASS** (§7 6-step + E12/E13) |
| FR-UP-3 patch-fail guard | **PASS** (§7 step 5) |
| FR-UP-4 dual opt-in gate | **PASS** (§8 6-row table) |
| (Implicit) FR-UP-5 staging-only | **PASS** (§8 `git add` only) |

Live `/readme --update` end-to-end is **PARTIAL by design (P9)** — AskUserQuestion + Task-tool wiring at T22+. Mirrors phase-4-r1 / phase-5-r1.

## Residuals delta

**Closed at Phase 6:** `[phase-5-r3]` — closed at T18 via 2-line cosmetic anchor fix.

**Carried unchanged:** `[phase-1-r1]`, `[phase-2-r1..r4]`, `[phase-3-r1..r4]`, `[phase-4-r1..r3]`, `[phase-5-r1, r2, r4]`.

**New Phase 6 residuals:** **None.** The "live --update unexercised" caveat is covered by the by-design P9 envelope already enumerated in phase-4-r1 / phase-5-r1.

## Recommendation
**PROCEED_TO_PHASE_7** — T20 / T21 / T22 cross-file rules R1-R4 + monorepo unified diff.
