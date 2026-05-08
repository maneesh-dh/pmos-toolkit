# Manual E2E — Pre-Rollout BC Fallback (FR-08)

This is a manual runbook. After Phase 3 every supported skill has the canonical block, so simulating "skill hasn't been rolled out yet" requires a temporary revert on a throwaway branch.

## Setup

1. From the merged feature branch (or main post-merge), branch off:
   ```bash
   git checkout -b throwaway/bc-fallback-smoke main
   ```
2. Pick a low-call skill (`/changelog` recommended — zero call sites, simplest). Find its rollout commit:
   ```bash
   git log --oneline -- plugins/pmos-toolkit/skills/changelog/SKILL.md | head
   ```
3. Revert just the rollout commit:
   ```bash
   git revert --no-commit <rollout-sha>
   git commit -m "chore(throwaway): simulate pre-rollout state for /changelog"
   ```

## Run

```
claude -p '/changelog --non-interactive' \
  --output-format=stream-json \
  --print >/tmp/bc.json 2>/tmp/bc.log
```

## Assertions (FR-08 / FR-08.1)

- [ ] **FR-08** — `/tmp/bc.log` contains the exact line `WARNING: --non-interactive not yet supported by /changelog; falling back to interactive.`
- [ ] **FR-08.1** — Skill ran to completion (`exit 0` from `claude -p`) without crash. In headless mode any `AskUserQuestion` would halt — for `/changelog` (zero calls) the run completes cleanly. For a skill with calls (e.g., `/diagram`) the headless run will block on the first prompt; that is acceptable for FR-08 (the warning fired; the skill correctly fell back to its normal interactive code path).
- [ ] No silent crash with `exit 64` or `exit 1` due to the missing block.

## Cleanup

```bash
git checkout main
git branch -D throwaway/bc-fallback-smoke
```

Do NOT merge the revert.

## Recording results

Append a `## YYYY-MM-DD run` section with:
- pmos-toolkit version
- Skill chosen for the smoke
- Whether the WARNING line appeared (quote it)
- Exit code
- Whether the throwaway branch was discarded
