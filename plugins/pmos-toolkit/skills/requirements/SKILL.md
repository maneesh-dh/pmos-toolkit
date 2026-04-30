---
name: requirements
description: Brainstorm, shape, and create a requirements document — problem definition, high-level solution direction, user journeys, research synthesis. First stage in the requirements -> spec -> plan pipeline. Auto-tiers by scope (bug fix / enhancement / feature). Use this skill when the user says things like "I have a feature idea", "let's brainstorm", "what should we build", "define what we need", "help me figure out the requirements", or shares initial thoughts about a problem to solve.
user-invocable: true
argument-hint: "<initial thoughts or observations to seed the requirements> [--feature <slug>] [--backlog <id>]"
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
- **Task tracking:** Use your available task tracking tool (e.g., `TaskCreate`/`TaskUpdate` in Claude Code, `update_plan` in Codex, or equivalent). If none is available, announce phase transitions verbally.

---

## Backlog Bridge

This skill optionally integrates with `/backlog`. See `plugins/pmos-toolkit/skills/backlog/pipeline-bridge.md` for the full contract.

**At skill start:**
- If `--backlog <id>` was passed: load the item via `cat <repo>/backlog/items/{id}-*.md` and use its content as the seed alongside any user-provided argument. Remember `<id>` for use at the end of the skill.
- If no argument was provided AND `<repo>/backlog/items/` exists: run the auto-prompt flow per `pipeline-bridge.md`. If the user picks an item, set `<id>` and use its content as the seed.

**At skill end (after writing the requirements doc):**
- If `<id>` was set, invoke `/backlog set {id} source={doc_path}`. On failure, warn and continue.

---

## Phase 0: Load Workstream Context

Before any other work, follow the context loading instructions in `product-context/context-loading.md` (relative to the skills directory). This determines `{docs_path}` and loads workstream context if available. Use workstream context to inform brainstorming — product understanding, user segments, metrics, and constraints make requirements more grounded. Also read `~/.pmos/learnings.md` if it exists. Note any entries under `## /requirements` and factor them into your approach for this session.

**Resolve feature folder.** Follow `../_shared/feature-folder.md` with `skill_name=requirements`, `feature_arg=<value of --feature flag if provided, else empty>`, and `feature_hint=<short user-supplied feature name from the conversation>`. Use the returned folder path as `{feature_folder}` for the rest of this run. The protocol creates the folder if needed.

---

## Phase 1: Intake & Tier Detection

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
3. **Check for existing requirements.** Look in `{docs_path}/requirements/` for an existing file covering this feature.
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

**Create phase tasks** using your available task tracking tool, scaled to tier:

| Tier | Tasks to create |
|------|----------------|
| **Tier 1** | Intake, Write Document, Final Review |
| **Tier 2** | Intake, Research (Code), Research (Industry), Brainstorm, Write Document, Review Loop 1, Review Loop 2, Final Review |
| **Tier 3** | Intake, Research (Code), Research (Industry), Brainstorm, Write Document, Review Loop 1, Review Loop 2, Final Review |

Mark each task as in-progress when you start it and completed when done.

---

## Phase 2: Research (Parallel Subagents)

**Skip for Tier 1.** For Tier 2 and Tier 3, do both 1a and 1b. Tier 3 goes deeper on 1b (more sources, more alternatives).

Dispatch subagents to explore:

### 1a. Existing Implementation & Patterns
- Search the codebase for features similar to what's being described
- Read existing UI pages, API endpoints, and data models in the relevant area
- Note user flows that already exist and how adjacent features work
- Identify patterns, conventions, and constraints from the existing system

### 1b. Industry Research (Tier 2+)

Goal: avoid inventing in a vacuum. Learn from how others have solved this problem before locking in a direction.

Investigate, with named examples:
- **Competitor / peer approaches:** How do 2–4 comparable products (Linear, Stripe, Notion, GitHub, Figma, Intercom — whichever are relevant) solve this exact problem? What does their UX flow look like? What did they choose NOT to do?
- **Alternative solution shapes:** Surface at least 2–3 genuinely different approaches (not variations of one). E.g., modal vs. inline vs. dedicated page; sync vs. async; rules engine vs. ML vs. heuristics. Note tradeoffs of each.
- **Established patterns / frameworks / libraries:** Known design patterns, OSS libraries, or standards that apply (OAuth flows, CRDTs, command palettes, etc.).
- **Anti-patterns and failure modes:** What have others gotten wrong here? Post-mortems, deprecated approaches, common complaints.

Depth: Tier 2 → 2–3 competitors, 2 alternatives, brief. Tier 3 → 3–4 competitors, 3+ alternatives, deeper writeup.

Collect sources (URLs, product names, library docs, blog posts) — these go into the Research Sources table.

### Research Output

Summarize findings before asking questions. Ground the conversation in what already exists and what the industry does. Include:
- What already exists in the codebase that's relevant
- How comparable products solve this, and what alternative approaches exist (Tier 2+)
- Sources researched (to avoid duplication in future sessions)

---

## Phase 3: Collaborative Brainstorming

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

## Phase 4: Write the Document

Save to `{feature_folder}/01_requirements.md`. Overwrite if it already exists (git provides version history).

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

## Phase 5: Review Loops

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
3. **Present findings via `AskUserQuestion` — do NOT dump them as prose and wait for a free-form reply.** Findings shown as text force the user to hand-write dispositions; batching them as structured questions is faster, clearer, and produces a reviewable audit trail. See "Findings Presentation Protocol" below.
4. Apply the user's dispositions (Fix as proposed / Modify / Skip / Defer) — see protocol below
5. Fix issues inline — do NOT create a new file
6. Commit: `git commit -m "docs: requirements review loop N for <feature>"`

### Findings Presentation Protocol

For every loop that produces findings (structural or product-critique):

1. **Group findings by category** (e.g., "Missing journeys", "Unstated rationale", "Ambiguous language"). Small categories can be merged; never present more than 4 findings in a single batch.
2. **One question per finding** via `AskUserQuestion`. Use this shape:
   - `question`: one-sentence restatement of the finding + the proposed fix (concrete, not "tighten section 3")
   - `options` (up to 4):
     - **Fix as proposed** — agent applies the stated change
     - **Modify** — user edits the proposal (free-form reply expected next turn)
     - **Skip** — not an issue; drop it (note briefly in Review Log)
     - **Defer** — log in Open Questions with rationale
3. **Batch up to 4 questions per `AskUserQuestion` call.** If there are more findings, issue multiple calls sequentially, one category per call.
4. **Skip `AskUserQuestion` only for findings that need open-ended input** (e.g., "what's the right retention window?"). For those, ask inline as a normal follow-up after the batch — do not shoehorn into options.
5. **After dispositions arrive,** apply them in order, update the Review Log row to cite dispositions, then ask the user if they see additional gaps before declaring the loop complete.

**Platform fallback (no `AskUserQuestion`):** list findings as a numbered table with columns [Finding | Proposed Fix | Options: Fix/Modify/Skip/Defer]; ask the user to reply with the disposition numbers. Do NOT silently self-fix.

**Anti-pattern:** A wall of prose ending in "Let me know what you'd like to fix." This forces the user to re-state each finding in their reply. Always structure the ask.

### Exit Criteria (ALL must be true)

- No gaps vs user's input/observations
- Decision table has entries with rationale (3+ for Tier 3)
- No ambiguous language that two engineers would interpret differently
- No open clarifications from user
- Last loop found only cosmetic issues
- **User has confirmed they have no further concerns** (do not self-declare exit)

---

## Phase 6: Final Review

Run one final improvement pass:

1. **Conciseness** — Can sections be tightened without losing essence?
2. **Missing journeys** — Any user flows or edge cases not covered?
3. **Coherence** — Any conflicting requirement statements?
4. **New-person test** — Can someone new to the team understand what we're trying to achieve with no blind spots?

**Share your analysis with the user BEFORE modifying anything.** Use the same `AskUserQuestion` batching as review loops (see Phase 5 Findings Presentation Protocol) — one question per final-review finding with Fix / Modify / Skip / Defer options, up to 4 per call. Do NOT declare the requirements complete until the user confirms.

After final fixes, commit:
```
git add {feature_folder}/01_requirements.md
git commit -m "docs: add requirements for <feature>"
```

Tell the user: "Requirements captured and committed. When ready, run `/spec` to create the detailed technical specification."

**The terminal state is handoff to /spec.** Do NOT start writing a spec or implementation plan from this skill.

---

## Phase 7: Workstream Enrichment

**Skip if no workstream was loaded in Phase 0.** Otherwise, follow the enrichment instructions in `product-context/context-loading.md` Step 4. For this skill, the signals to look for are:

- User segments mentioned in the requirements → workstream `## User Segments`
- Problem statements that refine the product's purpose → workstream `## Value Proposition` or `## Description`
- Success metrics → workstream `## Key Metrics`

This phase is mandatory whenever Phase 0 loaded a workstream — do not skip it just because the core deliverable is complete.

---

## Phase 8: Capture Learnings

**This skill is not complete until the learnings-capture process has run.** Read and follow `learnings/learnings-capture.md` (relative to the skills directory) now. Reflect on whether this session surfaced anything worth capturing — surprising behaviors, repeated corrections, non-obvious decisions. Proposing zero learnings is a valid outcome for a smooth session; the gate is that the reflection happens, not that an entry is written.

---

## Anti-Patterns (DO NOT)

- Do NOT skip the research phase (Tier 2-3) — it grounds the brainstorm in reality
- Do NOT dump a checklist of questions — ask ONE at a time, follow the conversation
- Do NOT include implementation details (DB schemas, API routes, code) — that's the spec's job
- Do NOT create a new document file in each review loop — update the original
- Do NOT stop after 1 review loop for Tier 2-3 — minimum is 2
- Do NOT write decision entries without "Options Considered" and "Rationale" columns
- Do NOT skip research source tracking (Tier 2+) — future sessions need to know what was explored
- Do NOT ask questions for the sake of asking — only ask what genuinely helps shape requirements
- Do NOT use vague success metrics like "improve user experience" — be specific and measurable
- Do NOT write non-goals without a "because" reason
