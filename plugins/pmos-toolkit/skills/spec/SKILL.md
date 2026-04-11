---
name: spec
description: Create a detailed technical specification from a requirements document — architecture, API contracts, DB schema, frontend design, testing strategy, verification plan. Second stage in the requirements -> spec -> plan pipeline. Auto-tiers by scope. Use when the user says "write the technical design", "design the system", "create the spec", "how should this work technically", or has a requirements doc ready for detailed design.
user-invocable: true
argument-hint: "<path-to-requirements-doc or requirements text>"
---

# Technical Specification Generator

Create a comprehensive technical specification from a requirements document. The spec defines HOW we're building it — architecture, API contracts, database design, frontend components, and verification strategy. This is the SECOND stage in a 3-stage pipeline:

```
/requirements  →  [/msf, /creativity]  →  /spec  →  /plan  →  /execute  →  /verify
                   optional enhancers     (this skill)
```

A spec is prescriptive about WHAT and WHY, but leaves room for engineering judgment on internal implementation details. It should be detailed enough that a competent engineer with subject expertise could implement it from the doc alone.

**Announce at start:** "Using the spec skill to create a detailed technical specification."

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No `AskUserQuestion`:** State your assumption, document it in the output, and proceed. The user reviews after completion.
- **No subagents:** Perform research and analysis sequentially as a single agent.
- **No Playwright MCP:** Note browser-based verification as a manual step for the user.

---

## Phase 0: Load Workstream Context

Before any other work, follow the context loading instructions in `context/context-loading.md` (relative to the skills directory). This determines `{docs_path}` and loads workstream context if available. Use workstream context to inform technical decisions — product constraints, tech stack, and stakeholder concerns shape architecture choices.

---

## Phase 1: Intake & Tier Detection

1. **Locate the requirements.** If the user passed an argument, use it. Otherwise check `{docs_path}/requirements/` for a recent file. If nothing found, ask.
2. **Read the requirements end-to-end.** Confirm understanding with the user — summarize the problem, goals, non-goals, and key decisions already made.
3. **Check for existing spec.** Look in `{docs_path}/specs/` for an existing file.
   - If found: read it, ask the user if this is an update or fresh start.
   - If not found: proceed.
4. **Detect the tier** from the requirements doc (carry forward the same tier if tagged, otherwise assess):

| Tier | Scope | Sections | Length |
|------|-------|----------|--------|
| **Tier 1: Bug Fix / Minor Enhancement** | Isolated fix or small change | Problem, Root Cause Analysis, Fix Approach, Edge Cases, Testing Strategy | ~1-2 pages |
| **Tier 2: Enhancement / UX Overhaul** | Improving existing behavior, adding to existing surface | Problem, Goals, Decision Log, Relevant FR tables, API changes (if any), Frontend Design (if any), Edge Cases, Testing Strategy | ~3-6 pages |
| **Tier 3: Feature / New System** | New capability, new surface, major redesign | ALL sections mandatory including Architecture diagrams, Sequence diagrams, Full FR/NFR tables, API contracts, DB schema (SQL), Frontend design, Feature flags, Rollout strategy | ~6-15 pages |

**Announce:** "This looks like a Tier N spec. Using the [tier name] template."

**Gate:** Do not proceed until you have confirmed understanding of the requirements and the tier.

---

## Phase 2: Research (Parallel Subagents)

**Tier 1:** Read the specific files/functions involved in the bug. No broader research needed.

**Tier 2-3:** Dispatch subagents to explore:

### 1a. Existing Implementation & Patterns
- Read the codebase areas that will be impacted
- Note current architecture patterns, data models, API conventions
- Read test patterns used in adjacent features
- Identify reusable components, utilities, and infrastructure

### 1b. Industry Research (Tier 3 only)
- Research frameworks, libraries, and design patterns relevant to the technical approach
- Look for established solutions to the problems being solved
- Collect recommendations with sources

Track all sources in a Research Sources table.

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

**Trigger heuristic:** if the feature mentions search, index, sync, export, import, process, queue, cache, or aggregate — run the trace. Skip for purely CRUD or purely UI features.

**When to adjust:** If the project is primarily a frontend/UX change with minimal backend work, move Designer to position 2 (before DBA) — the UX may drive what data needs to be stored. State your reordering rationale when you announce the first role.

For Tier 2 (2-3 roles), pick from this list in order — don't jump to role 5 while skipping role 2.

### Role Protocol (MANDATORY for Tier 2-3)

**Every applicable role MUST be announced to the user**, even when you have no questions. This ensures the user can verify that all perspectives were considered.

For each role:
1. **Announce:** "Speaking as [Role]:"
2. **Either:**
   - Ask 1-2 specific questions via AskUserQuestion (preferred when genuine gaps exist)
   - **OR** state explicitly: "No questions from this role — [specific reason, citing which requirements sections already cover the role's concerns]"
3. Note answers or stated assumptions as decisions for the spec

**Anti-pattern:** Silently skipping a role because "the requirements are detailed enough" — this denies the user visibility into which perspectives were evaluated. The "Skip if..." column in the table above is the ONLY valid reason to skip a role entirely without announcement. If a role is applicable (not in the "Skip if" condition), you MUST announce it.

---

## Phase 4: Think Hard About Verification

Before writing the spec, think creatively about how to verify the implementation. This is a CORE part of the spec, not an afterthought.

Good verification patterns:
- Automated unit + integration tests with specific assertions
- CLI scripts to verify APIs before building frontend
- Playwright MCP for end-to-end frontend flow testing
- Linting and static analysis checks
- Synthetic data scenarios that exercise edge cases
- Before/after comparison reports

For each major feature area, define HOW it will be verified.

---

## Phase 5: Write the Spec

Save to `{docs_path}/specs/YYYY-MM-DD-<feature-name>-spec.md`. Create the directory if it doesn't exist.

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

## 4. Edge Cases

| # | Scenario | Condition | Expected Behavior |
|---|----------|-----------|-------------------|
| E1 | [Name] | [Trigger] | [What happens] |

## 5. Testing Strategy
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

## 11. Open Questions

| # | Question | Owner | Needed By |
|---|----------|-------|-----------|
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

---

## 17. Open Questions

| # | Question | Owner | Needed By |
|---|----------|-------|-----------|
| 1 | [Unresolved decision] | [name] | [date or "before plan"] |
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
3. **Present findings to the user BEFORE making changes** — share what you found, what you plan to fix, and ask if the user sees additional gaps. Do NOT silently self-fix and move on. The review loop is a collaborative checkpoint, not a self-assessment.
4. Use AskUserQuestion if findings need user input
5. Fix issues inline — do NOT create a new file
6. Commit: `git commit -m "docs: spec review loop N for <feature>"`

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

**Share your analysis with the user BEFORE modifying anything.** Ask for confirmation on what needs to be fixed. Do NOT declare the spec complete until the user confirms.

After final fixes, commit:
```
git add {docs_path}/specs/<file>
git commit -m "docs: add spec for <feature>"
```

Ask the user: "I believe the spec is ready. Do you have any remaining concerns, or shall we move to `/plan`?" — the user's confirmation is required before declaring completion.

---

## Workstream Enrichment (after final review)

If a workstream was loaded in Phase 0, follow the enrichment instructions in `context/context-loading.md` Step 4. For this skill, the signals to look for are:

- Tech stack decisions → workstream `## Tech Stack`
- Architectural constraints → workstream `## Constraints & Scars`
- Key design decisions → workstream `## Key Decisions`

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
