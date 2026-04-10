---
name: requirements
description: Brainstorm, shape, and create a requirements document — problem definition, high-level solution direction, user journeys, research synthesis. First stage in the requirements -> spec -> plan pipeline. Auto-tiers by scope (bug fix / enhancement / feature). Use this skill when the user says things like "I have a feature idea", "let's brainstorm", "what should we build", "define what we need", "help me figure out the requirements", or shares initial thoughts about a problem to solve.
user-invocable: true
argument-hint: "<initial thoughts or observations to seed the requirements>"
---

# Requirements Document Generator

Brainstorm with the user, research existing patterns, and produce a requirements document that defines the **problem** and **high-level solution direction**. This is the FIRST stage in a 3-stage pipeline:

```
/requirements  →  [/msf, /creativity]  →  /spec  →  /plan  →  /execute  →  /verify
 (this skill)      optional enhancers
```

A requirements doc answers "What are we building and why?" — it contains ZERO implementation details. No database schemas, no API contracts, no code. Those belong in the spec.

**The acid test:** Could a product designer read every sentence and use it to evaluate design options? If not, it's implementation detail and doesn't belong here.

**Announce at start:** "Using the requirements skill to brainstorm and create a requirements document."

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No `AskUserQuestion`:** State your assumption, document it in the output, and proceed. The user reviews after completion.
- **No subagents:** Perform research and analysis sequentially as a single agent.
- **No Playwright MCP:** Note browser-based verification as a manual step for the user.

---

## Phase 0: Intake & Tier Detection

### Determine Input Mode

The user's input can take several forms. Handle each differently:

| Input Mode | What you receive | How to proceed |
|------------|-----------------|----------------|
| **Raw thoughts** | Rough observations, a problem statement, or scattered ideas | Full brainstorm flow (Phase 1-2) |
| **Existing doc update** | Path to an existing requirements doc + new observations | Read the doc, summarize what's there, ask if this is an update or extension, then brainstorm only the delta |
| **Multiple text inputs** | Several pasted texts, screenshots, or references | Synthesize all inputs into a coherent problem statement first, then confirm understanding before brainstorming |
| **Spec or detailed brief** | Already well-formed requirements that need shaping | Skip deep brainstorming, focus on gap analysis and structuring into the template |

### Steps

1. **Read the user's input.** If the argument is unclear about which product/service/surface the requirements concern, use AskUserQuestion to clarify upfront — do not guess.
2. **Scope check.** If the input describes multiple independent subsystems (e.g., "build X with chat, billing, analytics, and admin"), flag this immediately. Don't spend questions refining details of a project that needs decomposition first. Help the user break it into independent sub-requirements, each getting its own requirements doc.
3. **Check for existing requirements.** Look in `docs/requirements/` for an existing file covering this feature.
   - If found: read it, summarize what's there, ask the user if this is an update or fresh start.
   - If not found: proceed.
4. **Detect the tier** based on the nature of the work:

| Tier | Scope | Sections | Length |
|------|-------|----------|--------|
| **Tier 1: Bug / Minor Fix** | Isolated defect or small correction | Problem, Root Cause, Fix Direction, Acceptance Criteria | ~0.5-1 page |
| **Tier 2: Enhancement / UX Fix** | Improving existing behavior or adding to existing surface | Problem, Goals, Non-Goals, Solution Direction, User Journeys, Design Decisions, Open Questions | ~1-2 pages |
| **Tier 3: Feature / Product Launch** | New capability, new surface, or major redesign | ALL sections mandatory including UX Analysis, Success Metrics, Research Sources, detailed User Journeys | ~2-4 pages |

**Announce:** "This looks like a Tier N requirement ([type]). Using the [tier name] template."

The user can override the tier. If unsure, ask.

**Gate:** Do not proceed until you understand (a) what product/service area the requirements target and (b) the tier.

---

## Phase 1: Research (Parallel Subagents)

**Skip for Tier 1.** For Tier 2, do 1a only. For Tier 3, do both.

Dispatch subagents to explore:

### 1a. Existing Implementation & Patterns
- Search the codebase for features similar to what's being described
- Read existing UI pages, API endpoints, and data models in the relevant area
- Note user flows that already exist and how adjacent features work
- Identify patterns, conventions, and constraints from the existing system

### 1b. Industry Research (Tier 3 only)
- Research useful practices, patterns, frameworks, and libraries related to the stated requirements
- Look for how other products solve similar problems
- Identify approaches that could be adopted or adapted
- Collect sources (URLs, library names, framework docs)

### Research Output

Summarize findings before asking questions. Ground the conversation in what already exists and what the industry does. Include:
- What already exists in the codebase that's relevant
- What industry patterns/tools could apply (Tier 3)
- Sources researched (to avoid duplication in future sessions)

---

## Phase 2: Collaborative Brainstorming

Act as a **product director** and **senior analyst**. Use AskUserQuestion to ask questions — batch related questions into a single call (up to 4), but follow the natural conversation flow. Do not dump an unfocused checklist.

**Key brainstorming principles (borrowed from Shape Up and Continuous Discovery):**
- **One question at a time** — don't overwhelm with multiple questions per message
- **Prefer multiple choice** when possible — easier for the user to answer than open-ended. Offer 2-4 options with your recommendation marked.
- **Propose 2-3 approaches** before settling on a solution direction — present trade-offs and your recommendation. Lead with the recommended option and explain why.
- **Incremental validation** — for Tier 3, present each section of the solution direction and get approval before moving on. Don't write the full doc then ask "does this look right?"
- **State assumptions** rather than asking obvious questions. Do NOT ask questions for the sake of asking.

### Problem & Users
- What specific problem does this solve? Who experiences it? (Be concrete — not "users are frustrated" but "agents who search for an issue can't find it because the search vocabulary doesn't match their mental model")
- User personas — who are they, what's their context, what's their goal?
- Current workaround and its pain points
- Why now? What changed that makes this important?

### Solution Direction
- Propose 2-3 approaches with trade-offs and your recommendation
- What are the key user journeys for the recommended approach?
- What's explicitly out of scope and why?

### User Motivation, Friction & Satisfaction (Tier 2-3)

Pick the relevant lenses — don't ask all of these, only what's relevant:

**Motivation** — Why would the user act? What job are they doing? What's the cost of NOT doing it? What alternatives exist?

**Friction** — What could stop them? Will they understand what this does at first glance? How complex is the decision? What's the perceived effort? What could they lose?

**Satisfaction** — Does it fulfill the promised job? Does it meet or exceed expectations? Does it feel reassuring?

### Decision Points
Surface decisions that need to be made NOW (before spec). For each:
- What are the options?
- What are the trade-offs?
- What do you recommend and why?

**Stop interviewing when you have enough to write a complete document.**

---

## Phase 3: Write the Document

Save to `docs/requirements/YYYY-MM-DD-<feature-name>.md`.

Use the template matching the detected tier. Delete sections marked "skip" for that tier.

### Tier 1 Template: Bug / Minor Fix

```markdown
# <Bug/Fix Name> — Requirements

**Date:** YYYY-MM-DD
**Status:** Draft
**Tier:** 1 — Bug Fix

## Problem
[2-4 sentences. What's broken, what's the impact.]

### Who experiences this?
[User role + context]

### Reproduction / Root Cause
[How to reproduce. What's causing it if known.]

## Fix Direction
[High-level approach to fixing it. Not the code — the strategy.]

## Acceptance Criteria
- [ ] [Specific, testable criterion 1]
- [ ] [Specific, testable criterion 2]
```

### Tier 2 Template: Enhancement / UX Fix

```markdown
# <Feature Name> — Requirements

**Date:** YYYY-MM-DD
**Status:** Draft
**Tier:** 2 — Enhancement

## Problem
[2-4 sentences. Specific user pain or gap.]

### Who & Why Now
[Persona + trigger for this work]

## Goals & Non-Goals

### Goals
- [Observable user outcome 1]
- [Observable user outcome 2]

### Non-Goals
- NOT doing [X] because [reason]

## Solution Direction
[High-level approach. ASCII diagrams where useful.]

## User Journeys

### Primary Journey
[Step-by-step from entry point to completion]

### Error / Edge Cases
[What goes wrong, what the user sees]

## Design Decisions

| # | Decision | Options Considered | Rationale |
|---|----------|-------------------|-----------|
| D1 | [What was decided] | (a) ..., (b) ... | [Why] |

## Open Questions

| # | Question | Owner | Needed By |
|---|----------|-------|-----------|
| 1 | [Unresolved decision] | [name] | [date] |
```

### Tier 3 Template: Feature / Product Launch

```markdown
# <Feature Name> — Requirements

**Date:** YYYY-MM-DD
**Status:** Draft
**Tier:** 3 — Feature

## Problem
[2-4 sentences. Specific user pain or gap. No solution language.]

### Who experiences this?
[User role/persona + context. Be specific.]

### Why now?
[What changed that makes this a priority?]

## Goals & Non-Goals

### Goals
- [Observable user outcome 1] — measured by [metric]
- [Observable user outcome 2] — measured by [metric]

### Non-Goals (explicit scope cuts)
- NOT doing [X] in this iteration because [reason]
- NOT solving [adjacent problem] because [reason]

## User Experience Analysis

### Motivation
- **Job to be done:** [What the user is trying to accomplish]
- **Importance/Urgency:** [How critical? What happens if they don't do it?]
- **Alternatives:** [What else could they do? How does this compare?]

### Friction Points

| Friction Point | Cause | Mitigation |
|---------------|-------|------------|
| [e.g., "Will I lose my data?"] | [Uncertainty about save] | [Auto-save + confirmation] |

### Satisfaction Signals
- [How we know the user feels good about the experience]

## Solution Direction
[High-level approach. ASCII diagrams or wireframe links where useful.]

## User Journeys

### Primary Journey (Happy Path)
[Numbered steps. Each step = user action + system response.]

### Alternate Journeys
[Valid variations — user takes different route]

### Error Journeys
[What goes wrong. What the user sees. What they can do.]

### Empty States & Edge Cases

| Scenario | Condition | Expected Behavior |
|----------|-----------|-------------------|
| [name] | [trigger] | [what user sees] |

## Design Decisions

| # | Decision | Options Considered | Rationale |
|---|----------|-------------------|-----------|
| D1 | [What was decided] | (a) ..., (b) ..., (c) ... | [Why — include trade-offs] |

## Success Metrics

| Metric | Baseline | Target | Measurement |
|--------|----------|--------|-------------|
| [e.g., AHT for issue selection] | [current] | [goal] | [how measured] |

## Research Sources

| Source | Type | Key Takeaway |
|--------|------|-------------|
| [file path or URL] | Existing code / External | [What we learned] |

## Open Questions

| # | Question | Owner | Needed By |
|---|----------|-------|-----------|
| 1 | [Unresolved decision] | [name] | [date or "before spec"] |
```

### Document Guidelines (all tiers)
- Scannable — bullet points over paragraphs
- User-perspective language — "the agent sees X", not "the system stores Y"
- Link to wireframes/screenshots rather than describing visual design in prose
- No implementation details — no DB schemas, no API routes, no code snippets
- Bold the key constraint or decision in each paragraph — readers scan, they don't read linearly
- One requirement per bullet — if it needs a paragraph, it's multiple requirements
- Non-goals MUST include a "because" reason — naked exclusions invite re-litigation

---

## Phase 4: Review Loops

After writing the initial document, run iterative review loops.

**Tier 1:** Run 1 review loop (quick pass), then the final review. No Review Log table needed.

**Tier 2-3:** Run minimum 2 loops, continue until exit criteria are met.

### Two Types of Review

Each loop runs BOTH checks:

**A. Structural Checklist** (catches missing/incomplete sections):
1. Every user journey walked through (happy path + errors + empty states)?
2. Edge cases and error states covered?
3. Non-goals explicitly stated with reasons?
4. Decisions have options considered + rationale?
5. No implementation details leaking in?
6. New-person readability test — can someone unfamiliar understand what we're building?

**B. Product-Level Self-Critique** (catches shallow/incomplete thinking):
1. **Reviewer perspective:** If you were sent this document for review, what comments would you add? Read it as a critical reviewer, not the author — flag vague language, missing rationale, unstated assumptions, and gaps between steps.
2. For each user journey — is there a moment where the user would feel confused, stuck, or unsure what to do next? Are there gaps between steps that assume the user "just knows"?
3. Are there competing priorities or tensions in the requirements that haven't been acknowledged? (e.g., "simple onboarding" vs. "highly configurable" — which wins when they conflict?)
4. Would a skeptical stakeholder ask "why not just do X instead?" — are those alternatives addressed?

### Loop Protocol

1. Run BOTH checklists above
2. Log findings in the Review Log table (Tier 2-3):
   ```
   | Loop | Findings | Changes Made |
   |------|----------|-------------|
   ```
3. **Present findings to the user BEFORE making changes** — share what you found, what you plan to fix, and ask if the user sees additional gaps. Do NOT silently self-fix and move on. The review loop is a collaborative checkpoint, not a self-assessment.
4. Use AskUserQuestion if findings need user input
5. Fix issues inline — do NOT create a new file
6. Commit: `git commit -m "docs: requirements review loop N for <feature>"`

### Exit Criteria (ALL must be true)

- No gaps vs user's input/observations
- Decision table has entries with rationale (3+ for Tier 3)
- No ambiguous language that two engineers would interpret differently
- No open clarifications from user
- Last loop found only cosmetic issues
- **User has confirmed they have no further concerns** (do not self-declare exit)

---

## Phase 5: Final Review

Run one final improvement pass:

1. **Conciseness** — Can sections be tightened without losing essence?
2. **Missing journeys** — Any user flows or edge cases not covered?
3. **Coherence** — Any conflicting requirement statements?
4. **New-person test** — Can someone new to the team understand what we're trying to achieve with no blind spots?

**Share your analysis with the user BEFORE modifying anything.** Ask for confirmation on what needs to be fixed. Do NOT declare the requirements complete until the user confirms.

After final fixes, commit:
```
git add docs/requirements/<file>
git commit -m "docs: add requirements for <feature>"
```

Tell the user: "Requirements captured and committed. When ready, run `/spec` to create the detailed technical specification."

**The terminal state is handoff to /spec.** Do NOT start writing a spec or implementation plan from this skill.

---

## Anti-Patterns (DO NOT)

- Do NOT skip the research phase (Tier 2-3) — it grounds the brainstorm in reality
- Do NOT dump a checklist of questions — ask ONE at a time, follow the conversation
- Do NOT include implementation details (DB schemas, API routes, code) — that's the spec's job
- Do NOT create a new document file in each review loop — update the original
- Do NOT stop after 1 review loop for Tier 2-3 — minimum is 2
- Do NOT write decision entries without "Options Considered" and "Rationale" columns
- Do NOT skip research source tracking (Tier 3) — future sessions need to know what was explored
- Do NOT ask questions for the sake of asking — only ask what genuinely helps shape requirements
- Do NOT use vague success metrics like "improve user experience" — be specific and measurable
- Do NOT write non-goals without a "because" reason
