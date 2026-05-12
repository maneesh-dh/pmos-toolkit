---
task_number: 13
task_name: "Add skill-patterns.md citations + the skill-feedback /requirements seed wiring"
status: done
started_at: 2026-05-12T00:00:00Z
completed_at: 2026-05-12T00:00:00Z
files_touched:
  - plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md
tdd: "no — prose; verification is grep"
---

## What changed (`plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md`)

`reference/skill-patterns.md` is now cited at all four pipeline stages with the right role each time (FR-61):

- **Phase 2 (`/requirements`)** — in skill modes, the child prompt cites `skill-patterns.md §A–§F` as the standing acceptance criteria ("the produced/revised skill must conform to …"). In skill-feedback mode the seed is built from `reference/seed-requirements-template.md` — self-contained per-skill (approved findings verbatim + trimmed current-SKILL.md excerpts + proposed direction + out-of-scope + constraints + the `skill-patterns.md` citation) — producing **one combined `01_requirements.{html,md}` with a per-skill section** (FR-27). (The bulk of this was already in Phase 0c step 6 from T12; T13 makes the Phase-2 prose itself state it.)
- **Phase 4 (`/spec`)** — in skill modes, cite `skill-patterns.md`; `/spec` is the generic skill (no skill-aware spec template — D14/FR-92), so the cited §-sections must be turned into concrete FRs so the `03_plan` tasks are testable against them.
- **Phase 6 (`/execute`)** — in skill modes, cite `skill-patterns.md` as the implementation reference; `/execute` is the sole writer (writes to the `skill_location` from Phase 0d) and also honours the host repo's `CLAUDE.md` for repo-policy bits (canonical path, version-sync, release entry) that are deliberately NOT in `skill-patterns.md`.
- **Phase 7 (`/verify`)** — in skill modes, `/verify` re-runs `reference/skill-eval.md` fresh (which scores against `skill-patterns.md §A–§F` — re-runs `skill-eval-check.sh` + a fresh reviewer pass) as a final idempotent gate, and **reconciles against `accepted_residuals[]`**: still-failing residual → `KNOWN / accepted in Phase 6a` (non-blocking, surfaced loudly in the `/verify` report **and** the `/complete-dev` summary); newly-failing → blocks normally; previously-accepted-now-passing → dropped from the residual set (state updated) (FR-50). `/verify` also best-effort grades the detectable host-repo release prereqs (manifest version-sync if two manifests exist, README row, changelog), gracefully degrading (FR-51). `/verify` is non-skippable in all modes (FR-52). (Removed an accidental duplicate `/verify does not accept --tier.` line introduced while editing.)
- **FR-62 pointer** — a `> **Where the conventions live:**` blockquote near the Phase-6 citation: `skill-patterns.md` = the generic repo-agnostic conventions (§A–§F); this repo's `CLAUDE.md ## Skill-authoring conventions` = the pmos-specific bits (canonical `plugins/pmos-toolkit/skills/<name>/SKILL.md` path, synced `plugin.json` bump, `/complete-dev` as release entry).

## Verification

- `grep -c 'skill-patterns.md' SKILL.md` → 6 (≥4); citations land in the H1 framing + Phase 0c→2 hand-off + Phase 2 + Phase 4 + Phase 6 (×2 incl. the FR-62 pointer) + Phase 7.
- Phase 2 FR-27 wiring: `seed-requirements-template.md` + "one combined `01_requirements` … with a per-skill section" present.
- Phase 7: `KNOWN / accepted in Phase 6a`, "re-run `reference/skill-eval.md` fresh", "non-skippable" all present.
- FR-62 `CLAUDE.md ## Skill-authoring conventions` pointer present.
- `audit-recommended.sh` → exit 0; NI block byte-identical to HEAD; `^## Phase` sequence still the 21-line FR-85 order.
