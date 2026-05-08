# Pipeline Learnings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a feedback loop to all 7 pipeline skills that captures global, cross-project learnings into `~/.pmos/learnings.md` and reads them back at startup.

**Architecture:** A shared instruction file (`learnings/learnings-capture.md`) contains all capture and summarization logic. Each skill adds two integration points: read learnings at startup, capture learnings after workstream enrichment. The `/create-skill` template bakes both points into new skills by default.

**Tech Stack:** Markdown instruction files, no code dependencies.

**Spec:** `docs/specs/2026-04-12-pipeline-learnings-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `skills/learnings/learnings-capture.md` | Shared capture + summarization instructions |
| Modify | `skills/requirements/SKILL.md` | Add startup read + end-of-skill capture |
| Modify | `skills/spec/SKILL.md` | Add startup read + end-of-skill capture |
| Modify | `skills/plan/SKILL.md` | Add startup read + end-of-skill capture |
| Modify | `skills/execute/SKILL.md` | Add startup read + end-of-skill capture |
| Modify | `skills/verify/SKILL.md` | Add startup read + end-of-skill capture |
| Modify | `skills/msf/SKILL.md` | Add startup read + end-of-skill capture |
| Modify | `skills/creativity/SKILL.md` | Add startup read + end-of-skill capture |
| Modify | `skills/create-skill/SKILL.md` | Add learning integration to conventions |

All paths relative to `plugins/pmos-toolkit/`.

**Done when:** All 7 skills read `~/.pmos/learnings.md` at startup and offer to capture learnings at the end. `/create-skill` includes both integration points in its conventions. The shared instruction file handles capture, deduplication, and summarization.

---

### Task 1: Create the shared learnings-capture.md instruction file

**Files:**
- Create: `plugins/pmos-toolkit/skills/learnings/learnings-capture.md`

- [ ] **Step 1: Create the learnings directory and instruction file**

```markdown
# Learning Capture Instructions

Reference document for pipeline skills. Follow these steps at the END of every pipeline skill, after workstream enrichment and before the handoff to the next skill.

---

## Step 1: Read or Create the Learnings File

1. Check if `~/.pmos/learnings.md` exists
2. **If not found:** Create it with this header:

```markdown
# Pipeline Learnings

Global patterns and skill improvement notes captured across projects.
Keep this file under 300 lines — summarize when exceeded.

---
```

3. **If found:** Read the full file

---

## Step 2: Check Line Count and Summarize if Needed

If the file exceeds 300 lines, run summarization **before** appending new learnings:

1. Read the full file
2. Summarize per section — merge overlapping bullets, tighten wording, remove any that are project-specific noise. Target: reduce each section by ~40%
3. Show the diff to the user:

```
Pipeline Learnings file is over 300 lines. Proposing a consolidation:

## /spec (was 12 bullets → 7)
- [merged bullet]
- [tightened bullet]
- [removed: too project-specific]

Apply consolidation? (y/n/edit)
```

4. **If approved:** Write the consolidated file
5. **If declined:** Proceed anyway — file grows past 300 temporarily, next run will re-trigger

**Summarization rules:**
- Never delete a section entirely — keep the heading even if all bullets were consolidated
- Merge bullets that express the same insight in different words
- Remove bullets that turned out to be project-specific noise
- The user sees exactly what changes before anything is written

---

## Step 3: Reflect and Propose Learnings

1. Reflect on the current session:
   - What went wrong or was harder than it should have been?
   - What prompting gap or missing instruction in this skill caused friction?
   - What pattern would help future runs of this skill across any project?

2. Filter — only keep learnings that are:
   - **Global**: Not tied to a specific project, repo, or workstream
   - **Actionable**: Specific enough to change behavior (not "be more thorough")
   - **Novel**: Not already captured in substance under this skill's section in the learnings file

3. Propose 0-3 learnings to the user:

```
Based on this session, I'd add to Pipeline Learnings:

## /skill-name
+ Prompt for failure modes explicitly when user only describes happy path

Add these learnings? (y/n/edit)
```

4. **If approved:** Append bullets under the `## /skill-name` section. If the section doesn't exist, create it at the end of the file.
5. **If declined or nothing to add:** "No new global learnings from this session." Move on to the handoff.

**Rules:**
- Proposing 0 learnings is fine and expected for smooth sessions — do not force capture
- Never auto-write — always show the user what you'd add
- Each bullet should make sense to someone who wasn't in this session
- The learning targets the skill's instructions, not the user's project
- Flat bullets only, no nesting
```

- [ ] **Step 2: Verify the file was created correctly**

```bash
cat plugins/pmos-toolkit/skills/learnings/learnings-capture.md | head -5
```

Expected: The file header "# Learning Capture Instructions" is present.

- [ ] **Step 3: Commit**

```bash
git add plugins/pmos-toolkit/skills/learnings/learnings-capture.md
git commit -m "feat: add shared learnings-capture instruction file"
```

---

### Task 2: Add learning integration to the 5 core pipeline skills (requirements, spec, plan, execute, verify)

These 5 skills share the same pattern: they have Phase 0 context loading and Workstream Enrichment.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/requirements/SKILL.md:33-35` (startup), `plugins/pmos-toolkit/skills/requirements/SKILL.md:407-415` (end)
- Modify: `plugins/pmos-toolkit/skills/spec/SKILL.md:30-32` (startup), `plugins/pmos-toolkit/skills/spec/SKILL.md:513-520` (end)
- Modify: `plugins/pmos-toolkit/skills/plan/SKILL.md:30-32` (startup), `plugins/pmos-toolkit/skills/plan/SKILL.md:370-375` (end)
- Modify: `plugins/pmos-toolkit/skills/execute/SKILL.md:26-28` (startup), `plugins/pmos-toolkit/skills/execute/SKILL.md:224-228` (end)
- Modify: `plugins/pmos-toolkit/skills/verify/SKILL.md:49-51` (startup), `plugins/pmos-toolkit/skills/verify/SKILL.md:298` (end)

- [ ] **Step 1: Add startup learnings read to all 5 core skills**

For each of the 5 skills, append to the Phase 0 section (after the context-loading paragraph, before the `---` separator):

```markdown
Also read `~/.pmos/learnings.md` if it exists. Note any entries under this skill's section (`## /skill-name`) and factor them into your approach for this session.
```

The exact Phase 0 text for each skill currently ends with a sentence like "Use workstream context to inform..." — add the learnings line after that sentence, within the same Phase 0 section.

**requirements** Phase 0 currently:
```
## Phase 0: Load Workstream Context

Before any other work, follow the context loading instructions in `product-context/context-loading.md` (relative to the skills directory). This determines `{docs_path}` and loads workstream context if available. Use workstream context to inform brainstorming — product understanding, user segments, metrics, and constraints make requirements more grounded.
```

Add after "more grounded.":
```
Also read `~/.pmos/learnings.md` if it exists. Note any entries under `## /requirements` and factor them into your approach for this session.
```

**spec** — add after "shape architecture choices.":
```
Also read `~/.pmos/learnings.md` if it exists. Note any entries under `## /spec` and factor them into your approach for this session.
```

**plan** — read Phase 0 to find the ending sentence, then add:
```
Also read `~/.pmos/learnings.md` if it exists. Note any entries under `## /plan` and factor them into your approach for this session.
```

**execute** — add after Phase 0's ending sentence:
```
Also read `~/.pmos/learnings.md` if it exists. Note any entries under `## /execute` and factor them into your approach for this session.
```

**verify** — add after Phase 0's ending sentence:
```
Also read `~/.pmos/learnings.md` if it exists. Note any entries under `## /verify` and factor them into your approach for this session.
```

- [ ] **Step 2: Add Capture Learnings section to all 5 core skills**

For each skill, add a new section **after** the Workstream Enrichment section and **before** the Anti-Patterns section:

```markdown
---

## Capture Learnings (after workstream enrichment)

Follow the learning capture instructions in `learnings/learnings-capture.md` (relative to the skills directory).
```

Insertion points:
- **requirements**: After line 415 (end of Workstream Enrichment), before line 417 (Anti-Patterns)
- **spec**: After line 520 (end of Workstream Enrichment), before line 523 (Anti-Patterns)
- **plan**: After line 375 (end of Workstream Enrichment), before line 379 (Anti-Patterns)
- **execute**: After line 228 (end of Workstream Enrichment), before line 232 (Anti-Patterns)
- **verify**: After line 298 (end of Phase 8: Commit & Report), before line 301 (Evidence Standards). Note: verify has no Workstream Enrichment section, so insert after the commit/report phase.

- [ ] **Step 3: Verify all 5 skills have both integration points**

```bash
grep -l "learnings.md" plugins/pmos-toolkit/skills/requirements/SKILL.md plugins/pmos-toolkit/skills/spec/SKILL.md plugins/pmos-toolkit/skills/plan/SKILL.md plugins/pmos-toolkit/skills/execute/SKILL.md plugins/pmos-toolkit/skills/verify/SKILL.md
```

Expected: All 5 files listed.

```bash
grep -c "learnings" plugins/pmos-toolkit/skills/requirements/SKILL.md plugins/pmos-toolkit/skills/spec/SKILL.md plugins/pmos-toolkit/skills/plan/SKILL.md plugins/pmos-toolkit/skills/execute/SKILL.md plugins/pmos-toolkit/skills/verify/SKILL.md
```

Expected: Each file has at least 2 matches (one startup, one capture).

- [ ] **Step 4: Commit**

```bash
git add plugins/pmos-toolkit/skills/requirements/SKILL.md plugins/pmos-toolkit/skills/spec/SKILL.md plugins/pmos-toolkit/skills/plan/SKILL.md plugins/pmos-toolkit/skills/execute/SKILL.md plugins/pmos-toolkit/skills/verify/SKILL.md
git commit -m "feat: add learning capture to core pipeline skills (requirements, spec, plan, execute, verify)"
```

---

### Task 3: Add learning integration to the 2 enhancer skills (msf, creativity)

These skills have no Phase 0 context loading and no Workstream Enrichment. They need standalone integration points.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/msf/SKILL.md:28-30` (startup), `plugins/pmos-toolkit/skills/msf/SKILL.md:173-182` (end)
- Modify: `plugins/pmos-toolkit/skills/creativity/SKILL.md:24-28` (startup), `plugins/pmos-toolkit/skills/creativity/SKILL.md:140-150` (end)

- [ ] **Step 1: Add startup learnings read to both enhancer skills**

For both msf and creativity, add a new section after the Platform Adaptation section and before Phase 1:

```markdown
---

## Load Learnings

Read `~/.pmos/learnings.md` if it exists. Note any entries under `## /skill-name` and factor them into your approach for this session.
```

**msf**: Insert after line 27 (end of Platform Adaptation), before line 30 (Phase 1).
**creativity**: Insert after line 27 (end of Platform Adaptation), before line 30 (Phase 1).

Use the correct skill name in each (`## /msf` and `## /creativity` respectively).

- [ ] **Step 2: Add Capture Learnings section to both enhancer skills**

For both skills, add a new section **after** the last substantive phase (Phase 6: Consistency Pass / Report Format) and **before** the Anti-Patterns section:

**msf**: Insert after line 173 (end of Report Format section), before line 175 (Anti-Patterns):

```markdown
---

## Capture Learnings (after consistency pass)

Follow the learning capture instructions in `learnings/learnings-capture.md` (relative to the skills directory).
```

**creativity**: Insert after line 139 (end of Phase 6), before line 142 (Anti-Patterns):

```markdown
---

## Capture Learnings (after consistency pass)

Follow the learning capture instructions in `learnings/learnings-capture.md` (relative to the skills directory).
```

- [ ] **Step 3: Verify both skills have both integration points**

```bash
grep -c "learnings" plugins/pmos-toolkit/skills/msf/SKILL.md plugins/pmos-toolkit/skills/creativity/SKILL.md
```

Expected: Each file has at least 2 matches.

- [ ] **Step 4: Commit**

```bash
git add plugins/pmos-toolkit/skills/msf/SKILL.md plugins/pmos-toolkit/skills/creativity/SKILL.md
git commit -m "feat: add learning capture to enhancer skills (msf, creativity)"
```

---

### Task 4: Update /create-skill to include learning integration in new skills

**Files:**
- Modify: `plugins/pmos-toolkit/skills/create-skill/SKILL.md:86-97` (after Convention 4), `plugins/pmos-toolkit/skills/create-skill/SKILL.md:115-129` (checklist)

- [ ] **Step 1: Add Convention 6: Learning Integration**

Insert a new section after Convention 5 (Standard Frontmatter, line 112) and before the Checklist (line 115):

```markdown
---

## Convention 6: Learning Integration

Every pipeline skill MUST include two learning integration points:

**At startup** (in Phase 0 or as a standalone section after Platform Adaptation):

```markdown
Read `~/.pmos/learnings.md` if it exists. Note any entries under `## /skill-name` and factor them into your approach for this session.
```

**At end** (after the skill's core work and workstream enrichment, before Anti-Patterns):

```markdown
## Capture Learnings (after workstream enrichment)

Follow the learning capture instructions in `learnings/learnings-capture.md` (relative to the skills directory).
```

This ensures new skills participate in the global feedback loop from day one.
```

- [ ] **Step 2: Add learning checklist items**

Add two items to the "Checklist Before Saving" section:

```markdown
- [ ] Learning read at startup (Phase 0 or standalone Load Learnings section)
- [ ] Capture Learnings section at end (references `learnings/learnings-capture.md`)
```

Insert after the existing `- [ ] Anti-patterns section present` line (currently the last item).

- [ ] **Step 3: Verify changes**

```bash
grep -c "learnings" plugins/pmos-toolkit/skills/create-skill/SKILL.md
```

Expected: At least 4 matches (Convention 6 heading, startup code block, end code block, checklist items).

- [ ] **Step 4: Commit**

```bash
git add plugins/pmos-toolkit/skills/create-skill/SKILL.md
git commit -m "feat: add learning integration convention to create-skill template"
```

---

### Task 5: Update spec to mark as implemented

**Files:**
- Modify: `docs/specs/2026-04-12-pipeline-learnings-design.md:3`

- [ ] **Step 1: Update status**

Change `**Status**: Draft` to `**Status**: Implemented`.

- [ ] **Step 2: Commit**

```bash
git add docs/specs/2026-04-12-pipeline-learnings-design.md docs/plans/2026-04-12-pipeline-learnings-plan.md
git commit -m "docs: mark pipeline learnings spec as implemented, add plan"
```
