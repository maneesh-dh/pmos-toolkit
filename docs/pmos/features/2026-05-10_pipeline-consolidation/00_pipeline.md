---
slug: pipeline-consolidation
tier: 3
branch: feat/pipeline-consolidation
worktree: /Users/maneeshdhabria/Desktop/Projects/agent-skills-pipeline-consolidation
started: 2026-05-10
mode: interactive
---

# Pipeline status — pipeline-consolidation

| Phase            | Status     | Artifact                              |
|------------------|------------|---------------------------------------|
| requirements     | completed  | 01_requirements.md (Loop-2 from grill) |
| grill            | completed  | grills/2026-05-10_01_requirements.md  |
| msf-req          | completed  | msf-req-findings.md (3 Must / 5 Should / 6 Nice) |
| creativity       | skipped    | —                                     |
| wireframes       | skipped    | —                                     |
| prototype        | skipped    | —                                     |
| spec             | completed  | 02_spec.md (Ready for Plan; 35 decisions, 63 FRs) |
| simulate-spec    | completed  | simulate-spec/2026-05-10-trace.md (30 scen / 18 gaps / 16 patches) |
| plan             | completed  | 03_plan.md (22 tasks across 7 phases; 2 review loops) |
| execute          | pending    | —                                     |
| verify           | pending    | —                                     |
| complete-dev     | pending    | —                                     |

## Initial brief

User wants to fold pipeline skills into their parents (Tier-aware mandatory/optional gates):

1. `/msf-req` → phase inside `/requirements` (Tier 3 mandatory, Tier 1 optional)
2. `/msf-wf` → phase inside `/wireframes` (Tier 3 mandatory, Tier 1 optional)
3. `/simulate-spec` → phase inside `/spec` (Tier 3 mandatory, Tier 1 optional)
4. Fix `/msf-req` and `/msf-wf` artifact slug clash (both currently write to `msf-findings/`)
5. Update `/feature-sdlc` to reflect folded phases (remove Phase 4.a, 6 separate gates; phases now happen inside parents)
6. Standardize `--non-interactive` open_questions format across all pipeline skills (adopt /feature-sdlc canonical contract)
7. Fold `/retro` as final optional step in `/feature-sdlc` (after `/complete-dev`)
8. Enhance `/retro` to support multi-session analysis: `--last N`, `--days N`, `--since YYYY-MM-DD`, `--project current|all`; subagent-per-session dispatch; recurring-pattern aggregation.

User decisions captured at gate:

- **Folding model:** keep standalone slash commands + fold as phases (backwards-compatible).
- **Retro scope:** multi-session aggregation + `--project all` + subagent-per-session dispatch. (Cross-reference against current skill body NOT in scope.)
- **OQ format:** adopt `/feature-sdlc`'s existing canonical non-interactive-block contract across all pipeline skills.
- **Tier:** 3.
