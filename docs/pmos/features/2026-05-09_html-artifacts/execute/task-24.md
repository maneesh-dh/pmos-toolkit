---
task_number: 24
task_name: "Bump plugin version 2.32.0 → 2.33.0 (both manifests)"
task_goal_hash: t24-bump-manifests-2-33-0
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-10T03:30:00Z
completed_at: 2026-05-10T03:32:00Z
files_touched:
  - plugins/pmos-toolkit/.claude-plugin/plugin.json
  - plugins/pmos-toolkit/.codex-plugin/plugin.json
---

## T24 — Manifest version sync 2.32.0 → 2.33.0

**Outcome:** done. Both manifests at 2.33.0; pre-push sync invariant satisfied
(version + description byte-identical across `.claude-plugin/plugin.json` and
`.codex-plugin/plugin.json`).

### Inline verification

```
$ jq -r .version plugins/pmos-toolkit/.claude-plugin/plugin.json
2.33.0
$ jq -r .version plugins/pmos-toolkit/.codex-plugin/plugin.json
2.33.0
$ diff <(jq -r .version .claude-plugin/plugin.json) <(jq -r .version .codex-plugin/plugin.json)
[empty — version sync OK]
$ diff <(jq -r .description .claude-plugin/plugin.json) <(jq -r .description .codex-plugin/plugin.json)
[empty — description sync OK]
```

### Discovered (pre-existing) gap — non-blocking

`bash plugins/pmos-toolkit/tools/audit-recommended.sh` exits 1 with 13 unmarked
`AskUserQuestion` call sites across 4 skills:

```
skills/changelog/SKILL.md:    1 unmarked
skills/create-skill/SKILL.md: 2 unmarked
skills/execute/SKILL.md:      1 unmarked
skills/feature-sdlc/SKILL.md: 9 unmarked
```

These are **pre-existing** — audit was failing on `main` before this feature
started; the html-artifacts changes did not introduce the gap. Three of the
four skills (`changelog`, `create-skill`, `execute`) are not in this feature's
affected-skills set. `feature-sdlc/SKILL.md` was edited by T10 for HTML
artifact emission only — the unmarked calls predate T10 (they are the gate
prompts in Phases 3.b/4.a/4.b/4.c/4.d/6 whose `(Recommended)` annotation lives
inside a markdown comment after the option label, which the awk extractor's
"option-list block" terminator handling doesn't reach because the option
labels themselves don't carry `(Recommended)`).

**Disposition:** logged as advisory ADV-T24. Not introduced by Phase 5.
Recommend a separate "annotate gate prompts with (Recommended) suffix"
cleanup pass in a follow-on. Plan T24 inline-verification step says
"audit-recommended.sh exit 0" — that condition does not hold on `main` and
is unaffected by the version bump.

### Spec compliance

| FR | Requirement | Satisfied by |
|---|---|---|
| NFR-09 | Manifest sync invariant | Both versions + descriptions byte-identical |
| §15 (release) | Version bump for FR-RELEASE | 2.32.0 → 2.33.0 (minor bump per spec FR-RELEASE) |

### Advisories (logged, non-blocking)

- **ADV-T24** (pre-existing): `audit-recommended.sh` fails on 13 unmarked
  `AskUserQuestion` call sites across `changelog/create-skill/execute/feature-sdlc`
  SKILL.md files. Not introduced by html-artifacts work. Recommend separate
  cleanup pass.

T24 complete.
