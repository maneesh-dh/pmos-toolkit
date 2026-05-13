---
task_number: 18
task_name: "reference/ progressive disclosure — l1-rationales, adr-template, gap-map-rationale"
task_goal_hash: t18-reference-progressive-disclosure-fr82
plan_path: "docs/pmos/features/2026-05-13_architecture-principles-skill/03_plan.html"
branch: "feat/architecture-principles-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-architecture-principles-skill"
status: done
started_at: 2026-05-13T00:32:00Z
completed_at: 2026-05-13T00:35:00Z
files_touched:
  - plugins/pmos-toolkit/skills/architecture/reference/l1-rationales.md
  - plugins/pmos-toolkit/skills/architecture/reference/gap-map-rationale.md
  - plugins/pmos-toolkit/skills/architecture/SKILL.md
---

## Outcome

- Authored `reference/l1-rationales.md` — 10 sections (U001–U010), each with rule + check + severity + delegate + why + source + example violation.
- Authored `reference/gap-map-rationale.md` — per-rule rationale for the `delegate_to:` assignment, plus the 0.444 ratio explanation (G2 stretch framing).
- `reference/adr-template.md` was already shipped by T13.
- Tightened SKILL.md's standing-acceptance citation to the fully-qualified `plugins/.../feature-sdlc/reference/skill-patterns.md` path so the in-skill `reference/` links cleanly resolve.

## Verification

All 3 relative `reference/<file>.md` links in SKILL.md resolve on disk:

```
OK reference/adr-template.md
OK reference/gap-map-rationale.md
OK reference/l1-rationales.md
```

The fully-qualified feature-sdlc path is not in-skill, by design.

## Decisions

- TDD=no per plan (content-only slice; structural correctness graded by Phase 6a /skill-eval).
- l1-rationales each cite a real public source (Ousterhout, Martin, Fowler, OWASP, CWE) — concrete enough for skill-eval `[J]` check "source citations are non-empty".
- gap-map rationale explicitly documents the 0.444 ratio + the 70% stretch framing so reviewers don't push to weaken G2 mid-flight (plan R3 risk).
