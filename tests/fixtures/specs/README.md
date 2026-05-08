# /plan Integration Test Fixtures

Test fixtures consumed by /plan v2 integration tests (T39–T41 of the plan-skill-redesign plan). They live under `tests/`, **not** under `docs/pmos/features/`, so the pipeline-setup folder picker does not discover them as user-facing features.

The `wireframes/` subfolder exercises FR-16 bidirectional coverage: every HTML file under `wireframes/` must be referenced by ≥1 task in the generated plan, OR listed in the plan's `## Wireframes Out of Scope` section.

| Fixture | Tier | Type | Notes |
|---------|------|------|-------|
| `tier1_bugfix.md` | 1 | bugfix | Single FR — exercises Tier 1 reduced-TN path |
| `tier2_enhancement.md` | 2 | enhancement | 3 FRs, no UI — exercises Tier 2 single-loop path |
| `tier3_feature.md` | 3 | feature | 8 FRs, NFR table, sequence diagram, references both wireframes |
