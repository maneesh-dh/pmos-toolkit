# Grill Report — 01_requirements.md (html-artifacts)

**Depth:** standard  •  **Questions asked:** 6 (+ 1 user-driven rollback)
**Date:** 2026-05-09
**Target:** `docs/pmos/features/2026-05-09_html-artifacts/01_requirements.md`

## Resolved

- **D2 / OQ1 (Diagram strategy) — Q1:** `/spec` and `/plan` invoke `/diagram` as a **blocking Task subagent** per diagram-worthy moment, using its full reviewer loop. Wall-clock cost (30s–2min per diagram) accepted for quality. Stall-fallback path: skill prompt inlines an SVG directly when subagent stalls/errors. Specific timeout/retry/stall-fallback policy → `/spec`.
- **Cross-skill artifact resolution (NEW) — Q2:** Extend `_shared/resolve-input.md` with format-aware resolution: `prefer .html → fall back to .md → error if neither`. Every "read upstream artifact" path in every downstream skill routes through it. Handles forward-only migration cleanly across mixed-state folders.
- **Release shape — Q4:** Single release. All 10 skills + viewer + reviewers + `/diagram` integration ship together. Mixed-format folders (intra-folder) explicitly avoided.
- **CSS / JS asset distribution — Q5:** Skills copy `style.css`, `serve.js`, and any required JS (turndown for Copy-Markdown, viewer hooks) into `{feature_folder}/assets/` at write time. Each feature folder fully self-contained — meets Goal #1 (zip-and-share).
- **D3 / OQ2 (Reviewer parser tech) — User pushback after Q3/Q6:** Reviewers receive HTML wholesale; **the LLM is the parser**. No `jsdom`, regex, `data-section` attribute discipline, or section-taxonomy SSOT. The current markdown reviewers already pass MD wholesale to the LLM and find sections semantically; HTML is more structured than MD, not less, so the same approach is more robust on HTML, not less. Resolves OQ2.

## Rolled back (mid-grill course correction)

After Q3 (golden-output regression suite for reviewers) and Q6 (`section-taxonomy.md` as SSOT for `data-section` slugs), the user observed that the entire `data-section` story was solving a problem that doesn't exist if reviewers just trust the LLM to find sections semantically. Q3 and Q6 both got rolled back. Net effect: a **simpler design** than the post-Q6 state. Specifically dropped:

- `data-section="<slug>"` attribute discipline in skill prompts.
- `_shared/html-authoring/section-taxonomy.md` SSOT.
- Golden-output regression suite scoped specifically to reviewer-anchor-checking (a smaller smoke verification — "each reviewer emits non-empty findings on real HTML during `/verify`" — replaces it).

Lesson worth capturing in `~/.pmos/learnings.md` `## /grill`: when a series of grill answers pile complexity onto a design, surface the cumulative shape to the user before committing. The user caught the over-engineering in one challenge.

## Open / Deferred

- **OQ3 (html→md tech):** turndown.js bundled vs. server endpoint vs. pre-rendered `.md` sidecar — resolve in `/spec`. Whatever JS is bundled gets copied per `assets/` (Q5).
- **OQ4, OQ5 (viewer UX):** wireframes/prototype embed vs. link out; Copy-Markdown granularity (full doc vs. per-section) — resolve in `/wireframes`.
- **OQ6 (this doc itself):** when (if ever) is the bootstrap markdown re-authored as HTML — still deferred to `/complete-dev`.
- **OQ7 (`/feature-sdlc` orchestrator artifacts):** in-scope or not — resolve in `/spec`.
- **OQ8 (`/diagram` subagent timeout / retry / stall-fallback policy):** wall-clock budget per `/spec` run; resolve in `/spec`.

## Gaps folded into the requirements doc (loop 2)

1. ✅ Cross-skill artifact resolution — added as Solution Direction §6.
2. ✅ Reviewer testing strategy — replaced with smaller smoke-verification in §5; added Success Metrics row.
3. ✅ CSS + JS asset distribution — explicit in §1; "copy at write time" called out.
4. ❌ ~~`section-taxonomy.md`~~ — dropped per rollback.
5. ✅ `/diagram` subagent contract — D2 wording tightened to "spawn as blocking Task subagent".

## Recommended next step

Loop 2 of `/requirements` is done (this report's gaps folded in). Proceed to `/msf-req` (Phase 4.a, Tier-3 mandatory).
