---
task_number: 1
task_name: "Add sibling-prefer probe to /changelog docs_path resolver (CL1)"
plan_path: "docs/pmos/features/2026-05-08_update-skills-retro-pipeline-friction/changelog/01_requirements.md"
branch: "main"
worktree_path: "n/a — Tier 1 sub-pipeline; deviation logged"
status: done
started_at: 2026-05-08T00:00:00Z
completed_at: 2026-05-08T00:00:00Z
files_touched:
  - plugins/pmos-toolkit/skills/changelog/SKILL.md
---

## Goal

Implement CL1 acceptance criteria: probe `{repo_root}/docs/changelog.md` after resolving `docs_path` from settings; prefer the existing sibling when `docs_path != docs/`; emit one-line non-blocking advisory; consistent path resolution across Process steps 1 and 5.

## Deviations

- **Worktree skipped** — change is sub-Phase of an active /update-skills run on main; reverting is `git revert` of one commit. Documented per /execute Phase 2 "Log plan deviations" rule.
- **No formal plan doc** — Tier 1 per /update-skills triage skips /spec and /plan; the requirements doc's AC list serves as the task contract.

## Verification

All 6 acceptance criteria from `01_requirements.md` satisfied by the edited contract text:

- AC1 (sibling-prefer fires when `docs_path != docs/` AND sibling exists) — covered by the first bullet of the new "Sibling-prefer probe" section.
- AC2 (advisory is one non-blocking line) — codeblock template + explicit "Do NOT block on `AskUserQuestion`; do NOT auto-edit `settings.yaml`".
- AC3 (`docs_path == docs/` resolves to `docs/changelog.md` with no advisory) — handled by the `normalize → compare against literal "docs"` rule that routes to the Otherwise branch.
- AC4 (`docs_path != docs/` AND no sibling → falls through to `{docs_path}/changelog.md`, no advisory) — Otherwise branch.
- AC5 (Process steps 1 and 5 share the same resolved path) — both rewritten to consume `{changelog_path}`.
- AC6 (no new phases / reference files / argument-hint changes) — only the existing "## Determine docs_path" section and Process steps 1 and 5 were edited.

D1 / D2 / D3 design decisions from the requirements doc are encoded in the SKILL.md text:
- D1 (sibling-prefer scoped to `docs/changelog.md` only, not other siblings) — probe is a single literal path.
- D2 (advisory non-blocking) — explicit prohibition of `AskUserQuestion`.
- D3 (string compare with normalization) — explicit "normalize it (strip trailing `/`)" before compare against `docs`.

Verification mode: contract-text inspection (no test harness exists for skill prose; the skill is evaluated by execution-time agents reading the file).

