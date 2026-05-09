---
task_number: 7
task_name: "Create _shared/resolve-input.md (format-aware artifact resolver)"
task_goal_hash: t7-resolve-input
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-09T20:46:00Z
completed_at: 2026-05-09T20:48:00Z
files_touched:
  - plugins/pmos-toolkit/skills/_shared/resolve-input.md
---

## T7 — _shared/resolve-input.md

**Outcome:** done. 125-line resolver-contract document authored at `plugins/pmos-toolkit/skills/_shared/resolve-input.md`. FR-30..FR-33 + D21 satisfied.

### Sections

1. **Resolver contract** — inputs (`feature_folder`, `phase_or_label`), output (resolved abs path), 3-step resolution order (`.html` → `.md` → error), and the phase→prefix mapping table (`requirements=01`, `spec=02`, `plan=03`).
2. **Label-based lookup (FR-32)** — table covering `msf-findings`, `grills`, `simulate-spec`, `verify` non-numbered artifacts; multi-match disambiguation = lexicographic-max filename (latest date).
3. **Ambiguous-feature edge cases (FR-32)** — defers to `_shared/pipeline-setup.md` Section B; explicit no-fuzzy-matching rule inside the resolver.
4. **Fixture-folder examples** — 4 concrete examples per plan T7 Step 1 (post-html-artifacts default, legacy MD-only NFR-10 regression, `output_format: both` mixed sidecars, neither-exists error case).
5. **Caller pattern** — canonical wording for skill bodies; states the resolver is a path-resolution discipline (no executable resolver, no function call); cites T20 `assert_no_md_to_html.sh` as the per-skill enforcement gate (FR-33).

### Inline verification

All 4 plan-defined assertions pass:

```
test -f plugins/pmos-toolkit/skills/_shared/resolve-input.md          → exit 0
grep -q "prefer .html"                                                → match (heading + body)
grep -q "fall back to .md"                                            → match (heading + body)
grep -q "phase=requirements"                                          → match (resolver-contract section + caller-pattern example)
```

### Decisions / deviations

- **Length:** 125 lines vs plan's "≈60 lines" target. Denser because FR-32 label-coverage table (4 rows) and 4 fixture examples landed verbatim per Step 1 — not adding new content beyond the spec, just rendering the spec exhaustively. Not flagged as a deviation worth /plan handoff.
- **No executable resolver.** Spec FR-30 says "documents the resolver pattern that skill prompts inline" — kept it pure docs, no Python/JS shim. T8 runbook §5 will inline the call wording into SKILL.md edits.
- **No fuzzy slug matching inside the resolver.** Section B is the SSOT for ambiguous feature lookup; resolver explicitly defers (avoids two competing slug-disambiguation paths).

### Spec compliance

| FR | Requirement | Satisfied by |
|---|---|---|
| FR-30 | File created at exact path | `plugins/pmos-toolkit/skills/_shared/resolve-input.md` |
| FR-31 | `.html` → `.md` → error; phase prefix mapping | Resolver contract section + table |
| FR-32 | Label-based lookup; ambiguous-feature deferral | Label-based lookup table + Ambiguous-feature edge cases section |
| FR-33 | Skills update read phases (resolver displaces direct .md `Read`) | Caller-pattern note + T20 enforcement reference |
| D21 | Created (not extended) | New file; cited in spec §1 D21 |

T16 (`assert_resolve_input.sh`) — per-skill caller-pattern enforcement — lands in Phase 4 fixtures (T16). T8/T9 apply the resolver-call wording to the 10 affected SKILL.md files.
