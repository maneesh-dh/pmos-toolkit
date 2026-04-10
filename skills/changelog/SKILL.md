---
name: changelog
description: Use when merging to main or after a merge to main - generates user-facing changelog entries describing what the system can now do
---

# Changelog

Generate user-facing changelog entries in `docs/changelog.md`, prepended (newest first).

## Process

1. **Determine scope** — Run `git log` to find commits since the last changelog entry date (read the top entry in `docs/changelog.md` for the last date). If no changelog exists, use all commits on main.

2. **Analyze changes** — Read the commit messages and diffs to understand what was added, changed, or fixed. Focus on *what the system can now do*, not implementation details.

3. **Draft entry** — Write a dated entry with user-facing bullets. Format:

```markdown
## YYYY-MM-DD — [Brief feature/theme title]

- Added: what new capability exists
- Changed: what behaves differently
- Fixed: what broken thing now works
```

No "Added/Changed/Fixed" prefixes required — use them only when they add clarity. Write in plain language a user of the tool would understand.

4. **Show draft to user** — Present the entry and ask for confirmation or edits before writing.

5. **Write** — Prepend the entry to `docs/changelog.md`. If the file doesn't exist, create it with a single H1 header `# Changelog` followed by the entry.

## Rules

- User-facing language: "Search now combines keyword and semantic results" not "Implemented RRF fusion in SearchService"
- Group related changes under one bullet rather than listing every commit
- Skip internal refactors, test changes, and doc updates unless they affect user-visible behavior
- Keep entries concise: aim for 3-7 bullets per merge
- Date must be the actual current date
- Include a **References** section at the end of each entry linking to relevant plans, specs, requirements, or other docs (relative paths from repo root). Only include references that exist in the repo.
