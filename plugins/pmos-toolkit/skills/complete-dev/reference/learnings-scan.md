# Learnings scan heuristics

Used by `/complete-dev` Phase 6. Scope is **strictly bounded** to the feature branch's durable record:

- `git diff main..HEAD` (file changes since branching)
- Last N feature-branch commit messages (`git log main..HEAD --pretty=format:"%s%n%b"`)

**Conversation transcript is NOT scanned.** It's too noisy and includes detours that didn't ship.

## What counts as a candidate learning

A finding is worth proposing only if it's:

1. **Non-obvious from the code itself.** If reading the file makes it clear, no comment or learning needed.
2. **Likely to recur.** Single-incident gotchas usually belong in commit messages, not CLAUDE.md.
3. **Actionable for future sessions.** "Don't do X here because Y" beats "X happened once."

### Signal patterns to look for

- **Reverted-then-re-done** changes in the diff (file edited multiple times in different commits): often points to a learned constraint.
- **Commit messages with "fix(...)", "actually", "correct", "revert"**: signals a correction worth capturing.
- **Comments added in the diff** that explain WHY (e.g., `// must use X because Y`): often the learning is already articulated and just needs lifting into CLAUDE.md.
- **New entries in CONFIG / settings files** that aren't documented elsewhere: should be referenced in CLAUDE.md.
- **Test cases added for edge cases**: the edge case itself is the learning.

### Signal patterns to IGNORE

- Refactors with no behavior change.
- Style/formatting commits.
- Doc-only edits to files that aren't load-bearing for future agents.
- "WIP" or "checkpoint" commits later squashed (not durable).

## Target file selection

For each candidate, decide where it belongs:

| Type of learning | Target file |
|------------------|-------------|
| Repo-specific convention or constraint | `CLAUDE.md` (or `AGENTS.md` if that's the repo's convention) |
| Skill behavior surprise (e.g., "/changelog writes to docs_path, not CHANGELOG.md") | `~/.pmos/learnings.md` under `## /<skill-name>` |
| User preference signaled this session | `~/.claude-personal/.../memory/` (auto-memory; lower priority for /complete-dev — usually captured separately) |

If unclear, ask the user which file in the AskUserQuestion options.

## Caps

- Maximum 8 candidates per session — beyond that, the proposal noise outweighs the value.
- If more than 8 are found, prioritize by: corrections > non-obvious decisions > new patterns.

## Output format for proposed entries

For CLAUDE.md / AGENTS.md, follow the existing file's section structure. Common shape:

```markdown
- **<Rule>**: <one-line>. Reason: <why>. Applies when: <condition>.
```

For ~/.pmos/learnings.md, append under `## /<skill-name>` with the date:

```markdown
### 2026-05-08
- <observation> — <implication for future sessions>
```

Never overwrite existing sections; always append/insert at the right anchor.
