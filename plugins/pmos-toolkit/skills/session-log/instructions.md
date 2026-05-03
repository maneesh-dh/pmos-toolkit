# Session Log

Capture session learnings as concise bullet points, prepended (newest first). Determine `{docs_path}` by reading `.pmos/settings.yaml` if it exists (default: `.pmos`); otherwise use `docs/pmos/` (or legacy `docs/` if the repo already has `docs/{requirements,specs,plans,features}/` folders — see `product-context/context-loading.md` Step 1).

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

**References:**
- Spec: [`relative/path/to/spec.md`](relative/path/to/spec.md)
- Plan: [`relative/path/to/plan.md`](relative/path/to/plan.md)
- Requirements: [`relative/path/to/requirements.md`](relative/path/to/requirements.md)
```

Only include bullets that apply. No empty sections, no headers within the entry. Keep each bullet concise — one line, direct. Always include a **References** section at the end linking to the relevant documents (spec, plan, requirements, or any other key docs produced or consumed during the session).

3. **Show draft to user** — Present the entry and ask for confirmation or edits before writing.

4. **Write** — Prepend the entry to `{docs_path}/session-log.md`. If the file doesn't exist, create it with a single H1 header `# Session Log` followed by the entry.

## Rules

- Every bullet must be specific and actionable, not generic ("improved code quality" is useless; "extracted embedding batching into a generator to stay under Ollama's 5-connection semaphore" is useful)
- Decisions MUST include the "why" — the reasoning is the most valuable part for training material
- Keep the full entry under 15 bullets. Aim for 4-8.
- Do not include trivial changes (typo fixes, formatting) unless they revealed something non-obvious
- Date must be the actual current date, not inferred from commits
- Always include a **References** section linking to relevant documents (specs, plans, requirements, etc.) using relative paths from the docs/ directory, matching the format used in the changelog
