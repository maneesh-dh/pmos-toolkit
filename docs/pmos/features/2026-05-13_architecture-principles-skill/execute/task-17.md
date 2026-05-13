---
task_number: 17
task_name: "SKILL.md authoring — frontmatter, Phase 0, Platform Adaptation, Anti-Patterns"
task_goal_hash: t17-skill-md-authoring-fr80-fr81-fr83-fr85
plan_path: "docs/pmos/features/2026-05-13_architecture-principles-skill/03_plan.html"
branch: "feat/architecture-principles-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-architecture-principles-skill"
status: done
started_at: 2026-05-13T00:30:00Z
completed_at: 2026-05-13T00:32:00Z
files_touched:
  - plugins/pmos-toolkit/skills/architecture/SKILL.md
---

## Outcome

Authored SKILL.md, 141 lines (well under the 800-line skill-eval cap → FR-82 progressive disclosure satisfied; heavy content lives under `reference/`).

## Verification

- `wc -l SKILL.md` → 141 lines (< 800).
- Frontmatter: `name: architecture` matches dir name (skill-eval a-name-matches-dir).
- `description` carries 6 user-spoken trigger phrases (≥5): "audit my codebase against principles", "run an architecture review", "check for circular imports", "promote architectural decisions to ADRs", "/architecture", "lint my repo against universal rules".
- `argument-hint`: `audit [path] [--no-adr] [--non-interactive]`.
- `target: generic`.
- Body sections present: Platform Adaptation (Claude Code / Codex / no-Task), Phase 0 prerequisites, Phase 1-6 phases, Anti-Patterns (9 entries), Tool version requirements, Reference links.
- Cites `reference/skill-patterns.md §A–§F` as standing acceptance.
- 3 reference/ links (l1-rationales.md, adr-template.md, gap-map-rationale.md) — adr-template exists; the other two land in T18.

## Decisions

- Did NOT inline rule details — pushed to `reference/l1-rationales.md` (T18) per FR-82.
- Phase 5 ADR-promotion prompt is the only interactive checkpoint; documented as deferring to "promote all (capped at 5)" under --non-interactive.
- Tool version requirements section lists jq, python3, dep-cruiser, ruff, git with min versions.
