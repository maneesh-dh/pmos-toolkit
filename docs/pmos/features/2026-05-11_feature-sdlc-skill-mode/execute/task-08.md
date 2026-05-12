---
task_number: 8
task_name: "git mv the three update-skills reference files + generalise their framing"
plan_path: "docs/pmos/features/2026-05-11_feature-sdlc-skill-mode/03_plan.html"
branch: "feat/feature-sdlc-skill-mode"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-feature-sdlc-skill-mode"
status: done
started_at: 2026-05-12T00:00:00Z
completed_at: 2026-05-12T00:00:00Z
files_touched:
  - plugins/pmos-toolkit/skills/feature-sdlc/reference/retro-parser.md
  - plugins/pmos-toolkit/skills/feature-sdlc/reference/triage-doc-template.md
  - plugins/pmos-toolkit/skills/feature-sdlc/reference/seed-requirements-template.md
---
git mv'd retro-parser.md (no edits — no internal refs), triage-doc-template.md, and seed-requirements-template.md from update-skills/reference/ → feature-sdlc/reference/. update-skills/reference/ now empty (gone on commit). 3 renames staged.

triage-doc-template.md generalised: header marker pmos:update-skills-triage → pmos:feedback-triage + a note that Phase 0c renders the structure through the HTML substrate as {feature_folder}/0c_feedback_triage.html; {docs_path}/features/{YYYY-MM-DD}_update-skills-{slug}/ → {feature_folder}; "Resume by re-invoking /update-skills <path>. Phase 8 will pick up..." → "Resume via /feature-sdlc --resume — Phase 0c is a normal pipeline phase; recorded in state.yaml". Kept the 5 FR-25 sections (findings / critique / disposition log / approved-by-skill / per-skill tier); dropped the update-skills-specific "Pipeline status (Phase 8)" / "Failure log (Phase 8)" / "Final summary (Phase 9)" orchestration sections (that tracking lives in /feature-sdlc's 00_pipeline.html + state.yaml); per-skill-tier table now has a "Run tier (= max)" column; only a historical "lifted from /update-skills" note remains.

seed-requirements-template.md generalised: **Source:** /update-skills triage at {triage_doc_path} → /feature-sdlc skill --from-feedback — approved findings from {feature_folder}/0c_feedback_triage.html; added per-skill-tier + run-tier(=max) line; "Version bump at next /push" → "Version bump at /complete-dev"; the reference-paths constraint now points at repo-shape-detection.md (was hard-coded to plugins/pmos-toolkit/skills/); intro + a Notes bullet now say "one combined doc with a per-skill section" when multiple skills are in scope (FR-27); only a historical "lifted from /update-skills" note remains. No live skill references update-skills/reference/ paths (grep clean).
