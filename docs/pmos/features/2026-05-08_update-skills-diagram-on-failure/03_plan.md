# /diagram `--on-failure` flag — Implementation Plan

**Date:** 2026-05-08
**Spec:** none (Tier 1 — direct from requirements)
**Requirements:** `docs/pmos/features/2026-05-08_update-skills-diagram-on-failure/01_requirements.md`
**Tier:** 1
**Mode:** non-interactive

---

## Overview

Add a `--on-failure {drop|ship-with-warning|exit-nonzero}` flag to the `/diagram` SKILL.md so non-interactive Phase 6.5 disposition becomes deterministic. Interactive mode is unchanged. Verification is grep-based assertions over the edited SKILL.md plus the existing non-interactive audit toolchain.

**Done when:** SKILL.md frontmatter advertises the flag; Phase 0 parses it; Phase 6.5 documents the three-value dispatch + exit codes (3/0/4); SKILL.md contains an explicit Exit-Code contract table; the existing `tools/audit-recommended.sh` and `tools/lint-non-interactive-inline.sh` still report green; a runbook entry under `plugins/pmos-toolkit/tests/non-interactive/per-skill-rollout-runbook.md` documents the new flag.

**Execution order:**
```
T1 (frontmatter + Phase 0 parse)
  └─ T2 (Phase 6.5 dispatch + Exit-Code contract)
       └─ T3 (regression assertions: grep checks via bats)
            └─ T4 (audit/lint regression check)
                 └─ T5 (runbook + final verification)
```

---

## Decision Log

| # | Decision | Options Considered | Rationale |
|---|----------|--------------------|-----------|
| D1 | Use `bats` grep assertions over SKILL.md instead of pytest behavior tests | (a) pytest E2E (impractical — `/diagram` is LLM-driven prose; no programmatic harness), (b) bats grep over SKILL.md (matches existing `tools/lint-*.sh` + `tests/non-interactive/*.bats` pattern), (c) skip regression tests entirely | The repo already uses bats for SKILL.md contract assertions (parser.bats, lint-script.bats, audit-script.bats). Aligns the new tests with the established pattern. pytest behavior tests would require a fake skill-runner harness that doesn't exist. |
| D2 | Single SKILL.md edit task (T2) instead of splitting argument-hint, Phase 0, Phase 6.5 into 3 tasks | (a) Three small tasks (one per surface), (b) Single coherent SKILL.md edit task | The change is conceptually atomic — adding one flag's contract. Splitting would force partial-state intermediate commits where the flag is parsed but never honored, which is worse (looks like a bug). T1 splits out the frontmatter+parse-step boilerplate (cheap intro) and T2 does the Phase 6.5 dispatch (the substantive change). |
| D3 | Tag Phase 6.5's existing AUQ with `<!-- non-interactive: handled-via on-failure-flag -->` instead of removing `<!-- defer-only: ambiguous -->` outright | (a) Remove tag, (b) Keep `defer-only` tag (misleading), (c) Replace with explanatory comment | Per requirements doc D3. Future readers (and the `audit-recommended.sh` script) need a clear signal that this AUQ is interactive-only by design. The audit script accepts either `defer-only` or recommended-option presence; we'll keep the AUQ unchanged on the option side and rely on the explanatory comment for human readers. |
| D4 | Sidecar is NOT written on `drop` or `exit-nonzero` | (a) Write stub failure-sidecar in both, (b) Skip sidecar in both | Per requirements doc D4. Spec doesn't require it; `/rewrite` consumes exit code as the signal. Avoids accidental writes that might be mistaken for valid output. |
| D5 | Default `--on-failure` to `exit-nonzero` (not `ship-with-warning`) when `--non-interactive` is set | (a) `ship-with-warning` (current prose-fallback), (b) `exit-nonzero` (caller-decides) | Per requirements doc D1. Matches spec §2 default. Preserves the safest behavior for unconfigured automated callers. |

---

## Code Study Notes

- **`/diagram` SKILL.md structure**: 417 lines. Phase 0 (lines 43–164) includes both the per-skill arg-parse step and the inlined `<!-- non-interactive-block -->` (lines 80–163, byte-for-byte canonical from `_shared/non-interactive.md`). The non-interactive block is enforced by `tools/lint-non-interactive-inline.sh` — DO NOT edit that block.
- **Phase 6.5 source** (lines 347–365): contains a single `<!-- defer-only: ambiguous -->`-tagged AUQ with three options (`Ship with warning / Try alternative framing / Abandon`) and a one-line `Prose-fallback: ship-with-warning by default.`
- **No skill-runner harness**: `/diagram` is invoked via the Skill tool inside an LLM session. There is no Python entry-point for the skill; `tests/run.py` is the eval-only `--selftest` runner for SVG-quality grading. So "regression tests" for SKILL.md changes are necessarily contract-level (grep over SKILL.md), not behavior-level.
- **Existing test patterns at `plugins/pmos-toolkit/tests/non-interactive/`**: bats files (`parser.bats`, `lint-script.bats`, `audit-script.bats`, `propagation.bats`, `buffer-flush.bats`) — assertions are over file content + tool-script output. New per-flag assertions fit cleanly here.
- **Tools at `plugins/pmos-toolkit/tools/`**: `audit-recommended.sh` (verifies AUQ-recommended-or-defer-tagged), `lint-non-interactive-inline.sh` (verifies canonical block byte-match). Both should continue to pass after T1+T2.
- **Frontmatter line 5** is the canonical `argument-hint`. Other skills' argument-hint linters do not gate on /diagram's flag-set, so adding `--on-failure` is safe.

---

## Prerequisites

- Working tree clean on `main` (verified at /update-skills Phase 0).
- `bats` available locally (already required by `plugins/pmos-toolkit/tests/non-interactive/*.bats` runs).
- No active /diagram session in progress (the file edit is safe regardless, but avoids confusion).

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Modify | `plugins/pmos-toolkit/skills/diagram/SKILL.md` line 5 | Extend `argument-hint` with `--on-failure {drop\|ship-with-warning\|exit-nonzero}`. |
| Modify | `plugins/pmos-toolkit/skills/diagram/SKILL.md` Phase 0 step 1 (lines 45–47) | Add `--on-failure` to the parsed-flags list with default + validation rule. |
| Modify | `plugins/pmos-toolkit/skills/diagram/SKILL.md` Phase 6.5 (lines 347–365) | Replace the body with a mode-gated dispatch: interactive path = existing AUQ; non-interactive path = three-way switch on `--on-failure`. Add an Exit-Code contract sub-table. Add `<!-- non-interactive: handled-via on-failure-flag -->` explanatory comment near the AUQ. |
| Create | `plugins/pmos-toolkit/tests/non-interactive/diagram-on-failure.bats` | bats assertions: (a) frontmatter contains the flag enum, (b) Phase 0 documents the three values + default, (c) Phase 6.5 contains the three exit codes (3, 0, 4) explicitly, (d) Exit-Code contract table is present. |
| Modify | `plugins/pmos-toolkit/tests/non-interactive/per-skill-rollout-runbook.md` | Add a short "Per-skill addendum: /diagram --on-failure" section describing the flag and pointing to SKILL.md Phase 6.5. |

No changes to `plugins/pmos-toolkit/skills/diagram/tests/` (eval runner is unrelated).
No changes to `plugins/pmos-toolkit/tools/` (existing audit/lint already cover the AUQ pattern).
No changes to sidecar schema (`reference/sidecar-schema.md`).
No changes to plugin manifest (`plugins/pmos-toolkit/.claude-plugin/plugin.json`) — flag additions don't bump structure; version bump deferred to `/complete-dev`.

---

## Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Editing Phase 6.5 inadvertently touches the canonical non-interactive block, breaking `lint-non-interactive-inline.sh` | Low | Phase 6.5 is at line 347; canonical block ends at line 163. Verify post-edit by running the lint script. |
| `audit-recommended.sh` flags the modified AUQ if we strip the `defer-only` tag without preserving Recommended | Medium | Keep the AUQ option list unchanged (it has no Recommended marker today, only the `defer-only` tag — which we're keeping but adding an explanatory comment). Run audit script post-edit to confirm green. |
| `/rewrite` v0.14.0 design assumes exit codes 0/3/4 specifically; off-by-one would silently break the contract | Low | Test asserts on each numeric exit code in the bats file. Cross-checked against spec §2 verbatim. |
| Tier 1 plan skips /spec, so a misread of the requirements doc could land wrong | Low | Requirements doc has 8 explicit acceptance criteria; T5 final-verify checks each one against SKILL.md grep + bats output. |

---

## Rollback

No DB migrations, no deploys. Rollback = `git revert <merge>`. SKILL.md is the only behavior surface; reverting restores the existing Phase 6.5 AUQ-only path.

---

## Tasks

### T1: Extend `argument-hint` and Phase 0 arg-parse for `--on-failure`

**Goal:** Advertise and parse the flag without yet honoring it.
**Spec refs:** Requirements §Acceptance Criteria items 1, 2, 4 (default).

**Files:**
- Modify: `plugins/pmos-toolkit/skills/diagram/SKILL.md` line 5 (frontmatter)
- Modify: `plugins/pmos-toolkit/skills/diagram/SKILL.md` Phase 0 step 1 (lines 45–47)

**Steps:**

- [ ] Step 1: Edit line 5. Append ` [--on-failure drop|ship-with-warning|exit-nonzero]` to the `argument-hint` value (after the existing `[--non-interactive | --interactive]`).

- [ ] Step 2: Edit Phase 0 step 1's "Flags:" line to append `, --on-failure {drop|ship-with-warning|exit-nonzero}` to the list.

- [ ] Step 3: Add a new sub-bullet under Phase 0 step 1 right after the "Flags:" line:
  ```markdown
  - `--on-failure` validation:
    - Accepted values: `drop`, `ship-with-warning`, `exit-nonzero`. Unknown value → print `error: --on-failure must be one of {drop, ship-with-warning, exit-nonzero}` to stderr, exit 64.
    - Default when `mode == non-interactive` and flag absent: `exit-nonzero`.
    - When `mode == interactive`, the flag is parsed but advisory only — Phase 6.5's `AskUserQuestion` remains the source of truth.
  ```

- [ ] Step 4: Run grep verification:
  ```bash
  grep -c -- "--on-failure" plugins/pmos-toolkit/skills/diagram/SKILL.md
  ```
  Expected: ≥ 4 (frontmatter + 3 in Phase 0 step 1).

- [ ] Step 5: Commit:
  ```bash
  git add plugins/pmos-toolkit/skills/diagram/SKILL.md
  git commit -m "feat(diagram): add --on-failure flag to argument-hint and Phase 0 parse"
  ```

**Inline verification:**
- `grep "argument-hint:" plugins/pmos-toolkit/skills/diagram/SKILL.md | grep -- "--on-failure"` — non-empty.
- `bash plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh plugins/pmos-toolkit/skills/diagram/SKILL.md` — exits 0.

---

### T2: Rewrite Phase 6.5 with mode-gated dispatch + Exit-Code contract

**Goal:** Make Phase 6.5 deterministic in non-interactive mode. Document exit codes.
**Spec refs:** Requirements §Acceptance Criteria items 3 (a, b, c, d), 5, 6.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/diagram/SKILL.md` Phase 6.5 section (lines 347–365 pre-edit; line numbers will shift after edit)

**Steps:**

- [ ] Step 1: Replace the Phase 6.5 body. Target post-edit text:
  ```markdown
  ## Phase 6.5 — Terminal failure handler (high / medium rigor only)

  Loops are exhausted and gating fails remain. Disposition depends on `mode`.

  ### Non-interactive mode (`mode == non-interactive`)

  Dispatch on `--on-failure` (default: `exit-nonzero`). Do NOT issue `AskUserQuestion`.

  | `--on-failure` | Behavior |
  |---|---|
  | `drop` | Do NOT write the SVG. Do NOT write the sidecar. Print `diagram dropped: <comma-joined hard_fails>` to stderr. **Exit 3.** |
  | `ship-with-warning` | Write the SVG with a leading `<!-- WARNING: <comma-joined hard_fails> -->` comment. Write the sidecar normally. **Exit 0.** |
  | `exit-nonzero` | Do NOT write the SVG. Do NOT write the sidecar. Print `diagram failed: <comma-joined hard_fails>` to stderr. **Exit 4.** |

  ### Interactive mode (`mode == interactive`)

  <!-- non-interactive: handled-via on-failure-flag -->
  <!-- defer-only: ambiguous -->
  `AskUserQuestion`:

  ​```
  question: "After N refinement loops, the diagram still has gating fails. What now?"
  header: "Terminal"
  options:
    - Ship with warning: write the SVG with a leading XML comment listing remaining fails.
    - Try alternative framing: restart from Phase 3 using one of the brainstormed alternatives.
    - Abandon: delete the temp SVG, exit non-zero.
  ​```

  Prose-fallback: ship-with-warning by default.

  If user picks **alt framing** → restart at Phase 2 with the next brainstormed approach pre-selected; loop budget is fresh. If even the alternative fails its terminal handler, default to ship-with-warning.

  ### Exit-Code contract (across all modes)

  | Exit code | Meaning |
  |---|---|
  | 0 | Success — SVG + sidecar written. May include warning comment if `ship-with-warning` was selected. |
  | 2 | Environmental — renderer missing, theme schema invalid, mode/theme combo unsupported. |
  | 3 | Non-interactive `--on-failure drop` — caller dropped the slot. |
  | 4 | Non-interactive `--on-failure exit-nonzero` (default) — caller decides. |
  | 64 | Argument error — unknown `--on-failure` value, malformed `settings.yaml`, etc. |
  ```
  (Replace the backtick-fence-escapes appropriately when applying the edit.)

- [ ] Step 2: Run grep verification:
  ```bash
  grep -c "Exit 0\|Exit 3\|Exit 4" plugins/pmos-toolkit/skills/diagram/SKILL.md
  ```
  Expected: ≥ 6 (each appears in both the per-value table and the Exit-Code contract).

- [ ] Step 3: Re-run audit + lint:
  ```bash
  bash plugins/pmos-toolkit/tools/audit-recommended.sh plugins/pmos-toolkit/skills/diagram/SKILL.md
  bash plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh plugins/pmos-toolkit/skills/diagram/SKILL.md
  ```
  Expected: both exit 0.

- [ ] Step 4: Commit:
  ```bash
  git add plugins/pmos-toolkit/skills/diagram/SKILL.md
  git commit -m "feat(diagram): gate Phase 6.5 on --on-failure for non-interactive mode + exit-code contract"
  ```

**Inline verification:**
- `grep -c "## Phase 6.5" plugins/pmos-toolkit/skills/diagram/SKILL.md` — exactly 1.
- `grep "non-interactive: handled-via on-failure-flag" plugins/pmos-toolkit/skills/diagram/SKILL.md` — non-empty.

---

### T3: bats assertions for the SKILL.md contract

**Goal:** Lock in the contract so future edits can't silently regress it.
**Spec refs:** Requirements §Acceptance Criteria item 7 (regression tests).

**Files:**
- Create: `plugins/pmos-toolkit/tests/non-interactive/diagram-on-failure.bats`

**Steps:**

- [ ] Step 1: Write the failing test:
  ```bash
  #!/usr/bin/env bats
  # diagram-on-failure.bats — locks in the --on-failure contract in /diagram SKILL.md.

  SKILL=plugins/pmos-toolkit/skills/diagram/SKILL.md

  @test "argument-hint advertises --on-failure with all three values" {
    run grep -E 'argument-hint:.*--on-failure[[:space:]]+drop\|ship-with-warning\|exit-nonzero' "$SKILL"
    [ "$status" -eq 0 ]
  }

  @test "Phase 0 documents --on-failure default + validation" {
    run grep -E 'Default when .mode == non-interactive. and flag absent: .exit-nonzero.' "$SKILL"
    [ "$status" -eq 0 ]
  }

  @test "Phase 6.5 documents Exit 3 for drop" {
    run grep -E '\| .drop. .*Exit 3' "$SKILL"
    [ "$status" -eq 0 ]
  }

  @test "Phase 6.5 documents Exit 0 for ship-with-warning" {
    run grep -E '\| .ship-with-warning. .*Exit 0' "$SKILL"
    [ "$status" -eq 0 ]
  }

  @test "Phase 6.5 documents Exit 4 for exit-nonzero" {
    run grep -E '\| .exit-nonzero. .*Exit 4' "$SKILL"
    [ "$status" -eq 0 ]
  }

  @test "Exit-Code contract table is present" {
    run grep -F 'Exit-Code contract' "$SKILL"
    [ "$status" -eq 0 ]
  }

  @test "Phase 6.5 AUQ tagged interactive-only" {
    run grep -F 'non-interactive: handled-via on-failure-flag' "$SKILL"
    [ "$status" -eq 0 ]
  }
  ```

- [ ] Step 2: Run it. Pre-T1+T2 it would have failed; post-T1+T2 it should pass.
  ```bash
  bats plugins/pmos-toolkit/tests/non-interactive/diagram-on-failure.bats
  ```
  Expected: `7 tests, 0 failures`.

- [ ] Step 3: Commit:
  ```bash
  git add plugins/pmos-toolkit/tests/non-interactive/diagram-on-failure.bats
  git commit -m "test(diagram): bats contract assertions for --on-failure"
  ```

**Inline verification:**
- `bats plugins/pmos-toolkit/tests/non-interactive/diagram-on-failure.bats` — `7 tests, 0 failures`.

---

### T4: Audit/lint regression — confirm existing scripts still pass

**Goal:** Verify the canonical non-interactive block + AUQ audit are still green after the edit.
**Spec refs:** Requirements §Acceptance Criteria item 8 (no schema changes), implicit non-regression.

**Files:**
- None (read-only verification step).

**Steps:**

- [ ] Step 1: Run the canonical-block lint:
  ```bash
  bash plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh plugins/pmos-toolkit/skills/diagram/SKILL.md
  ```
  Expected: exits 0; output contains `OK:` (or whatever the green signal is for that script).

- [ ] Step 2: Run the AUQ audit:
  ```bash
  bash plugins/pmos-toolkit/tools/audit-recommended.sh plugins/pmos-toolkit/skills/diagram/SKILL.md
  ```
  Expected: exits 0.

- [ ] Step 3: If either fails, halt — likely the canonical block was inadvertently mutated in T2 or the AUQ structure changed. Inspect the diff at `git diff HEAD~2 plugins/pmos-toolkit/skills/diagram/SKILL.md`.

**Inline verification:** both scripts return exit 0.

---

### T5: Per-skill runbook addendum + final verification

**Goal:** Document the new flag in the rollout runbook. Walk acceptance criteria.
**Spec refs:** Requirements §Acceptance Criteria all items.

**Files:**
- Modify: `plugins/pmos-toolkit/tests/non-interactive/per-skill-rollout-runbook.md` (append section)

**Steps:**

- [ ] Step 1: Append to `per-skill-rollout-runbook.md`:
  ```markdown
  ---

  ## Per-skill addendum: /diagram `--on-failure`

  /diagram extends the standard non-interactive contract with a `--on-failure {drop|ship-with-warning|exit-nonzero}` flag that gates Phase 6.5 (Terminal failure handler) disposition. See `plugins/pmos-toolkit/skills/diagram/SKILL.md` Phase 6.5 for the exit-code contract.

  This is the first per-skill addendum; future skills with deterministic-disposition flags should follow the same pattern (separate `### Per-skill addendum: /<skill>` section, link to the relevant phase).
  ```

- [ ] Step 2: Walk through all 8 acceptance criteria from `01_requirements.md` § "Acceptance Criteria" against the current state of SKILL.md + bats test. Each must be checked off.

- [ ] Step 3: Commit:
  ```bash
  git add plugins/pmos-toolkit/tests/non-interactive/per-skill-rollout-runbook.md
  git commit -m "docs(diagram): runbook addendum for --on-failure"
  ```

**Inline verification:**
- All 8 acceptance criteria pass review (manual checklist below).
- All bats tests in `diagram-on-failure.bats` green.
- `lint-non-interactive-inline.sh` and `audit-recommended.sh` both exit 0.

---

### TN: Final Verification

**Goal:** Verify the entire implementation against requirements + lint chain.

- [ ] **Acceptance criterion 1:** `grep "argument-hint:.*--on-failure" plugins/pmos-toolkit/skills/diagram/SKILL.md` returns the line with all 3 enum values.
- [ ] **Acceptance criterion 2:** Phase 0 contains `--on-failure validation:` block with default + unknown-value handling + interactive-mode advisory note.
- [ ] **Acceptance criterion 3a (drop):** Phase 6.5 table row shows `drop` → no SVG, no sidecar, Exit 3, stderr message.
- [ ] **Acceptance criterion 3b (ship-with-warning):** Phase 6.5 row shows `ship-with-warning` → SVG + sidecar written with warning comment, Exit 0.
- [ ] **Acceptance criterion 3c (exit-nonzero):** Phase 6.5 row shows `exit-nonzero` → no SVG, no sidecar, Exit 4, stderr message.
- [ ] **Acceptance criterion 3d (default):** Phase 0 + Phase 6.5 both confirm default is `exit-nonzero`.
- [ ] **Acceptance criterion 4 (interactive unchanged):** Phase 6.5 still contains the original AUQ with the three options (Ship-with-warning / Try-alt / Abandon).
- [ ] **Acceptance criterion 5 (exit-code documentation):** SKILL.md contains the Exit-Code contract table.
- [ ] **Acceptance criterion 6 (defer-only tag handling):** Phase 6.5 AUQ has the `<!-- non-interactive: handled-via on-failure-flag -->` explanatory comment.
- [ ] **Acceptance criterion 7 (regression tests):** `bats plugins/pmos-toolkit/tests/non-interactive/diagram-on-failure.bats` reports `7 tests, 0 failures`.
- [ ] **Acceptance criterion 8 (no schema changes):** `git diff main -- plugins/pmos-toolkit/skills/diagram/reference/sidecar-schema.md` is empty.
- [ ] **Lint:** `bash plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh plugins/pmos-toolkit/skills/diagram/SKILL.md` exits 0.
- [ ] **Audit:** `bash plugins/pmos-toolkit/tools/audit-recommended.sh plugins/pmos-toolkit/skills/diagram/SKILL.md` exits 0.
- [ ] **No collateral damage:** `git diff main -- plugins/pmos-toolkit/skills/diagram/SKILL.md` only touches lines 5, Phase 0 step 1, and Phase 6.5 — no edits inside the canonical `<!-- non-interactive-block -->` (lines ~80–163).

**Cleanup:** none — no temp files, no containers, no flags to flip.

---

## Review Log

| Loop | Findings | Changes Made |
|------|----------|-------------|
| 1    | (Tier 1 + non-interactive: review-loop dispositions auto-applied via OQ-buffer protocol; recorded inline.) | Initial plan written from requirements doc; no findings. |
