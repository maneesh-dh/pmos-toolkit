---
task_number: 10
task_name: "/feature-sdlc orchestrator emits 00_pipeline.html + 00_open_questions_index.html"
task_goal_hash: t10-orchestrator-html
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-09T22:30:00Z
completed_at: 2026-05-09T22:45:00Z
files_touched:
  - plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md
---

## T10 — /feature-sdlc orchestrator HTML emission (FR-11 / D14)

**Outcome:** done. /feature-sdlc now emits `00_pipeline.html` (Phase 1 init-state + Phase 2 atomic post-phase regen) and `00_open_questions_index.html` (Phase 11 final summary). Per runbook edge case row 3, no `<NN>_<artifact>.sections.json` companion is written for orchestrator artifacts (they have no `<h2>`-anchored substantive TOC; the status table is the body). Heading-id rule still applies — `/verify` smoke asserts it.

### Edits applied

11 Edits to `plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md`:

1. argument-hint adds `[--format <html|md|both>]`
2. Phase 0 addendum (between line 64 and `<!-- non-interactive-block:start -->`): step 6 `output_format` resolution + child-dispatch convention `[output_format: <resolved>]\n` first-line passthrough
3. Phase 1 step 2: `00_pipeline.md` → `00_pipeline.html` + canonical write-phase block (atomic write, asset substrate, `assets/` prefix, cache-bust, heading IDs, no-sections.json carve-out per runbook edge case row 3, index regen seed, mixed-format sidecar)
4. Phase 2 atomic post-phase update: regen `00_pipeline.html` (+ `.md` sidecar in mixed mode)
5. Phase 11: status-table source `00_pipeline.html` (or `.md` sidecar); artifact links use `{html,md}` + manifest lookup; `00_open_questions_index.md` → `00_open_questions_index.html` with full canonical write block
6-9. Phase 3 / 3.b / 4.a / 5 / 7: child-dispatch arg paths use `{html,md}` resolved primary; capture-artifact paths use resolver
10. Anti-pattern #6: protocol regen names `00_pipeline.html` + `.md` sidecar
11. Release prerequisites argument-hint flag list adds `--format`
12. (also) Platform Adaptation `00_pipeline.md` mention → `{html,md}`

(Some edits combined into single replacements; total Edit count ≈ 12 vs the plan's "~6" estimate. Higher than plan because the orchestrator references its own primary artifact in many places — Phase 0.b status, Phase 11 summary, Anti-pattern #6, Platform Adaptation footer.)

### Decisions / deviations

- **No-sections.json companion** for `00_pipeline.html` / `00_open_questions_index.html` per runbook edge case row 3. The orchestrator artifacts have no anchored substantive content (status tables, OQ index sections both render as bodies); a sections.json would be empty noise. T22 `assert_heading_ids.sh` still applies — heading IDs are required.
- **Index regen on init.** Phase 1 step 2 explicitly seeds `<feature_folder>/index.html` with a single-entry manifest pointing at `00_pipeline.html`. Subsequent child-skill writes extend the manifest as they run.
- **Child-dispatch passthrough.** Added the `[output_format: <resolved>]\n` second-line convention to subagent dispatch so children inherit without re-reading settings — keeps `output_format` consistent across the entire pipeline run regardless of intermediate settings edits.
- **Edit count over estimate (~12 vs ~6).** Driver: orchestrator self-references its primary artifact in many tracking paths. No work was wasted; each Edit was load-bearing.

### Spec compliance

| FR | Requirement | Satisfied by |
|---|---|---|
| FR-10 / .1 / .2 / .3 | Substrate, prefix, atomic write, cache-bust | Phase 1 step 2 explicit |
| FR-11 (D14) | Orchestrator artifacts emitted as HTML | Phase 1 + Phase 11 |
| FR-12 / .1 | output_format settings/flag + sidecar | Phase 0 addendum + Phase 1 step 2 mixed-format clause + Phase 11 |
| FR-22 / FR-41 | Index regen + inline manifest | Phase 1 step 2 + Phase 2 atomic protocol |
| FR-03.1 | Heading IDs (h2/h3) | Phase 1 step 2 explicit |
| FR-33 | Resolver enforcement on capture-artifact paths | Phases 3 / 5 / 7 capture clauses |
| Edge case row 3 | No sections.json for orchestrator artifacts | Phase 1 step 2 + Phase 11 explicit |

### Forward-dependencies

- **T15 / T18:** real /feature-sdlc orchestrator end-to-end run will exercise these edits.
- **Phase 2.5 boundary:** /verify --scope phase --feature 2026-05-09_html-artifacts --phase 2 fires next.

### Inline verification (plan-defined)

```
grep -nE '00_pipeline\.md\b|00_open_questions_index\.md\b' plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md | grep -vE 'legacy|sidecar|format: both|format=both|html-to-md|\{html,md\}'
```

Result: 0 matches.

Holistic audit (R0-R9 + T10) across all 11 affected skill files: 0 residual MD primary references with the runbook §7 + edge case row 7 filter.

T10 is the final task in Phase 2. Phase 2.5 boundary is next.
