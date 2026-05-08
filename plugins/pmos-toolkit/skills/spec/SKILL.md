---
name: spec
description: Create a detailed technical specification from a requirements document — architecture, API contracts, DB schema, frontend design, testing strategy, verification plan. Second stage in the requirements -> spec -> plan pipeline. Auto-tiers by scope. Use when the user says "write the technical design", "design the system", "create the spec", "how should this work technically", or has a requirements doc ready for detailed design.
user-invocable: true
argument-hint: "<path-to-requirements-doc or requirements text> [--feature <slug>] [--backlog <id>]"
---

# Technical Specification Generator

Create a comprehensive technical specification from a requirements document. The spec defines HOW we're building it — architecture, API contracts, database design, frontend components, and verification strategy. This is the SECOND stage in a 3-stage pipeline:

```
/requirements  →  [/msf, /creativity]  →  /spec  →  [/simulate-spec]  →  /plan  →  /execute  →  /verify
                   optional enhancers     (this skill)    optional validator
```

A spec is prescriptive about WHAT and WHY, but leaves room for engineering judgment on internal implementation details. It should be detailed enough that a competent engineer with subject expertise could implement it from the doc alone.

**Announce at start:** "Using the spec skill to create a detailed technical specification."

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No `AskUserQuestion`:** State your assumption, document it in the output, and proceed. The user reviews after completion.
- **No subagents:** Perform research and analysis sequentially as a single agent.
- **No Playwright MCP:** Note browser-based verification as a manual step for the user.

---

## Backlog Bridge

This skill optionally integrates with `/backlog`. See `plugins/pmos-toolkit/skills/backlog/pipeline-bridge.md`.

**At skill start:**
- If `--backlog <id>` was passed: load the item file as supplementary context.
- If no argument provided AND `<repo>/backlog/items/` has items with status=ready: run the auto-prompt flow.

**At skill end (after writing the spec doc):**
- If `<id>` was set, invoke `/backlog set {id} spec_doc={doc_path}`, then `/backlog set {id} status=spec'd` (only if current status is `inbox` or `ready`). On failure, warn and continue.

---

## Phase 0: Pipeline Setup (inline — do not skip)

Use workstream context (loaded by step 3 below) to inform technical decisions — product constraints, tech stack, and stakeholder concerns shape architecture choices. The skill supports users who enter the pipeline at `/spec` (folder will be created in step 4 if needed).

<!-- pipeline-setup-block:start -->
1. **Read `.pmos/settings.yaml`.**
   - If missing → you MUST invoke the `Read` tool on `_shared/pipeline-setup.md` Section A and run first-run setup before proceeding. (Skipping this Read is the most common cause of folder-naming defects.)
2. Set `{docs_path}` from `settings.docs_path`.
3. If `settings.workstream` is non-null → load `~/.pmos/workstreams/{workstream}.md` as context preamble; if frontmatter `type` is `charter` or `feature` and a `product` field exists, also load `~/.pmos/workstreams/{product}.md` read-only.
4. Resolve `{feature_folder}`:
   - If `--feature <slug>` was passed → glob `{docs_path}/features/*_<slug>/`. **Exactly 1 match required**; on 0 or 2+ → you MUST `Read` `_shared/pipeline-setup.md` Section B before acting.
   - Else if `settings.current_feature` is set AND `{docs_path}/features/{current_feature}/` exists → use it.
   - Else → ask user (offer: create new with derived slug, pick existing from folder list, or specify via Other...).
5. **Edge cases — you MUST `Read` `_shared/pipeline-setup.md` Section B before acting:** slug collision, slug validation failure, legacy date-less folder encountered, ambiguous `--feature` lookup, any folder creation.
6. Read `~/.pmos/learnings.md` if present; note entries under `## /<this-skill-name>` and factor them into approach (skill body wins on conflict; surface conflicts to user before applying).
<!-- pipeline-setup-block:end -->

---

## Phase 1: Intake & Tier Detection

1. **Locate the requirements.** Follow `../.shared/resolve-input.md` with `phase=requirements`, `label="requirements doc"`.
2. **Read the requirements end-to-end.** Confirm understanding with the user — summarize the problem, goals, non-goals, and key decisions already made.
3. **Check for existing spec.** Look at `{feature_folder}/02_spec.md` for an existing file.
   - If found: read it, ask the user if this is an update or fresh start.
   - If not found: proceed.
4. **Detect the tier.** If the requirements doc has a `Tier:` tag in its frontmatter or header, **carry it forward without asking**. If it is untagged, OR the user entered the pipeline at `/spec` without a requirements doc, assess the tier from the table below and **confirm with the user via `AskUserQuestion`** before proceeding (recommend the assessed tier as option 1).

| Tier | Scope | Sections | Length |
|------|-------|----------|--------|
| **Tier 1: Bug Fix / Minor Enhancement** | Isolated fix or small change | Problem, Root Cause Analysis, Fix Approach, Decision Log (lightweight), Edge Cases, Testing Strategy | ~1-2 pages |
| **Tier 2: Enhancement / UX Overhaul** | Improving existing behavior, adding to existing surface | Problem, Goals, Decision Log, Relevant FR tables, API changes (if any), Frontend Design (if any), Edge Cases, Testing Strategy | ~3-6 pages |
| **Tier 3: Feature / New System** | New capability, new surface, major redesign | ALL sections mandatory including Architecture diagrams, Sequence diagrams, Full FR/NFR tables, API contracts, DB schema (SQL), Frontend design, Feature flags, Rollout strategy | ~6-15 pages |

**Announce:** "This looks like a Tier N spec. Using the [tier name] template." (When the tier was carried forward from a tagged requirements doc, no confirmation question is needed — just announce.)

**Gate:** Do not proceed until you have confirmed understanding of the requirements and (where required) the user has confirmed the tier.

---

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

---

## Phase 3: Multi-Role Interview

Act as each role IN SEQUENCE. For each role, identify gaps, risks, and missing details. Use AskUserQuestion to ask questions — batch related questions from the same role into a single call (up to 4), but do not mix questions across roles.

**Do NOT ask questions for the sake of asking.** Only ask what genuinely helps create the specification. State assumptions rather than asking obvious questions. The number of questions per role should match the number of genuine gaps — zero is fine (announce the role and state why), five is fine if all five matter.

**Tier 1:** Skip this phase — bug fixes don't need multi-role review.

**Tier 2:** Use 2-3 relevant roles.

**Tier 3:** Use all applicable roles.

### Roles, Ordering & Focus Areas

Run roles in this order. Each role's decisions inform the next — architecture constrains schema, schema constrains APIs, APIs constrain frontend, user flows validate the full stack, deployment wraps everything.

| Order | Role | Focus | Skip if... |
|-------|------|-------|------------|
| 1 | **Principal Architect** | System boundaries, service interactions, data flow, deployment model | No new services or data flows |
| 2 | **Database Administrator** | Schema design, migrations, indexes, query patterns, data integrity | No DB changes |
| 3 | **Principal Designer** | UI components, state management, design tokens, user interactions, responsive behavior | No frontend changes |
| 4 | **Product Director** | User personas, user flows, edge cases, empty states, first-time experience | Already thorough in requirements |
| 5 | **DevOps Engineer** | Deployment, configuration, feature flags, monitoring, rollout strategy | Tier 1-2 |
| 6 | **Senior Analyst** | Functional & non-functional requirements coverage, acceptance criteria, success metrics — final gap sweep | Tier 1 |

**Why this order:** Architect establishes the system shape (containers, protocols, service boundaries). DBA designs the schema within those boundaries. Designer builds the frontend knowing what data and APIs exist. Product Director validates that the technical decisions serve user flows. DevOps wraps deployment around the full picture. Analyst does a final coverage check.

### Data Flow Trace (conditional)

**When the feature involves a write→read pipeline** (search indexing, background processing, sync, export, import, caching, aggregation — anything where data written in one flow is consumed in another), the Architect role must produce a data flow trace:

1. Name the **write entry point** (e.g., `add_book()`)
2. Name the **storage target** (e.g., `search_index` table, cache key, queue)
3. Name the **read entry point** (e.g., `SearchService.search()`)
4. **Verify each link exists** in the current codebase with a grep or file read — not assumption
5. If any link is missing, flag it as a **gap to implement** in the spec

**Trigger (property-based):** Run the data flow trace whenever the feature has the property *"data persisted by one code path is consumed by a different code path."* This includes — but is not limited to — search/indexing, notifications, feeds, digests, audit logs, sync, export, import, queues, caches, aggregations, and report generation. Skip for purely CRUD-on-a-single-entity features or purely UI/UX changes that don't introduce new persistence-to-read flows. When in doubt, run the trace — it's cheap.

**When to adjust:** If the project is primarily a frontend/UX change with minimal backend work, move Designer to position 2 (before DBA) — the UX may drive what data needs to be stored. State your reordering rationale when you announce the first role.

For Tier 2 (2-3 roles), pick from this list in order — don't jump to role 5 while skipping role 2.

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

---

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

---

## Phase 5: Write the Spec

Save to `{feature_folder}/02_spec.md`.

**Before overwriting an existing spec:** if `{feature_folder}/02_spec.md` exists AND has uncommitted changes (check `git status --porcelain "{feature_folder}/02_spec.md"`), commit it first:

```bash
git add "{feature_folder}/02_spec.md"
git commit -m "docs: snapshot prior spec before /spec rewrite"
```

This makes git the backup; the rewrite then proceeds normally with `Write` (no `.bak` files needed). If the file exists but is already committed, no pre-commit is needed — just proceed.

### Status Field Lifecycle

All templates start at `**Status:** Draft`. The status is promoted to `**Status:** Ready for Plan` only on user confirmation in Phase 7 (see that phase). Downstream skills (`/simulate-spec`, `/plan`) check this field and warn the user if invoked against a `Draft` spec.

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

### Tier 2 Template: Enhancement / UX Overhaul

```markdown
# <Feature Name> — Spec

**Date:** YYYY-MM-DD
**Status:** Draft
**Requirements:** `<path>`

## 1. Problem Statement
[Restate from requirements + primary success metric]

## 2. Goals

| # | Goal | Success Metric |
|---|------|---------------|
| G1 | [Outcome] | [Measurement] |

## 3. Non-Goals
- [Exclusion] — because [reason]

## 4. Decision Log

| # | Decision | Options Considered | Rationale |
|---|----------|-------------------|-----------|
| D1 | [What] | (a) ..., (b) ... | [Why] |

## 5. User Journeys
[Key flows with diagrams if 3+ branches]

## 6. Functional Requirements

### 6.1 [Area]

| ID | Requirement |
|----|-------------|
| FR-01 | [Specific, testable] |

## 7. API Changes (if any)
[Endpoint, request, response, errors]

## 8. Frontend Design (if any)
[Component hierarchy, state, interactions]

## 9. Edge Cases

| # | Scenario | Condition | Expected Behavior |
|---|----------|-----------|-------------------|

## 10. Testing & Verification Strategy
[What to test, how, exact commands]
```

### Tier 3 Template: Feature / New System

```markdown
# <Feature Name> — Spec

**Date:** YYYY-MM-DD
**Status:** Draft
**Requirements:** `<path>`

---

## 1. Problem Statement
[Restate from requirements. 2-4 sentences. Include the primary success metric.]

---

## 2. Goals

| # | Goal | Success Metric |
|---|------|---------------|
| G1 | [Observable outcome] | [How measured] |

---

## 3. Non-Goals
- [Explicit exclusion] — because [reason]

---

## 4. Decision Log

| # | Decision | Options Considered | Rationale |
|---|----------|-------------------|-----------|
| D1 | [What was decided] | (a) ..., (b) ..., (c) ... | [Why — include trade-offs] |

---

## 5. User Personas & Journeys

### 5.1 [Persona Name] (primary)
[Context, goals, constraints]

### 5.2 User Journey: [Journey Name]
[Step-by-step flow. Use Mermaid for complex flows with 3+ branches.]

---

## 6. System Design

### 6.1 Architecture Overview
[ASCII or Mermaid diagram showing components and data flow. Use C4 Level 1-2.]

### 6.2 Sequence Diagrams
[Mermaid sequence diagrams for key interactions. One diagram per flow — do NOT combine multiple scenarios. Include error paths alongside happy paths.]

---

## 7. Functional Requirements

### 7.1 [Feature Area]

| ID | Requirement |
|----|-------------|
| FR-01 | [Specific, testable requirement] |
| FR-02 | ... |

### 7.2 [Feature Area 2]
...

---

## 8. Non-Functional Requirements

| ID | Category | Requirement |
|----|----------|-------------|
| NFR-01 | Performance | [Specific threshold] |
| NFR-02 | Accessibility | ... |

---

## 9. API Contracts

### 9.1 [Endpoint Name]

```
METHOD /path
```

**Request:**
```json
{ "field": "type — description" }
```

**Response (200):**
```json
{ "field": "type — description" }
```

**Error responses:** [status codes and shapes]

---

## 10. Database Design

### 10.1 Schema Changes

```sql
CREATE TABLE ... (
    ...
);
```

### 10.2 Migration Notes
[Forward/backward compatibility, data backfill, rollback strategy]

### 10.3 Indexes & Query Patterns
[Key queries and supporting indexes]

---

## 11. Frontend Design

### 11.1 Component Hierarchy
[Tree showing nesting]

### 11.2 State Management
[What state lives where — component / store / URL / server]

### 11.3 UI Specifications
[Per-component: layout, states, interactions, responsive behavior]

---

## 12. Edge Cases

| # | Scenario | Condition | Expected Behavior |
|---|----------|-----------|-------------------|
| E1 | [Name] | [Trigger] | [What happens] |

---

## 13. Configuration & Feature Flags

| Variable | Default | Purpose |
|----------|---------|---------|
| `ENV_VAR` | value | [What it controls] |

---

## 14. Testing & Verification Strategy

### 14.1 Unit Tests
[What to test, specific assertions]

### 14.2 Integration Tests
[API contract tests, DB integration]

### 14.3 End-to-End Tests
[Playwright flows, CLI verification, manual spot checks]

### 14.4 Verification Commands
[Exact commands with expected output]

---

## 15. Rollout Strategy
[Feature flags, migration order, rollback plan, graceful degradation]

---

## 16. Research Sources

| Source | Type | Key Takeaway |
|--------|------|-------------|
| [path or URL] | Existing code / External | [What we learned] |
```

### Document Guidelines (all tiers)
- Use numbered FR-XX IDs for functional requirements — they're referenced in the plan
- Sequence diagrams are REQUIRED (Tier 3) when 3+ components interact — one diagram per flow
- API contracts must show request AND response shapes AND error responses
- DB schema must show actual SQL, not prose descriptions
- Edge cases must have specific conditions and expected behaviors
- Non-goals distinguish scope exclusions from negated goals ("We won't support multi-region" is a non-goal; "the system should not crash" is NOT)
- Keep each section as concise as possible while remaining unambiguous — over-specification is an anti-pattern

---

## Phase 6: Review Loops

**Tier 1:** Run 1 review loop, then final review.

**Tier 2-3:** Run minimum 2 loops, continue until exit criteria are met.

### Two Types of Review

Each loop runs BOTH checks:

**A. Structural Checklist** (catches missing/incomplete sections):
1. Every requirement from the requirements doc mapped to a spec section?
2. API contracts have request + response + error shapes?
3. DB schema is actual SQL, not prose?
4. Sequence diagrams present for 3+ component interactions?
5. Edge cases have specific conditions + expected behavior?
6. Testing strategy has exact verification commands?
7. Verification plan is concrete enough to execute?

**B. Design-Level Self-Critique** (catches wrong/shallow decisions):
1. **Reviewer perspective:** If you were sent this document for review, what comments would you add? Read it as a critical reviewer, not the author — flag implicit decisions not in the Decision Log, vague interface contracts, missing error paths, and architectural assumptions that aren't justified.
2. Would a different engineer reading this spec ask "but what about X?" — identify the Xs.
3. Are there areas where the spec says WHAT but not HOW (or vice versa)? The spec should be prescriptive about interfaces and flexible about internals.
4. Are there cross-cutting concerns (theming, error handling, loading states, auth) that are mentioned once but affect many components?

The structural checklist catches omissions. The design critique catches shallow thinking. Both are needed — a spec can be structurally complete but architecturally weak.

### Loop Protocol

1. Run BOTH checklists above
2. Log findings in the Review Log table:
   ```
   | Loop | Findings | Changes Made |
   |------|----------|-------------|
   ```
3. **Present findings via `AskUserQuestion` — do NOT dump them as prose.** Findings shown as text force the user to hand-write dispositions; batching them as structured questions is faster, clearer, and produces a reviewable audit trail. See "Findings Presentation Protocol" below.
4. Apply the user's dispositions (Fix as proposed / Modify / Skip / Defer) — see protocol below
5. Fix issues inline — do NOT create a new file
6. Commit: `git commit -m "docs: spec review loop N for <feature>"`

### Findings Presentation Protocol

For every loop that produces findings (structural or design-critique):

1. **Group findings by category** (e.g., "Missing API error shapes", "Unclear component boundaries", "Undocumented decisions"). Small categories can be merged; never present more than 4 findings in a single batch.
2. **One question per finding** via `AskUserQuestion`. Use this shape:
   - `question`: one-sentence restatement of the finding + the proposed fix (concrete — e.g., "Add 409 response for duplicate email to POST /users" not "tighten error handling")
   - `options` (up to 4):
     - **Fix as proposed** — agent applies the stated change via `Edit`
     - **Modify** — user edits the proposal (free-form reply expected next turn)
     - **Skip** — not an issue; drop it (note briefly in Review Log)
     - **Defer** — log in Open Questions with rationale
3. **Batch up to 4 questions per `AskUserQuestion` call.** If there are more findings, issue multiple calls sequentially, one category per call.
4. **Skip `AskUserQuestion` only for findings that need open-ended input** (e.g., "what retry policy should the worker use?"). For those, ask inline as a normal follow-up after the batch — do not shoehorn into options.
5. **After dispositions arrive,** apply them in order, update the Review Log row to cite dispositions, then ask the user if they see additional gaps before declaring the loop complete.

**Platform fallback (no `AskUserQuestion`):** list findings as a numbered table with columns [Finding | Proposed Fix | Options: Fix/Modify/Skip/Defer]; ask the user to reply with the disposition numbers. Do NOT silently self-fix.

**Anti-pattern:** A wall of prose ending in "Let me know what you'd like to fix." This forces the user to re-state each finding in their reply. Always structure the ask.

**Edge cases of structured asks:** when a user reply slips outside the offered options (free-form text, a non-recommended pick that may break an invariant, or leftover findings that don't share a category), follow `../_shared/structured-ask-edge-cases.md`.

### Exit Criteria (ALL must be true)

- Every requirement from the requirements doc is covered
- Decision log has entries with rationale for every non-trivial choice
- API contracts complete with req/res/error shapes (Tier 2-3)
- Edge cases have specific conditions and behaviors
- Testing strategy has exact verification commands
- No open clarifications from user
- Last loop found only cosmetic issues
- **User has confirmed they have no further concerns** (do not self-declare exit)

---

## Phase 7: Final Review

Run one final improvement pass:

1. **Requirements coverage** — Re-read the requirements doc. Is EVERYTHING covered? List gaps.
2. **Conciseness** — Can sections be tightened without losing essence?
3. **Missing standard sections** — Any typical spec sections absent?
4. **Coherence** — Any conflicting specifications?
5. **Engineer readability** — Can a different engineer fully understand what to build, how to build it, and how to verify it?

**Share your analysis with the user BEFORE modifying anything.** Use the same `AskUserQuestion` batching as review loops (see Phase 6 Findings Presentation Protocol) — one question per final-review finding with Fix / Modify / Skip / Defer options, up to 4 per call. Do NOT declare the spec complete until the user confirms.

After final fixes, commit:
```
git add {feature_folder}/02_spec.md
git commit -m "docs: add spec for <feature>"
```

Ask the user: "I believe the spec is ready. Do you have any remaining concerns? Next options:
- `/pmos-toolkit:simulate-spec` — pressure-test the design against scenarios and adversarial failure modes before planning (recommended for Tier 2-3)
- `/pmos-toolkit:plan` — proceed directly to implementation planning"

The user's confirmation is required before declaring completion.

---

## Phase 8: Workstream Enrichment

**Skip if no workstream was loaded in Phase 0.** Otherwise, follow `_shared/pipeline-setup.md` Section C. For this skill, the signals to look for are:

- Tech stack decisions → workstream `## Tech Stack`
- Architectural constraints → workstream `## Constraints & Scars`
- Key design decisions → workstream `## Key Decisions`

This phase is mandatory whenever Phase 0 loaded a workstream — do not skip it just because the core deliverable is complete.

---

## Phase 9: Capture Learnings

**This skill is not complete until the learnings-capture process has run.** Read and follow `learnings/learnings-capture.md` (relative to the skills directory) now. Reflect on whether this session surfaced anything worth capturing — surprising behaviors, repeated corrections, non-obvious decisions. Proposing zero learnings is a valid outcome for a smooth session; the gate is that the reflection happens, not that an entry is written.

---

## Anti-Patterns (DO NOT)

- Do NOT skip the multi-role interview for Tier 2-3 — each role catches different gaps
- Do NOT write API contracts without response shapes and error responses
- Do NOT write DB schemas as prose — show actual SQL
- Do NOT write "add tests" without specifying what to test and how
- Do NOT treat verification as an afterthought — it's a core section
- Do NOT create a new spec file in each review loop — update the original
- Do NOT stop after 1 review loop for Tier 2-3 — minimum is 2
- Do NOT write decision entries without "Options Considered" and "Rationale"
- Do NOT ask questions for the sake of asking — only ask what genuinely helps
- Do NOT skip sequence diagrams for multi-component interactions (Tier 3)
- Do NOT over-specify internal implementation details — prescribe the interface, leave the internals to engineering judgment
- Do NOT combine multiple scenarios into one sequence diagram — one diagram per flow
