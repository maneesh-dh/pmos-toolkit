# Structured-Ask Edge Cases + Per-Skill Retro Patches — Implementation Plan

**Date:** 2026-05-02
**Spec:** `docs/specs/2026-05-02-structured-ask-edge-cases-design.md`
**Source retro:** conversation context, 2026-05-02 session

---

## Overview

This plan implements a docs-only change across 6 skill files plus one new shared protocol file. It codifies three "structured-ask edge cases" (free-form replies, invariant-breaking picks, leftover-batch coherence) in a shared file referenced by every consuming skill, and applies 7 per-skill nit fixes from a retro session.

There is no code, no schema, no API, no tests in the traditional sense. The plan adapts the standard TDD task shape to docs work: each task ends with a **grep-based proof-of-life check** that the patch landed at the intended anchor.

**Done when:** the new shared file exists with 4 H2 sections; all 6 skill files reference it via the `_shared/` relative path; all 7 per-skill nits land at their named anchors; the §10.1 structural verification block from the spec passes 9/9; a follow-up grep audit shows no unintended duplicates.

**Execution order:**

```
T1 (write shared protocol)
  ├─ T2 (requirements: nit + reference) [P]
  ├─ T3 (spec: nit + reference)          [P]
  ├─ T4 (simulate-spec: 2 nits + reference) [P]
  ├─ T5 (plan: 3 nits + reference)       [P]
  ├─ T6 (wireframes: reference only)     [P]
  └─ T7 (prototype: reference only)      [P]
TN (final verification: run §10.1 9-command block + audit)
```

T2–T7 are mutually independent (different files); T1 must precede them so the relative-path target exists.

---

## Decision Log

> Inherits all decisions from the spec (D1–D9). Entries below are plan-specific decisions made during code study.

| # | Decision | Options Considered | Rationale |
|---|----------|-------------------|-----------|
| P1 | Save plan to `docs/plans/2026-05-02-structured-ask-edge-cases-plan.md` (flat repo convention) | (a) flat `docs/plans/`, (b) `docs/pmos/features/<date>_<slug>/03_plan.md` per `_shared/feature-folder.md` | (a). Repo's actual convention is `docs/plans/YYYY-MM-DD-<slug>-plan.md` (9 existing files match this) and `docs/specs/YYYY-MM-DD-<slug>-design.md`. The feature-folder protocol is for end-user product work; this is toolkit-internal. The spec already lives at `docs/specs/2026-05-02-structured-ask-edge-cases-design.md`, so the plan follows it. |
| P2 | TDD adaptation: each task uses **anchor-string Edit + grep verification** instead of `pytest` red/green | (a) grep verify, (b) skip verification, (c) write a Bats test suite | (a). The "test that fails first, then passes" idea maps cleanly to "grep returns 0 matches before, ≥1 after". A Bats suite for a 7-patch docs change is over-engineered. |
| P3 | Single Edit call per FR (not bundling multiple FRs into one Edit), even when the same file gets multiple patches | (a) one Edit per FR, (b) multi-FR Edit blocks | (a). Each FR has a unique anchor string, so per-FR Edits give surgical diffs and easy rollback if any one anchor has drifted since the spec was written. Bundling risks one bad anchor blocking a successful patch. |
| P4 | Spec §6 said `/requirements` has no `### Findings Presentation Protocol` heading — code study disproved this. The plan corrects FR-06 to anchor on the existing heading at line 396. | (a) Use the existing heading, (b) Add a new heading per spec text | (a). Code study found the heading exists. The spec drafter under-read; insertion goes after line 414 (Anti-pattern), matching the pattern of all other consumer skills. Logged here so future readers don't re-investigate. |
| P5 | User scope decision: include `/wireframes` and `/prototype` in the reference insertions (6 skills total, not 4) | (a) 6 skills, (b) 4 skills per original spec, (c) gated on grep finding | (a). User explicitly answered "Yes, add references to all 6 skills" during plan-time question batch. Both skills already have `Findings Presentation Protocol` sections (wireframes line 381, prototype line 409) so the same anchor pattern applies. |
| P6 | FR-16 footer: remove the existing footer at `plan/SKILL.md:251` rather than trim or keep | (a) remove, (b) keep, (c) trim | (a). User answered "Remove it (redundant)" during plan-time. Inline `[only if applicable]` markers carry the meaning; the second sentence ("every item must have the exact command and expected outcome") is a duplicate of the broader "exact commands" rule that runs throughout the skill. |
| P7 | FR-10: single `_shared/` file, no `.codex/` mirror | user answer | User confirmed `_shared/` is sufficient — same pattern as `feature-folder.md` and `interactive-prompts.md`. |

---

## Code Study Notes

Files read during Phase 2:

- `plugins/pmos-toolkit/skills/_shared/feature-folder.md` — pattern for the new shared file: H1 title with "MUST READ" callout, numbered Steps, "Anti-Patterns" footer.
- `plugins/pmos-toolkit/skills/_shared/interactive-prompts.md` — pattern for two-path protocol (primary `AskUserQuestion` + Platform fallback) and `## Consumers` footer listing consuming skills.
- `requirements/SKILL.md` (479 lines) — has `### Findings Presentation Protocol` at line 396; insertion anchor is the Anti-pattern line 414. Non-Goals templates at lines 231 (Tier 2) and 282-283 (Tier 3) need em-dash patch. Confirmed precedent: spec-template line 38 already uses `- NOT doing [X] in this iteration because [reason]` — the patch standardizes on em-dash.
- `spec/SKILL.md` (592 lines) — `### Findings Presentation Protocol` at line 502; Anti-pattern at line 520. Phase 3 Role Protocol numbered list at lines 149-154 (currently 3 steps, FR-12 adds step 4).
- `simulate-spec/SKILL.md` (450 lines) — Phase 6 four-section template at lines 316-321 (4 bullets). Phase 7 Tier 3 line at 349 (Tier 2 at 348). Anti-pattern at line 351 footer.
- `plan/SKILL.md` (451 lines) — Cleanup at lines 246-249 (4 bullets); footer at 251 (to be removed per P6). "Prescribe the interface, leave the implementation" rule at line 282. Structural Checklist items 1–11 at lines 329-339; insertion point after line 339. Anti-pattern at line 374.
- `wireframes/SKILL.md` — `### Findings Presentation Protocol (cross-file rollup)` at line 381; Anti-pattern at line 393.
- `prototype/SKILL.md` — `## Phase 8: Findings Presentation Protocol` at line 409; Anti-pattern at line 428.

**Pattern observation:** every consumer's Findings Presentation block ends with an italicized `**Anti-pattern:** A wall of prose...` line, then a blank line, then either Exit Criteria or the next phase. The reference pointer slots cleanly between Anti-pattern and the next heading.

**Constraint:** `Edit` tool requires unique `old_string` matches per file. Most anchors are unique by construction (Anti-pattern lines mention "Always structure the ask" — globally unique), but the `[only if applicable]` patches (FR-16) need full-line context to disambiguate the 4 Cleanup bullets.

---

## Prerequisites

- Working tree on branch `main` (current state confirmed: only `docs/plans/2026-04-23-verify-skill-teeth-plan.md` is untracked from prior work; this plan adds another untracked plan doc).
- Spec doc at `docs/specs/2026-05-02-structured-ask-edge-cases-design.md` exists (confirmed).
- No in-flight pipeline run consuming the affected skills (docs change only; no runtime risk).

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `plugins/pmos-toolkit/skills/_shared/structured-ask-edge-cases.md` | Canonical home for the three edge-case rules + Platform fallback subsection + Consumers footer |
| Modify | `plugins/pmos-toolkit/skills/requirements/SKILL.md:231` | Em-dash on Tier 2 Non-Goals example |
| Modify | `plugins/pmos-toolkit/skills/requirements/SKILL.md:282-283` | Em-dash on Tier 3 Non-Goals examples (2 lines) |
| Modify | `plugins/pmos-toolkit/skills/requirements/SKILL.md:~414` | Append shared-protocol pointer after Anti-pattern |
| Modify | `plugins/pmos-toolkit/skills/spec/SKILL.md:149-154` | Add step 4 (invariant-impact check) to Role Protocol numbered list |
| Modify | `plugins/pmos-toolkit/skills/spec/SKILL.md:~520` | Append shared-protocol pointer after Anti-pattern |
| Modify | `plugins/pmos-toolkit/skills/simulate-spec/SKILL.md:316-321` | Add N/A-allowed sentence to Phase 6 four-section guidance |
| Modify | `plugins/pmos-toolkit/skills/simulate-spec/SKILL.md:349` | Add "Category coherence over batch fullness" sentence to Tier 3 batching rule |
| Modify | `plugins/pmos-toolkit/skills/simulate-spec/SKILL.md:~351` | Append shared-protocol pointer (after Platform fallback line, before "Spec edits" H3) |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md:282` | Add "Task code block size" bullet after "Prescribe the interface" rule |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md:246-251` | Append `[only if applicable]` to each of 4 Cleanup bullets; remove footer at line 251 |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md:339` | Add Structural Checklist item 12 (Refactor-before-modify) |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md:~374` | Append shared-protocol pointer after Anti-pattern |
| Modify | `plugins/pmos-toolkit/skills/wireframes/SKILL.md:~393` | Append shared-protocol pointer after Anti-pattern |
| Modify | `plugins/pmos-toolkit/skills/prototype/SKILL.md:~428` | Append shared-protocol pointer after Anti-pattern |
| Test | (none — verification is grep, see TN) | n/a |

---

## Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| An anchor line has drifted since the spec was written (someone else edited the file in parallel) | Low | Per-FR Edit calls use unique full-line `old_string`; failure isolates to that one FR. Re-anchor by re-reading the file, do not bypass. |
| FR-16 Cleanup-bullet edits create double markers (`[only if applicable] [only if applicable]`) on re-application | Low | TN includes a negative grep that fails the run if doubles are present; idempotent `old_string` includes the original text without the marker. |
| The new pointer line uses `../_shared/` relative path; if a consumer skill is later moved up/down a level, the path breaks | Low | All 6 consumers live one level deep at `plugins/pmos-toolkit/skills/<skill>/SKILL.md`; relative path is uniform. Documented in shared file's Consumers section so a future mover sees it. |
| The shared file's anti-patterns or examples drift from individual skill phrasing as those skills evolve | Medium | The shared file is canonical; consumers reference, don't re-state. Future retros that surface a new edge case append to the shared file in one place. |

---

## Tasks

### T1: Create the shared protocol file

**Goal:** A new file at `plugins/pmos-toolkit/skills/_shared/structured-ask-edge-cases.md` documenting the three edge cases + Platform fallback + Consumers footer.

**Spec refs:** FR-01, FR-02, FR-03, FR-04, FR-05

**Files:**
- Create: `plugins/pmos-toolkit/skills/_shared/structured-ask-edge-cases.md`

**Steps:**

- [ ] **Step 1: Confirm absence (red).**
  Run: `test ! -f plugins/pmos-toolkit/skills/_shared/structured-ask-edge-cases.md && echo OK`
  Expected: `OK`

- [ ] **Step 2: Write the file with `Write` tool.** Content shape (prescribed; the implementor writes the body):
  - H1: `# Structured-Ask Edge Cases — Shared Protocol`
  - Opening "MUST READ" callout (1-2 sentences) saying consumers MUST read this before applying any disposition; do not infer.
  - Brief framing paragraph explaining the cross-cutting pattern.
  - **H2 `## 1. Free-form reply to a structured question`** — trigger condition (user reply isn't one of the offered options), prescribed steps (1: paraphrase the reply back as one of the offered options; 2: confirm the disposition with the user before applying; 3: log both the original reply and back-mapped disposition in the consumer's Review/Findings Log). Concrete example with a "clean up old data first" reply mapped to **Modify**.
  - **H2 `## 2. Non-recommended pick that may break an invariant`** — trigger (agent's recommended option was not chosen), prescribed steps (1: before moving on, ask "Does this choice change any existing invariant or contract?"; 2: if yes, append a Decision-Log entry with explicit trade-off; 3: if no, record disposition and continue). Concrete example with a one-photo-one-moment invariant breaking under a "both" choice.
  - **H2 `## 3. Leftover findings that don't share a category`** — trigger (last batch's findings don't share a coherent grouping), prescribed steps (1: prefer category coherence over batch fullness; 2: issue 1-2 question calls instead of padding to 4 with unrelated items). One concrete example.
  - **H2 `## Platform fallback (no AskUserQuestion)`** — same three rules adapted to numbered-list reply mode: free-form reply → echo back as numbered option; non-recommended pick → ask the invariant question as a follow-up text prompt; leftover-coherence rule unchanged.
  - **H2 `## Consumers`** — bullet list naming the 6 consuming skills with one-line context each (`requirements`, `spec`, `simulate-spec`, `plan`, `wireframes`, `prototype`).
  - **H2 `## Anti-Patterns (DO NOT)`** — 4-5 bullets:
    1. Don't silently re-interpret a free-form reply without confirming the back-mapped disposition.
    2. Don't skip the invariant question after a non-recommended pick.
    3. Don't pad a final batch with unrelated leftovers to hit the ≤4 cap.
    4. Don't duplicate this protocol's content in the consumer files — link to it.
    5. **Don't add a 4th edge case to this file without retro evidence (named scenario + named skill + named line). Rule-bloat is its own anti-pattern; the three current cases earned their place by surfacing in a real session.**

- [ ] **Step 3: Verify presence and section count (green).**
  Run: `test -f plugins/pmos-toolkit/skills/_shared/structured-ask-edge-cases.md && grep -c "^## " plugins/pmos-toolkit/skills/_shared/structured-ask-edge-cases.md`
  Expected: file exists; integer ≥ 5 (3 edge cases + Platform fallback + Consumers, plus optional Anti-Patterns).

- [ ] **Step 4: Verify each required H2 is present.**
  Run: `for h in "Free-form reply" "Non-recommended" "Leftover findings" "Platform fallback" "Consumers"; do grep -q "^## .*$h" plugins/pmos-toolkit/skills/_shared/structured-ask-edge-cases.md && echo "✓ $h" || echo "✗ MISSING: $h"; done`
  Expected: 5 lines, all `✓`.

- [ ] **Step 5: Commit.**
  ```bash
  git add plugins/pmos-toolkit/skills/_shared/structured-ask-edge-cases.md
  git commit -m "feat(skills): add shared structured-ask edge-cases protocol"
  ```

**Inline verification:**
- File exists.
- All 5 mandatory H2 sections present.
- Consumers footer names all 6 skills.

---

### T2: requirements — Non-Goals em-dash + shared-protocol pointer

**Goal:** Patch FR-11 (em-dash on 3 Non-Goals example lines) and FR-06 (pointer after Anti-pattern in Findings Presentation Protocol).

**Spec refs:** FR-06, FR-10, FR-11. Decision-Log refs: D4, P4.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/requirements/SKILL.md`

**Steps:**

- [ ] **Step 1: Pre-patch grep (red).**
  Run: `grep -n 'NOT doing \[X\] — because' plugins/pmos-toolkit/skills/requirements/SKILL.md ; grep -n 'structured-ask-edge-cases' plugins/pmos-toolkit/skills/requirements/SKILL.md`
  Expected: both grep commands print **no matches**.

- [ ] **Step 2: Edit Tier 2 Non-Goals (line ~231).**
  - `old_string`: `- NOT doing [X] because [reason]`
  - `new_string`: `- NOT doing [X] — because [reason]`

- [ ] **Step 3: Edit Tier 3 Non-Goals (lines ~282-283).** Two separate Edits if both lines exist verbatim, or one Edit if a unique anchor block can be matched.
  - `old_string` line 1: `- NOT doing [X] in this iteration because [reason]`
  - `new_string` line 1: `- NOT doing [X] in this iteration — because [reason]`
  - `old_string` line 2: `- NOT solving [adjacent problem] because [reason]`
  - `new_string` line 2: `- NOT solving [adjacent problem] — because [reason]`

- [ ] **Step 4: Append pointer after Anti-pattern (line ~414).**
  - `old_string`:
    ```
    **Anti-pattern:** A wall of prose ending in "Let me know what you'd like to fix." This forces the user to re-state each finding in their reply. Always structure the ask.

    ### Exit Criteria (ALL must be true)
    ```
  - `new_string`:
    ```
    **Anti-pattern:** A wall of prose ending in "Let me know what you'd like to fix." This forces the user to re-state each finding in their reply. Always structure the ask.

    **Edge cases of structured asks:** when a user reply slips outside the offered options (free-form text, a non-recommended pick that may break an invariant, or leftover findings that don't share a category), follow `../_shared/structured-ask-edge-cases.md`.

    ### Exit Criteria (ALL must be true)
    ```

- [ ] **Step 5: Post-patch grep (green).**
  Run:
  ```
  grep -c 'NOT doing \[X\] — because\|NOT doing \[X\] in this iteration — because\|NOT solving \[adjacent problem\] — because' plugins/pmos-toolkit/skills/requirements/SKILL.md
  grep -c 'structured-ask-edge-cases.md' plugins/pmos-toolkit/skills/requirements/SKILL.md
  ```
  Expected: first = 3; second = 1.

- [ ] **Step 6: Commit.**
  ```bash
  git add plugins/pmos-toolkit/skills/requirements/SKILL.md
  git commit -m "docs(requirements): em-dash on Non-Goals examples + structured-ask edge-case pointer"
  ```

**Inline verification:**
- 3 em-dash matches, 1 pointer match.
- No bare "because" left in any `NOT doing ...` line: `! grep -E '^- NOT (doing|solving) \[[^]]+\] (in this iteration )?because' plugins/pmos-toolkit/skills/requirements/SKILL.md`.

---

### T3: spec — Role Protocol invariant step + shared-protocol pointer

**Goal:** Patch FR-12 (add step 4 to Role Protocol) and FR-07 (pointer after Anti-pattern).

**Spec refs:** FR-07, FR-10, FR-12. Decision-Log refs: D2.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/spec/SKILL.md`

**Steps:**

- [ ] **Step 1: Pre-patch grep (red).**
  Run: `grep -n 'change any existing invariant' plugins/pmos-toolkit/skills/spec/SKILL.md ; grep -n 'structured-ask-edge-cases' plugins/pmos-toolkit/skills/spec/SKILL.md`
  Expected: both empty.

- [ ] **Step 2: Add step 4 to Role Protocol (after line 154).**
  - `old_string`:
    ```
    3. Note answers or stated assumptions as decisions for the spec

    **Anti-pattern:** Silently skipping a role
    ```
  - `new_string`:
    ```
    3. Note answers or stated assumptions as decisions for the spec
    4. **If the user picks a non-recommended option** in any AskUserQuestion you issued for this role, before moving to the next role ask: "Does this choice change any existing invariant or contract? If yes, capture it as a Decision-Log entry with the trade-off explicit." See `../_shared/structured-ask-edge-cases.md` §2 for the canonical form.

    **Anti-pattern:** Silently skipping a role
    ```

- [ ] **Step 3: Append pointer after Findings Presentation Protocol Anti-pattern (line ~520).**
  - `old_string`:
    ```
    **Anti-pattern:** A wall of prose ending in "Let me know what you'd like to fix." This forces the user to re-state each finding in their reply. Always structure the ask.

    ### Exit Criteria (ALL must be true)
    ```
  - `new_string`:
    ```
    **Anti-pattern:** A wall of prose ending in "Let me know what you'd like to fix." This forces the user to re-state each finding in their reply. Always structure the ask.

    **Edge cases of structured asks:** when a user reply slips outside the offered options (free-form text, a non-recommended pick that may break an invariant, or leftover findings that don't share a category), follow `../_shared/structured-ask-edge-cases.md`.

    ### Exit Criteria (ALL must be true)
    ```

- [ ] **Step 4: Post-patch grep (green).**
  Run:
  ```
  grep -c 'change any existing invariant' plugins/pmos-toolkit/skills/spec/SKILL.md
  grep -c 'structured-ask-edge-cases.md' plugins/pmos-toolkit/skills/spec/SKILL.md
  ```
  Expected: first ≥ 1; second = 2 (Role Protocol's §2 reference + Findings Protocol pointer).

- [ ] **Step 5: Commit.**
  ```bash
  git add plugins/pmos-toolkit/skills/spec/SKILL.md
  git commit -m "docs(spec): role protocol invariant-impact step + structured-ask edge-case pointer"
  ```

**Inline verification:**
- Role Protocol numbered list now has 4 steps: `grep -A 8 'For each role:' plugins/pmos-toolkit/skills/spec/SKILL.md | head -10` shows steps 1-4.

---

### T4: simulate-spec — N/A pseudocode + category coherence + shared-protocol pointer

**Goal:** Patch FR-13 (N/A allowed in four-section template), FR-14 (category-coherence rule), FR-08 (pointer).

**Spec refs:** FR-08, FR-10, FR-13, FR-14. Decision-Log refs: D5, D6.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/simulate-spec/SKILL.md`

**Steps:**

- [ ] **Step 1: Pre-patch grep (red).**
  Run:
  ```
  grep -n 'N/A —' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
  grep -n 'Category coherence' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
  grep -n 'structured-ask-edge-cases' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
  ```
  Expected: all three empty.

- [ ] **Step 2: Add N/A-allowed sentence to Phase 6 (after the four bullets at lines 318-321).**
  - `old_string`:
    ```
    - **Concurrency notes:** every variable is what's protected by what (advisory lock, transaction isolation level, unique constraint, CAS column)

    ### Why these four sections
    ```
    *(Note: actual line is `- **Concurrency notes:** what's protected by what...` — adjust `old_string` to match the actual text.)*
  - `new_string`: same as old + insertion of one paragraph between the last bullet and `### Why these four sections`:
    ```
    If a section doesn't apply to this flow (e.g., file-IO-only flows have no DB calls; stateless transforms have no state transitions), declare it as `**<Section>:** N/A — <one-line reason>` and move on. Do not pad with empty bullets.
    ```

- [ ] **Step 3: Add category-coherence rule to Phase 7 Tier 3 line (~349).**
  - `old_string`: the full Tier 3 bullet starting with `- **Tier 3:** batch gaps by category` and ending at the line break before `**Platform fallback**`.
  - `new_string`: same bullet + one trailing sentence: ` **Category coherence over batch fullness:** if leftover findings don't share a category, issue them as separate 1-2 question calls rather than padding a final batch to 4 with unrelated items. See \`../_shared/structured-ask-edge-cases.md\` §3.`

- [ ] **Step 4: Append pointer after Platform fallback line (~351).**
  - `old_string`:
    ```
    **Platform fallback (no `AskUserQuestion`):** present a numbered gap table with a disposition column; ask the user to reply with the selections. Do NOT silently apply patches.

    ### Spec edits
    ```
  - `new_string`:
    ```
    **Platform fallback (no `AskUserQuestion`):** present a numbered gap table with a disposition column; ask the user to reply with the selections. Do NOT silently apply patches.

    **Edge cases of structured asks:** when a user reply slips outside the offered options (free-form text, a non-recommended pick that may break an invariant, or leftover findings that don't share a category), follow `../_shared/structured-ask-edge-cases.md`.

    ### Spec edits
    ```

- [ ] **Step 5: Post-patch grep (green).**
  Run:
  ```
  grep -c 'N/A —' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
  grep -c 'Category coherence over batch fullness' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
  grep -c 'structured-ask-edge-cases.md' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
  ```
  Expected: 1 / 1 / 2 (Phase 7 cite + footer pointer).

- [ ] **Step 6: Commit.**
  ```bash
  git add plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
  git commit -m "docs(simulate-spec): N/A pseudocode sections + category coherence + edge-case pointer"
  ```

**Inline verification:**
- Phase 6 four-section guidance now ends with N/A escape hatch.
- Phase 7 Tier 3 bullet ends with category-coherence sentence.

---

### T5: plan — task code-block bullet + Cleanup `[only if applicable]` + Structural Checklist item 12 + shared-protocol pointer

**Goal:** Patch FR-15 (task code-block bullet), FR-16 (per-bullet Cleanup markers + footer removal per P6), FR-17 (Structural Checklist item 12), FR-09 (pointer).

**Spec refs:** FR-09, FR-10, FR-15, FR-16, FR-17. Decision-Log refs: D7, D8, D9, P6.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/plan/SKILL.md`

**Steps:**

- [ ] **Step 1: Pre-patch grep (red).**
  Run:
  ```
  grep -n 'Task code block size' plugins/pmos-toolkit/skills/plan/SKILL.md
  grep -n 'Refactor-before-modify' plugins/pmos-toolkit/skills/plan/SKILL.md
  grep -n '\[only if applicable\]' plugins/pmos-toolkit/skills/plan/SKILL.md
  grep -n 'structured-ask-edge-cases' plugins/pmos-toolkit/skills/plan/SKILL.md
  ```
  Expected: all four empty.

- [ ] **Step 2: Add task code-block-size bullet (FR-15, after line 282 "Prescribe the interface" rule).**
  - `old_string`:
    ```
    **Prescribe the interface, leave the implementation:** Specify function names, signatures, test assertions, file paths, and commands. Leave internal algorithm details and refactoring decisions to the implementor.

    ### Verification Must Prove Behavior
    ```
  - `new_string`:
    ```
    **Prescribe the interface, leave the implementation:** Specify function names, signatures, test assertions, file paths, and commands. Leave internal algorithm details and refactoring decisions to the implementor.

    **Task code block size:** if a single task's pasted code block exceeds ~80 lines, choose one of: (a) split the task into smaller tasks, (b) reference an external scratch file the implementor opens, or (c) prescribe the interface (function signatures, test assertions, expected behavior) and let the implementor write the body. Long pasted code blocks bias plan length and substitute for engineering judgment.

    ### Verification Must Prove Behavior
    ```

- [ ] **Step 3: Append `[only if applicable]` to each Cleanup bullet (FR-16, lines 246-249) AND remove the footer at line 251 (per P6).** Single Edit covering the full block:
  - `old_string`:
    ```
    **Cleanup:**
    - [ ] Remove temporary files and debug logging
    - [ ] Stop worktree containers if running: `docker compose -f docker-compose.worktree.yml -p <project> down`
    - [ ] Flip feature flags if applicable
    - [ ] Update documentation files (`CLAUDE.md`, changelogs, etc.)

    [Only include items that apply to this feature. But every item must have the exact command and expected outcome.]
    ```
  - `new_string`:
    ```
    **Cleanup:**
    - [ ] Remove temporary files and debug logging [only if applicable]
    - [ ] Stop worktree containers if running: `docker compose -f docker-compose.worktree.yml -p <project> down` [only if applicable]
    - [ ] Flip feature flags if applicable
    - [ ] Update documentation files (`CLAUDE.md`, changelogs, etc.) [only if applicable]

    [Every retained item must have an exact command and expected outcome.]
    ```
    *(Note: "Flip feature flags if applicable" already has "if applicable" inline — leaving as-is avoids redundant doubling. The replacement footer keeps the second sentence's intent without re-stating "only include items that apply" since per-bullet markers now carry that.)*

- [ ] **Step 4: Add Structural Checklist item 12 (FR-17, after line 339 item 11).**
  - `old_string`:
    ```
    11. **Final-verification polish coverage:** Does TN include the hard-reload-every-route step, the force-an-error-path step, the UX polish checklist line, and (if wireframes exist) the wireframe diff line?

    **B. Design-Level Self-Critique**
    ```
  - `new_string`:
    ```
    11. **Final-verification polish coverage:** Does TN include the hard-reload-every-route step, the force-an-error-path step, the UX polish checklist line, and (if wireframes exist) the wireframe diff line?
    12. **Refactor-before-modify:** Does any task modify a function whose existing structure isn't preserved by the modification? If yes, the prerequisite refactor must be its own numbered sub-step before the additive change.

    **B. Design-Level Self-Critique**
    ```

- [ ] **Step 5: Append pointer after Findings Presentation Protocol Anti-pattern (line ~374).**
  - `old_string`:
    ```
    **Anti-pattern:** A wall of prose ending in "Let me know what you'd like to fix." This forces the user to re-state each finding in their reply. Always structure the ask.

    ### Exit Criteria (ALL must be true)
    ```
  - `new_string`:
    ```
    **Anti-pattern:** A wall of prose ending in "Let me know what you'd like to fix." This forces the user to re-state each finding in their reply. Always structure the ask.

    **Edge cases of structured asks:** when a user reply slips outside the offered options (free-form text, a non-recommended pick that may break an invariant, or leftover findings that don't share a category), follow `../_shared/structured-ask-edge-cases.md`.

    ### Exit Criteria (ALL must be true)
    ```

- [ ] **Step 6: Post-patch grep (green).**
  Run:
  ```
  grep -c 'Task code block size' plugins/pmos-toolkit/skills/plan/SKILL.md
  grep -c 'Refactor-before-modify' plugins/pmos-toolkit/skills/plan/SKILL.md
  grep -c '\[only if applicable\]' plugins/pmos-toolkit/skills/plan/SKILL.md
  grep -c 'structured-ask-edge-cases.md' plugins/pmos-toolkit/skills/plan/SKILL.md
  grep -c 'Only include items that apply to this feature' plugins/pmos-toolkit/skills/plan/SKILL.md
  ```
  Expected: 1 / 1 / 3 / 1 / 0 (footer removed).

- [ ] **Step 7: Idempotency check.**
  Run: `grep -E '\[only if applicable\] \[only if applicable\]' plugins/pmos-toolkit/skills/plan/SKILL.md ; echo "rc=$?"`
  Expected: `rc=1` (no doubles).

- [ ] **Step 8: Commit.**
  ```bash
  git add plugins/pmos-toolkit/skills/plan/SKILL.md
  git commit -m "docs(plan): task code-block size + cleanup markers + refactor checklist + edge-case pointer"
  ```

**Inline verification:**
- 4 patches landed, 0 doubles, footer line gone.

---

### T6: wireframes — shared-protocol pointer

**Goal:** Patch FR-09 equivalent for wireframes (insertion after Findings Presentation Protocol Anti-pattern).

**Spec refs:** Scope expansion per P5 + user dispositions during plan. Decision-Log ref: P5.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/wireframes/SKILL.md`

**Steps:**

- [ ] **Step 1: Pre-patch grep (red).**
  Run: `grep -n 'structured-ask-edge-cases' plugins/pmos-toolkit/skills/wireframes/SKILL.md`
  Expected: empty.

- [ ] **Step 2: Append pointer after Anti-pattern (line ~393).**
  - `old_string`:
    ```
    **Anti-pattern:** A wall of prose ending in "Let me know what you'd like to fix." Always structure the ask.
    ```
    *(End-of-section anchor; verify it's the last line of the file or followed by a blank line.)*
  - `new_string`:
    ```
    **Anti-pattern:** A wall of prose ending in "Let me know what you'd like to fix." Always structure the ask.

    **Edge cases of structured asks:** when a user reply slips outside the offered options (free-form text, a non-recommended pick that may break an invariant, or leftover findings that don't share a category), follow `../_shared/structured-ask-edge-cases.md`.
    ```

- [ ] **Step 3: Post-patch grep (green).**
  Run: `grep -c 'structured-ask-edge-cases.md' plugins/pmos-toolkit/skills/wireframes/SKILL.md`
  Expected: `1`.

- [ ] **Step 4: Commit.**
  ```bash
  git add plugins/pmos-toolkit/skills/wireframes/SKILL.md
  git commit -m "docs(wireframes): structured-ask edge-case pointer"
  ```

---

### T7: prototype — shared-protocol pointer

**Goal:** Patch the equivalent reference in `/prototype` (insertion after Phase 8 Findings Presentation Anti-pattern).

**Spec refs:** Scope expansion per P5. Decision-Log ref: P5.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/prototype/SKILL.md`

**Steps:**

- [ ] **Step 1: Pre-patch grep (red).**
  Run: `grep -n 'structured-ask-edge-cases' plugins/pmos-toolkit/skills/prototype/SKILL.md`
  Expected: empty.

- [ ] **Step 2: Append pointer after Anti-pattern (line ~428).** Same `old_string` / `new_string` pattern as T6, anchored on prototype's Anti-pattern line: `**Anti-pattern:** A wall of prose ending in "Let me know what you'd like to fix." Always structure the ask.`
  - Add the same one-paragraph pointer below it.

- [ ] **Step 3: Post-patch grep (green).**
  Run: `grep -c 'structured-ask-edge-cases.md' plugins/pmos-toolkit/skills/prototype/SKILL.md`
  Expected: `1`.

- [ ] **Step 4: Commit.**
  ```bash
  git add plugins/pmos-toolkit/skills/prototype/SKILL.md
  git commit -m "docs(prototype): structured-ask edge-case pointer"
  ```

---

### TN: Final Verification

**Goal:** Confirm every patch landed correctly and no unintended side-effects exist.

- [ ] **Run spec §10.1 9-command structural verification block (with the 6-skill expansion adjustment):**
  ```bash
  # 1. Shared protocol file exists with ≥4 H2 sections (3 edge cases + Platform fallback; Consumers + Anti-Patterns push it ≥5)
  test -f plugins/pmos-toolkit/skills/_shared/structured-ask-edge-cases.md && \
    grep -c "^## " plugins/pmos-toolkit/skills/_shared/structured-ask-edge-cases.md
  # Expected: integer ≥ 4

  # 2. All SIX consumer skills reference the new file (was 4 in spec; expanded per P5)
  grep -l "structured-ask-edge-cases.md" \
    plugins/pmos-toolkit/skills/requirements/SKILL.md \
    plugins/pmos-toolkit/skills/spec/SKILL.md \
    plugins/pmos-toolkit/skills/simulate-spec/SKILL.md \
    plugins/pmos-toolkit/skills/plan/SKILL.md \
    plugins/pmos-toolkit/skills/wireframes/SKILL.md \
    plugins/pmos-toolkit/skills/prototype/SKILL.md
  # Expected: 6 file paths printed

  # 3. Em-dash applied to Non-Goals templates
  grep -cE 'NOT (doing|solving) \[[^]]+\] (in this iteration )?— because' plugins/pmos-toolkit/skills/requirements/SKILL.md
  # Expected: 3

  # 4. Plan structural-checklist item 12 added
  grep -c 'Refactor-before-modify' plugins/pmos-toolkit/skills/plan/SKILL.md
  # Expected: 1

  # 5. Plan task-code-block-size rule added
  grep -c 'Task code block size' plugins/pmos-toolkit/skills/plan/SKILL.md
  # Expected: 1

  # 6. simulate-spec category-coherence rule added
  grep -c 'Category coherence over batch fullness' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
  # Expected: 1

  # 7. simulate-spec N/A pseudocode-section rule added
  grep -c 'N/A —' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
  # Expected: ≥ 1

  # 8. spec invariant-impact step added
  grep -c 'change any existing invariant' plugins/pmos-toolkit/skills/spec/SKILL.md
  # Expected: 1

  # 9. No double-marker leak from Cleanup edits
  grep -E '\[only if applicable\] \[only if applicable\]' plugins/pmos-toolkit/skills/plan/SKILL.md ; echo "rc=$?"
  # Expected: rc=1 (no matches)
  ```

- [ ] **Audit: no orphan footers from FR-16 removal.**
  Run: `grep -c 'Only include items that apply to this feature' plugins/pmos-toolkit/skills/plan/SKILL.md`
  Expected: `0`.

- [ ] **Audit: every consumer's pointer is the identical canonical paragraph (per OQ1).**
  Run: `grep -h 'structured-ask-edge-cases' plugins/pmos-toolkit/skills/{requirements,spec,simulate-spec,plan,wireframes,prototype}/SKILL.md | sort -u | wc -l`
  Expected: `1` (exactly one distinct line, since /spec has 2 mentions both should match the canonical sentence — note: spec also has a `§2` cite in the Role Protocol; so this audit may show 2 lines for /spec only. Adjust expected to 2 if so, both matching the OQ1 canonical text or the §2-cited variant.)
  Run instead the safer audit: `grep -c 'follow \`../_shared/structured-ask-edge-cases.md\`' plugins/pmos-toolkit/skills/{requirements,spec,simulate-spec,plan,wireframes,prototype}/SKILL.md`
  Expected: 1 / ≥1 / 1 / 1 / 1 / 1 (each consumer ≥1 match).

- [ ] **Manual review:** open each patched section in context and read it as a critical reviewer. Confirm:
  1. The Role Protocol numbered list in `/spec` flows naturally with 4 steps (not jarring).
  2. The Cleanup section in `/plan` reads naturally with the new markers and the trimmed footer.
  3. The Structural Checklist item 12 fits the cadence of items 1-11 (similar voice and length).
  4. The new `_shared/structured-ask-edge-cases.md` reads as a coherent standalone protocol — not a rule-dump.

- [ ] **Run full repo sanity check** (no broken links from the new pointer paths):
  ```bash
  # Confirm the relative path resolves: from any consumer skill dir, ../_shared/structured-ask-edge-cases.md must exist.
  for skill in requirements spec simulate-spec plan wireframes prototype; do
    target="plugins/pmos-toolkit/skills/$skill/../_shared/structured-ask-edge-cases.md"
    test -f "$target" && echo "✓ $skill" || echo "✗ BROKEN from $skill"
  done
  ```
  Expected: 6 lines, all `✓`.

**Cleanup:**
- [ ] No temp files were created [only if applicable]
- [ ] No worktree containers in use [only if applicable]

---

## Review Log

| Loop | Findings | Changes Made |
|------|----------|-------------|
| 1    | (to be filled in review) | (to be filled) |
| 2    | (to be filled in review) | (to be filled) |

---

## Open Questions

All resolved during plan-time review:

| # | Question | Resolution |
|---|----------|-----------|
| 1 | Pointer paragraph: identical copy-paste vs. local adaptation? | **Identical copy-paste in all 6 skills.** The exact paragraph is: `**Edge cases of structured asks:** when a user reply slips outside the offered options (free-form text, a non-recommended pick that may break an invariant, or leftover findings that don't share a category), follow \`../_shared/structured-ask-edge-cases.md\`.` Use verbatim in T2–T7. TN audit expects exactly 1 distinct phrasing across the 6 files. |
| 2 | Shared protocol Anti-Patterns: forbid 4th edge case? | **Yes — add explicit anti-pattern in T1 Step 2.** The Anti-Patterns block must include: "Do NOT add a 4th edge case to this file without retro evidence (named scenario + named skill + named line). Rule-bloat is its own anti-pattern; the three current cases earned their place by surfacing in a real session." |
| 3 | MEMORY.md entry? | **Skip.** The protocol lives in the skill files themselves and is loaded on skill invocation. MEMORY.md is reserved for facts not derivable from code; this is derivable. Remove the MEMORY.md cleanup line from TN. |
