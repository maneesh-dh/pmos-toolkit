---
task_id: 26
status: done
commits: [886f588122ccdf798926677ca169d9d613941a40]
verify_status: PASS_WITH_RESIDUALS
fr_refs: [G1, G3, FR-63, NFR-2]
residuals_closed: [phase-7-r1]
residuals_added: [phase-9-r1]
---

# T26 — Dogfood pass + phase-7-r1 close

## Summary

Authored `plugins/pmos-toolkit/skills/readme/tests/dogfood/run-dogfood.sh` —
the empirical G1 / G3 gate over this repo's READMEs. Per /plan Loop-1 F2
disposition, the script is **advisory: always exits 0**. /verify Phase 7 owns
the gate via `accepted_residuals[]`, mirroring the spec §13.5 + dogfood
follow-up A2/A4 residual pattern.

Also closed carried-residual **phase-7-r1** (R3 forward-cite anchor mismatch)
via a P11-safe **pure-add** in the reference doc rather than the planned
SKILL.md substring edit. See "Deviations" below for the rationale.

### Files created

- `plugins/pmos-toolkit/skills/readme/tests/dogfood/run-dogfood.sh`
  - Bash 3.2-safe (`set -euo pipefail`; no `mapfile`, no `<<<` heredoc-string,
    no associative arrays); `chmod +x`.
  - Target set: `$REPO_ROOT/README.md` + `$REPO_ROOT/plugins/pmos-toolkit/README.md`
    + up to 4 additional `$REPO_ROOT/plugins/*/README.md` ranked by mtime-desc
    (BSD `stat -f %m` / GNU `stat -c %Y` fallback). If <5 plugins exist, the
    script logs the shortfall and proceeds with what's available.
  - Invokes `scripts/rubric.sh` per target; counts `\tPASS\t` / `\tFAIL\t` TSV
    lines (rubric.sh may exit 1 on findings — output captured regardless).
  - Emits one `dogfood: <path> — pass=N fail=M` line per target, then the
    summary line `dogfood: G1 <status> (<pct>%) | G3 <status> (<n> findings)`.
  - Status values: `PASS` or `ADVISORY_FAIL — residual for /verify`.

### Files modified (pure-add only — P11 safe)

- `plugins/pmos-toolkit/skills/readme/reference/cross-file-rules.md` —
  inserted a single `<a id="r3-install-contributing-license-root-only"></a>`
  line immediately above the `## §R3` H2. **0 deletions** (pure-add).
  Closes phase-7-r1: the SKILL.md §9 forward-cite to
  `cross-file-rules.md#r3-install-contributing-license-root-only` now resolves
  to the §R3 section directly instead of landing at page-top.

## Deviations

1. **P11 (append-only) compliance — Option B-equivalent, not Option A.**
   The plan and the controller brief both name Option A (edit the SKILL.md
   anchor fragment in-place) as the "less disruptive" path. On re-checking
   P11 ("SKILL.md ## Implementation subsections are append-only across tasks
   ... No mid-subsection rewrites of prior tasks' content") and the Phase 7
   verify report ("Deferred to T26 dogfood polish pass to preserve Phase 7
   P11 append-only across **both SKILL.md and ref doc**"), a substring-edit
   that lengthens a URL fragment is a `-1 / +1` git diff — technically a
   mid-subsection rewrite. Selected the **pure-add anchor in the ref doc**
   (controller's "alternate path" example) instead:
   - SKILL.md unchanged in Phase 9 (P11 strict).
   - Ref doc gains one HTML anchor line above an existing H2 — 0 deletions.
   - SKILL.md §9's existing cite `cross-file-rules.md#r3-install-contributing-license-root-only`
     now resolves directly to the inserted `<a id>` anchor.
   - Evidence: `git diff 0a8f1ce HEAD -- SKILL.md | grep '^-' | grep -v '^---' | wc -l` → `0`.
   - Evidence: `git diff -- reference/cross-file-rules.md | grep '^-' | grep -v '^---' | wc -l` → `0`.

2. **G1 / G3 ADVISORY_FAIL is the expected real-world dogfood signal.**
   Only one plugin lives in `plugins/` (`pmos-toolkit`) and it has **no
   top-level README.md** — so the 6-target plan-spec set is unattainable on
   today's repo. Script output:

   ```text
   dogfood: NOTE — only 1/6 targets available (need root + pmos-toolkit + 4 more plugins). Proceeding with what exists.
   dogfood: README.md — pass=11 fail=4
   dogfood: NOTE — plugins/pmos-toolkit/README.md missing; G3 cannot be measured (treated as 0 findings).
   dogfood: G1 ADVISORY_FAIL — residual for /verify (73%) | G3 ADVISORY_FAIL — residual for /verify (0 findings)
   ```

   Per /plan Loop-1 F2 disposition this is **not a phase blocker**; the
   advisory residual is queued for /verify Phase 7 reconciliation per
   `accepted_residuals[]` — logged as **phase-9-r1** in the carry-forward
   list.

3. **T26 file-set narrower than briefed.** The controller brief permitted a
   single-line in-place SKILL.md edit "fine because T26 is the SKILL.md task
   in this phase per the plan." With the P11-safe pure-add path, SKILL.md is
   not touched — the file-set is the dogfood script (new) plus one anchor
   line in `reference/cross-file-rules.md`. /verify deterministic check
   on SKILL.md across the phase remains clean.

## Residuals closed

- **phase-7-r1** — R3 forward-cite in SKILL.md §9 (`cross-file-rules.md#r3-install-contributing-license-root-only`)
  now resolves to a real `<a id>` anchor in the ref doc. SKILL.md untouched.
  Evidence: `grep -n 'a id="r3-install-contributing-license-root-only"' plugins/pmos-toolkit/skills/readme/reference/cross-file-rules.md`
  returns line 64 (above the §R3 H2 at line 67).

## Residuals added

- **phase-9-r1** — Dogfood G1 (73%) and G3 (0 findings on missing
  `plugins/pmos-toolkit/README.md`) both ADVISORY_FAIL on the host repo:
  only 1 plugin exists (no 4 more) and that plugin has no top-level
  README.md. Per /plan Loop-1 F2 this is an advisory residual queued for
  /verify Phase 7 `accepted_residuals[]`. Resolution belongs to the
  maintainer (out-of-scope of T26 per plan: "findings are NOT applied in T26;
  that's a separate maintainer action").

## Inline verification

```text
$ chmod +x plugins/pmos-toolkit/skills/readme/tests/dogfood/run-dogfood.sh
$ bash plugins/pmos-toolkit/skills/readme/tests/dogfood/run-dogfood.sh
dogfood: NOTE — only 1/6 targets available (need root + pmos-toolkit + 4 more plugins). Proceeding with what exists.
dogfood: README.md — pass=11 fail=4
dogfood: NOTE — plugins/pmos-toolkit/README.md missing; G3 cannot be measured (treated as 0 findings).
dogfood: G1 ADVISORY_FAIL — residual for /verify (73%) | G3 ADVISORY_FAIL — residual for /verify (0 findings)
EXIT=0

$ shellcheck plugins/pmos-toolkit/skills/readme/tests/dogfood/run-dogfood.sh
EXIT=0

$ bash plugins/pmos-toolkit/skills/readme/tests/run-all.sh
[/readme] run-all: 4 scripts + 9 integration tests = 13 passed
EXIT=0

$ bash plugins/pmos-toolkit/skills/readme/scripts/rubric.sh --selftest
[/readme] selftest: PASS (15 checks; A2 agreement 100% on 10 fixtures)
EXIT=0

# P11 invariant — 0 deletions on both files this phase:
$ git diff 0a8f1ce HEAD -- plugins/pmos-toolkit/skills/readme/SKILL.md | grep '^-' | grep -v '^---' | wc -l
0
$ git diff -- plugins/pmos-toolkit/skills/readme/reference/cross-file-rules.md | grep '^-' | grep -v '^---' | wc -l
0
```

R9 / P11 invariant: SKILL.md not touched by T26. Anchor fix routed via
pure-add to ref doc per controller's alternate path.
