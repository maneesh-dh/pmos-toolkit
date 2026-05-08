# /create-skill plan+verify integration — Implementation Plan

**Date:** 2026-05-08
**Spec:** `docs/pmos/features/2026-05-08_update-skills-add-plan-verify/02_spec.md`
**Requirements:** `docs/pmos/features/2026-05-08_update-skills-add-plan-verify/01_requirements.md`

---

## Overview

Edit `plugins/pmos-toolkit/skills/create-skill/SKILL.md` to add a new Phase 6 (/plan invocation, Tier 2+) and a new Phase 8 (/verify invocation, mandatory all tiers), delete the inline pre-save checklist, renumber existing phases, update the tier table, add anti-pattern bullets, update README, and bump plugin versions to 2.25.0.

**Done when:** All §14.1 static checks pass on the modified SKILL.md, README has the updated row, both plugin.json files show 2.25.0, and `/pmos-toolkit:verify` against this spec returns no Critical findings.

**Execution order:**

```
T1 (new Phase 6 plan) ─┐
T2 (renumber Phase 6→7) ┴─→ T3 (new Phase 8 verify + delete checklist) ─→ T4 (renumber learnings 8→9)
T5 (tier table + status flow) [P]
T6 (anti-patterns bullets) [P]
T7 (README + version bump) [P]
                                                                            ↓
                                                                        T8 (final verification)
```

T5, T6, T7 can run in parallel after T4 completes (they touch different sections / files).

---

## Decision Log

| # | Decision | Options Considered | Rationale |
|---|---|---|---|
| D-P1 | One task per logical SKILL.md region (insert/replace/renumber) rather than one task per FR. | (a) per-region; (b) per-FR. | Per-region matches the actual edit shape; FRs map to multiple regions (e.g., FR-04 tier table + FR-07 status flow share the same edit scope). Per-FR would force redundant context loads. |
| D-P2 | Verification is grep/wc-based, not test-suite-based. | (a) grep; (b) write a SKILL-md linter. | No test framework exists for SKILL.md edits. The §14.1 grep commands are the contract. Building a linter is out of scope. |
| D-P3 | T7 (README + version bump) is bundled, not split. | (a) Bundle; (b) split. | Both are single-line edits in adjacent files; splitting adds two commits with no isolation benefit. |
| D-P4 | The Conventions "Checklist Before Saving" block (L314-344) is deleted in T3 along with the Phase 7 reference. | (a) Delete both in T3; (b) separate T8a. | Same logical concern (the inline checklist that /verify replaces). One task = one consistent diff. |
| D-P5 | No git worktree — edits are scoped to one SKILL.md file plus README + 2 plugin.json files. | (a) Worktree; (b) main branch. | Worktree adds overhead for what is effectively a single-file change with two trivial siblings. /verify will run against main. |

---

## Code Study Notes

Current `plugins/pmos-toolkit/skills/create-skill/SKILL.md` structure (line numbers from current head):

- L1-12: Frontmatter + intro
- L14-21: Platform Adaptation
- L22-29: Track Progress + Load Learnings
- L32: `## Phase 1: Intent capture`
- L40: `## Phase 2: Auto-tier` — tier table at L44-L48
- L54: `## Phase 3: Requirements gathering`
- L70: `## Phase 4: Write spec to disk (Tier 2+)` — status flow language inside
- L92: `## Phase 5: Adversarial review via /grill (Tier 3 only)`
- L111: `## Phase 6: Implement against the spec` ← becomes new Phase 7
- L131: `## Phase 7: Pre-save checklist` ← deleted; replaced by new Phase 8 /verify
- L137: `## Phase 8: Capture Learnings` ← becomes new Phase 9
- L143: `## Conventions (implementation reference for Phase 6)` — heading text references "Phase 6" → must update to "Phase 7"
- L314: `## Checklist Before Saving` ← entire section deleted (duplicates Phase 7 inline checklist)
- L347: `## Anti-patterns` ← gain 2 bullets

Reference skills already studied (spec §16): `/plan` takes spec path arg; `/verify` takes spec path arg with `--scope phase` optional. `/update-skills` Phase 8 dispatch is the pattern to mirror.

README.md L81 has the current /create-skill row; L93 has standalone-skills line that already includes /create-skill.

Both plugin.json files at version 2.24.0; bump to 2.25.0.

---

## Prerequisites

- On `main` branch, working tree clean (current branch matches: `git status` is clean per session start).
- Have read the spec end-to-end (FR-01..FR-13 and §14.1 verification commands).

---

## File Map

| Action | File | Responsibility |
|---|---|---|
| Modify | `plugins/pmos-toolkit/skills/create-skill/SKILL.md` (multiple regions) | Phase additions/renumbers, tier table, anti-patterns, status flow, checklist deletion. |
| Modify | `README.md` (around L81 row) | Update /create-skill description to reflect plan+verify pipeline. |
| Modify | `plugins/pmos-toolkit/.claude-plugin/plugin.json` (version field) | 2.24.0 → 2.25.0. |
| Modify | `plugins/pmos-toolkit/.codex-plugin/plugin.json` (version field) | 2.24.0 → 2.25.0 (must match claude-plugin). |

No new files. No deletions of files.

---

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Renumbering misses an internal cross-reference (e.g., text says "see Phase 6" when target is now Phase 7). | Medium | T8 final verification greps `Phase [0-9]` across the file; manually inspect each match. |
| Phase numbering becomes non-monotonic (e.g., 1,2,3,4,5,6,7,9 with a gap). | Low | T8 NFR-02 check explicitly enforces this. |
| Deleting the Conventions checklist drops content not covered by /verify (e.g., "saved to correct path"). | Medium | The Convention 1 "Save Location" section (L147+) already covers path; /verify Phase 5 4b checks FRs. Confirm no orphan content during T3. |
| README row update is ambiguous (existing row already broad). | Low | Inspect L81 first; small edit only if existing wording is misleading post-change. |

---

## Rollback

Single-commit revert: `git revert HEAD`. No DB, no deploy. The plugin manifest version bump is reversible by reverting plugin.json files.

---

## Tasks

### T1: Insert new Phase 6 — /plan invocation (Tier 2+)

**Goal:** Add a new numbered Phase 6 section that invokes `/pmos-toolkit:plan` after Phase 5 (grill) and before the existing Phase 6 (implement, which T2 renumbers).
**Spec refs:** FR-01, D1, D2, D6, §5 Phase 6 contract.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/create-skill/SKILL.md` (insert ~30 lines between current L109 and L111)

**Steps:**

- [ ] Insert the following block immediately before the line `## Phase 6: Implement against the spec` (which will be renumbered in T2):

  ```markdown
  ## Phase 6: Plan via /pmos-toolkit:plan (Tier 2+)

  **Skip if Tier 1.** Otherwise:

  1. Resolve the spec path written in Phase 4.
  2. Invoke `/pmos-toolkit:plan <spec-path>`. Default-foreground.
  3. On success: spec status `approved → planned`. The user approves the plan doc as part of `/plan`'s own Phase 5 review — do not gate again here.
  4. On failure:
     - **`/plan` skill missing:** log a one-paragraph warning to spec §14, then `AskUserQuestion`: **Continue (skip plan, log warning)** / **Abort**. Default Continue. (Mirrors how Phase 5 handles missing `/grill`.)
     - **`/plan` cancelled or errored:** `AskUserQuestion`: **Retry** / **Abort**. Default Retry once; on second failure show the same dialog.
  5. Do not proceed to Phase 7 until plan status is `approved` (or the user explicitly chose Continue on missing).

  ---
  ```

- [ ] Inline verification:
  ```bash
  grep -n '^## Phase 6: Plan via /pmos-toolkit:plan' plugins/pmos-toolkit/skills/create-skill/SKILL.md
  # Expected: exactly one match
  grep -A 5 '^## Phase 6: Plan via' plugins/pmos-toolkit/skills/create-skill/SKILL.md | grep -c 'pmos-toolkit:plan'
  # Expected: ≥ 1
  ```

- [ ] Commit:
  ```bash
  git add plugins/pmos-toolkit/skills/create-skill/SKILL.md
  git commit -m "feat(create-skill): add Phase 6 /plan invocation (Tier 2+)"
  ```

---

### T2: Renumber current Phase 6 → Phase 7; add plan-source note

**Goal:** The current `## Phase 6: Implement against the spec` becomes `## Phase 7: Implement against the spec`; add one sentence noting the plan is the source of truth when present.
**Spec refs:** FR-06, FR-09, D10.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/create-skill/SKILL.md`

**Steps:**

- [ ] Replace `## Phase 6: Implement against the spec` with `## Phase 7: Implement against the spec`.
- [ ] Insert this sentence as the second sentence of the Phase 7 body (after the existing "This is where the actual SKILL.md, ..." line):
  > "If a plan was produced in Phase 6, implement against it; the plan is the source of truth, the spec is its parent."
- [ ] Update the Conventions heading at current L143 from `## Conventions (implementation reference for Phase 6)` → `## Conventions (implementation reference for Phase 7)`.
- [ ] Inline verification:
  ```bash
  grep -c '^## Phase 6: Implement against the spec' plugins/pmos-toolkit/skills/create-skill/SKILL.md
  # Expected: 0
  grep -c '^## Phase 7: Implement against the spec' plugins/pmos-toolkit/skills/create-skill/SKILL.md
  # Expected: 1
  grep -c 'plan is the source of truth' plugins/pmos-toolkit/skills/create-skill/SKILL.md
  # Expected: 1
  grep -c 'implementation reference for Phase 7' plugins/pmos-toolkit/skills/create-skill/SKILL.md
  # Expected: 1
  ```
- [ ] Commit: `git commit -am "refactor(create-skill): renumber implement to Phase 7 + plan source note"`

---

### T3: Replace inline checklist with new Phase 8 — /verify; delete Conventions checklist block

**Goal:** Delete the current `## Phase 7: Pre-save checklist` AND the standalone `## Checklist Before Saving` Conventions section. Replace the deleted Phase 7 region with a new `## Phase 8: Verify via /pmos-toolkit:verify` section.
**Spec refs:** FR-02, FR-03, D3, D4, D7, §5 Phase 8 contract.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/create-skill/SKILL.md`

**Steps:**

- [ ] Delete the entire `## Phase 7: Pre-save checklist` section through the line right before `## Phase 8: Capture Learnings`.
- [ ] In its place, insert:

  ```markdown
  ## Phase 8: Verify via /pmos-toolkit:verify (mandatory all tiers)

  **Mandatory at all tiers — no skip gate.**

  1. Resolve the spec path (or, for Tier 1 with no spec, the new SKILL.md path itself; pass via `--scope phase` only if /verify supports it for the target — default mode is fine for both cases).
  2. Invoke `/pmos-toolkit:verify <spec-path>`. Default-foreground.
  3. The release-prereq items (README row, version bump) live as FRs in the spec — `/verify` Phase 5 4b reads the spec and grades each FR-ID, so no separate hint mechanism is needed.
  4. On success (no Critical findings): spec status `implemented → verified`.
  5. On unresolved blocker findings: spec status stays `implemented`. The skill is flagged as not-ready in the Phase 8 pipeline-status table. The user may re-invoke `/pmos-toolkit:verify <spec-path>` directly (it is idempotent) — `/create-skill` itself has no `--resume` flag.
  6. On `/verify` skill missing: HARD ERROR. `AskUserQuestion`: **Install/upgrade /verify** / **Accept-as-risk override** (logs a warning to spec §14 and sets status `unverified`) / **Abort**. Default Abort.
  7. After Phase 8 returns, emit a pipeline-status summary table to chat (mirror of `/update-skills` Phase 8):

     | phase | status | artifact path | timestamp |
     |---|---|---|---|
     | requirements | completed/skipped/failed | <path or n/a> | <YYYY-MM-DD> |
     | spec | … | … | … |
     | grill | … | … | … |
     | plan | … | … | … |
     | implement | … | … | … |
     | verify | … | … | … |

  ---
  ```

- [ ] Delete the entire `## Checklist Before Saving` section (currently at L314-344) — from the heading through the trailing `---` separator before `## Anti-patterns`.
- [ ] Inline verification:
  ```bash
  grep -c '^## Phase 7: Pre-save checklist' plugins/pmos-toolkit/skills/create-skill/SKILL.md
  # Expected: 0
  grep -c '^## Checklist Before Saving' plugins/pmos-toolkit/skills/create-skill/SKILL.md
  # Expected: 0
  grep -c '^## Phase 8: Verify via /pmos-toolkit:verify' plugins/pmos-toolkit/skills/create-skill/SKILL.md
  # Expected: 1
  grep -A 12 '^## Phase 8: Verify' plugins/pmos-toolkit/skills/create-skill/SKILL.md | grep -E -c 'mandatory|non-skippable|Mandatory'
  # Expected: ≥ 1
  ```
- [ ] Commit: `git commit -am "feat(create-skill): add Phase 8 /verify + delete inline checklist"`

---

### T4: Renumber Capture Learnings → Phase 9

**Goal:** Final phase becomes Phase 9.
**Spec refs:** FR-09, D10, NFR-02.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/create-skill/SKILL.md`

**Steps:**

- [ ] Replace `## Phase 8: Capture Learnings` with `## Phase 9: Capture Learnings`.
- [ ] Inline verification:
  ```bash
  grep -E '^## Phase [0-9]+:' plugins/pmos-toolkit/skills/create-skill/SKILL.md | awk '{print $3}' | tr -d ':' | tr '\n' ' '
  # Expected: "1 2 3 4 5 6 7 8 9 " (monotonic, no gaps)
  ```
- [ ] Commit: `git commit -am "refactor(create-skill): renumber capture learnings to Phase 9"`

---

### T5: Update tier table workflow column + spec status flow

**Goal:** Tier table at L44-L48 reflects new phases; Phase 4 spec status flow language updated.
**Spec refs:** FR-04, FR-07, D5, §5 tier table.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/create-skill/SKILL.md`

**Steps:**

- [ ] Replace the existing tier-table rows (the three rows with Tier 1/2/3 in column 1, "Workflow" being the rightmost column) with:

  ```markdown
  | **1** | One-shot utility; ≤ 2 phases; no `assets/`; no `reference/`; no eval rubric; no workstream awareness | Skip Phases 4, 5, 6 (plan). Implement (Phase 7) directly from the interview. Run Phase 8 /verify mandatorily. |
  | **2** | 3+ phases OR has `reference/` files OR has `assets/` OR uses workstream context OR has a structured output format | Run Phases 4 (spec), 6 (plan), 7 (implement), 8 (/verify). Skip Phase 5 (grill). |
  | **3** | 5+ phases AND (has eval rubric OR has external integrations OR multi-source/multi-tier behavior OR pipeline integration) | Run Phases 4, 5 (grill), 6 (plan), 7 (implement), 8 (/verify). Full pipeline. |
  ```

- [ ] In Phase 4 body, locate the line that says `Set \`Status: draft\` in the spec header.` and append a sentence right after the surrounding paragraph:
  > "Spec status lifecycle across the full pipeline: `draft → grilled (Tier 3, after Phase 5) → planned (Tier 2+, after Phase 6) → approved → implemented (after Phase 7) → verified (after Phase 8)`."

- [ ] Inline verification:
  ```bash
  sed -n '/^| Tier |/,/^$/p' plugins/pmos-toolkit/skills/create-skill/SKILL.md | grep -E -c 'Phase 6|Phase 8'
  # Expected: ≥ 3 (T1, T2, T3 rows all reference new phase numbers)
  grep -c 'planned (Tier 2+, after Phase 6)' plugins/pmos-toolkit/skills/create-skill/SKILL.md
  # Expected: 1
  grep -c 'verified (after Phase 8)' plugins/pmos-toolkit/skills/create-skill/SKILL.md
  # Expected: 1
  ```
- [ ] Commit: `git commit -am "docs(create-skill): update tier table workflow + spec status flow"`

---

### T6: Add anti-pattern bullets

**Goal:** Anti-patterns gains 2 new bullets.
**Spec refs:** FR-05.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/create-skill/SKILL.md`

**Steps:**

- [ ] In the `## Anti-patterns` section, append two new bullets verbatim:
  - `- **Skipping the /plan phase at Tier 2+.** Plan is the cheapest place to map the spec to TDD-friendly tasks before code lands. Without it, Phase 7 implements from the spec directly and the implementor reverse-engineers task ordering.`
  - `- **Skipping /verify because /execute looked clean.** /verify is non-skippable per the per-skill pipeline contract; no opt-out at any tier. Visual confidence after implement is not evidence — /verify Phase 2 lint, Phase 3 multi-agent review, and Phase 5 spec compliance are the contract.`

- [ ] Inline verification:
  ```bash
  grep -c 'Skipping the /plan phase at Tier 2+' plugins/pmos-toolkit/skills/create-skill/SKILL.md
  # Expected: 1
  grep -c 'Skipping /verify because /execute looked clean' plugins/pmos-toolkit/skills/create-skill/SKILL.md
  # Expected: 1
  ```
- [ ] Commit: `git commit -am "docs(create-skill): add /plan and /verify skip anti-patterns"`

---

### T7: README row + version bump (parallel-safe with T5/T6)

**Goal:** README L81 row updated; both plugin.json files bumped 2.24.0 → 2.25.0.
**Spec refs:** FR-12, FR-13.

**Files:**
- Modify: `README.md` (around L81)
- Modify: `plugins/pmos-toolkit/.claude-plugin/plugin.json`
- Modify: `plugins/pmos-toolkit/.codex-plugin/plugin.json`

**Steps:**

- [ ] Update the README row at L81:
  - Old: `| `/pmos-toolkit:create-skill` | Create a new skill with cross-platform conventions and project save paths |`
  - New: `| `/pmos-toolkit:create-skill` | Create a new skill via the requirements → spec → [grill] → plan → implement → /verify pipeline; cross-platform conventions, project save paths, mandatory /verify gate. |`
- [ ] In `plugins/pmos-toolkit/.claude-plugin/plugin.json`: `"version": "2.24.0"` → `"version": "2.25.0"`.
- [ ] In `plugins/pmos-toolkit/.codex-plugin/plugin.json`: `"version": "2.24.0"` → `"version": "2.25.0"`.
- [ ] Inline verification:
  ```bash
  grep -c '/pmos-toolkit:create-skill.*plan.*verify' README.md
  # Expected: 1
  grep '"version"' plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json
  # Expected: both show "2.25.0"; values must match
  ```
- [ ] Commit:
  ```bash
  git add README.md plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json
  git commit -m "chore(pmos-toolkit): bump 2.25.0 + README row for /create-skill"
  ```

---

### T8: Final Verification

**Goal:** Run all §14.1 spec verification commands plus integration probe.

- [ ] **Phase numbering monotonic:**
  ```bash
  grep -E '^## Phase [0-9]+:' plugins/pmos-toolkit/skills/create-skill/SKILL.md | awk '{print $3}' | tr -d ':'
  ```
  Expected: lines `1 2 3 4 5 6 7 8 9` in order.

- [ ] **Line count NFR-01:**
  ```bash
  wc -l plugins/pmos-toolkit/skills/create-skill/SKILL.md
  ```
  Expected: ≤ 500. (Current ~356; expected ~400-420.) If exceeded, flag for E7 refactor before declaring done.

- [ ] **/plan invocation present:**
  ```bash
  grep -A 5 '^## Phase 6:' plugins/pmos-toolkit/skills/create-skill/SKILL.md | grep -c 'pmos-toolkit:plan'
  ```
  Expected: ≥ 1.

- [ ] **/verify invocation + mandatory language:**
  ```bash
  grep -A 10 '^## Phase 8:' plugins/pmos-toolkit/skills/create-skill/SKILL.md | grep -E 'pmos-toolkit:verify|mandatory|non-skippable|Mandatory'
  ```
  Expected: ≥ 2 hits.

- [ ] **Inline checklist removed:**
  ```bash
  grep -E 'Pre-save checklist|Checklist Before Saving' plugins/pmos-toolkit/skills/create-skill/SKILL.md
  ```
  Expected: 0 hits.

- [ ] **Anti-pattern bullets present:**
  ```bash
  grep -E 'Skipping.*/plan|Skipping /verify' plugins/pmos-toolkit/skills/create-skill/SKILL.md
  ```
  Expected: ≥ 2 hits.

- [ ] **Tier table updated:**
  ```bash
  sed -n '/^| Tier |/,/^$/p' plugins/pmos-toolkit/skills/create-skill/SKILL.md | grep -E 'Phase 6|Phase 8'
  ```
  Expected: hits in T2 and T3 rows (and T1 should reference Phase 7 + Phase 8).

- [ ] **Versions in sync at 2.25.0:**
  ```bash
  grep '"version"' plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json
  ```
  Expected: both show `"2.25.0"`.

- [ ] **Cross-reference scan (manual):** `grep -nE 'Phase [0-9]+' plugins/pmos-toolkit/skills/create-skill/SKILL.md | grep -v '^## Phase'` — open in viewer; confirm every "see Phase N" / "in Phase N" reference targets the new numbering. Manually fix any drift (this would be a Risk-1 hit).

- [ ] **Run /verify against the spec (the actual /verify gate, not just static checks):**
  ```bash
  # User runs: /pmos-toolkit:verify docs/pmos/features/2026-05-08_update-skills-add-plan-verify/02_spec.md
  ```
  Expected: /verify Phase 5 4b grades FR-01..FR-13. No Critical gaps.

- [ ] **Cleanup:** None — no temp files, no containers, no debug logging introduced.

**Done when:** all greps above match expectations, both plugin.json versions are 2.25.0, and `/verify` reports no Critical findings.

---

## Review Log

| Loop | Findings | Changes Made |
|---|---|---|
| (none yet) | | |
