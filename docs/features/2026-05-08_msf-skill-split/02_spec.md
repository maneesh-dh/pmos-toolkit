# /msf Skill Split & PSYCH Relocation — Spec

**Date:** 2026-05-08
**Status:** Draft
**Tier:** 2 (Enhancement)
**Requirements:** `01_requirements.md`
**Grill report:** `grills/2026-05-08_msf-skill-design.md`

---

## 1. Problem Statement

The current `/msf` skill bundles two architecturally different jobs (pre-/spec req-doc evaluation and post-/wireframes UI evaluation) behind flag-driven branching. Phase 5 mutates source artifacts and Phase 6 self-grades those edits. PSYCH scoring is duplicated between `/msf` Pass B and `/wireframes` Phase 6. The persona × scenario × journey × 24-considerations matrix routinely exceeds the documented 300-line report cap. Primary success metric: zero flag-driven mode-switching in the replacement skills, and zero PSYCH duplication across the toolkit.

---

## 2. Goals

| # | Goal | Success Metric |
|---|------|---------------|
| G1 | Replace `/msf` with two purpose-built skills | `/msf-req` and `/msf-wf` exist; `/msf` SKILL.md is deleted |
| G2 | Make standalone runs recommendations-only | Standalone invocations of either skill produce only `msf-findings.md`; no source-artifact diffs |
| G3 | Source-artifact writes only when parent skill authorizes | `--apply-edits` flag required; absent flag → recommendations-only |
| G4 | PSYCH owned by `/msf-wf` only | `/wireframes` SKILL.md contains no PSYCH instructions; `reference/psych-output-format.md` moves to `/msf-wf` |
| G5 | Findings co-located with pipeline artifacts | `NN_<slug>/msf-findings.md` for pipeline runs; `~/.pmos/msf/` for ad-hoc |
| G6 | Two-tier output | Saved doc uncapped; chat summary ≤200 lines |
| G7 | All callers updated in same release | No remaining `/msf` references in any pmos-toolkit skill |

---

## 3. Non-Goals

- Calibrating PSYCH thresholds against empirical data — keep current heuristics; soften threshold language only.
- Tier auto-gating in `/msf-req` — descriptions claim Tier 3 but skills don't enforce.
- Resolving `/msf-wf` ↔ `/wireframes` regenerate-loop semantics — deferred to a follow-up grill on `/msf-wf` once drafted.
- Backward-compatible `/msf` shim — hard removal in same release.
- Changing the M/F/S consideration questions or PSYCH scoring rubric.

---

## 4. Decision Log

| # | Decision | Options Considered | Rationale |
|---|----------|-------------------|-----------|
| D1 | Split into `/msf-req` and `/msf-wf` | (a) keep one skill with `--mode` flag, (b) split, (c) wireframes-only | Two genuinely different jobs (abstract text vs grounded DOM); split eliminates flag-driven branching. (Grill Q1) |
| D2 | Standalone = recommendations-only; parent-invoked writes via `--apply-edits` | (a) always write, (b) never write, (c) flag-gated | Mirrors `/grill`'s terminal-state discipline. Parent skill (only `/wireframes` today) opts in via explicit flag. (Grill Q2, Architect role) |
| D3 | PSYCH moves out of `/wireframes` Phase 6 into `/msf-wf` | (a) keep in /wireframes, (b) duplicate, (c) move to /msf-wf | PSYCH is fundamentally motivation/friction analysis; co-located with MSF heuristics. Removes `--skip-psych`. (Grill Q5) |
| D4 | Findings save to `NN_<slug>/msf-findings.md` (or `~/.pmos/msf/` ad-hoc) | (a) `docs/msf/`, (b) feature dir, (c) hybrid | Mirrors `/grill` save convention; `/spec` auto-discovers in feature dir. (Grill Q4) |
| D5 | Two-tier output: uncapped saved doc, ≤200-line chat summary | (a) cap both, (b) findings-first only, (c) two-tier | Matrix volume is real; saved doc preserves audit trail, chat surfaces decisions. (Grill Q3) |
| D6 | Shared heuristics in single `_shared/msf-heuristics.md` | (a) per-skill, (b) one file, (c) sub-directory | Matches existing `_shared/` patterns; minimal indirection. (Architect role) |
| D7 | Hard-remove `/msf`, update all callers same release | (a) shim, (b) deprecate, (c) hard-remove | Limited blast radius (only `/wireframes` invokes inline); minor version bump captures it. (Architect role) |
| D8 | Disjoint trigger phrases by artifact type | (a) shape-based routing, (b) shared triggers, (c) disjoint | Argument shape is a tiebreaker only; descriptions should distinguish intent. (Designer role) |
| D9 | Wrong-input → error and suggest sibling skill | (a) auto-redirect, (b) degraded run, (c) error | Strictness prevents silent wrong-mode runs. (Designer role) |
| D10 | `/wireframes` Phase 6 becomes thin wrapper invoking `/msf-wf --apply-edits` | (a) drop Phase 6, (b) prompt user, (c) auto-invoke | Preserves user-visible flow; centralizes PSYCH logic. (Product role) |

---

## 5. User Journeys

### J1 — Pre-/spec UX evaluation (standalone /msf-req)
1. User runs `/msf-req <path-to-01_requirements.md>`.
2. Skill aligns on personas, journeys; runs MSF Pass A only (no PSYCH — no UI to score).
3. Saves `NN_<slug>/msf-findings.md`; chat shows executive summary.
4. **Skill terminates.** No edits to requirements doc.
5. User folds findings into a revised requirements doc (manually or via `/requirements`), then proceeds to `/spec`.

### J2 — Post-wireframes UX evaluation (standalone /msf-wf)
1. User runs `/msf-wf <path-to-wireframes-folder>`.
2. Skill reads every `.html` file; runs MSF Pass A + PSYCH Pass B grounded in DOM elements.
3. Saves `NN_<slug>/msf-findings.md` + journey-level PSYCH tables.
4. **Skill terminates with no edits.** Final message suggests: "To apply: re-run with `--apply-edits`, or run `/wireframes <feature>` to regenerate."

### J3 — Inline invocation from /wireframes (replaces current Phase 6 + Phase 7 inline /msf)
1. `/wireframes` finishes generating HTML in Phase 5.
2. `/wireframes` (new) Phase 6 invokes `/msf-wf <folder> --apply-edits`.
3. `/msf-wf` runs analysis, presents findings via `AskUserQuestion` batches, applies user-approved HTML edits inline.
4. `/msf-wf` saves `msf-findings.md` and returns control to `/wireframes`.
5. `/wireframes` continues to Phase 7 (Spec Handoff).

### J4 — Wrong input
1. User runs `/msf-req <wireframes-folder>` (or `/msf-wf <req-doc.md>`).
2. Skill detects argument shape mismatch, prints: "This looks like a wireframes folder. Run `/msf-wf` instead." (or vice versa).
3. Skill exits without analysis.

---

## 6. Functional Requirements

### 6.1 New skills

| ID | Requirement |
|----|-------------|
| FR-01 | Create `plugins/pmos-toolkit/skills/msf-req/SKILL.md` with frontmatter `name: msf-req`, `user-invocable: true`, `argument-hint: "<path-to-requirements-doc>"`. |
| FR-02 | Create `plugins/pmos-toolkit/skills/msf-wf/SKILL.md` with frontmatter `name: msf-wf`, `user-invocable: true`, `argument-hint: "<path-to-wireframes-folder> [--apply-edits]"`. |
| FR-03 | Both SKILL.md files MUST reference `_shared/msf-heuristics.md` for the M/F/S consideration questions and persona-alignment template instead of inlining them. |
| FR-04 | `/msf-req` description trigger phrases: "evaluate UX of the requirements", "will the proposed solution work for users", "persona check on this PRD", "friction analysis on requirements". |
| FR-05 | `/msf-wf` description trigger phrases: "evaluate the wireframes", "check friction in the UI", "PSYCH score these screens", "wireframe UX evaluation". |
| FR-06 | Trigger phrase sets MUST be disjoint — no shared phrases between the two skills. |

### 6.2 Shared module

| ID | Requirement |
|----|-------------|
| FR-07 | Create `plugins/pmos-toolkit/skills/_shared/msf-heuristics.md` containing: M/F/S 24-consideration list, persona-alignment template, executive-summary template. |
| FR-08 | The heuristics file MUST NOT contain PSYCH scoring rubric — that lives in `/msf-wf` only. |
| FR-09 | The heuristics file MUST be plain markdown referenced via `follow ../_shared/msf-heuristics.md` style instructions. |

### 6.3 Write authority

| ID | Requirement |
|----|-------------|
| FR-10 | `/msf-req` MUST NOT support any flag that mutates the source requirements doc. Final phase emits findings doc only. |
| FR-11 | `/msf-wf` MUST accept `--apply-edits` as the only flag enabling HTML edits to wireframe files. |
| FR-12 | When `--apply-edits` is absent, `/msf-wf` MUST NOT call `Edit` or `Write` against any file in the wireframes folder. |
| FR-13 | When `--apply-edits` is present, `/msf-wf` MUST present each finding via `AskUserQuestion` with Fix/Modify/Skip/Defer options before editing (matches existing /msf Phase 5 pattern). |

### 6.4 PSYCH relocation

| ID | Requirement |
|----|-------------|
| FR-14 | `/msf-wf` MUST contain the PSYCH scoring rubric (entry-context starting scores, ±10 per element, danger-zone thresholds — softened to "directional" language per non-goal). |
| FR-15 | `/msf-wf` MUST produce `psych-findings.md` (or merge into `msf-findings.md` — see open question Q-1) following the format in `reference/psych-output-format.md`. |
| FR-16 | Move `plugins/pmos-toolkit/skills/wireframes/reference/psych-output-format.md` to `plugins/pmos-toolkit/skills/msf-wf/reference/psych-output-format.md`. |
| FR-17 | `/wireframes` SKILL.md MUST have all PSYCH instructions removed. Affected line ranges (as of HEAD): 25, 53, 57, 59–60, 77, 449–555 (entire Phase 6 body), 561–593 (PSYCH/MSF section + flag references), 614, 630, 647, 678, 694–707 (anti-patterns). Verification: `grep -n "PSYCH\|psych-findings\|psych-output-format" plugins/pmos-toolkit/skills/wireframes/SKILL.md` MUST return empty after edit (except for the single thin-wrapper invocation in FR-18). |
| FR-18 | `/wireframes` Phase 6 MUST be replaced with a thin wrapper that invokes `/msf-wf <wireframes-folder> --apply-edits` and waits for completion. |

### 6.5 Output

| ID | Requirement |
|----|-------------|
| FR-19 | Findings doc save path: when invoked inside a pipeline feature folder (matches `.../NN_<slug>/`), save to `<feature_folder>/msf-findings.md`. |
| FR-20 | Findings doc save path: when invoked outside a feature folder (ad-hoc), save to `~/.pmos/msf/YYYY-MM-DD_<slug>.md`. |
| FR-21 | Saved findings doc has no line cap. Contains full persona × scenario × journey × consideration matrix. |
| FR-22 | Chat summary MUST be ≤200 lines. Contains: top 5 friction points, danger-zone screens (if any), prioritized recommendations grouped Must/Should/Nice. |
| FR-23 | Both skills MUST emit a "no actionable findings" terminal state when analysis surfaces nothing — do not manufacture Must/Should/Nice items to fill the template. |

### 6.6 Migration & callers

| ID | Requirement |
|----|-------------|
| FR-24 | Delete `plugins/pmos-toolkit/skills/msf/SKILL.md`. |
| FR-25 | Update `/requirements/SKILL.md` lines 13, 320, 554: replace `/msf` with `/msf-req`. |
| FR-26 | Update `/spec/SKILL.md` line 13: replace `[/msf, /creativity]` with `[/msf-req, /creativity]`. |
| FR-27 | Update `/wireframes/SKILL.md`: remove `--skip-psych` and `--wireframes` flag references; replace inline `/msf` invocation with `/msf-wf --apply-edits`. |
| FR-28 | Audit and update any remaining `/msf` references in: `/create-skill`, `/creativity`, `/design-crit`, `/plan`, `/product-context`, `/simulate-spec`. |
| FR-29 | Bump pmos-toolkit minor version (current 2.21.0 → 2.22.0). |
| FR-30 | Update `CHANGELOG.md` with breaking-change note for `/msf` → `/msf-req` + `/msf-wf` split. |

### 6.7 Wrong-input handling

| ID | Requirement |
|----|-------------|
| FR-31 | `/msf-req` MUST detect when the argument resolves to a directory and exit with: "Argument looks like a wireframes folder. Use `/msf-wf` instead." |
| FR-32 | `/msf-wf` MUST detect when the argument resolves to a single `.md` file and exit with: "Argument looks like a requirements doc. Use `/msf-req` instead." |
| FR-33 | Wrong-input detection MUST run before any analysis or persona alignment. |

### 6.8 Phase requirements

| ID | Requirement |
|----|-------------|
| FR-34 | Neither `/msf-req` nor `/msf-wf` MUST accept `--default-scope`, `--wireframes`, or `--skip-psych`. The only flag recognized is `--apply-edits` on `/msf-wf`. Argument hints MUST list only the path argument (and `[--apply-edits]` for /msf-wf). |
| FR-35 | Both skills MUST execute a Persona Alignment phase before analysis. Behavior: extract any personas/journeys explicitly named in the source artifact (req doc for /msf-req, wireframes + sibling 01_requirements.md for /msf-wf), propose them via `AskUserQuestion` for user confirmation. If the source contains no explicit personas, propose 2–5 inferred personas (max 2 scenarios each) and confirm. Persona alignment is mandatory in both standalone and parent-invoked modes — confirmation step never skipped. |
| FR-36 | `/msf-wf` MUST default the PSYCH entry-context starting score to Medium (40) when not specified. Document the assumption in a header line at the top of `msf-findings.md`: "Entry context: Medium (40, default). Override by editing this line and re-running." |
| FR-37 | Both skills MUST include a "Capture Learnings" final phase per `learnings/learnings-capture.md`, with entries logged under `## /msf-req` and `## /msf-wf` respectively in `~/.pmos/learnings.md`. |
| FR-38 | Both skills MUST include a "Load Workstream Context" Phase 0 per `product-context/context-loading.md`, matching the pattern in other pmos-toolkit pipeline skills. |
| FR-39 | If `/msf-wf` returns a non-zero state or the user terminates it, `/wireframes` Phase 6 MUST abort and surface the underlying error. `/wireframes` MUST NOT auto-continue to Phase 7. The user can re-run `/msf-wf` manually and then proceed with `/spec`. |
| FR-40 | Audit external docs for stale `/msf` references: run `grep -rn '/msf\b' --include='*.md' .` from repo root; update active references in `README.md`, `docs/`, and any CLAUDE.md. Historical changelog entries (e.g., past release notes) left unchanged. `CHANGELOG.md` gets a new top-of-file entry describing the split. |

---

## 7. API / Integration Contracts

This is a markdown-skill refactor — no HTTP APIs. The integration contract is the **invocation contract** between `/wireframes` and `/msf-wf`:

**Caller:** `/wireframes` Phase 6
**Invocation:** `/msf-wf <feature_folder>/wireframes --apply-edits`
**Inputs `/msf-wf` reads:**
- All `.html` files in the wireframes folder
- The feature folder's `01_requirements.md` (for persona context — `/msf-wf` resolves via `_shared/feature-folder.md` protocol)
- `~/.pmos/learnings.md` (entries under `## /msf-wf`)

**Outputs `/msf-wf` produces:**
- `<feature_folder>/msf-findings.md` (canonical findings doc)
- Edits to `<feature_folder>/wireframes/*.html` (when --apply-edits and user approves each finding)
- Chat summary (≤200 lines)

**Failure modes:**
- Wireframes folder missing or empty → exit with error, do not silently degrade
- `01_requirements.md` missing → continue, but flag in findings doc that persona alignment was inferred from wireframes only

---

## 8. Frontend Design

N/A — no UI changes. Skill interaction is text + `AskUserQuestion`.

---

## 9. Edge Cases

| # | Scenario | Condition | Expected Behavior |
|---|----------|-----------|-------------------|
| E1 | `/msf-req` on a Tier 1 requirements doc | Doc tagged Tier 1 | Run anyway; log a warning that MSF is best-suited to Tier 3 |
| E2 | `/msf-wf` standalone, then user re-runs `/wireframes` | User edited findings into req doc, re-runs /wireframes | New /wireframes Phase 6 invokes /msf-wf again; old findings doc overwritten |
| E3 | `/msf-wf --apply-edits` and user picks "Skip" for every finding | All findings dispositioned Skip | No HTML edits; findings doc still saved with all dispositions logged |
| E4 | Findings doc already exists | Re-run on same feature | Overwrite existing `msf-findings.md`; preserve a `.bak` copy for one cycle |
| E5 | Wireframes folder has subfolders | Nested HTML in `wireframes/components/` | Read all .html files recursively |
| E6 | `--apply-edits` passed by user directly (not via /wireframes) | Standalone user invocation with the flag | Allowed; flag is the contract, not the invoker identity |
| E7 | No actionable findings | Analysis surfaces nothing rated Must/Should/Nice | Emit "no actionable findings" message; save findings doc with empty recommendations table; do not pad |
| E8 | Argument is a path that doesn't exist | Bad path | Exit with file-not-found error from `_shared/resolve-input.md` (no special handling needed) |
| E9 | `/msf-req` finds wireframes folder *adjacent* to the req doc | Folder exists at `<feature>/wireframes/` | Suggest in chat: "Wireframes detected at <path>; consider running /msf-wf for grounded analysis." Do not auto-invoke. |

---

## 10. Testing & Verification Strategy

### 10.1 Structural tests (skill-validator)

Run `claude validate plugin pmos-toolkit` after changes:
- `/msf-req` and `/msf-wf` SKILL.md frontmatter parses
- `/msf` SKILL.md is absent
- All cross-skill references in `/requirements`, `/spec`, `/wireframes`, etc. resolve

### 10.2 Reference integrity grep

```bash
# After implementation, this MUST return empty:
grep -rn "/msf\b\|skill: msf$\|name: msf$" plugins/pmos-toolkit/skills/ \
  | grep -v "msf-req\|msf-wf\|msf-heuristics\|msf-findings"
```

### 10.3 Behavior tests (manual, scripted)

| # | Scenario | Verification |
|---|----------|--------------|
| T1 | Standalone /msf-req on a sample req doc | After run: `msf-findings.md` exists; `git diff` on req doc shows no changes |
| T2 | Standalone /msf-wf on a sample wireframes folder | After run: `msf-findings.md` exists; `git diff` on `*.html` shows no changes |
| T3 | /msf-wf --apply-edits with one finding accepted | After run: `git diff` shows expected HTML edit; findings doc records "Fix as proposed" disposition |
| T4 | Wrong input: /msf-req <folder> | Exits with sibling-skill suggestion; no findings doc created |
| T5 | /wireframes end-to-end on Tier 2 feature | Phase 6 invokes /msf-wf; psych-findings/msf-findings produced; HTML edits applied for accepted findings |
| T6 | Trigger phrase test | Submit "evaluate UX of requirements" → triggers /msf-req; "PSYCH score these screens" → triggers /msf-wf |
| T7 | No-actionable-findings exit | Run on a deliberately clean req doc; verify "no actionable findings" output; no padded recommendations |

### 10.4 Verification commands

```bash
# Skill files exist
test -f plugins/pmos-toolkit/skills/msf-req/SKILL.md
test -f plugins/pmos-toolkit/skills/msf-wf/SKILL.md
test -f plugins/pmos-toolkit/skills/_shared/msf-heuristics.md
test -f plugins/pmos-toolkit/skills/msf-wf/reference/psych-output-format.md

# Old skill removed
test ! -f plugins/pmos-toolkit/skills/msf/SKILL.md
test ! -f plugins/pmos-toolkit/skills/wireframes/reference/psych-output-format.md

# No stale refs
! grep -rn "skill: /msf\b\|name: msf$" plugins/pmos-toolkit/skills/

# Version bumped
grep -q '"version": "2.22' plugins/pmos-toolkit/.claude-plugin/plugin.json
```

---

## 11. Open Questions

| # | Question | Owner | Needed By |
|---|----------|-------|-----------|
| Q-1 | One findings doc (`msf-findings.md` containing PSYCH section) or two (`msf-findings.md` + `psych-findings.md`)? | maneesh | Before /plan |
| Q-2 | Does `/msf-wf` get its own subagent for parallel journey analysis, or sequential to keep findings doc consistent? | maneesh | Before /plan |
| Q-3 | Where does the executive-summary template live — `_shared/msf-heuristics.md` or per-skill? Today's chat caps and structure differ slightly between req-mode and wf-mode. | maneesh | Before /plan |
| Q-4 | Backlog item or feature flag for the version bump rollout, or just ship in 2.22.0? | maneesh | Before /execute |

---

## 12. Review Log

| Loop | Findings | Changes Made |
|------|----------|--------------|
| 1 | (a) `--default-scope` removal not explicit; (b) persona-alignment phase missing as FR; (c) PSYCH entry-context default homeless; (d) FR-17 scope vague; (e) learnings-capture + workstream-context Phase 0 not required | Added FR-34 (flag forbidlist), FR-35 (persona alignment with confirm-always), FR-36 (entry-context default), FR-37 (learnings), FR-38 (workstream Phase 0); rewrote FR-17 with line ranges + grep verification |
| 2 | (a) /wireframes Phase 6 failure handling unspecified; (b) external doc references (README, docs/, CLAUDE.md) not in scope | Added FR-39 (Phase 6 abort-on-error) and FR-40 (external doc audit) |
