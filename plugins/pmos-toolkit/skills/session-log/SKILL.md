---
name: session-log
description: Use when the user invokes /session-log, or before ending a significant session where meaningful work was done - captures learnings, decisions, gotchas, and patterns
---

# Session Log

Capture session learnings as concise bullet points, prepended (newest first).

## Load Workstream Context

Before any other work, follow the context loading instructions in `context/context-loading.md` (relative to the skills directory). This determines `{docs_path}`. Use `{docs_path}/session-log.md` as the output path.

## Process

1. **Gather context** — Read the git diff (`git diff HEAD~` or appropriate range for the session's changes) and reflect on the conversation: what was built, what decisions were made and why, what was surprising, what patterns worked well.

2. **Draft entry** — Write a dated entry as flat bullet points. Format:

```markdown
## YYYY-MM-DD — [Brief title]

- What changed / was built
- Key decisions with reasoning (chose X over Y because Z)
- Gotchas or surprises encountered
- Patterns or techniques that worked well
- Takeaway: what you'd teach someone from this session
```

Only include bullets that apply. No empty sections, no headers within the entry. Keep each bullet concise — one line, direct.

3. **Show draft to user** — Present the entry and ask for confirmation or edits before writing.

4. **Write** — Prepend the entry to `{docs_path}/session-log.md`. If the file doesn't exist, create it with a single H1 header `# Session Log` followed by the entry.

5. **Workstream Enrichment** — If a workstream was loaded, follow the enrichment instructions in `context/context-loading.md` Step 4. Session log signals: decisions with reasoning → workstream `## Key Decisions`; gotchas → workstream `## Constraints & Scars`.

## Rules

- Every bullet must be specific and actionable, not generic ("improved code quality" is useless; "extracted embedding batching into a generator to stay under Ollama's 5-connection semaphore" is useful)
- Decisions MUST include the "why" — the reasoning is the most valuable part for training material
- Keep the full entry under 15 bullets. Aim for 4-8.
- Do not include trivial changes (typo fixes, formatting) unless they revealed something non-obvious
- Date must be the actual current date, not inferred from commits
