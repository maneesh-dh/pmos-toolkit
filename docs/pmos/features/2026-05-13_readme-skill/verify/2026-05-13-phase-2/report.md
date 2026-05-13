# /verify --scope phase-2 — readme-skill

## Verdict
**PASS**

Combined T7 per-task (spec + quality) + Phase 2.5 boundary review.

## Deterministic evidence

**Selftest A2 gate:**
```
strong 01..05: PASS=13/15 [AGREE]   (×5)
slop   01..05: PASS=7/15  [AGREE]   (×5)
[/readme] selftest: 10/10 fixtures agree (100%)
[/readme] selftest: PASS (15 checks; A2 agreement 100% on 10 fixtures)
exit 0
```

**Shellcheck -x:** only SC1091 info (acceptable convention).

**Variant warn-and-skip:**
- `--variant monorepo-root` → 2 warns (contents-table-presence, per-package-link-table)
- `--variant plugin` → 1 warn (plugin-manifest-mentioned)

**Auto-apply:** `~~blazing fast~~`, `~~robust~~`, `~~production-ready~~` strikethrough applied; re-run shows `no-banned-phrases PASS`.

**Demoable:** `rubric.sh strong/01 --variant library | grep -c PASS` → **13** (≥12 required).

## T7 spec-compliance (15/15)

All 15 `check_*` functions implement their rubric.yaml `pass_when` contract correctly:
hero-line-presence, install-or-quickstart-presence (widened to Download), what-it-does-in-60s (BSD-awk-compatible boundary), no-banned-phrases (strikethrough-aware), tldr-fits-screen, code-example-runnable-as-shown (vacuous-pass when no block), links-resolve, no-marketing-hyperbole, sections-in-recommended-order (subsequence, non-spine ignored), contributing-link-or-section, license-present, badges-not-stale, anchor-links-resolve (GitHub-style slug), image-alt-text, line-length-soft-cap.

## T7 code-quality

| Dimension | Verdict |
|---|---|
| Bash 3.2 portability | PASS (no `declare -A`, no `${var^^}`, no `read -d`, no `mapfile`, no `[[ -v ]]`; heredoc + IFS-read used) |
| Error handling | PASS (`set -euo pipefail`; `readme::die` for usage; safe subshells) |
| `_lib.sh` append-only invariant | PASS (T2's lines 1-4 byte-identical; `readme::yaml_get` at lines 6-36) |
| Shellcheck | PASS (only SC1091 info) |
| Path portability | PASS (all paths via `$HERE` or relative; no hardcoded absolutes) |

## Phase 2 done-when (9/9)

1. rubric.yaml 15 checks (4/7/4) + 14 banned + 7 variants — PASS
2. section-schema.yaml 7-spine + commit_affinity + variants — PASS
3. opening-shapes.md 5-block + map+identity — PASS
4. rubric.sh applies 15 checks + variant + auto-apply + selftest — PASS
5. _lib.sh append-only + yaml_get — PASS
6. 5+5 fixture corpus — PASS
7. Demoable ≥12/15 on library — PASS (13/15)
8. A2 ≥85% — PASS (100%)
9. SKILL.md untouched by T7 — PASS (`git show 66efe39 --name-status` confirms)

## Fixture coverage gaps (residuals)

| Check | Has slop calibration? |
|---|---|
| badges-not-stale | NO — narrow regex `cacheSeconds=-1` not exercised. Carry to T26 dogfood. |

All other 14 checks have ≥1 slop fixture that triggers the FAIL.

## Residuals carried forward

1. **rubric.yaml `pass_when` doc-impl drift** on `install-or-quickstart-presence` — impl widened to accept `Download` heading; YAML prose still narrow. Reconcile in T26 or /verify Phase 7.
2. **`_lib.sh` header comment** still says "Bash ≥ 4 required" — actual code is 3.2-safe. Update in T26.
3. **`badges-not-stale` lacks slop fixture** with `cacheSeconds=-1` URL. T26 dogfood candidate.
4. **`plugin-manifest-mentioned`** added by plugin variant but check undefined — intentional warn-and-skip per plan (deferred impl to T21).

## Recommendation
**PROCEED_TO_PHASE_3**

Phase 3 = T8/T9/T10 (workspace-discovery.sh + 8 manifests + MS01 multi-stack + 20-fixture self-test).
