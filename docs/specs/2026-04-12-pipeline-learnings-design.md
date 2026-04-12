# Pipeline Learnings — Design Spec

**Date**: 2026-04-12
**Status**: Implemented

---

## Problem

Pipeline skills produce output but never improve from experience. When a skill's instructions are inadequate — missing a prompt for error contracts, not flagging migration ordering, skipping non-functional requirements — the same gap appears in every future session. Users notice the same friction repeatedly but have no mechanism to capture it so the skill adapts.

The existing `/session-log` and workstream enrichment capture project-specific context (decisions, gotchas, constraints). Neither captures **global, skill-level patterns** — the kind of insight that applies across all projects and all runs of a given skill.

## Solution

A shared `learnings-capture.md` instruction file that each pipeline skill references as its final task. It captures global patterns into a single `~/.pmos/learnings.md` file, which every skill reads at startup to inform its approach. The file self-maintains via user-approved summarization when it exceeds 300 lines.

## Design Principles

1. **Global, not project-specific**: Learnings apply across all projects and repos
2. **User-approved, never auto-written**: Every addition is shown as a diff and confirmed
3. **Zero is valid**: Smooth sessions produce no learnings — no forced capture
4. **Self-maintaining**: Summarization triggers automatically, no manual cleanup needed
5. **Organic growth**: Skills create their own sections on first write — no predefined structure
6. **First-class convention**: New skills created via `/create-skill` include learning capture by default

---

## Storage

### File location

```
~/.pmos/learnings.md
```

Global, not per-repo or per-workstream. Created on first write with a minimal header.

### File format

```markdown
# Pipeline Learnings

Global patterns and skill improvement notes captured across projects.
Keep this file under 300 lines — summarize when exceeded.

---

## /spec

- Error contract design gets skipped when the user describes only the happy path — prompt explicitly for failure modes
- For API-heavy specs, sequence diagrams catch integration gaps that prose descriptions miss

## /plan

- Always flag database migration ordering as a dependency when the spec mentions schema changes
```

### Format rules

- Flat bullets only, no nesting
- Each bullet is a global pattern, not project-specific ("our API needs X" is wrong; "APIs generally need X during spec" is right)
- No duplicates — if a learning already exists in substance, skip it
- Sections are created by skills on first write, not predefined
- New sections appended at end of file
- Section heading format: `## /skill-name`

---

## Instruction File

### Location

```
plugins/pmos-toolkit/skills/learnings/learnings-capture.md
```

A shared instruction file referenced by all pipeline skills. Contains both capture and summarization logic.

### Capture process

1. **Read** `~/.pmos/learnings.md` — create with header if it doesn't exist
2. **Check line count** — if over 300 lines, run summarization (see below) before proceeding
3. **Reflect** on the current session:
   - What went wrong or was harder than it should have been?
   - What prompting gap or missing instruction caused friction?
   - What pattern would help future runs of this skill across any project?
4. **Filter** — only keep learnings that are:
   - **Global**: Not tied to a specific project, repo, or workstream
   - **Actionable**: Specific enough to change behavior (not "be more thorough")
   - **Novel**: Not already captured in substance under this skill's section
5. **Propose** 0-3 learnings to the user:
   ```
   Based on this session, I'd add to Pipeline Learnings:

   ## /spec
   + Prompt for failure modes explicitly when user only describes happy path

   Add these learnings? (y/n/edit)
   ```
6. **If approved**: Append bullets under the `## /skill-name` section (create section if it doesn't exist)
7. **If declined or nothing to add**: "No new global learnings from this session." Move on.

### Summarization process

Triggered when line count exceeds 300, runs before appending new learnings:

1. **Read the full file**
2. **Summarize per section** — merge overlapping bullets, tighten wording, remove any that are project-specific noise. Target: reduce each section by ~40%
3. **Show the diff to the user:**
   ```
   Pipeline Learnings file is over 300 lines. Proposing a consolidation:

   ## /spec (was 12 bullets → 7)
   - [merged bullet]
   - [tightened bullet]
   - [removed: too project-specific]

   Apply consolidation? (y/n/edit)
   ```
4. **If approved**: Write the consolidated file, then proceed with appending new learnings
5. **If declined**: Append the new learning anyway — file grows past 300 temporarily, next run will re-trigger

### Summarization rules

- Runs before appending new learnings (so new entries don't get immediately summarized)
- Never delete a section entirely — keep the heading even if all bullets were consolidated
- Merge bullets that express the same insight in different words
- Remove bullets that turned out to be project-specific noise
- The user sees exactly what changes before anything is written

---

## Skill Integration

### End-of-skill task (all 7 pipeline skills)

Each skill gets a new phase after Workstream Enrichment, before the handoff to the next skill:

```markdown
## Capture Learnings (after workstream enrichment)

Follow the learning capture instructions in `learnings/learnings-capture.md`.
```

This is an explicit task in the skill's workflow — visible, not ambient.

### Startup loading (all 7 pipeline skills)

Each skill's context-loading phase gets one addition:

```markdown
Read `~/.pmos/learnings.md` and note any entries under your skill's section.
Factor these into your approach for this session.
```

This closes the feedback loop — learnings captured at the end of one session inform the start of the next.

### Skill execution order at end of pipeline skill

1. Skill's core work completes (e.g., spec written, plan committed)
2. **Task: Workstream Enrichment** — follow context-loading.md Step 4 (existing)
3. **Task: Capture Learnings** — follow learnings-capture.md (new)
4. Handoff to next skill (e.g., "shall we move to `/plan`?")

### Skills modified (7)

| Skill | Startup change | End-of-skill change |
|-------|---------------|-------------------|
| `/requirements` | Read learnings | Capture learnings |
| `/spec` | Read learnings | Capture learnings |
| `/plan` | Read learnings | Capture learnings |
| `/execute` | Read learnings | Capture learnings |
| `/verify` | Read learnings | Capture learnings |
| `/msf` | Read learnings | Capture learnings |
| `/creativity` | Read learnings | Capture learnings |

---

## `/create-skill` Integration

The `/create-skill` template includes both integration points as standard sections in any new skill it generates:

1. **At startup**: Read `~/.pmos/learnings.md` for the skill's section
2. **At end**: Follow `learnings/learnings-capture.md`

This ensures learning capture is a first-class convention — new skills get it automatically without anyone remembering to add it.

---

## Backward Compatibility

- No `~/.pmos/learnings.md` file → skills work exactly as today, learning capture step creates the file on first approved write
- Skills that don't have the integration yet → unaffected, can be updated incrementally
- No degradation if the user declines every learning proposal — the step completes silently

---

## Out of Scope for v1

- Central collection of learnings across users (telemetry) — revisit when the toolkit has enough users to make aggregate data meaningful
- A standalone `/learnings` skill for browsing or manually editing — users can read `~/.pmos/learnings.md` directly
- Skill-specific summarization strategies (e.g., different 300-line thresholds per skill)
- Automated learning extraction without user approval
