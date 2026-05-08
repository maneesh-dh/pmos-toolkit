# Manual E2E — Subagent Mode Propagation (FR-06)

This is a manual runbook. It is not executable in `bats`; it requires a real Claude session because subagent dispatch only fires on actual Task-tool invocations.

## Setup

1. Create a tiny seed feature folder under `docs/pmos/features/2026-XX-XX_smoke-ni/` containing only `03_plan.md` with a single trivial T1 task that triggers `/verify` from `/execute`.
2. Ensure `.pmos/settings.yaml` exists.
3. Open a fresh Claude session.

## Run

```
claude -p '/execute --non-interactive docs/pmos/features/2026-XX-XX_smoke-ni/03_plan.md' \
  --output-format=stream-json \
  --print >/tmp/exec.json 2>/tmp/exec.log
```

## Assertions (FR-06.1 / .2 / .3)

- [ ] **FR-06.1** — When `/execute` dispatches `/verify` via the Task tool, the child prompt's first line is exactly `[mode: non-interactive]`. Inspect `/tmp/exec.json` and grep for the dispatched-prompt field; the first newline-terminated line MUST be the marker.
- [ ] **FR-06.1** — `/verify`'s stderr opening line is `mode: non-interactive (source: parent-skill-prompt)`. Inspect `/tmp/exec.log` (or the per-task `verify` stderr capture) for the literal line.
- [ ] **FR-06.2** — Parent `/execute`'s final OQ block (in the per-task log under `{feature_folder}/execute/task-NN.md`) contains entries with id format `OQ-verify-NNN` (parent-namespaced child id).
- [ ] **FR-06.3** — If the parent runs `--interactive` and the child sees `[mode: interactive]` in its prompt prefix, the parent flag still wins on the child. Re-run with `claude -p '/execute --interactive ...'` against a parent-marker fixture; assert child's stderr says `mode: interactive (source: cli_flag)` (cli wins over parent-marker per FR-01.1 precedence).

## Recording results

Append a `## YYYY-MM-DD run` section to this file with:
- `claude` version
- pmos-toolkit version
- Exec exit code
- Whether each assertion passed; quote the key line of evidence
- Any deviations from the expected output

## Known caveats

- Subagent propagation only fires when the parent uses the actual Task tool. `/execute` does this for `/verify` post-task. Skills that invoke siblings via inline references (no Task tool) are not in FR-06 scope.
- The marker is consumed by the child resolver and must NOT be echoed back to the parent in transcripts (NFR-04 byte-identical interactive mode).
