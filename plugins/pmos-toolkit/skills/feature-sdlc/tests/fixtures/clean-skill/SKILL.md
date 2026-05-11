---
name: clean-skill
description: Format a CSV file into a tidy markdown table and write it next to the source. Use when the user says "turn this CSV into a table", "make a markdown table from this data", "tabulate this CSV", "format my CSV as markdown", "convert csv to a table", or hands over a `.csv` and asks for a readable version. Run it whenever a CSV needs to become human-readable markdown.
user-invocable: true
argument-hint: "<path-to-csv> [--non-interactive | --interactive]"
---

# Clean Skill

A minimal, well-formed example skill used as the green fixture for
`tools/skill-eval-check.sh`. It turns a CSV file into a markdown table written
alongside the source. It is intentionally small and conventional — every applicable
deterministic `skill-eval.md` check passes against it.

**Announce at start:** "Using clean-skill to format the CSV into a markdown table."

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:

- **No interactive prompt tool:** state your assumption (output path = source path with `.md` extension) and proceed; the user reviews after.
- **No subagents:** do the formatting inline as a single agent.
- **No Playwright / MCP:** not used by this skill.

## Track Progress

This skill has multiple phases. Create one task per phase using your agent's
task-tracking tool (e.g., `TaskCreate` in Claude Code, `TodoWrite` in older
harnesses). Mark each task in-progress when you start it and completed as soon as it
finishes — do not batch completions.

## Load Learnings

Read `~/.pmos/learnings.md` if it exists. Note any entries under `## /clean-skill`
and factor them into your approach for this session.

---

## Phase 1: Read the CSV

Read the file at the path given in the argument. If the argument is missing, ask the
user for the path (or, non-interactively, stop with a clear message). Confirm the
column count and row count back to the user in one line.

## Phase 2: Format the table

Build a GitHub-flavoured markdown table: the header row from the CSV's first line, a
separator row, then one row per data line. Escape any pipe characters in cell values.
Right-trim trailing whitespace.

## Phase 3: Write the output

Write the table to `<source>.md` (the source path with its extension replaced by
`.md`). If that file already exists, append `-2`, `-3`, … until the name is free.
Print the output path back to the user.

## Phase 4: Capture Learnings

**This skill is not complete until the learnings-capture process has run.** Reflect on
whether this session surfaced anything worth capturing under `## /clean-skill` —
malformed-CSV handling, encoding surprises, escaping edge cases. Proposing zero
learnings is a valid outcome for a smooth session; the gate is that the reflection
happens.

---

## Anti-patterns (DO NOT)

- Do NOT overwrite an existing `.md` file silently — disambiguate the name.
- Do NOT load the whole CSV into memory if it is large — stream it line by line.
- Do NOT skip the pipe-escaping step — an unescaped `|` breaks the table.
