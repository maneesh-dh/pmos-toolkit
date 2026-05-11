# Seed brief — consolidate skill-dev pipelines into `/feature-sdlc`

Captured from the brainstorming session that preceded this `/feature-sdlc` run. This is the input for Phase 2 `/requirements`.

## Problem

`/create-skill` and `/update-skills` each re-implement most of the `requirements → spec → plan → execute → verify → complete-dev` pipeline that `/feature-sdlc` already orchestrates — but without `/feature-sdlc`'s git-worktree isolation or `state.yaml`-based resume. We want one orchestrator that handles feature dev *and* skill dev, archive the two old skills, and add a quality bar (eval rubric + self-refinement loop) plus a research-grounded patterns guide for authoring SKILL.md files that comply with the broad SKILLS standard (Claude Code primary, Codex and other compliant agents in scope).

## Decisions already made (do not re-litigate)

1. **Full merge.** `/feature-sdlc` absorbs both skills' logic. `/create-skill` and `/update-skills` move to `<repo>/archive/skills/<name>/` (in-repo, outside `plugins/` so the loader ignores them) + an `archive/README.md` noting supersession.
2. **Explicit subcommand.** `/feature-sdlc skill <desc>` → new-skill mode; `/feature-sdlc skill --from-feedback <text|path|--from-retro>` → skill-feedback mode; bare `/feature-sdlc <idea>` → feature mode (unchanged).
3. **Skill-feedback mode is single-skill** per invocation — multi-skill batching from `/update-skills` is dropped.
4. **All artifacts use the feature-folder model** (`<docs_path>/features/<date>_<slug>/`). `/create-skill`'s `~/.pmos/skill-specs/` location is retired.
5. **Generic, not pmos-tied.** The skill must work for any repo / any plugin. No canonical-path-enforcement phase. Host-repo policy (where skills live, version bump, learnings hooks, manifest sync) is read from the host repo's `CLAUDE.md` by `/execute` — and this work moves pmos-toolkit's skill-authoring conventions into this repo's `CLAUDE.md`.
6. **Thin wrapper `/skill-sdlc`** — a ~15-line skill whose entire body forwards to `/feature-sdlc skill …` (parses `--from-feedback`/`--from-retro` and passes through). Exists only for discoverability; no logic.
7. **`/msf-req` is kept** in skill-dev modes — skills are user-facing; analyze user friction/motivation. `/requirements`' folded MSF sub-phase runs normally.
8. **Cross-platform patterns/evals.** `skill-patterns.md` and `skill-eval.md` target the agentskills.io open SKILLS standard; checks phrased portably (e.g. "no hardcoded absolute script paths", not "must use `${CLAUDE_SKILL_DIR}`").
9. **`/grill` at Tier 2+** in skill-dev modes (same as feature mode).
10. **Alphabetic sub-phases** (`2a`, `6a`, …) — no `.5`.
11. **Linear renumber of `/feature-sdlc`** — the current numbering (`0 → 0.a → 0.b → 1 → 2 → 3 → 3.b → 4.b → 4.c → 4.d → 5 → 7 → 8 → 9 → 10 → 11 → 13 → 12`) skips 4 and 6 and ends out of order; fix it.
12. **One resume mechanism** — `/feature-sdlc`'s `state.yaml` resume (Phase 0b) for every mode. Do NOT port `/update-skills`' triage-doc-header resume or `/create-skill`'s re-invoke-verify pattern. The feedback-triage step runs as a pipeline phase; its output is an artifact + a `state.yaml` entry, never a separate resume entry point.
13. **Skill-eval gate is a TDD-style loop** (new sub-phase after `/execute`, skill-dev modes only): run a deterministic check script + a reviewer subagent that **scores and reports only — never edits**; route the fix brief back to `/execute`; re-score; cap 2 loops; then `AskUserQuestion` Accept-as-risk / iterate / abort. `/verify` re-runs the eval as a final idempotent gate.
14. **`skill-eval.md` scoring is hybrid** — each check tagged `[deterministic]` (regex/structural, machine-run) or `[llm-judge]` (reviewer subagent), binary pass/fail.

## Proposed linear phase map (target state for unified `/feature-sdlc`)

| Phase | Name | Modes | Notes |
|---|---|---|---|
| 0 | Pipeline setup, load learnings, subcommand dispatch | all | dispatches `list`; routes `skill` / `skill --from-feedback` vs bare feature |
| 0a | Worktree + slug + branch | all | unchanged; `--no-worktree` bypass |
| 0b | Resume detection | all | the single resume mechanism (state.yaml) |
| 0c | Feedback triage | skill-feedback only | parse input (raw / file / `/retro` paste-back) → critique each finding vs current SKILL.md → AskUserQuestion keep/drop → approved-change list. `retro-parser.md` used only when input is `/retro` format. |
| 0d | Tier resolve | skill-new, skill-feedback | applies create-skill's Tier 1/2/3 matrix, AskUserQuestion, passes `--tier N` down. Feature mode keeps deferring tier to `/requirements`. |
| 1 | Initialize state | all | `state.yaml` schema v4 adds `mode` field (feature/skill-new/skill-feedback); phase list reflects new numbering |
| 2 | `/requirements` | all | seed includes `skill-patterns.md` in skill-dev modes; folded `/msf-req` runs normally incl. skill-dev |
| 2a | `/grill` | all | Tier 2+, mandatory; auto-skip in `--non-interactive` (logged) |
| 3 | Enhancement gates | — | container for the soft optional gates below |
| 3a | `/creativity` gate | all | soft, Recommended = Skip |
| 3b | `/wireframes` gate | feature only | suppressed in skill-dev modes |
| 3c | `/prototype` gate | feature only | suppressed in skill-dev modes |
| 4 | `/spec` | all | generic spec; in skill-dev modes `skill-patterns.md` items flow in as requirements; folded `simulate-spec` runs per its own tiering |
| 5 | `/plan` | all | |
| 6 | `/execute` | all | `skill-patterns.md` passed as implementation reference in skill-dev modes |
| 6a | Skill-eval gate (TDD loop) | skill-new, skill-feedback | see decision 13 |
| 7 | `/verify` | all | non-skippable; in skill-dev modes also re-runs `skill-eval.md` + grades host-repo release prereqs |
| 8 | `/complete-dev` | all | |
| 8a | `/retro` gate | all | soft, Recommended = Skip |
| 9 | Final summary | all | |
| 10 | Capture learnings | all | |

(Compact checkpoint stays a recurring named procedure invoked before heavy phases 3b/3c/6/7 — not a numbered step.)

## New / moved files (target state)

- NEW: `feature-sdlc/reference/skill-patterns.md` — generic SKILLS-standard authoring guide (sections A–E below). Supersedes `/create-skill`'s "Conventions" section, minus the pmos-specific bits (those → repo `CLAUDE.md`).
- NEW: `feature-sdlc/reference/skill-eval.md` — ~35–40 binary checks (1:1 with patterns), each tagged `[deterministic]`/`[llm-judge]`, with check / why / how-to-verify / pass-condition; groups skipped when N/A.
- NEW: `feature-sdlc/tools/skill-eval-check.sh` (or `.js`) — implements the `[deterministic]` subset (mirrors `audit-recommended.sh`).
- NEW: `plugins/pmos-toolkit/skills/skill-sdlc/SKILL.md` — thin wrapper.
- MOVED: `update-skills/reference/retro-parser.md` → `feature-sdlc/reference/`.
- MOVED: `update-skills/reference/triage-doc-template.md`, `seed-requirements-template.md` → `feature-sdlc/reference/` (used by Phase 0c + Phase 2 seed in skill-feedback mode).
- MOVED: `plugins/pmos-toolkit/skills/create-skill/` → `archive/skills/create-skill/`; `…/update-skills/` → `archive/skills/update-skills/`; + `archive/README.md`.
- DROPPED: `create-skill/reference/spec-template.md` (generic `/spec` output used instead).
- EDITED: `/feature-sdlc/SKILL.md` (subcommand parsing, schema v4, new phases 0c/0d/6a, mode-conditioned gate table, skill-tier resolver, renumber), `reference/state-schema.md` (schema v4), `README.md`, both `plugin.json` (minor bump, in sync), this repo's `CLAUDE.md` (skill-authoring conventions section).

## `skill-patterns.md` outline (research-grounded)

A. **Frontmatter** — open-standard required `name` (≤64 chars, `^[a-z0-9-]+$`, no `anthropic`/`claude`, no XML), `description` (≤1024 chars; ideally combined description+`when_to_use` ≤1536); naming-convention consistency (gerund or verb-first imperative — pick one per collection); per-platform optional fields (Claude Code: `when_to_use`, `argument-hint`, `arguments`, `disable-model-invocation` for side-effecting skills, `user-invocable`, `allowed-tools`, `model`, `effort`, `context: fork`+`agent`, `paths`, `hooks`, `shell`; Codex: `agents/openai.yaml` sidecar); fully-qualified MCP tool names (`Server:tool`); no hardcoded absolute script paths (use env-resolved / relative).
B. **Description & triggering** — "what + when" (brief what, clear when, NEVER an enumerated procedure/step-count — documented bug); third person only; ≥2 concrete trigger terms (keywords, file extensions, user phrasings); front-load the key use case (both CC and Codex truncate listings); state when-NOT-to-use; the 20-query trigger-eval methodology (8–10 should-trigger + 8–10 should-NOT, casual + formal, near-misses, concrete).
C. **Structure & progressive disclosure** — three-layer model (metadata always loaded / SKILL.md body on trigger / bundled files on demand); SKILL.md body ≤500 lines; references one level deep only; reference files >100 lines start with a ToC; forward slashes everywhere; descriptive file names (not `doc2.md`); explicit execute-vs-read intent for each script; grep patterns for files >~10k words.
D. **Body & content** — overview/core-principle in 1–2 sentences first; numbered steps for procedures, copy-able checklist for complex ones; validate→fix→repeat feedback loops for quality-critical tasks; match degrees of freedom to task fragility (prose / pseudocode / exact script); no time-sensitive info (use a collapsed "old patterns" section); consistent terminology (one term per concept); one recommended tool/library + one escape hatch (not a menu); concrete examples (real I/O, not placeholders); imperative voice, emphasis sparingly + with a reason; platform/tool-availability fallbacks; don't explain what a competent model already knows.
E. **Scripts (only if bundled)** — handle expected errors in the script (don't punt to the agent); no voodoo constants (justify config values in comments); list required packages + verify availability (no network in some envs); plan-validate-execute for destructive/batch ops.

(Disagreements to note in the doc: Anthropic "what+when" vs obra/superpowers "when-only — never workflow" → resolved as "brief what + clear when, no procedure"; ToC threshold 100 vs 300 lines → use 100; naming gerund vs verb-first → either, consistency is the rule.)

## `skill-eval.md` check groups (raw rules from research, ~39 items)

Frontmatter (1–14): name present/≤64/regex/no-reserved/not-generic/consistent-convention; description present/≤1024/(combined ≤1536); third-person; states what; states when (trigger clause); ≥2 concrete triggers; not a banned vague phrase; no embedded workflow/step-count; key use case in first sentence; side-effecting → `disable-model-invocation`; `allowed-tools` scoped; MCP tools fully qualified.
Structure (15–23): body ≤500 lines; oversize detail split to sibling files referenced from SKILL.md; references one level deep; reference file >100 lines has ToC; forward slashes; no hardcoded absolute script paths; descriptive reference names; execute-vs-read intent unambiguous; grep patterns for huge files.
Body (24–34): overview-first; when-to-use (and ideally when-NOT) covered in body or description; numbered steps + checklist for complex procedures; validate→fix→repeat loop for quality-critical tasks; no time-sensitive statements outside marked "old patterns"; consistent terminology; ≤1 recommended tool + optional escape hatch; concrete examples; doesn't explain the obvious; imperative form, emphasis backed by reason; platform/tool fallbacks + listed deps.
Scripts (35–37, skip if none bundled): scripts handle expected errors; no unexplained magic numbers; scripts have usage docs in SKILL.md.
Process/evals (38–39, skip if N/A): ≥3 evaluation scenarios exist; (if applicable) ≥~16–20 trigger-eval queries split should/should-not.

## Source list (research subagent)

Anthropic "Skill authoring best practices" (platform.claude.com/docs); `anthropics/skills` skill-creator & doc-coauthoring SKILL.md; Claude Code "Extend Claude with skills" (code.claude.com/docs); OpenAI Codex "Agent Skills" (developers.openai.com/codex/skills); `openai/skills` catalog; `obra/superpowers` writing-skills + anthropic-best-practices.md; `travisvn/awesome-claude-skills`; practitioner writeups (Kristopher Dunham, Nick Babich, claudeskills.info, claude.com blog).

## Scope of THIS run

This is a **Tier 3** change to `/feature-sdlc` itself (pipeline integration, multi-mode behavior, new eval rubric, archival migration). Run the full pipeline: `/requirements → /grill → /spec → /plan → /execute → /verify → /complete-dev`.
