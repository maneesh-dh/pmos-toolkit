---
task_number: 14
task_name: "Update the pipeline diagram, anti-patterns, and release prerequisites in feature-sdlc/SKILL.md"
status: done
started_at: 2026-05-12T00:00:00Z
completed_at: 2026-05-12T00:00:00Z
files_touched:
  - plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md
tdd: "no — prose; verification is grep"
---

## What changed (`plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md`)

- **H1 intro prose** — rewritten: lists the feature-mode chain (`/requirements → [/grill] → [/creativity] → [/wireframes → /prototype] → /spec → /plan → /execute → /verify → /complete-dev → [/retro]` — `/msf-req`/`/simulate-spec` no longer named, since folded), then describes the `skill` subcommand (`skill-new` / `skill-feedback`), the suppressed UI gates, the `/feedback-triage` + `/skill-tier-resolve` + Phase-6a additions, and the `/skill-sdlc` alias.
- **"Pipeline position" block** — the ASCII tree now shows the optional `[feedback-triage]` / `[skill-tier-resolve]` / `[skill-eval]` / `[retro]` nodes with mode annotations, the three subcommand → `pipeline_mode` mappings, and the `/skill-sdlc` alias note. Added a **Mode × phase** table (paraphrase of spec §6.1): which phases run in `feature` / `skill-new` / `skill-feedback` (0c skill-feedback-only; 0d/6a skill-modes-only; 3b/3c feature-only; everything else all-modes), plus the note that `/msf-req` and `/simulate-spec` are folded.
- **Anti-Patterns** — #10 amended (in skill modes Phase 6a `/skill-eval` is also non-skippable). Three new items:
  - #11 — letting the Phase-6a reviewer make edits (reviewer scores/reports only; `/execute` is the sole writer — D10).
  - #12 — treating Phase-6a's "accept residuals as known risk" as a silent pass (`accepted_residuals[]` recorded, re-checked by `/verify`, surfaced in `/verify` + `/complete-dev`; don't exceed the 2-iteration cap).
  - #13 — inferring the run mode from the seed text (`pipeline_mode` comes from the explicit `skill` subcommand — FR-02 — never from sniffing).
  (#4's mode-conditional-by-design clause was added in T12.)
- **"Release prerequisites"** — rewritten to items (i)–(vii) per FR-94/FR-95 and Decision P5: (i) README — add `/skill-sdlc` row, update `/feature-sdlc` row + standalone line + flow note, remove `/update-skills` & `/create-skill` rows (→ point at `archive/skills/README.md`); (ii) both `plugin.json` — minor bump 2.37.0 → 2.38.0, one commit, synced; manifests carry no per-command description fields so FR-95's byte-identical-description is satisfied vacuously (SKILL.md frontmatter `description` is the single source — Decision P5); (iii) `argument-hint` enumerates every token/flag (`skill`, `--from-feedback`, `--from-retro`, `--tier`, `--resume`, `--no-worktree`, `--format`, `--non-interactive`, `--interactive`, `--backlog`, `--minimal`, `list`); (iv) `description` carries ≥5 trigger phrases incl. the skill-authoring ones; (v) `archive/skills/{create-skill,update-skills}/` + `archive/skills/README.md` exist; `ls plugins/pmos-toolkit/skills/` shows neither but shows `skill-sdlc`; (vi) `CLAUDE.md` gains `## Skill-authoring conventions`; (vii) bootstrap `## /feature-sdlc` in `~/.pmos/learnings.md` (idempotent; no separate `## /skill-sdlc` — D19/FR-81). Also fixed the legacy `/push` reference → `/complete-dev` is the canonical release skill.
- **"Track Progress"** — no change needed; the prose says "multiple phases", no stale count.

## Verification

- "Pipeline position" region mentions `skill-sdlc` / `skill subcommand` / `skill-new` / `skill-feedback` (4 hits in-region).
- New anti-patterns present (reviewer-scores-only / sole-writer / accept-residuals-not-a-pass / infer-mode-from-seed).
- "Release prerequisites" mentions `archive/skills/README.md`, `2.38.0`, `byte-identical`, `## /feature-sdlc`, `## Skill-authoring conventions`.
- `audit-recommended.sh` → exit 0; NI block byte-identical to HEAD; `^## Phase` sequence still the 21-line FR-85 order; frontmatter intact.
