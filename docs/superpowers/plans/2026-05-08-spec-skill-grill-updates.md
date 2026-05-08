# /spec Skill — Grill-Driven Update Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the 16 resolved findings from the 2026-05-08 grill of the `/spec` skill to its source SKILL.md, releasing as pmos-toolkit 2.21.0.

**Architecture:** Single-file documentation edit on `plugins/pmos-toolkit/skills/spec/SKILL.md` plus a version bump in `plugins/pmos-toolkit/.claude-plugin/plugin.json` and `plugins/pmos-toolkit/.codex-plugin/plugin.json`. Edits are grouped by phase region of the SKILL.md so each commit is atomic and reviewable. Findings reference: `~/.pmos/grills/2026-05-08_spec-skill.md`.

**Tech Stack:** Markdown + JSON. No code, no tests. Verification = re-read the file end-to-end and confirm the resulting flow is internally consistent.

**Source file (target of all edits):** `/Users/maneeshdhabria/Desktop/Projects/agent-skills/plugins/pmos-toolkit/skills/spec/SKILL.md` (current at commit `57a0a75`, 607 lines).

---

## File Map

| File | Change | Why |
|------|--------|-----|
| `plugins/pmos-toolkit/skills/spec/SKILL.md` | Modify (Tasks 1–9) | Apply all 16 findings |
| `plugins/pmos-toolkit/.claude-plugin/plugin.json` | Modify (Task 10) | Version bump 2.20.0 → 2.21.0 |
| `plugins/pmos-toolkit/.codex-plugin/plugin.json` | Modify (Task 10) | Version bump 2.20.0 → 2.21.0 |
| `.claude-plugin/marketplace.json` | Modify if it pins versions (Task 10, conditional) | Marketplace consistency |

---

## Finding → Task Map

| # | Finding | Task |
|---|---------|------|
| 1 | Tier gating only when untagged | T1 |
| 2 | T2 industry research conditional | T2 |
| 3 | Subagent fan-out contract (2 max) | T2 |
| 4 | Silent-role summary block | T3 |
| 5 | Data-flow trace property-based | T3 |
| 6 | Verification plan sketch in chat | T4 |
| 7 | Commit prior spec before overwrite | T5 |
| 8 | T1 Decision Log added | T5 |
| 9 | Spec status "Ready for Plan" | T5 + T7 |
| 10 | Forbid Open Questions at exit | T5 + T6 |
| 11 | Drop min-2 review-loop floor | T6 |
| 12 | Universal exit checklist + N/A | T6 |
| 13 | Structural-finding escape hatch | T6 |
| 14 | Severity tags on findings | T6 |
| 15 | Phase 7 narrowed scope | T7 |
| 16 | Phase 8 evaluate-mandatory, write-optional | T8 |
| — | Anti-Patterns block sync | T9 |
| — | Version bump | T10 |
| — | End-to-end consistency check | T11 |

---

## Task 1: Phase 1 — Tier gating only when untagged

**Files:**
- Modify: `plugins/pmos-toolkit/skills/spec/SKILL.md:69-79`

- [ ] **Step 1: Read the file to confirm current line numbers**

Run: `sed -n '65,82p' plugins/pmos-toolkit/skills/spec/SKILL.md`
Expected: lines match the snippet below.

- [ ] **Step 2: Apply edit**

Replace the existing step 4 of Phase 1 (the tier-detection paragraph + announce + gate) with:

```markdown
4. **Detect the tier.** If the requirements doc has a `Tier:` tag in its frontmatter or header, **carry it forward without asking**. If it is untagged, OR the user entered the pipeline at `/spec` without a requirements doc, assess the tier from the table below and **confirm with the user via `AskUserQuestion`** before proceeding (recommend the assessed tier as option 1).

| Tier | Scope | Sections | Length |
|------|-------|----------|--------|
| **Tier 1: Bug Fix / Minor Enhancement** | Isolated fix or small change | Problem, Root Cause Analysis, Fix Approach, Decision Log (lightweight), Edge Cases, Testing Strategy | ~1-2 pages |
| **Tier 2: Enhancement / UX Overhaul** | Improving existing behavior, adding to existing surface | Problem, Goals, Decision Log, Relevant FR tables, API changes (if any), Frontend Design (if any), Edge Cases, Testing Strategy | ~3-6 pages |
| **Tier 3: Feature / New System** | New capability, new surface, major redesign | ALL sections mandatory including Architecture diagrams, Sequence diagrams, Full FR/NFR tables, API contracts, DB schema (SQL), Frontend design, Feature flags, Rollout strategy | ~6-15 pages |

**Announce:** "This looks like a Tier N spec. Using the [tier name] template." (When the tier was carried forward from a tagged requirements doc, no confirmation question is needed — just announce.)

**Gate:** Do not proceed until you have confirmed understanding of the requirements and (where required) the user has confirmed the tier.
```

- [ ] **Step 3: Commit**

```bash
git add plugins/pmos-toolkit/skills/spec/SKILL.md
git commit -m "docs(spec): tier gate only when untagged"
```

---

## Task 2: Phase 2 — Conditional T2 research + subagent fan-out contract

**Files:**
- Modify: `plugins/pmos-toolkit/skills/spec/SKILL.md:83-110`

- [ ] **Step 1: Read the section**

Run: `sed -n '83,110p' plugins/pmos-toolkit/skills/spec/SKILL.md`

- [ ] **Step 2: Apply edit**

Replace Phase 2 (from the heading to the "Track all sources" line) with:

```markdown
## Phase 2: Research

**Tier 1:** Read the specific files/functions involved in the bug. No broader research needed.

**Tier 2-3: Dispatch up to 2 subagents in parallel.** Each has an explicit return contract:

### Subagent A — Existing Implementation & Patterns
**Always run for Tier 2-3.** Returns:
- File paths + 1-line summaries of code areas the spec will impact
- Current architecture patterns, data models, API conventions in use
- Test patterns from adjacent features (file paths)
- Reusable components/utilities/infrastructure already available

### Subagent B — Industry Research & Alternatives
**Tier 3: always run.** **Tier 2: run only when the design has a non-obvious architectural choice** (e.g., queue vs. webhook vs. polling; relational vs. document; sync vs. async; new infrastructure component). Skip for routine UX overhauls and additive enhancements on an established stack — state explicitly in the spec why you skipped.

Returns:
- **Comparables table:** 2–4 (T3) or 2 (T2) named examples — products, OSS projects, engineering blog posts. Architecture used + documented trade-offs.
- **Alternatives table:** 3+ (T3) or 2 (T2) materially different design shapes with trade-offs (complexity, latency, cost, failure modes, operational burden).
- Established patterns / frameworks / standards that apply, with a build-vs-adopt recommendation.
- Known failure modes / anti-patterns from comparable systems (scaling cliffs, consistency bugs, migration pain).
- For Tier 3: explicit recommendation + rejected-alternatives section.

### Reconciliation
After both subagents return, reconcile any conflicts (e.g., A says "we already have a queue" but B recommends webhooks) explicitly in the Decision Log of the spec — do not silently pick one.

Track all sources in the Research Sources table of the spec.
```

- [ ] **Step 3: Commit**

```bash
git add plugins/pmos-toolkit/skills/spec/SKILL.md
git commit -m "docs(spec): conditional T2 industry research + 2-subagent fan-out contract"
```

---

## Task 3: Phase 3 — Silent-role summary + property-based data-flow trigger

**Files:**
- Modify: `plugins/pmos-toolkit/skills/spec/SKILL.md:140-168` (data flow trigger + role protocol)

- [ ] **Step 1: Read the section**

Run: `sed -n '140,170p' plugins/pmos-toolkit/skills/spec/SKILL.md`

- [ ] **Step 2: Edit the data-flow-trace trigger heuristic**

Replace the existing line:
```
**Trigger heuristic:** if the feature mentions search, index, sync, export, import, process, queue, cache, or aggregate — run the trace. Skip for purely CRUD or purely UI features.
```

With:

```markdown
**Trigger (property-based):** Run the data flow trace whenever the feature has the property *"data persisted by one code path is consumed by a different code path."* This includes — but is not limited to — search/indexing, notifications, feeds, digests, audit logs, sync, export, import, queues, caches, aggregations, and report generation. Skip for purely CRUD-on-a-single-entity features or purely UI/UX changes that don't introduce new persistence-to-read flows. When in doubt, run the trace — it's cheap.
```

- [ ] **Step 3: Edit the Role Protocol — replace per-role announcement rule with end-of-phase summary**

Replace the entire `### Role Protocol (MANDATORY for Tier 2-3)` subsection (currently lines 156–168) with:

```markdown
### Role Protocol (MANDATORY for Tier 2-3)

For each role with **at least one genuine question or stated assumption**:
1. **Announce:** "Speaking as [Role]:"
2. Ask 1-2 specific questions via `AskUserQuestion` (batch up to 4 within the same role) OR state the assumption you're proceeding with as a Decision-Log entry.
3. Note answers or stated assumptions as decisions for the spec.
4. **If the user picks a non-recommended option** in any `AskUserQuestion` you issued for this role, before moving to the next role ask: "Does this choice change any existing invariant or contract? If yes, capture it as a Decision-Log entry with the trade-off explicit." See `../_shared/structured-ask-edge-cases.md` §2.

For roles with **no genuine questions** — do NOT announce inline. Instead, at the end of Phase 3, emit a single **"Roles considered, no questions"** block:

```text
Silent roles considered:
- DBA — no schema changes; covered by §X of requirements
- DevOps — Tier 2, deployment unchanged
- Senior Analyst — FR coverage already validated by Architect role
```

Each silent-role entry MUST cite the specific reason (which requirements section, or which earlier role's answer, makes this role's concerns moot). The user gets the same audit trail without per-role chat noise.

**Anti-pattern:** Silently skipping a role with no entry in the silent-roles block. The "Skip if..." column in the role table is the ONLY valid reason to omit a role from BOTH the inline interview AND the silent-roles block.
```

- [ ] **Step 4: Commit**

```bash
git add plugins/pmos-toolkit/skills/spec/SKILL.md
git commit -m "docs(spec): silent-role summary block + property-based data-flow trigger"
```

---

## Task 4: Phase 4 — Emit verification plan sketch in chat

**Files:**
- Modify: `plugins/pmos-toolkit/skills/spec/SKILL.md:172-185`

- [ ] **Step 1: Read the section**

Run: `sed -n '172,186p' plugins/pmos-toolkit/skills/spec/SKILL.md`

- [ ] **Step 2: Apply edit**

Replace Phase 4 in full with:

```markdown
## Phase 4: Verification Plan Sketch

Before writing the spec, sketch HOW each major requirement will be verified, and **emit the sketch in chat for the user to confirm or push back on**. This is a CORE part of the spec, not an afterthought — surfacing it as a chat artifact (rather than a thinking-only step) catches under-thought verification when it's still cheap to fix.

Format:

```markdown
**Verification plan sketch (Phase 4):**

| Requirement | Verification approach |
|-------------|----------------------|
| FR-01 | Unit test: assert X given Y; integration test: hit /endpoint and verify Z |
| FR-02 | Playwright flow: log in → navigate → assert visible element |
| NFR-01 (perf) | k6 script targeting /api/foo at 100 RPS; assert p95 < 200ms |
```

Good verification patterns to draw from:
- Automated unit + integration tests with specific assertions
- CLI scripts to verify APIs before building frontend
- Playwright MCP for end-to-end frontend flow testing
- Linting and static analysis checks
- Synthetic data scenarios that exercise edge cases
- Before/after comparison reports

**Gate:** Wait for user acknowledgment of the sketch before moving to Phase 5. If the user pushes back on an approach, revise inline; do not write the spec until the sketch is accepted.
```

- [ ] **Step 3: Commit**

```bash
git add plugins/pmos-toolkit/skills/spec/SKILL.md
git commit -m "docs(spec): Phase 4 emits verification plan sketch in chat"
```

---

## Task 5: Phase 5 — Pre-write commit, T1 Decision Log, status default, drop Open Questions tables

**Files:**
- Modify: `plugins/pmos-toolkit/skills/spec/SKILL.md:188-471`

This task is the largest. Five sub-edits.

- [ ] **Step 1: Add pre-write commit instruction**

Replace the line `Save to `{feature_folder}/02_spec.md`. Overwrite if it already exists.` (currently line 190) with:

```markdown
Save to `{feature_folder}/02_spec.md`.

**Before overwriting an existing spec:** if `{feature_folder}/02_spec.md` exists AND has uncommitted changes (check `git status --porcelain "{feature_folder}/02_spec.md"`), commit it first:

```bash
git add "{feature_folder}/02_spec.md"
git commit -m "docs: snapshot prior spec before /spec rewrite"
```

This makes git the backup; the rewrite then proceeds normally with `Write` (no `.bak` files needed). If the file exists but is already committed, no pre-commit is needed — just proceed.
```

- [ ] **Step 2: Add Decision Log section to Tier 1 template**

In the Tier 1 template (currently lines 192–218), insert a new `## 3. Decision Log` section between "Fix Approach" and "Edge Cases" (renumbering subsequent sections). Replace the Tier 1 template block in full with:

```markdown
### Tier 1 Template: Bug Fix / Minor Enhancement

```markdown
# <Bug/Fix Name> — Spec

**Date:** YYYY-MM-DD
**Status:** Draft
**Requirements:** `<path>`

## 1. Problem Statement
[What's broken, the impact, how to reproduce]

## 2. Root Cause Analysis
[Why it's happening — trace through the code]

## 3. Fix Approach
[What changes, why this approach over alternatives]

## 4. Decision Log
[Lightweight — 1–3 rows expected. Capture the fix-approach choice and any rejected alternatives. Skip the table entirely only if there was exactly one obvious fix with no alternatives considered.]

| # | Decision | Options Considered | Rationale |
|---|----------|-------------------|-----------|
| D1 | [What was decided] | (a) ..., (b) ... | [Why] |

## 5. Edge Cases

| # | Scenario | Condition | Expected Behavior |
|---|----------|-----------|-------------------|
| E1 | [Name] | [Trigger] | [What happens] |

## 6. Testing Strategy
[Exact tests to write, exact verification commands]
```
```

- [ ] **Step 3: Remove the Open Questions table from the Tier 2 template**

In the Tier 2 template, delete the entire `## 11. Open Questions` block (the heading and the empty table). The Tier 2 template should end at the `## 10. Testing & Verification Strategy` block. (Open Questions are now forbidden at exit per Phase 6 — see Task 6 — and during work they live in the Review Log, not as a permanent template section.)

- [ ] **Step 4: Remove the Open Questions table from the Tier 3 template**

In the Tier 3 template, delete the entire `## 17. Open Questions` block (heading + table). The Tier 3 template should end at `## 16. Research Sources`.

- [ ] **Step 5: Add status-lifecycle note above the templates**

Immediately after the line `Save to ...` (post Step 1 above) and before `### Tier 1 Template`, insert:

```markdown
### Status Field Lifecycle

All templates start at `**Status:** Draft`. The status is promoted to `**Status:** Ready for Plan` only on user confirmation in Phase 7 (see that phase). Downstream skills (`/simulate-spec`, `/plan`) check this field and warn the user if invoked against a `Draft` spec.
```

- [ ] **Step 6: Commit**

```bash
git add plugins/pmos-toolkit/skills/spec/SKILL.md
git commit -m "docs(spec): pre-write commit, T1 decision log, status lifecycle, drop Open Questions templates"
```

---

## Task 6: Phase 6 — Drop floor, escape hatch, severity tags, universal exit checklist

**Files:**
- Modify: `plugins/pmos-toolkit/skills/spec/SKILL.md:474-546`

- [ ] **Step 1: Read the section**

Run: `sed -n '474,546p' plugins/pmos-toolkit/skills/spec/SKILL.md`

- [ ] **Step 2: Replace the loop-count rule**

Replace the lines:

```
**Tier 1:** Run 1 review loop, then final review.

**Tier 2-3:** Run minimum 2 loops, continue until exit criteria are met.
```

With:

```markdown
**Loop count is emergent — there is no minimum or maximum.** Run review loops until the universal exit checklist (below) is satisfied: every applicable item is `pass` and the user has confirmed no further concerns. A single clean loop is a valid stopping point; a Tier 3 spec may need four. The exit criteria are the contract, not the loop count.
```

- [ ] **Step 3: Add severity tagging to the Findings Presentation Protocol**

In the `### Findings Presentation Protocol` block, modify item 2's `question` shape description from:

```
- `question`: one-sentence restatement of the finding + the proposed fix (concrete — e.g., "Add 409 response for duplicate email to POST /users" not "tighten error handling")
```

To:

```markdown
- `question`: **prefix with severity tag `[Blocker]`, `[Should-fix]`, or `[Nit]`**, then a one-sentence restatement of the finding + the proposed fix. Example: `[Blocker] Add 409 response for duplicate email to POST /users` or `[Nit] Rename §6.2 heading from 'DB' to 'Database Design' for consistency`. Severity definitions: **Blocker** = spec cannot ship without this fix (missing requirement coverage, broken contract); **Should-fix** = real defect, ship-blocker absent good reason to defer; **Nit** = cosmetic or stylistic.
```

- [ ] **Step 4: Add the structural-finding escape hatch**

Append a new subsection after `### Findings Presentation Protocol` and before `### Exit Criteria`:

```markdown
### Escape Hatch: Structural Findings

A finding that requires re-architecting (not an inline fix) — e.g., "the whole event-driven approach is wrong, this should be transactional" — does NOT belong in the standard Fix/Modify/Skip/Defer flow. The "fix issues inline" rule of the Loop Protocol assumes local edits.

**When you detect a structural finding:**
1. Pause the loop immediately. Do not batch it with other findings.
2. Surface it to the user with a dedicated `AskUserQuestion`:
   - `question`: state the structural concern + the architectural shift it implies (one sentence each).
   - Options:
     - **Revise scope and re-enter Phase 3** — multi-role review with the new architectural direction; spec is rewritten substantially.
     - **Defer** — log in the Review Log with rationale; ship the current architecture and revisit in a follow-up.
     - **Accept trade-off** — keep the current architecture; document the rejected alternative in the Decision Log with the trade-off explicit.
     - **Modify** — user proposes a different resolution path next turn.
3. After the user picks, resume the loop: either back to Phase 3 (option 1), to applying remaining findings (options 2/3), or to a free-form discussion (option 4).

A structural finding is one where the proposed fix would invalidate three or more existing spec sections. If you can fix it with a localized edit to one or two sections, it's not structural — handle it through the standard flow.
```

- [ ] **Step 5: Replace the Exit Criteria block with the universal checklist + N/A**

Replace the entire `### Exit Criteria (ALL must be true)` block with:

```markdown
### Universal Exit Checklist

All items below must be `pass` or `N/A` (with a stated reason for N/A). Loop until satisfied.

| # | Criterion | When N/A |
|---|-----------|----------|
| 1 | Every requirement from the requirements doc is covered by a numbered FR/NFR | Never N/A — if there is no requirements doc, this skill should not have started |
| 2 | Decision Log has entries with Options Considered + Rationale for every non-trivial choice | Tier 1 with a single obvious fix and no alternatives |
| 3 | API contracts complete with request + response + error shapes | No API surface introduced or changed |
| 4 | DB schema is actual SQL with migration notes | No DB changes |
| 5 | Sequence diagrams present (one per flow, error paths included) | Fewer than 3 components interact in any flow |
| 6 | Edge cases have specific Conditions + Expected Behaviors | Never N/A — Tier 1 still requires this |
| 7 | Verification Plan Sketch (from Phase 4) is reflected in §14 with exact commands | Never N/A |
| 8 | Frontend design specifies hierarchy + state + interactions | No frontend changes |
| 9 | Rollout strategy documented (flags, migration order, rollback) | Tier 1-2 with no deploy-time risk |
| 10 | **Open Questions section is empty (no unresolved items)** | Never N/A — see below |
| 11 | Last loop produced only `[Nit]` findings or none | Never N/A |
| 12 | User has explicitly confirmed no further concerns | Never N/A — do not self-declare exit |

**Open Questions are forbidden at exit.** The spec is the contract; if a decision is not made, the spec is not done. Resolve every open question before promoting status — either decide and log to the Decision Log, or split the unresolved scope into a follow-up spec and remove it from this one. The Review Log may carry deferred items DURING work, but the published spec must have none.
```

- [ ] **Step 6: Commit**

```bash
git add plugins/pmos-toolkit/skills/spec/SKILL.md
git commit -m "docs(spec): emergent loop count, severity tags, structural escape hatch, universal exit checklist, forbid open questions at exit"
```

---

## Task 7: Phase 7 — Narrow scope, promote status on confirm

**Files:**
- Modify: `plugins/pmos-toolkit/skills/spec/SKILL.md:549-571`

- [ ] **Step 1: Apply edit**

Replace Phase 7 in full with:

```markdown
## Phase 7: Final Review — Conciseness, Readability, Coherence

Phase 6 already covered structural completeness and design soundness. Phase 7 is the **fresh-eyes prose pass** — what remains after the spec is structurally and architecturally sound:

1. **Conciseness** — Can sections be tightened without losing essence? Flag verbose passages.
2. **Engineer readability** — Read as a stranger to this feature. Can you build it from this doc alone? Where do you stumble?
3. **Cross-section coherence** — Do §6 (architecture), §9 (APIs), §10 (schema), and §11 (frontend) tell one consistent story? Flag any place where two sections imply different shapes.

(Requirements coverage and missing-section checks are owned by the Phase 6 universal exit checklist — do NOT re-run them here.)

**Share findings via the same `AskUserQuestion` batching as Phase 6** — including the `[Blocker]/[Should-fix]/[Nit]` severity tags. Up to 4 per call. Apply dispositions inline.

**On user confirmation that the spec is complete:**

1. Promote the status field in the spec doc:

```bash
# Update line containing **Status:** Draft to **Status:** Ready for Plan
```

   Use `Edit` with `old_string="**Status:** Draft"` and `new_string="**Status:** Ready for Plan"`.

2. Commit:

```bash
git add {feature_folder}/02_spec.md
git commit -m "docs: spec ready for plan — <feature>"
```

3. Ask the user:

> "Spec is Ready for Plan. Next options:
> - `/pmos-toolkit:simulate-spec` — pressure-test the design against scenarios and adversarial failure modes (recommended for Tier 2-3)
> - `/pmos-toolkit:plan` — proceed directly to implementation planning"

The user's explicit confirmation is required before promoting status. Do not self-declare completion.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/pmos-toolkit/skills/spec/SKILL.md
git commit -m "docs(spec): Phase 7 narrowed scope + status promotion to Ready for Plan"
```

---

## Task 8: Phase 8 — Evaluate-mandatory, write-optional

**Files:**
- Modify: `plugins/pmos-toolkit/skills/spec/SKILL.md:575-583`

- [ ] **Step 1: Apply edit**

Replace Phase 8 in full with:

```markdown
## Phase 8: Workstream Enrichment

**Skip if no workstream was loaded in Phase 0.** Otherwise, follow `_shared/pipeline-setup.md` Section C.

For this skill, evaluate whether anything from this session is worth writing back to the workstream. Signals to look for:
- Tech stack decisions → workstream `## Tech Stack`
- Architectural constraints → workstream `## Constraints & Scars`
- Key design decisions → workstream `## Key Decisions`

**The reflection is mandatory; writing entries is not.** If the spec produced no workstream-level signal (typical for small Tier 2 specs that operate within established constraints), explicitly state "No workstream-level signals from this session" and exit. Forced enrichment produces noise; zero entries is a valid outcome.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/pmos-toolkit/skills/spec/SKILL.md
git commit -m "docs(spec): Phase 8 evaluate-mandatory, write-optional"
```

---

## Task 9: Anti-Patterns block — sync with new rules

**Files:**
- Modify: `plugins/pmos-toolkit/skills/spec/SKILL.md:593-606`

- [ ] **Step 1: Apply edit**

Replace the `## Anti-Patterns (DO NOT)` list in full with:

```markdown
## Anti-Patterns (DO NOT)

- Do NOT skip the multi-role interview for Tier 2-3 — each role catches different gaps. Roles with no questions go in the silent-roles summary block, not omitted.
- Do NOT write API contracts without response shapes and error responses
- Do NOT write DB schemas as prose — show actual SQL
- Do NOT write "add tests" without specifying what to test and how
- Do NOT treat verification as an afterthought — Phase 4 emits a sketch in chat before the spec is written
- Do NOT create a new spec file in each review loop — update the original
- Do NOT promote status to "Ready for Plan" before user confirmation
- Do NOT ship a spec with non-empty Open Questions — resolve or split scope
- Do NOT self-declare loop completion — the user gates exit
- Do NOT write decision entries without "Options Considered" and "Rationale"
- Do NOT ask questions for the sake of asking — only ask what genuinely helps
- Do NOT skip sequence diagrams for multi-component interactions (Tier 3)
- Do NOT over-specify internal implementation details — prescribe the interface, leave the internals to engineering judgment
- Do NOT combine multiple scenarios into one sequence diagram — one diagram per flow
- Do NOT force-fit a structural finding into the inline-edit flow — use the Phase 6 escape hatch
- Do NOT batch findings without `[Blocker]/[Should-fix]/[Nit]` severity tags
- Do NOT run industry research at Tier 2 unless the design has a non-obvious architectural choice
```

- [ ] **Step 2: Commit**

```bash
git add plugins/pmos-toolkit/skills/spec/SKILL.md
git commit -m "docs(spec): anti-patterns synced with grill updates"
```

---

## Task 10: Version bump to 2.21.0

**Files:**
- Modify: `plugins/pmos-toolkit/.claude-plugin/plugin.json`
- Modify: `plugins/pmos-toolkit/.codex-plugin/plugin.json`
- Conditional modify: `.claude-plugin/marketplace.json` (only if it pins pmos-toolkit version)

- [ ] **Step 1: Check whether marketplace.json pins the version**

Run: `grep -n "pmos-toolkit\|version" .claude-plugin/marketplace.json | head -20`
Decision: if a `"version":` field is associated with pmos-toolkit, include it in the bump; otherwise leave it alone.

- [ ] **Step 2: Bump `.claude-plugin/plugin.json`**

Edit `plugins/pmos-toolkit/.claude-plugin/plugin.json`:
- Replace `"version": "2.20.0"` with `"version": "2.21.0"`.

- [ ] **Step 3: Bump `.codex-plugin/plugin.json`**

Edit `plugins/pmos-toolkit/.codex-plugin/plugin.json`:
- Replace `"version": "2.20.0"` with `"version": "2.21.0"`.

- [ ] **Step 4: Conditional — bump marketplace.json if it pins the version**

If Step 1 found a pinned version, edit `.claude-plugin/marketplace.json`:
- Replace `"version": "2.20.0"` (or whatever is pinned for pmos-toolkit) with `"version": "2.21.0"`.

- [ ] **Step 5: Commit**

```bash
git add plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore(release): pmos-toolkit 2.21.0 — /spec grill-driven updates"
```

(If marketplace.json was not modified, it will be silently dropped from `git add` — no error.)

---

## Task 11: End-to-end consistency check

**Files:** Read-only review — no edits unless issues found.

- [ ] **Step 1: Read the entire SKILL.md top to bottom**

Run: `wc -l plugins/pmos-toolkit/skills/spec/SKILL.md`
Then `cat plugins/pmos-toolkit/skills/spec/SKILL.md` (or Read in chunks).

- [ ] **Step 2: Verify the following coherence properties**

Walk this checklist; if any item fails, fix inline and add a follow-up commit:

1. **Phase numbering** is sequential (0, 1, 2, ..., 9) with no gaps after edits.
2. **Phase 4 sketch → Phase 5 §14** — Phase 5 verification template still aligns with what Phase 4 sketches; the sketch's table headers should match §14 of the Tier 3 template.
3. **Phase 6 exit checklist item 7** references Phase 4 — confirm the wording matches.
4. **Phase 7 status promotion** — confirm `**Status:** Draft` appears literally in all three template blocks (T1, T2, T3) so the Edit operation works.
5. **Open Questions removed** — grep `grep -n "Open Questions" plugins/pmos-toolkit/skills/spec/SKILL.md` should return ONLY the Phase 6 exit-criterion #10 reference and the anti-pattern. NO template sections, NO Phase 7 references.
6. **Tier 1 Decision Log** — confirm §3 of T1 template is `## 4. Decision Log` (renumbered) and Edge Cases is now §5, Testing is §6.
7. **Silent-roles block** — confirm Phase 3 mentions the silent-roles block and the role table's "Skip if..." column is still the only valid full-skip path.
8. **Subagent contract** — confirm Phase 2 names "Subagent A" and "Subagent B" with explicit return contracts.
9. **Anti-patterns** — every bullet still corresponds to a rule somewhere in the body. No orphans.
10. **Version bump** — `grep version plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json` returns `"version": "2.21.0"` for both.

- [ ] **Step 3: Render the file in a markdown viewer (mental render is fine) and skim**

The reader should be able to follow Phase 0 → Phase 9 without cross-referencing the old version. If a section assumes prior context that's no longer present (e.g., "the minimum 2 loops" mentioned somewhere we missed), fix it.

- [ ] **Step 4: Final commit (only if Step 2 or Step 3 produced fixes)**

```bash
git add plugins/pmos-toolkit/skills/spec/SKILL.md
git commit -m "docs(spec): consistency fixes after grill-driven update"
```

---

## Self-Review Notes

- **Spec coverage check:** Each of the 16 grill findings is mapped in the Finding → Task table. The two "stronger than recommended" findings (universal exit checklist, forbid Open Questions at exit) are implemented per the user's stated preference, not the original recommendation.
- **Placeholder scan:** Every Edit step shows the new content explicitly. No "TBD" or "implement later". Conditional steps (Task 10 marketplace.json) state the decision rule explicitly.
- **Type consistency:** Status values are always `Draft` and `Ready for Plan` (no "Approved" or other variants). Severity tags are always `[Blocker]/[Should-fix]/[Nit]`. Subagent labels are always `Subagent A` (existing) and `Subagent B` (industry).
- **Risks:** Task 5 is the largest task and touches three template blocks. If Edit string-matching fails on whitespace or section numbering, fall back to reading the affected lines and re-issuing the Edit with exact line content.
- **Out of scope:** This plan does NOT update the gaps surfaced in the report's "not deeply grilled" section ("3+ components" definition, backlog auto-prompt threshold, Phase 1 step 2 confirmation mechanism). Those are tracked for a follow-up grill.
