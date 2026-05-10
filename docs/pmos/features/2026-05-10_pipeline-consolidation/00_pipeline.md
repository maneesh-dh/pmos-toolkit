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
| requirements     | completed  | 01_requirements.md                    |
| grill            | pending    | —                                     |
| msf-req          | pending    | —                                     |
| creativity       | pending    | —                                     |
| wireframes       | pending    | —                                     |
| prototype        | pending    | —                                     |
| spec             | pending    | —                                     |
| simulate-spec    | pending    | —                                     |
| plan             | pending    | —                                     |
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
