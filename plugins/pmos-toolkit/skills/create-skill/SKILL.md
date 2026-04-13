---
name: create-skill
description: Create a new skill in the user's agent-skills repo with cross-platform compatibility and proper conventions. Wraps /skill-creator:skill-creator with project-specific save paths, platform adaptation patterns, and description quality standards. Use when the user says "create a skill", "make a new skill", "turn this into a skill", or "I want a slash command for this".
user-invocable: true
argument-hint: "<what the skill should do>"
---

# Create Skill

Lightweight wrapper around `/skill-creator:skill-creator` that adds project-specific conventions: save location, cross-platform adaptation, description quality, and pipeline integration.

**Announce at start:** "Using create-skill to set up a new skill with cross-platform conventions."

## Before You Start

Invoke `/skill-creator:skill-creator` for the full skill creation workflow (intent capture, interview, drafting, test cases, evaluation loop). This skill adds conventions on top of that process — it does NOT replace it.

---

## Convention 1: Save Location

The repo has two skill directories:

- **`skills/`** — Skills created by the user (pipeline, utilities, custom workflows)
- **`plugins/`** — Skills from external plugins (e.g., impeccable design ecosystem)

New user-created skills go in:

```
~/Desktop/Projects/agent-skills/skills/<skill-name>/SKILL.md
```

The `<skill-name>` directory should be lowercase, hyphenated (e.g., `create-skill`, `msf`, `verify`). Check both directories for name collisions:

```bash
ls ~/Desktop/Projects/agent-skills/skills/ ~/Desktop/Projects/agent-skills/plugins/
```

Skills in `skills/` are delivered via the `pmos-toolkit` plugin (namespace: `pmos-toolkit:<skill-name>`). No symlink step needed — the plugin system discovers them automatically. Just restart your session or run `/reload-plugins`.

---

## Convention 2: Cross-Platform Adaptation

Every skill MUST include this section after the "Announce at start" line:

```markdown
## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No `AskUserQuestion`:** State your assumption, document it in the output, and proceed. The user reviews after completion.
- **No subagents:** Perform research and analysis sequentially as a single agent.
- **No Playwright MCP:** Note browser-based verification as a manual step for the user.
```

Additionally, when writing skill instructions:
- Do NOT make `AskUserQuestion` the only way to get user input — always provide a "proceed with stated assumptions" fallback
- Do NOT delegate core logic to external plugins — include enough inline instructions that the skill works standalone
- Do NOT assume MCP tools are available — treat them as optional enhancements
- Do NOT assume subagent dispatch — write instructions that work sequentially too

**Self-contained skills should inline these patterns where applicable:**
- **Setup** — environment preparation, dependency detection, workspace isolation
- **Self-review & refinement loops** — review own output against requirements, iterate until quality bar is met (minimum 2 loops)
- **Escalation policy** — when to stop and ask for help vs. proceeding with stated assumptions
- **Evidence standards** — what constitutes proof that a step succeeded (command output, not "should work")

---

## Convention 3: Description Quality

The `description:` field in frontmatter must include:

1. **What it does** (1 sentence)
2. **Pipeline position** if it fits in the requirements→spec→plan→execute→verify pipeline
3. **Natural trigger phrases** — common things users say that should invoke this skill

Example of a good description:
```
description: Create a detailed technical specification from a requirements document — architecture, API contracts, DB schema, frontend design, testing strategy, verification plan. Second stage in the requirements -> spec -> plan pipeline. Auto-tiers by scope. Use when the user says "write the technical design", "design the system", "create the spec", or has a requirements doc ready for detailed design.
```

The trigger phrases matter because skill descriptions are how the agent decides whether to invoke a skill. Without natural-language triggers, users have to remember the exact slash command name.

---

## Convention 4: Pipeline Awareness

If the new skill fits into the existing pipeline, include the full pipeline diagram:

```markdown
/requirements  →  [/msf, /creativity]  →  /spec  →  /plan  →  /execute  →  /verify
                   optional enhancers
```

Mark the new skill's position with `(this skill)`. If it's an optional enhancer, show it in the brackets. If it's standalone (like `/verify`), note that in the description.

---

## Convention 5: Standard Frontmatter

Every skill must have at minimum:

```yaml
---
name: <skill-name>
description: <what + when — see Convention 3>
user-invocable: true
argument-hint: "<what to pass>"
---
```

---

## Convention 6: Learning Integration

Every pipeline skill MUST include two learning integration points:

**At startup** (in Phase 0 or as a standalone section after Platform Adaptation):

```markdown
Read `~/.pmos/learnings.md` if it exists. Note any entries under `## /skill-name` and factor them into your approach for this session.
```

**At end** — Workstream Enrichment and Capture Learnings MUST be numbered phases (not trailing unnumbered sections), otherwise they get skipped. Place them as the last two phases, before Anti-Patterns:

```markdown
## Phase N: Workstream Enrichment

**Skip if no workstream was loaded in Phase 0.** Otherwise, follow the enrichment instructions in `product-context/context-loading.md` Step 4. For this skill, the signals to look for are:

- [skill-specific signal] → workstream `## [Section]`

This phase is mandatory whenever Phase 0 loaded a workstream — do not skip it just because the core deliverable is complete.

---

## Phase N+1: Capture Learnings

**This skill is not complete until learnings are captured.** Read and follow `learnings/learnings-capture.md` (relative to the skills directory) now. Record anything that will help a future invocation of this skill go better — surprising behaviors, repeated corrections, non-obvious decisions.
```

If the skill doesn't load workstream context in Phase 0, omit the Workstream Enrichment phase and only include Capture Learnings.

This ensures new skills participate in the global feedback loop from day one and that the feedback loop actually runs.

---

## Convention 7: Progress Tracking for Multi-Phase Skills

If the skill has **3 or more sequential phases, steps, or user-approval gates**, include a progress-tracking instruction near the top (after Platform Adaptation). Single-shot skills (e.g., `/commit`, `/changelog`) should skip this — the overhead clutters them.

Use platform-neutral phrasing so the instruction works across Claude Code, Codex, and other agents:

```markdown
## Track Progress

This skill has multiple phases. Create one task per phase using your agent's task-tracking tool (e.g., `TodoWrite` in Claude Code, equivalent in other agents). Mark each task in-progress when you start it and completed as soon as it finishes — do not batch completions.
```

Rule of thumb: if a user reading the skill would benefit from seeing which phase you're in, add the tracking instruction. Otherwise don't.

---

## Checklist Before Saving

Before writing the final SKILL.md, verify:

- [ ] Saved to `~/Desktop/Projects/agent-skills/skills/<name>/SKILL.md` (NOT `plugins/`)
- [ ] Restarted session or ran `/reload-plugins` to pick up the new skill
- [ ] Platform Adaptation section present
- [ ] Description includes natural trigger phrases
- [ ] No hard dependency on external plugins (fully self-contained)
- [ ] No hard dependency on `AskUserQuestion` (assumption fallback exists)
- [ ] No hard dependency on MCP tools (noted as manual step if unavailable)
- [ ] Pipeline diagram included if the skill fits the pipeline
- [ ] Under 500 lines (extract to `reference/` files if needed)
- [ ] Anti-patterns section present
- [ ] Learning read at startup (Phase 0 or standalone Load Learnings section)
- [ ] Capture Learnings is a **numbered phase** (not a trailing unnumbered section) with terminal-gate language ("this skill is not complete until learnings are captured")
- [ ] Workstream Enrichment is a **numbered phase** (if the skill loads workstream context in Phase 0) with skip-gate language
- [ ] Progress tracking instruction included if skill has ≥3 phases/gates
