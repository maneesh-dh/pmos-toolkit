---
name: artifact
description: Generate, refine, and update structured PM/eng artifacts (PRD, Experiment Design Doc, Engineering Design Doc, Discovery Doc) from existing context plus targeted gap-filling questions. Each artifact passes through a reviewer-subagent + auto-apply loop (max 2 iters) governed by per-section eval criteria. Ships with 4 built-in templates and 4 writing-style presets (Concise, Tabular, Narrative, Executive); users can author their own at ~/.pmos/artifacts/. Use when the user says "draft a PRD", "create an experiment design", "write a design doc", "generate a discovery doc", "/artifact", or names an artifact type to produce.
user-invocable: true
argument-hint: "[ | <type> [--tier lite|full] [--preset <slug>] | create <type> [...] | refine <path> | update <path> | template add|list|remove [<slug>] | preset add|list|remove [<slug>]]"
---

# /artifact

Generate, refine, and update structured PM/eng artifacts (PRD, Experiment Design Doc, Engineering Design Doc, Discovery Doc) with section-level eval criteria, a reviewer-subagent refinement loop (max 2 iterations), and writing-style presets. Templates ship in this skill; user-defined templates and presets live at `~/.pmos/artifacts/` and survive plugin upgrades.

**Announce at start:** "Using /artifact to {create|refine|update} a {type}."

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No `AskUserQuestion`:** State your assumption inline, document it in the artifact's frontmatter as `assumed: <field>`, proceed. User reviews after.
- **No subagents:** Run the refinement reviewer inline as the same agent. Same eval.md; same output format.
- **Task tracking:** Use whatever task tool exists (TaskCreate / update_plan / verbal phase announcements).

## Phase 0 — Load Context

1. Follow `../product-context/context-loading.md` (relative to this skill dir) to resolve `{docs_path}` and load any active workstream context.
2. Read `~/.pmos/learnings.md` if it exists. Note entries under `## /artifact` and factor them into this session.
3. Ensure `~/.pmos/artifacts/` exists. If not, create the empty tree:
   ```
   ~/.pmos/artifacts/
     templates/
     presets/
   ```
4. Determine the subcommand and route to the appropriate phase. Default subcommand is `create`.

## Phase 1 — Subcommand Routing

| Argument shape | Route to |
|---|---|
| `(empty)` | Phase 2.0 — type picker |
| `<type>` (one word matching a template slug) | Phase 2 — Create flow with `<type>` |
| `create <type> [flags]` | Phase 2 — Create flow |
| `refine <path>` | Refine flow |
| `update <path>` | Update flow |
| `template add` | Template Add flow |
| `template list` | Template List flow |
| `template remove <slug>` | Template Remove flow |
| `preset add` | Preset Add flow |
| `preset list` | Preset List flow |
| `preset remove <slug>` | Preset Remove flow |

If `<type>` doesn't match any template slug (built-in or user), list available templates and offer fuzzy match before erroring.

Recognized flags on `create`:
- `--tier lite|full` — bypass tier auto-detection
- `--preset <slug>` — bypass default preset selection
