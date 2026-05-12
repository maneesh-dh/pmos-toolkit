---
task_number: 15
task_name: "Edit feature-sdlc/reference/state-schema.md to schema v4"
status: done
started_at: 2026-05-12T00:00:00Z
completed_at: 2026-05-12T00:00:00Z
files_touched:
  - plugins/pmos-toolkit/skills/feature-sdlc/reference/state-schema.md
tdd: "no — prose (schema doc); verification is grep + the conceptual migration table"
---

## What changed (`plugins/pmos-toolkit/skills/feature-sdlc/reference/state-schema.md`)

- **`## schema_version`** — "current version" bumped to `4`; migration-policy prose updated to describe the `v1 → v2 → v3 → v4` chain (each step additive/idempotent, run in version order), and that the pre-2.34.0 `msf-req`/`simulate-spec` phase-id elision runs before the v4 step.
- **Top-level fields table** — added `pipeline_mode` row (string, required v4+, `feature`/`skill-new`/`skill-feedback`, resolved by the Phase-0 dispatch, **distinct from `mode`** — explicit naming-collision note, defaults to `feature` reading a v1–v3 file); `mode` row annotated "untouched by v4"; `tier` row updated to mention Phase 0d as the skill-mode source; `phases` row annotated "membership mode-conditional per `pipeline_mode` (FR-11)".
- **`## `phases[]` entries`** — added per-phase optional fields: `feedback_source` / `target_skills` (on `feedback-triage`), `resolved_tier` / `skill_location` / `target_platform` / `per_skill_tiers` (on `skill-tier-resolve`), `skill_eval` (on `skill-eval`).
- **`### Phase identifiers + hardness`** — converted the flat list to a table with `feature` / `skill-new` / `skill-feedback` columns; added `feedback-triage` (hard), `skill-tier-resolve` (infra), `skill-eval` (hard) — each marked "new in v4 (D22)" with the hardness rationale; removed the `msf-req`/`simulate-spec` rows (those phases don't exist in 2.34.0+; noted they're elided on read).
- **NEW `#### Mode-conditional `phases[]` membership (v4)`** — the three mode-specific `phases[]` sets verbatim (feature = 2.36.0 set; skill-new = that − {wireframes, prototype} + {skill-tier-resolve, skill-eval}; skill-feedback = skill-new + {feedback-triage} after init-state), the mode-agnostic resume-cursor note (FR-05 — `pipeline_mode` read back, never re-derived), `current_phase` at fresh init, and the updated compact-checkpoint firing rule (feature: before wireframes/prototype/execute/verify; skill modes: before execute/verify only — not before skill-eval).
- **NEW `#### `skill_eval` substructure (v4)`** — the `iterations[]` (`{n, pre_ref, addendum_task_ids, checks_failed, result}`) + `accepted_residuals[]` (`{check_id, fix_note, acked_at}`) shape, with a worked yaml snippet, the `iterations[0]`-is-implicit note, and the "Restore iteration 1" → `git reset` to `iterations[2].pre_ref` rule. Atomic-write (D31) applies.
- **NEW `## Schema v4 (added 2026-05-11)`** — "what's new in v4" (the four additions) + the **v3 → v4 auto-migration block (4 steps, idempotent)**: set `schema_version: 4`; set `pipeline_mode: feature` if absent; `phases[]` unchanged (skill-dev ids never retrofitted); emit `migration: state.schema v3 → v4 (added: pipeline_mode=feature; cohort-marker bump)`. Plus the `> 4` abort and the v1→v2→v3→v4-in-order note.
- **Worked example A** — bumped to `schema_version: 4`, added `pipeline_mode: feature`, dropped the stale `msf-req`/`simulate-spec` phase entries (relabelled "Worked example A — feature mode").
- **NEW Worked example B — skill-feedback mode** — a full `--resume`-ready state.yaml mid-`verify` for a two-skill (`/polish`, `/wireframes`) feedback run: `pipeline_mode: skill-feedback`, run `tier: 3`, the `feedback-triage` entry (`feedback_source`, `target_skills`), the `skill-tier-resolve` entry (`resolved_tier`, `skill_location`, `target_platform`, `per_skill_tiers: {polish: 2, wireframes: 3}`), and the `skill-eval` entry with a two-iteration `skill_eval` substructure + one `accepted_residuals[]` entry.

## Verification

- `grep -c 'schema_version: 4\|schema v4\|Schema v4'` → 5 (≥2).
- `pipeline_mode` present; prose explicitly says it does NOT collide with `mode`.
- `feedback-triage` → hard, `skill-tier-resolve` → infra, `skill-eval` → hard — all three rows present in the table with hardness rationale.
- `skill_eval` / `accepted_residuals` / `iterations:` / `pre_ref` present (14 hits).
- `v3 → v4` migration block present.
- `skill-new` / `skill-feedback` present in the `phases[]`-membership prose (9 hits).
- 4 balanced fenced blocks (lines 112-129, 158-164, 249-329, 337-460); the `phases[]` sets in the doc match the SKILL.md phase prose from T12.
