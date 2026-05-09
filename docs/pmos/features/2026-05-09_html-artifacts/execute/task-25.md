---
task_number: 25
task_name: "README + CHANGELOG entry for 2.33.0"
task_goal_hash: t25-changelog-readme-2-33-0
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-10T03:32:00Z
completed_at: 2026-05-10T03:38:00Z
files_touched:
  - docs/pmos/changelog.md
---

## T25 — CHANGELOG entry for 2.33.0

**Outcome:** done. New top entry prepended to `docs/pmos/changelog.md`
covering the html-artifacts release. README left unchanged (per plan
T25 Step 2 — README is keyword-level and contains no skill rows
explicitly stating "markdown" output format).

### Inline verification

```
$ head -10 docs/pmos/changelog.md | grep -q "2.33.0"
head check OK — 2.33.0 entry present
```

### What the entry covers

- HTML-primary feature-folder artifact migration across 10 pipeline skills + `/feature-sdlc` orchestrator
- `output_format ∈ {html, md, both}` resolution gate; `markdown` exits 64
- `_shared/resolve-input.md` format-aware resolver
- Reviewer subagent input-contract subsection in 5 skills (FR-50/50.1/52)
- `/diagram` blocking subagent pattern (FR-60..65 + D2)
- FR-92 cross-doc anchor scan, FR-03.1 heading-id rule, FR-05.1 viewer.js classic-script
- 8 new assert scripts in `tests/scripts/`
- Canonical fixture at `tests/fixtures/repos/node/docs/pmos/features/2026-05-09_html-artifacts-fixture/`
- Known limitations: OQ-1, OQ-2 (inherited deferred), ADV-T19, ADV-T21, ADV-T24 (pre-existing or non-blocking polish)

### README — no-op

Per plan T25 Step 2: `grep -nE "markdown|html" README.md` surfaces only one
match — the `/polish` row at line 69 ("Critique and refactor any markdown
doc"). `/polish` is unrelated to this feature; the description is
accurate. No README changes warranted.

### Spec compliance

| FR | Requirement | Satisfied by |
|---|---|---|
| §15 (release) | CHANGELOG entry per FR-RELEASE | New top entry in `docs/pmos/changelog.md` |
| FR-RELEASE.iii | Description sync (mentioned via T24) | Plugin descriptions byte-identical (verified in T24) |

T25 complete.
