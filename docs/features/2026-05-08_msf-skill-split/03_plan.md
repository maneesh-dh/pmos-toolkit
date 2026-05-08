# /msf Skill Split & PSYCH Relocation — Implementation Plan

**Date:** 2026-05-08
**Spec:** `02_spec.md`
**Requirements:** `01_requirements.md`
**Grill:** `grills/2026-05-08_msf-skill-design.md`

---

## Overview

This plan splits `/msf` into `/msf-req` and `/msf-wf`, extracts shared MSF heuristics into `_shared/`, relocates PSYCH scoring out of `/wireframes` Phase 6 into `/msf-wf`, updates all callers, and ships in pmos-toolkit 2.22.0. The work is purely a markdown-skill refactor — no code, no DB, no APIs. Verification is grep-based plus a structural skill-validator pass plus a manual end-to-end test through `/wireframes` on a sample feature.

**Done when:** `/msf-req` and `/msf-wf` SKILL.md files exist with disjoint triggers; `/msf/SKILL.md` is deleted; `_shared/msf-heuristics.md` exists; PSYCH content (incl. `reference/psych-output-format.md`) lives in `/msf-wf` only; `/wireframes/SKILL.md` Phase 6 is a thin wrapper invoking `/msf-wf --apply-edits`; all six caller skills + README updated; plugin version bumped to 2.22.0; CHANGELOG entry added; spec §10.4 verification commands all pass; T11 standalone /msf-req run + trigger-phrase test + wrong-input test all pass.

**Execution order:**

```
T1 (extract _shared/msf-heuristics.md)
  └── T2 (create /msf-req)             [P with T3]
  └── T3 (create /msf-wf, incl. PSYCH) [P with T2]
       └── T4 (move reference/psych-output-format.md)
            └── T5 (rewrite /wireframes Phase 6)
                 └── T6 (update /requirements + /spec)
                      └── T7 (update other 4 callers)
                           └── T8 (external doc audit + CHANGELOG)
                                └── T9 (delete /msf/SKILL.md)
                                     └── T10 (bump plugin version)
                                          └── T11 (final verification)
```

T2 and T3 can run in parallel after T1. Everything else is sequential because each step's grep-verification depends on the prior state.

---

## Decision Log

> Inherits 10 architecture decisions from spec §4. Implementation-specific decisions below.

| # | Decision | Options Considered | Rationale |
|---|----------|-------------------|-----------|
| D1 | One findings doc with embedded PSYCH section, not two files | (a) one file, (b) two files, (c) two with cross-links | Easier for /spec to consume; one save step in /msf-wf; resolves spec Q-1. (User dispositioned at plan start.) |
| D2 | /msf-wf walks journeys sequentially, no subagent fan-out | (a) sequential, (b) parallel subagents, (c) flag-gated | Avoids shared-file write contention; deterministic findings doc; fine for the typical 3–4 journeys; resolves spec Q-2. |
| D3 | Executive-summary template lives in `_shared/msf-heuristics.md` with mode-specific overrides per skill | (a) shared with overrides, (b) per-skill, (c) hybrid | Single source of truth for shape; mode overrides are 1 paragraph each; resolves spec Q-3. |
| D4 | T1 (extract shared module) is the gating prerequisite for T2 + T3 | (a) shared first, (b) skills first then extract, (c) parallel | Building skills first risks divergent inline templates that re-merge poorly. Extract canonical heuristics first. |
| D5 | T2 and T3 in parallel; T4 (file move) sequential after T3 | (a) all sequential, (b) T2//T3, (c) full parallel | T2 and T3 touch disjoint files. T4 moves a file referenced by T3, so it sequences after. |
| D6 | Drop `/design-crit` from FR-28's audit list | (a) audit anyway, (b) drop | Phase 2 grep confirmed no `/msf` references in design-crit. FR-28's list was based on a substring false positive. |
| D7 | Historical docs in `docs/plans/`, `docs/specs/` left unchanged | (a) update all, (b) update active only, (c) leave historical | Per FR-40 spirit: historical artifacts are immutable record. Active references (README, CLAUDE.md) get updated. |
| D8 | T5 (/wireframes rewrite) does the entire Phase 6 deletion + thin-wrapper insertion in one task with one commit | (a) split delete + insert, (b) one task | Delete-then-insert leaves the file in a broken intermediate state with no Phase 6 at all. Single atomic edit. |
| D9 | T11 (final verification) uses spec §10.4 commands verbatim plus a manual `/wireframes` end-to-end on a sample feature | (a) automated only, (b) manual only, (c) both | Grep covers structural correctness; manual run covers behavioral correctness (the thin wrapper actually invokes /msf-wf). |
| D10 | `_shared/msf-heuristics.md` content extraction strategy: copy verbatim from `/msf/SKILL.md` Phase 1 + Phase 3 Pass A consideration lists, then add new mode-override blocks at the end | (a) verbatim + overrides, (b) rewrite from scratch, (c) hybrid | Verbatim preserves the well-tested consideration questions; rewrite risks dropping subtle wording. Mode overrides are additive. |

---

## Code Study Notes

- **Current `/msf/SKILL.md`** (238 lines): self-contained, contains M/F/S 24-consideration list (lines 96–125), PSYCH rubric (lines 126–155), Phase 1 persona alignment via AskUserQuestion (lines 59–73), Phase 5 dual-write logic (lines 191–203). Most of this content gets distributed across `_shared/msf-heuristics.md`, `/msf-req/SKILL.md`, and `/msf-wf/SKILL.md`.
- **Current `/wireframes/SKILL.md`** (712 lines): Phase 6 = lines 449–555 (entire body), plus PSYCH/MSF integration prose at lines 561–593 with `--skip-psych` and `--wireframes` flag references. Anti-patterns at lines 694–707. Ten more single-line PSYCH mentions scattered (lines 25, 53, 57, 59–60, 77, 614, 630, 647, 678).
- **`reference/psych-output-format.md`** lives at `plugins/pmos-toolkit/skills/wireframes/reference/psych-output-format.md` — referenced from /wireframes line 527 and (per spec) from /msf line ~141. Moves wholesale to `plugins/pmos-toolkit/skills/msf-wf/reference/psych-output-format.md`.
- **Cross-skill `/msf` references** (Phase 2 grep, after dropping /design-crit false positive):
  - `/requirements/SKILL.md`: lines 13, 320, 554
  - `/spec/SKILL.md`: line 13
  - `/wireframes/SKILL.md`: lines 583, 587–593 (handled in T5)
  - `/create-skill/SKILL.md`: line 241
  - `/creativity/SKILL.md`: lines 12, 15
  - `/plan/SKILL.md`: line 13
  - `/product-context/SKILL.md`: line 13
  - `/simulate-spec/SKILL.md`: line 15
- **Plugin manifest:** `plugins/pmos-toolkit/.claude-plugin/plugin.json` line 3 currently `"version": "2.21.0"` → bump to `"2.22.0"`.
- **External docs with active `/msf` refs:** `README.md` line 86. `docs/plans/`, `docs/specs/`, `CLAUDE.md` (if any) per FR-40.
- **Patterns to follow:**
  - Other split-skill packages (`commit-commands/`) show how multi-skill plugins live side-by-side with shared concepts.
  - `_shared/interactive-prompts.md` is the precedent for a single shared markdown referenced by multiple skills via `follow ../_shared/<file>.md`.
  - Skill frontmatter follows the `name`, `description`, `user-invocable`, `argument-hint` shape — copy from `/msf/SKILL.md` lines 1–6.

---

## Prerequisites

- Working directory: `/Users/maneeshdhabria/Desktop/Projects/agent-skills`
- On a clean working tree on `main` (or a feature branch off main); no uncommitted changes related to /msf or /wireframes
- `git`, standard `grep`/`mv` available (macOS BSD or GNU both fine)
- `claude validate plugin` available (for T11 structural test) — if absent, T11 falls back to manual frontmatter inspection

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `plugins/pmos-toolkit/skills/_shared/msf-heuristics.md` | M/F/S consideration list, persona-alignment template, executive-summary template (with mode overrides marker) |
| Create | `plugins/pmos-toolkit/skills/msf-req/SKILL.md` | Req-doc-only MSF analysis; recommendations-only; req-mode summary override |
| Create | `plugins/pmos-toolkit/skills/msf-wf/SKILL.md` | Wireframes MSF + PSYCH; `--apply-edits` for HTML edits; wf-mode summary override |
| Create | `plugins/pmos-toolkit/skills/msf-wf/reference/` | Directory for psych-output-format.md (created by `mv`) |
| Move   | `plugins/pmos-toolkit/skills/wireframes/reference/psych-output-format.md` → `plugins/pmos-toolkit/skills/msf-wf/reference/psych-output-format.md` | PSYCH artifact format spec relocates with PSYCH ownership |
| Modify | `plugins/pmos-toolkit/skills/wireframes/SKILL.md` (lines 25, 53, 57, 59–60, 77, 449–555, 561–593, 614, 630, 647, 678, 694–707) | Remove all PSYCH/MSF prose; replace Phase 6 with thin wrapper invoking `/msf-wf --apply-edits`; remove `--skip-psych` and `--wireframes` flag references |
| Modify | `plugins/pmos-toolkit/skills/requirements/SKILL.md:13,320,554` | Replace `/msf` with `/msf-req` |
| Modify | `plugins/pmos-toolkit/skills/spec/SKILL.md:13` | Replace `[/msf, /creativity]` with `[/msf-req, /creativity]` |
| Modify | `plugins/pmos-toolkit/skills/create-skill/SKILL.md:241` | Replace `/msf` in pipeline diagram |
| Modify | `plugins/pmos-toolkit/skills/creativity/SKILL.md:12,15` | Replace `/msf` (prose + diagram) |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md:13` | Replace `/msf` in pipeline diagram |
| Modify | `plugins/pmos-toolkit/skills/product-context/SKILL.md:13` | Replace `/msf` in pipeline diagram |
| Modify | `plugins/pmos-toolkit/skills/simulate-spec/SKILL.md:15` | Replace `/msf` in pipeline diagram |
| Modify | `README.md:86` | Replace `/msf` in repo-level pipeline diagram |
| Modify | `CHANGELOG.md` (top of file) | New entry for pmos-toolkit 2.22.0 describing the split |
| Modify | `plugins/pmos-toolkit/.claude-plugin/plugin.json:3` | Version bump 2.21.0 → 2.22.0 |
| Delete | `plugins/pmos-toolkit/skills/msf/SKILL.md` | Old skill removed (entire `msf/` directory if empty after) |

---

## Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| /wireframes Phase 6 rewrite drops a subtlety from the original (e.g., the entry-context-medium silent default) | Medium | T3 explicitly preserves FR-36 default; T5 grep verifies no PSYCH text remains; T11 manual run on a sample feature exercises the wrapper end-to-end |
| Trigger-phrase collision: Claude routes "evaluate UX" ambiguously between /msf-req and /msf-wf | Medium | FR-04/05/06 enforce disjoint phrases; T6 spot-checks via the trigger-phrase test (T11 step T11.6) |
| Stale `/msf` references missed in audit (FR-28, FR-40) | Low–Medium | T11 runs the full grep from spec §10.2 + §10.4 — empty result is a hard gate |
| External users running `/msf` directly after the upgrade hit "skill not found" | Low (single-user repo today) | CHANGELOG entry calls out the breaking change; `argument-hint` of new skills is descriptive enough that re-typing is obvious |
| `_shared/msf-heuristics.md` extraction loses wording from the well-tested consideration questions | Low | D10: copy verbatim from /msf SKILL.md, do not paraphrase; T1 verification diffs the consideration list against the original |
| `claude validate plugin` not installed locally → T11 structural test cannot run | Low | T11.1 has a fallback: manual frontmatter inspection per skill |

---

## Rollback

This is a markdown-only refactor with no data mutations. Rollback = `git revert <commit-range>` for the implementation commits. No migration, no deploy, no feature flag.

If a partial-failure state needs unwinding mid-execution: `git reset --hard <commit-before-T1>` is safe because every task commits independently.

---

## Tasks

### T1: Extract `_shared/msf-heuristics.md` from current `/msf/SKILL.md`

**Goal:** Create the canonical shared heuristics file, copying the M/F/S consideration list, persona-alignment template, and executive-summary template verbatim from the existing `/msf/SKILL.md`. Leave `/msf/SKILL.md` in place for now (T9 deletes it).

**Spec refs:** FR-07, FR-08, FR-09, D6 (spec §4), D10 (this plan)

**Files:**
- Create: `plugins/pmos-toolkit/skills/_shared/msf-heuristics.md`
- Read (no modify): `plugins/pmos-toolkit/skills/msf/SKILL.md`

**Steps:**

- [ ] **T1.1.** Read `plugins/pmos-toolkit/skills/msf/SKILL.md` lines 59–73 (Phase 1 persona alignment), 96–125 (M/F/S consideration list), and 174–186 (Phase 4 recommendation table format).

- [ ] **T1.2.** Create `plugins/pmos-toolkit/skills/_shared/msf-heuristics.md` with the structure below. Copy considerations and persona-alignment text verbatim from /msf SKILL.md — DO NOT paraphrase. The file MUST NOT contain any PSYCH content (FR-08).

  Required sections in the new file:
  1. `# MSF Shared Heuristics` heading + 1-paragraph purpose block referencing /msf-req and /msf-wf.
  2. `## Persona Alignment` — copy lines 59–73 of /msf SKILL.md verbatim, replace the AskUserQuestion-format example with the canonical pattern (2–5 personas, max 2 scenarios, "extract from source first" guidance from FR-35).
  3. `## Motivation Considerations` — 7 questions, verbatim from /msf SKILL.md lines 97–103.
  4. `## Friction Considerations` — 11 questions, verbatim from /msf SKILL.md lines 105–115.
  5. `## Satisfaction Considerations` — 6 questions, verbatim from /msf SKILL.md lines 117–123.
  6. `## Executive Summary Template` — Must/Should/Nice rec table (verbatim from lines 174–186), top-N friction list shape, "no actionable findings" terminal-state instruction (FR-23). Add at the end: `> Mode-specific overrides: see invoking skill's "Summary Overrides" section.`

- [ ] **T1.3.** Verify the file exists and the 24 consideration questions are present:
  ```bash
  test -f plugins/pmos-toolkit/skills/_shared/msf-heuristics.md
  grep -c "^- " plugins/pmos-toolkit/skills/_shared/msf-heuristics.md
  ```
  Expected: file exists; bullet count ≥ 24 (the consideration questions) plus any persona-alignment bullets.

- [ ] **T1.4.** Verify no PSYCH content leaked in:
  ```bash
  ! grep -i "psych\|±10\|danger zone\|bounce risk\|entry-context" plugins/pmos-toolkit/skills/_shared/msf-heuristics.md
  ```
  Expected: command exits 0 (no matches).

- [ ] **T1.5.** Diff the consideration list against the original to catch paraphrasing:
  ```bash
  diff <(sed -n '97,123p' plugins/pmos-toolkit/skills/msf/SKILL.md) \
       <(grep -A 7 "## Motivation\|## Friction\|## Satisfaction" plugins/pmos-toolkit/skills/_shared/msf-heuristics.md)
  ```
  Expected: only structural diffs (heading wrappers); the 24 question lines themselves match.

- [ ] **T1.6.** Commit:
  ```bash
  git add plugins/pmos-toolkit/skills/_shared/msf-heuristics.md
  git commit -m "feat(pmos-toolkit): extract shared MSF heuristics module"
  ```

**Inline verification:**
- File exists at `plugins/pmos-toolkit/skills/_shared/msf-heuristics.md`
- Bullet count ≥24 for the consideration list
- Zero PSYCH-related strings in the file
- Diff against original shows verbatim consideration text

---

### T2: Create `/msf-req/SKILL.md` [P with T3]

**Goal:** Create the requirements-doc-only MSF skill. Standalone-only (no `--apply-edits`); recommendations-only output; references `_shared/msf-heuristics.md` for considerations + persona-alignment + summary template.

**Spec refs:** FR-01, FR-03, FR-04, FR-06, FR-10, FR-19, FR-20, FR-21, FR-22, FR-23, FR-31, FR-33, FR-34, FR-35, FR-37, FR-38

**Files:**
- Create: `plugins/pmos-toolkit/skills/msf-req/SKILL.md`

**Steps:**

- [ ] **T2.1.** Create `plugins/pmos-toolkit/skills/msf-req/SKILL.md` with frontmatter:
  ```yaml
  ---
  name: msf-req
  description: Evaluate a requirements document from the end-user perspective using Motivation/Satisfaction/Friction analysis. Produces a recommendations-only findings doc; never edits the source. Use when the user says "evaluate UX of the requirements", "will the proposed solution work for users", "persona check on this PRD", or "friction analysis on requirements".
  user-invocable: true
  argument-hint: "<path-to-requirements-doc>"
  ---
  ```
  The `description` MUST contain the four trigger phrases verbatim (FR-04). It MUST NOT mention any phrase from FR-05 (FR-06 disjointness).

- [ ] **T2.2.** Add the body, in this order. Each phase MUST be present:
  1. **Phase 0: Load Workstream Context** — copy the standard pattern from `/spec/SKILL.md` Phase 0 (FR-38), substituting `/msf-req` for `/spec` in the learnings reference.
  2. **Phase 1: Wrong-input Guard** — if argument resolves to a directory, exit with: `Argument looks like a wireframes folder. Use /msf-wf instead.` (FR-31, FR-33). MUST run before any other phase.
  3. **Phase 2: Locate Requirements** — `follow ../_shared/resolve-input.md` with `phase=requirements`.
  4. **Phase 3: Persona Alignment** — `follow ../_shared/msf-heuristics.md` Persona Alignment section. Confirmation step is mandatory (FR-35).
  5. **Phase 4: Journey Confirmation** — list user journeys from req doc, confirm via AskUserQuestion.
  6. **Phase 5: MSF Pass A** — `follow ../_shared/msf-heuristics.md` Motivation/Friction/Satisfaction sections. Run for each persona × scenario × journey. State assumptions inline because no UI to ground in.
  7. **Phase 6: Save Findings** — save to `<feature_folder>/msf-findings.md` (per FR-19) when invoked inside a pipeline feature folder, else `~/.pmos/msf/YYYY-MM-DD_<slug>.md` (FR-20). Findings doc has no line cap (FR-21). Emit "no actionable findings" terminal state when nothing surfaces (FR-23).
  8. **Phase 7: Executive Summary in Chat** — render the summary per `_shared/msf-heuristics.md` template; cap chat at 200 lines (FR-22). Add the req-mode override paragraph: "No PSYCH section. If wireframes exist adjacent to the req doc, append a one-line suggestion: `Wireframes detected at <path>; consider /msf-wf for grounded analysis.`" (FR-22, edge case E9).
  9. **Phase 8: Capture Learnings** — read and follow `learnings/learnings-capture.md`, log under `## /msf-req` (FR-37).

- [ ] **T2.3.** Add an "Anti-Patterns (DO NOT)" section copied from `/msf/SKILL.md` lines 229–238, edited to drop wireframe-specific entries and to forbid `--apply-edits`/`--wireframes`/`--skip-psych`/`--default-scope` flags (FR-34).

- [ ] **T2.4.** Verify file structure:
  ```bash
  test -f plugins/pmos-toolkit/skills/msf-req/SKILL.md
  head -7 plugins/pmos-toolkit/skills/msf-req/SKILL.md | grep -q "name: msf-req"
  head -7 plugins/pmos-toolkit/skills/msf-req/SKILL.md | grep -q 'argument-hint: "<path-to-requirements-doc>"'
  ```
  Expected: all three commands exit 0.

- [ ] **T2.5.** Verify trigger phrases present and disjoint from /msf-wf set:
  ```bash
  grep -c "evaluate UX of the requirements\|will the proposed solution work for users\|persona check on this PRD\|friction analysis on requirements" plugins/pmos-toolkit/skills/msf-req/SKILL.md
  ! grep "evaluate the wireframes\|check friction in the UI\|PSYCH score these screens\|wireframe UX evaluation" plugins/pmos-toolkit/skills/msf-req/SKILL.md
  ```
  Expected: first command outputs ≥4; second exits 0.

- [ ] **T2.5.5.** Verify Phase 0 (Workstream Context, FR-38) is present:
  ```bash
  grep -qE "Phase 0.*Workstream|Workstream Context" plugins/pmos-toolkit/skills/msf-req/SKILL.md
  ```
  Expected: exit 0.

- [ ] **T2.6.** Verify no forbidden flags mentioned (except as anti-pattern entries):
  ```bash
  ! grep -E "^[[:space:]]*--apply-edits|^[[:space:]]*--wireframes|^[[:space:]]*--skip-psych|^[[:space:]]*--default-scope" plugins/pmos-toolkit/skills/msf-req/SKILL.md
  ```
  Expected: exit 0 (the anti-pattern lines reference flags inline, not as standalone arguments).

- [ ] **T2.7.** Commit:
  ```bash
  git add plugins/pmos-toolkit/skills/msf-req/SKILL.md
  git commit -m "feat(pmos-toolkit): add /msf-req skill for requirements-only MSF analysis"
  ```

**Inline verification:**
- Frontmatter parses (name, description, argument-hint correct)
- 4 FR-04 trigger phrases present; 0 FR-05 trigger phrases present
- All 8 phases present (search for `## Phase 0` … `## Phase 8`)
- No standalone forbidden-flag references

---

### T3: Create `/msf-wf/SKILL.md` (with PSYCH content) [P with T2]

**Goal:** Create the wireframes-folder MSF + PSYCH skill. Recommendations-only by default; `--apply-edits` enables HTML edits. PSYCH rubric lives here only.

**Spec refs:** FR-02, FR-03, FR-05, FR-06, FR-11, FR-12, FR-13, FR-14, FR-15 (one-doc per D1), FR-19, FR-20, FR-21, FR-22, FR-23, FR-32, FR-33, FR-34, FR-35, FR-36, FR-37, FR-38

**Files:**
- Create: `plugins/pmos-toolkit/skills/msf-wf/SKILL.md`
- Read (no modify): `plugins/pmos-toolkit/skills/msf/SKILL.md`, `plugins/pmos-toolkit/skills/wireframes/SKILL.md` (lines 449–555 for PSYCH rubric source)

**Steps:**

- [ ] **T3.1.** Create `plugins/pmos-toolkit/skills/msf-wf/SKILL.md` with frontmatter:
  ```yaml
  ---
  name: msf-wf
  description: Evaluate generated wireframes from the end-user perspective with grounded MSF analysis plus PSYCH scoring per screen. Recommendations-only by default; pass --apply-edits (typically when invoked from /wireframes Phase 6) to apply user-approved HTML edits inline. Use when the user says "evaluate the wireframes", "check friction in the UI", "PSYCH score these screens", or "wireframe UX evaluation".
  user-invocable: true
  argument-hint: "<path-to-wireframes-folder> [--apply-edits]"
  ---
  ```
  Description MUST contain the four FR-05 trigger phrases verbatim and MUST NOT contain any FR-04 phrase (FR-06).

- [ ] **T3.2.** Add the body, in this order:
  1. **Phase 0: Load Workstream Context** — same pattern as T2.2 step 1, with `/msf-wf` substitution (FR-38).
  2. **Phase 1: Wrong-input Guard** — if argument resolves to a single `.md` file, exit with: `Argument looks like a requirements doc. Use /msf-req instead.` (FR-32, FR-33).
  3. **Phase 2: Locate Wireframes** — read every `.html` file in the folder recursively (edge case E5); read sibling `01_requirements.md` if present (for persona context); `01_requirements.md` missing → continue with a flag in findings (per spec §7 Failure modes).
  4. **Phase 3: Persona Alignment** — `follow ../_shared/msf-heuristics.md`. Confirmation always required (FR-35).
  5. **Phase 4: Journey Confirmation** — list journeys based on wireframe screen-flow + req doc; confirm via AskUserQuestion.
  6. **Phase 5: MSF Pass A** — `follow ../_shared/msf-heuristics.md` Motivation/Friction/Satisfaction sections. Walks each persona × scenario × journey **sequentially** (D2 — explicit anti-pattern bullet later). Cite wireframe elements/copy/screen names per finding.
  7. **Phase 6: PSYCH Pass B** — copy the PSYCH rubric verbatim from `/msf/SKILL.md` lines 126–155 (entry-context starts, ±10 element scoring, danger-zone <20 / bounce-risk <0). Soften threshold language to "directional indicator" wording per spec non-goal. Default entry-context = Medium (40); top of findings doc records: `Entry context: Medium (40, default). Override by editing this line and re-running.` (FR-36). Reference `reference/psych-output-format.md` for the dual-table format.
  8. **Phase 7: Save Findings** — single `msf-findings.md` (per D1) at `<feature_folder>/msf-findings.md` or `~/.pmos/msf/...` (FR-19, FR-20, FR-21). Section A = MSF analysis matrix; Section B = PSYCH per-journey scoring tables (per `reference/psych-output-format.md`). Emit "no actionable findings" terminal state when applicable (FR-23).
  9. **Phase 8: Apply Edits (conditional on `--apply-edits`)** — if flag present: present each finding via AskUserQuestion with Fix/Modify/Skip/Defer options (FR-13). For each "Fix as proposed" disposition, edit the corresponding `.html` file using `Edit`. Log every applied change in the findings doc under "Applied changes". If flag absent: emit followup message: `To apply: re-run /msf-wf <folder> --apply-edits, or run /wireframes <feature> to regenerate.` (J2 step 4).
  10. **Phase 9: Executive Summary in Chat** — render summary per `_shared/msf-heuristics.md` template; cap chat at 200 lines (FR-22). Add the wf-mode override paragraph: "Include danger-zone screens (PSYCH < 20 directional) and bounce-risk screens (< 0 directional) in the summary's top-issues list."
  11. **Phase 10: Capture Learnings** — log under `## /msf-wf` (FR-37).

- [ ] **T3.3.** Add an "Anti-Patterns (DO NOT)" section adapted from `/msf/SKILL.md`:
  - Do NOT skip persona confirmation
  - Do NOT pad PSYCH scores
  - Do NOT walk journeys in parallel via subagents (D2 — known sharp edge for shared-file edits)
  - Do NOT call `Edit` or `Write` against any wireframe HTML file when `--apply-edits` is absent (FR-12)
  - Do NOT accept `--default-scope`, `--wireframes`, or `--skip-psych` (FR-34) — only `--apply-edits` is recognized
  - Do NOT trigger `/wireframes` Phase 4 review-loops after editing (preserve the existing /msf line 237 anti-pattern)

- [ ] **T3.4.** Verify file structure + frontmatter:
  ```bash
  test -f plugins/pmos-toolkit/skills/msf-wf/SKILL.md
  head -7 plugins/pmos-toolkit/skills/msf-wf/SKILL.md | grep -q "name: msf-wf"
  head -7 plugins/pmos-toolkit/skills/msf-wf/SKILL.md | grep -q 'argument-hint: "<path-to-wireframes-folder> \[--apply-edits\]"'
  ```
  Expected: all exit 0.

- [ ] **T3.5.** Verify disjoint trigger phrases:
  ```bash
  grep -c "evaluate the wireframes\|check friction in the UI\|PSYCH score these screens\|wireframe UX evaluation" plugins/pmos-toolkit/skills/msf-wf/SKILL.md
  ! grep "evaluate UX of the requirements\|will the proposed solution work for users\|persona check on this PRD\|friction analysis on requirements" plugins/pmos-toolkit/skills/msf-wf/SKILL.md
  ```
  Expected: first ≥4; second exits 0.

- [ ] **T3.6.** Verify PSYCH content present and apply-edits gating language present:
  ```bash
  grep -q "Entry context: Medium (40, default)" plugins/pmos-toolkit/skills/msf-wf/SKILL.md
  grep -q "danger.*<.*20\|directional indicator" plugins/pmos-toolkit/skills/msf-wf/SKILL.md
  grep -q "MUST NOT call.*Edit.*when.*--apply-edits.*absent\|--apply-edits is absent" plugins/pmos-toolkit/skills/msf-wf/SKILL.md
  ```
  Expected: all exit 0.

- [ ] **T3.6.5.** Verify Phase 0 (Workstream Context, FR-38) is present:
  ```bash
  grep -qE "Phase 0.*Workstream|Workstream Context" plugins/pmos-toolkit/skills/msf-wf/SKILL.md
  ```
  Expected: exit 0.

- [ ] **T3.7.** Commit:
  ```bash
  git add plugins/pmos-toolkit/skills/msf-wf/SKILL.md
  git commit -m "feat(pmos-toolkit): add /msf-wf skill for grounded MSF + PSYCH on wireframes"
  ```

**Inline verification:**
- Frontmatter correct
- All 11 phases present
- Disjoint trigger phrases
- PSYCH default + write-gating language present

---

### T4: Move `reference/psych-output-format.md` from /wireframes to /msf-wf

**Goal:** Move the PSYCH artifact format spec to its new home alongside /msf-wf.

**Spec refs:** FR-16

**Files:**
- Move: `plugins/pmos-toolkit/skills/wireframes/reference/psych-output-format.md` → `plugins/pmos-toolkit/skills/msf-wf/reference/psych-output-format.md`

**Steps:**

- [ ] **T4.1.** Create the destination directory:
  ```bash
  mkdir -p plugins/pmos-toolkit/skills/msf-wf/reference
  ```

- [ ] **T4.2.** Move the file with `git mv` to preserve history:
  ```bash
  git mv plugins/pmos-toolkit/skills/wireframes/reference/psych-output-format.md \
         plugins/pmos-toolkit/skills/msf-wf/reference/psych-output-format.md
  ```

- [ ] **T4.3.** Verify the move:
  ```bash
  test -f plugins/pmos-toolkit/skills/msf-wf/reference/psych-output-format.md
  test ! -f plugins/pmos-toolkit/skills/wireframes/reference/psych-output-format.md
  ```
  Expected: both exit 0.

- [ ] **T4.4.** Commit:
  ```bash
  git commit -m "refactor(pmos-toolkit): move psych-output-format.md to /msf-wf"
  ```

**Inline verification:**
- File exists at new location, absent at old location
- `git log --follow` on new path shows the move

---

### T5: Rewrite `/wireframes/SKILL.md` Phase 6 as thin wrapper; remove all PSYCH content

**Goal:** Atomically remove the entire Phase 6 PSYCH body, the `--skip-psych`/`--wireframes` flag handling, and all 10 scattered PSYCH references; replace with a thin Phase 6 that invokes `/msf-wf <wireframes-folder> --apply-edits` and aborts on non-zero return.

**Spec refs:** FR-17, FR-18, FR-27, FR-39

**Files:**
- Modify: `plugins/pmos-toolkit/skills/wireframes/SKILL.md`

**Steps:**

- [ ] **T5.1.** Re-read `plugins/pmos-toolkit/skills/wireframes/SKILL.md` to confirm the line ranges from spec FR-17 still match HEAD (the file may have shifted since spec was written):
  ```bash
  grep -n "PSYCH\|psych-findings\|psych-output-format\|--skip-psych\|--wireframes" plugins/pmos-toolkit/skills/wireframes/SKILL.md
  ```
  Compare output against spec FR-17's line list. If lines have drifted, use the new line numbers — the spec's list is illustrative.

- [ ] **T5.2.** Replace lines 449–555 (Phase 6 body) with a thin wrapper. The new Phase 6 contains:
  ```markdown
  ## Phase 6: MSF + PSYCH (delegated to /msf-wf)

  Wireframes are now generated. Phase 6 hands off to `/msf-wf` for combined MSF + PSYCH analysis with inline edit application.

  **Invocation:**
  ```
  /msf-wf {feature_folder}/wireframes --apply-edits
  ```

  **Behavior:**
  - `/msf-wf` runs persona alignment, MSF Pass A, PSYCH Pass B, and (with `--apply-edits`) presents each finding via AskUserQuestion for Fix/Modify/Skip/Defer disposition. Approved findings are applied as inline `Edit` calls to the relevant `.html` files.
  - Output: a single `msf-findings.md` co-located with the wireframes folder.

  **Failure handling (FR-39):**
  If `/msf-wf` returns non-zero or the user terminates it, this Phase aborts. /wireframes MUST NOT auto-continue to Phase 7. Surface the underlying error to the user; the user can re-run `/msf-wf` manually and then continue with `/spec`.

  **Tier gating:**
  - Tier 1: skip Phase 6 entirely → jump to Phase 8 (Spec Handoff). (Tier 1 wireframes are usually 1–2 screens; MSF/PSYCH overkill.)
  - Tier 2 / Tier 3: Phase 6 is mandatory.
  ```

- [ ] **T5.3.** Remove the 10 scattered single-line PSYCH/MSF references identified by Phase 2 grep (lines 25, 53, 57, 59–60, 77, 561–593, 614, 630, 647, 678, 694–707 in the pre-edit file). For each:
  - Lines that are pure PSYCH-mode references in a list of phase summaries → delete the line.
  - Lines describing the rigor protocol "PSYCH walkthrough" — replace with "MSF + PSYCH (delegated)" or delete if redundant.
  - The PSYCH/MSF integration prose at lines 561–593 (`--skip-psych`, `--wireframes` flag handling, /msf locate-wireframes coordination, etc.) → delete entirely.
  - The Phase 8 Spec Handoff message at line 647 ("PSYCH findings…") → update to "MSF findings (`{relative_path}/msf-findings.md`, if Phase 6 ran)".
  - The line 630 `/wireframes` summary message ("PSYCH walkthrough: ...") → replace with `MSF + PSYCH: {relative_path}/msf-findings.md (if Phase 6 ran)`.
  - Anti-pattern bullets at lines 694–707 — remove the **five** PSYCH-related entries: line 694 "Do NOT run PSYCH on more than 5 journeys in one session", line 695 "Do NOT run PSYCH per-wireframe", line 696 "Do NOT trigger a second Phase 4 review-loop pass to verify PSYCH or MSF edits", line 697 "Do NOT skip Phase 6 on Tier 2 or Tier 3", line 699 "Do NOT pad PSYCH scores". The "do not silently downgrade" bullet (and any other non-PSYCH entries) stays.
  - Line 678 (the learnings-capture parenthetical that references "PSYCH driver pattern" / "MSF persona-conditional finding") → delete the parenthetical, keep the surrounding sentence.

- [ ] **T5.4.** Verify all PSYCH text is gone except for the single delegated-invocation reference in the new Phase 6:
  ```bash
  grep -cE "PSYCH|psych-findings|psych-output-format|--skip-psych|--wireframes" plugins/pmos-toolkit/skills/wireframes/SKILL.md
  ```
  Expected: count ≤2 (the title "## Phase 6: MSF + PSYCH (delegated to /msf-wf)" and one reference inside the phase body). If count >2, find and remove the strays.

- [ ] **T5.5.** Verify the thin wrapper invocation is present:
  ```bash
  grep -q "/msf-wf {feature_folder}/wireframes --apply-edits" plugins/pmos-toolkit/skills/wireframes/SKILL.md
  grep -q "MUST NOT auto-continue to Phase 7" plugins/pmos-toolkit/skills/wireframes/SKILL.md
  ```
  Expected: both exit 0.

- [ ] **T5.6.** Commit:
  ```bash
  git add plugins/pmos-toolkit/skills/wireframes/SKILL.md
  git commit -m "refactor(pmos-toolkit): replace /wireframes Phase 6 with /msf-wf delegation"
  ```

**Inline verification:**
- Total PSYCH/psych references in /wireframes ≤2 (the new Phase 6 title + one body reference)
- Thin-wrapper invocation string present
- Phase-6-abort language present
- File still parses as valid markdown (eyeball the frontmatter and section structure)

---

### T6: Update `/requirements` and `/spec` references

**Goal:** Replace `/msf` with `/msf-req` in the two pipeline-adjacent skills.

**Spec refs:** FR-25, FR-26

**Files:**
- Modify: `plugins/pmos-toolkit/skills/requirements/SKILL.md` (lines 13, 320, 554)
- Modify: `plugins/pmos-toolkit/skills/spec/SKILL.md` (line 13)

**Steps:**

- [ ] **T6.1.** In `requirements/SKILL.md`:
  - Line 13 (pipeline diagram): replace `[/msf, /creativity]` with `[/msf-req, /creativity]`.
  - Line 320: replace `For UX friction analysis, run `/msf` after this doc is committed.` with `For UX friction analysis, run `/msf-req` after this doc is committed.`.
  - Line 554: replace `/msf` with `/msf-req` in the next-step suggestion.

- [ ] **T6.2.** In `spec/SKILL.md` line 13: replace `[/msf, /creativity]` with `[/msf-req, /creativity]`.

- [ ] **T6.3.** Verify:
  ```bash
  ! grep '/msf\b' plugins/pmos-toolkit/skills/requirements/SKILL.md plugins/pmos-toolkit/skills/spec/SKILL.md
  grep -c '/msf-req' plugins/pmos-toolkit/skills/requirements/SKILL.md
  grep -c '/msf-req' plugins/pmos-toolkit/skills/spec/SKILL.md
  ```
  Expected: first exits 0 (no matches); second outputs 3; third outputs 1.

- [ ] **T6.4.** Commit:
  ```bash
  git add plugins/pmos-toolkit/skills/requirements/SKILL.md plugins/pmos-toolkit/skills/spec/SKILL.md
  git commit -m "refactor(pmos-toolkit): /requirements and /spec point to /msf-req"
  ```

**Inline verification:**
- No bare `/msf` references in either file
- 3 `/msf-req` mentions in /requirements; 1 in /spec

---

### T7: Update remaining caller skills (create-skill, creativity, plan, product-context, simulate-spec)

**Goal:** Replace `/msf` with `/msf-req` in the five remaining pipeline-diagram references identified in code study.

**Spec refs:** FR-28 (revised per D6 to drop /design-crit)

**Files:**
- Modify: `plugins/pmos-toolkit/skills/create-skill/SKILL.md:241`
- Modify: `plugins/pmos-toolkit/skills/creativity/SKILL.md:12,15`
- Modify: `plugins/pmos-toolkit/skills/plan/SKILL.md:13`
- Modify: `plugins/pmos-toolkit/skills/product-context/SKILL.md:13`
- Modify: `plugins/pmos-toolkit/skills/simulate-spec/SKILL.md:15`

**Steps:**

- [ ] **T7.1.** Pipeline-diagram edits in 5 files. For each, replace `[/msf, /creativity]` with `[/msf-req, /creativity]`:
  - `create-skill/SKILL.md:241`
  - `creativity/SKILL.md:15`
  - `plan/SKILL.md:13`
  - `product-context/SKILL.md:13`
  - `simulate-spec/SKILL.md:15`

- [ ] **T7.1.5.** Prose edit in `creativity/SKILL.md:12` (separate from diagram edits): replace `Can be combined with /msf.` with `Can be combined with /msf-req.`.

- [ ] **T7.2.** Verify no stale `/msf` references remain in any of the 5 files:
  ```bash
  ! grep '/msf\b' \
      plugins/pmos-toolkit/skills/create-skill/SKILL.md \
      plugins/pmos-toolkit/skills/creativity/SKILL.md \
      plugins/pmos-toolkit/skills/plan/SKILL.md \
      plugins/pmos-toolkit/skills/product-context/SKILL.md \
      plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
  ```
  Expected: exit 0.

- [ ] **T7.3.** Verify `/msf-req` count incremented:
  ```bash
  grep -c '/msf-req' \
      plugins/pmos-toolkit/skills/create-skill/SKILL.md \
      plugins/pmos-toolkit/skills/creativity/SKILL.md \
      plugins/pmos-toolkit/skills/plan/SKILL.md \
      plugins/pmos-toolkit/skills/product-context/SKILL.md \
      plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
  ```
  Expected: each file shows ≥1.

- [ ] **T7.4.** Commit:
  ```bash
  git add plugins/pmos-toolkit/skills/create-skill/SKILL.md \
          plugins/pmos-toolkit/skills/creativity/SKILL.md \
          plugins/pmos-toolkit/skills/plan/SKILL.md \
          plugins/pmos-toolkit/skills/product-context/SKILL.md \
          plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
  git commit -m "refactor(pmos-toolkit): update remaining pipeline diagrams for /msf-req"
  ```

**Inline verification:**
- Zero stale `/msf` references in the 5 files
- Each file shows ≥1 `/msf-req` reference

---

### T8: External doc audit + CHANGELOG entry

**Goal:** Update active `/msf` references in repo-level docs (README, CLAUDE.md, etc.); add CHANGELOG entry. Leave historical plan/spec docs unchanged.

**Spec refs:** FR-30, FR-40

**Files:**
- Modify: `README.md:86`
- Modify: `CHANGELOG.md` (top of file)
- Possibly: `CLAUDE.md` (if it contains active `/msf` references)

**Steps:**

- [ ] **T8.1.** In `README.md` line 86: replace `[/msf, /creativity, /grill]` with `[/msf-req, /creativity, /grill]`.

- [ ] **T8.2.** Identify any other active `/msf` references outside historical plan/spec dirs:
  ```bash
  grep -rln '/msf\b' --include='*.md' . | grep -v "docs/plans/\|docs/specs/\|docs/features/\|node_modules"
  ```
  For each file in the result: open it, determine whether the reference is active prose or historical record, update active prose to `/msf-req` (or `/msf-wf` if context is wireframe-related). Skip historical record.

- [ ] **T8.3.** Add CHANGELOG.md top-of-file entry. If `CHANGELOG.md` doesn't exist, create one. Entry shape:
  ```markdown
  ## pmos-toolkit 2.22.0 — 2026-05-08

  ### Breaking changes
  - **`/msf` removed**, replaced by two skills:
    - `/msf-req` — MSF analysis on a requirements doc (recommendations-only).
    - `/msf-wf` — MSF + PSYCH analysis on a wireframes folder; pass `--apply-edits` to apply HTML edits inline (typically invoked by `/wireframes` Phase 6).
  - **PSYCH scoring moved** from `/wireframes` Phase 6 into `/msf-wf`. `/wireframes` Phase 6 is now a thin wrapper that delegates to `/msf-wf --apply-edits`.
  - **Removed flags:** `--wireframes`, `--skip-psych`, `--default-scope`. The only flag on the new skills is `--apply-edits` (on `/msf-wf` only).

  ### Migration
  - Anywhere you wrote `/msf <req-doc>`, write `/msf-req <req-doc>`.
  - Anywhere you wrote `/msf <folder> --wireframes <folder>`, write `/msf-wf <folder>` (omit `--wireframes` — the folder argument is the input).
  - `/wireframes` end-to-end behavior unchanged from the user's perspective; PSYCH still runs in Phase 6, just delegated.
  ```

- [ ] **T8.4.** Verify no active `/msf` in README:
  ```bash
  ! grep '/msf\b' README.md
  ```
  Expected: exit 0.

- [ ] **T8.5.** Verify CHANGELOG entry:
  ```bash
  grep -q "pmos-toolkit 2.22.0" CHANGELOG.md
  grep -q "/msf-req" CHANGELOG.md
  grep -q "/msf-wf" CHANGELOG.md
  ```
  Expected: all exit 0.

- [ ] **T8.6.** Commit:
  ```bash
  git add README.md CHANGELOG.md
  # Add CLAUDE.md if it was modified
  git commit -m "docs: update README + CHANGELOG for /msf split (2.22.0)"
  ```

**Inline verification:**
- Zero active `/msf` references in README
- CHANGELOG entry mentions 2.22.0, /msf-req, /msf-wf, breaking-change, migration

---

### T9: Delete `/msf/SKILL.md`

**Goal:** Hard-remove the old skill. T1–T8 have already extracted the heuristics, created replacements, and updated all callers.

**Spec refs:** FR-24

**Files:**
- Delete: `plugins/pmos-toolkit/skills/msf/SKILL.md`
- Possibly delete: `plugins/pmos-toolkit/skills/msf/` (the directory) if empty after removal.

**Steps:**

- [ ] **T9.1.** Verify all callers updated (rerun T6, T7 verification greps to confirm no regression):
  ```bash
  ! grep -rn '/msf\b' plugins/pmos-toolkit/skills/ | grep -v "msf-req\|msf-wf\|msf-heuristics\|msf-findings"
  ```
  Expected: exit 0. If anything matches, fix it before proceeding (T9 is irreversible without revert).

- [ ] **T9.2.** Delete the SKILL.md:
  ```bash
  git rm plugins/pmos-toolkit/skills/msf/SKILL.md
  ```

- [ ] **T9.3.** Check if the `msf/` directory has any other files:
  ```bash
  ls plugins/pmos-toolkit/skills/msf/ 2>/dev/null
  ```
  If empty (no output): `rmdir plugins/pmos-toolkit/skills/msf/`. Otherwise leave the directory and inspect remaining files.

- [ ] **T9.4.** Verify deletion:
  ```bash
  test ! -f plugins/pmos-toolkit/skills/msf/SKILL.md
  ```
  Expected: exit 0.

- [ ] **T9.5.** Commit:
  ```bash
  git commit -m "refactor(pmos-toolkit): remove old /msf skill (replaced by /msf-req + /msf-wf)"
  ```

**Inline verification:**
- /msf SKILL.md absent
- No regression in pre-T9 grep

---

### T10: Bump pmos-toolkit version to 2.22.0

**Goal:** Release marker for the breaking change.

**Spec refs:** FR-29

**Files:**
- Modify: `plugins/pmos-toolkit/.claude-plugin/plugin.json:3`

**Steps:**

- [ ] **T10.1.** In `plugins/pmos-toolkit/.claude-plugin/plugin.json` line 3: replace `"version": "2.21.0",` with `"version": "2.22.0",`.

- [ ] **T10.2.** Verify:
  ```bash
  grep -q '"version": "2.22.0"' plugins/pmos-toolkit/.claude-plugin/plugin.json
  ```
  Expected: exit 0.

- [ ] **T10.3.** Commit:
  ```bash
  git add plugins/pmos-toolkit/.claude-plugin/plugin.json
  git commit -m "chore(release): pmos-toolkit 2.22.0 — /msf split + PSYCH relocation"
  ```

**Inline verification:**
- Version string is `2.22.0`

---

### T11: Final Verification

**Goal:** Verify the entire implementation works end-to-end. This task runs all spec §10 verification commands plus a manual `/wireframes` end-to-end on a sample feature.

**Spec refs:** Section 10 (10.1, 10.2, 10.3, 10.4)

**Files:** none modified — verification only.

- [ ] **T11.1. Structural / frontmatter (spec §10.1).**
  - If `claude validate plugin pmos-toolkit` is available:
    ```bash
    claude validate plugin pmos-toolkit
    ```
    Expected: validator passes; reports `/msf-req` and `/msf-wf` parse, `/msf` absent.
  - Fallback (validator missing): manually inspect frontmatter:
    ```bash
    head -7 plugins/pmos-toolkit/skills/msf-req/SKILL.md
    head -7 plugins/pmos-toolkit/skills/msf-wf/SKILL.md
    test ! -f plugins/pmos-toolkit/skills/msf/SKILL.md
    ```
    Expected: both `head` outputs show valid YAML frontmatter; absence test exits 0.

- [ ] **T11.2. Reference integrity grep (spec §10.2).**
  ```bash
  grep -rn "/msf\b\|skill: msf$\|name: msf$" plugins/pmos-toolkit/skills/ \
    | grep -v "msf-req\|msf-wf\|msf-heuristics\|msf-findings"
  ```
  Expected: empty output (zero stale references).

- [ ] **T11.3. File-existence checks (spec §10.4).**
  ```bash
  test -f plugins/pmos-toolkit/skills/msf-req/SKILL.md
  test -f plugins/pmos-toolkit/skills/msf-wf/SKILL.md
  test -f plugins/pmos-toolkit/skills/_shared/msf-heuristics.md
  test -f plugins/pmos-toolkit/skills/msf-wf/reference/psych-output-format.md
  test ! -f plugins/pmos-toolkit/skills/msf/SKILL.md
  test ! -f plugins/pmos-toolkit/skills/wireframes/reference/psych-output-format.md
  grep -q '"version": "2.22' plugins/pmos-toolkit/.claude-plugin/plugin.json
  ```
  Expected: all 7 commands exit 0.

- [ ] **T11.4. /wireframes PSYCH-strip verification (FR-17 grep).**
  ```bash
  count=$(grep -cE "PSYCH|psych-findings|psych-output-format" plugins/pmos-toolkit/skills/wireframes/SKILL.md)
  echo "PSYCH refs remaining in /wireframes: $count"
  test "$count" -le 2
  ```
  Expected: count ≤2 (the new Phase 6 title + one body reference); test exits 0.

- [ ] **T11.5. T1 (standalone /msf-req) behavioral test.**
  Manual run: invoke `/msf-req docs/features/2026-05-08_msf-skill-split/01_requirements.md` in a fresh Claude session.
  Expected:
  - Skill triggers (no "skill not found" error)
  - Persona alignment phase runs and asks for confirmation
  - Run completes; `docs/features/2026-05-08_msf-skill-split/msf-findings.md` exists
  - `git diff docs/features/2026-05-08_msf-skill-split/01_requirements.md` shows zero changes (FR-10 / G2)

- [ ] **T11.6. Trigger-phrase test (spec T6).**
  Manual run in a fresh session, type each phrase and verify the right skill triggers:
  - "evaluate UX of the requirements" → /msf-req triggers
  - "PSYCH score these screens" → /msf-wf triggers
  - "wireframe UX evaluation" → /msf-wf triggers
  - "persona check on this PRD" → /msf-req triggers
  Expected: 4/4 correct routes; zero ambiguity.

- [ ] **T11.7. Wrong-input handling.**
  - Run `/msf-req plugins/pmos-toolkit/skills/wireframes/` (folder argument). Expected: skill exits with sibling-skill suggestion; no findings doc created.
  - Run `/msf-wf docs/features/2026-05-08_msf-skill-split/01_requirements.md` (md argument). Expected: skill exits with sibling-skill suggestion.

- [ ] **T11.8. CHANGELOG + version sanity.**
  ```bash
  grep -q "pmos-toolkit 2.22.0" CHANGELOG.md
  grep -q '"version": "2.22.0"' plugins/pmos-toolkit/.claude-plugin/plugin.json
  ```
  Expected: both exit 0.

- [ ] **T11.9. No-actionable-findings exit (FR-23).**
  Manual run /msf-req on a deliberately clean req doc (synthetic — pick a tightly-scoped Tier 1 doc). Expected: skill emits "no actionable findings" terminal state; saved findings doc has empty Must/Should/Nice tables; chat does NOT manufacture recommendations.

**Cleanup:**
- [ ] No temp files, no debug logging, no feature flags introduced — nothing to clean up.
- [ ] Confirm working tree is clean: `git status` shows no uncommitted changes.
- [ ] Confirm commit chain is reasonable (one commit per task, plus T11 has no commit since it's verification-only):
  ```bash
  git log --oneline -15
  ```
  Expected: ~10 commits with the task labels, plus the spec/plan commits.

---

## Review Log

| Loop | Findings | Changes Made |
|------|----------|--------------|
| 1    | (a) T11.7 fixture-dependency vague; (b) T7 prose vs diagram edits lumped; (c) T3 size borderline | Removed T11.7 (manual /wireframes end-to-end deferred to next real run); split T7.1 into diagram edits + creativity prose edit (T7.1.5); kept T3 atomic (D8 rationale upheld) |
| 2    | (a) Done-when stale post-T11.7 removal; (b) Tier 1 thin-wrapper jumps to wrong phase; (c) FR-38 Phase 0 not verified in T2/T3; (d) T5.3 anti-pattern count off-by-one (4 → 5) | Updated Done-when; Tier 1 jump corrected to Phase 8 (Spec Handoff); added T2.5.5 + T3.6.5 Workstream-Context grep; T5.3 enumerates 5 anti-pattern bullets |
