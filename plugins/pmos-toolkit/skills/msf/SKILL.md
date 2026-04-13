---
name: msf
description: Evaluate requirements from an end-user perspective using Motivation, Satisfaction, and Friction analysis with PSYCH scoring. Optional enhancer for Tier 3 requirements — apply before /spec. Use when the user says "evaluate the UX", "will users actually use this", "check for friction", "user experience analysis", or wants to simulate how users will feel about the proposed solution.
user-invocable: true
argument-hint: "<path-to-requirements-doc>"
---

# MSF Analysis — Motivation, Satisfaction & Friction

Evaluate requirements by simulating end-user experience across personas and journeys. Identifies hidden friction points, motivation gaps, and satisfaction shortfalls that would otherwise surface as UX problems during implementation.

Best applied to **Tier 3 requirements** (features / product launches) after `/requirements` and before `/spec`.

```
/requirements  →  [/msf, /creativity]  →  /spec  →  /plan  →  /execute  →  /verify
                   (this skill) ↑
```

**Announce at start:** "Using the MSF skill to evaluate user motivation, friction, and satisfaction."

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No `AskUserQuestion`:** State your assumption, document it in the output, and proceed. The user reviews after completion.
- **No subagents:** Perform research and analysis sequentially as a single agent.
- **No Playwright MCP:** Note browser-based verification as a manual step for the user.

---

## Load Learnings

Read `~/.pmos/learnings.md` if it exists. Note any entries under `## /msf` and factor them into your approach for this session.

---

## Locate Requirements

Follow `../.shared/resolve-input.md` with `phase=requirements`, `label="requirements doc"`. Read the resolved file end-to-end before Phase 1.

---

## Phase 1: Identify & Align on Personas

Propose user personas (minimum 2, maximum 5) and typical usage scenarios (maximum 2 per persona — these are usage contexts, not error cases).

**Priority guidance:** Focus depth on **new users** and **power users**. Go lighter on others.

Present via AskUserQuestion for approval before proceeding. Format:

> **Proposed personas:**
> 1. **[Name]** — [role, context, goal]. Scenarios: (a) [context 1], (b) [context 2]
> 2. **[Name]** — [role, context, goal]. Scenarios: (a) [context 1], (b) [context 2]
>
> **Approve these personas, or suggest changes?**

---

## Phase 2: Identify & Confirm Journeys

List the key user journeys from the requirements that should be analyzed. Confirm the list with the user via AskUserQuestion before proceeding.

---

## Phase 3: Analyze

Use subagents to analyze each journey from the approved personas and scenarios. For each journey, perform two passes:

### Pass A: MSF Analysis

Answer each consideration question (below) for each persona + scenario + journey combination. If a question isn't applicable, say so briefly rather than skipping silently.

#### Motivation Considerations
- What is the job the user is trying to do?
- How important is the job for the user?
- How urgent is the job?
- What else could be more important or urgent for them?
- What are benefits of action to do this job?
- What are consequences if the user doesn't perform any action to fulfil this job?
- What are alternatives and how good are they?

#### Friction Considerations
- Will the user understand this product?
- When does the user need to make this decision to act?
- How complex is the decision to act or use this product?
- What is the cost of making a wrong decision?
- Do they understand what their next action is?
- How difficult is it to initiate this action?
- How difficult will they think it is to complete this action?
- What else is going on in their life or at work or in front of them?
- What do they stand to lose?
- How inconsistent is this with their expectations or habits or experiences?
- How much thought do they need to put into this before initiating action?

#### Satisfaction Considerations
- Did it fulfill the promised job?
- Did it live up to their expectations?
- Did it generate "happy hormones"?
- Did it feel reassuring?
- Did it raise their prestige, self-esteem, or security?
- Did it make them feel smart?

### Pass B: PSYCH Scoring

If wireframes are available, walk through each screen following the user's attention path (left-to-right, top-to-bottom). Score notable UI elements as +Psych or -Psych.

**+Psych (adds motivation):**
- Positive emotions: attractive visuals, social proof, credibility signals
- Motivational boosts: urgency, progress indicators, value previews, completion cues
- Rewards: immediate value delivery, clear outcomes, "aha" moments

**-Psych (drains motivation):**
- Physical effort: form fields, data entry, clicks, scrolling, waiting
- Decisions to make: choices, configurations, ambiguous options, unfamiliar terminology
- Questions to figure out: unclear UI, unknown costs, jargon, missing feedback

**Starting Psych by entry context:**
- High-intent (user chose to act): 60
- Medium-intent (exploring): 40
- Low-intent (casual/first-time): 25

Use +1 to +10 / -1 to -10 per element. Track a running total. Flag any screen dropping below 20 ("danger zone") or 0 ("bounce risk").

**Output per-journey scoring table:**

| Screen | Element | +/- Psych | Running Total | Notes |
|--------|---------|-----------|---------------|-------|

Scores are relative, not scientific. Focus on elements that stand out as clearly positive or negative. Skip neutral/expected elements.

### Parallelization

If there are multiple flows and screens, analyze each independently using subagents. Capture analysis at both journey level and aggregate level. Serialize edits to any shared file — do not have multiple agents edit the same file concurrently.

### Save Analysis

Save consolidated MSF findings and PSYCH scoring tables to `docs/msf/YYYY-MM-DD-<feature-name>-msf-analysis.md`. Commit.

---

## Phase 4: Prioritize & Agree on Recommendations

Present recommendations grouped by priority:
- **Must** — Critical friction or motivation gaps that will block adoption
- **Should** — Significant UX improvements worth the effort
- **Nice-to-Have** — Polish items that enhance but aren't essential

Each recommendation must include:
- Severity (Must / Should / Nice-to-Have)
- Affected screens/journeys
- Implementation effort (Low / Medium / High)

Let the user accept or reject each group, then drill into specific items to modify. Capture agreed recommendations in the analysis doc.

---

## Phase 5: Check Scope of Changes

Ask the user whether to update:
- (a) The requirements doc
- (b) Wireframes
- (c) Both

Only proceed with what the user approves.

**Wireframe guidance:** Update only `-final.html` wireframes (not iterations). Add visual elements for layout-affecting changes. Copy/label changes can be text annotations only.

---

## Phase 6: Consistency Pass

After any updates, run a final check:

1. Cross-reference every agreed recommendation against the revised requirements to confirm it was applied
2. Check for contradictions between sections
3. Verify wireframes match updated requirements text (if wireframes were updated)

Report any discrepancies found.

---

## Report Format

Table-heavy, minimal prose. Keep the report under 300 lines.

---

## Phase 7: Capture Learnings

**This skill is not complete until learnings are captured.** Read and follow `learnings/learnings-capture.md` (relative to the skills directory) now. Record anything that will help a future invocation of this skill go better — surprising behaviors, repeated corrections, non-obvious decisions.

---

## Anti-Patterns (DO NOT)

- Do NOT skip the persona alignment step — analyzing without confirmed personas produces generic findings
- Do NOT pad PSYCH scores — 0 ideas from a consideration is better than a forced insight
- Do NOT apply PSYCH scoring without wireframes — it requires visual walkthrough
- Do NOT modify requirements or wireframes without user approval in Phase 5
- Do NOT present recommendations as a wall of text — use tables with severity and effort
