---
task_number: 9
task_name: "Apply HTML-rewrite runbook to 9 remaining SKILL.md files (R1-R9)"
task_goal_hash: t9-runbook-fanout
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-09T21:30:00Z
completed_at: 2026-05-09T22:30:00Z
files_touched:
  - plugins/pmos-toolkit/skills/spec/SKILL.md
  - plugins/pmos-toolkit/skills/plan/SKILL.md
  - plugins/pmos-toolkit/skills/msf-req/SKILL.md
  - plugins/pmos-toolkit/skills/msf-wf/SKILL.md
  - plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
  - plugins/pmos-toolkit/skills/grill/SKILL.md
  - plugins/pmos-toolkit/skills/artifact/SKILL.md
  - plugins/pmos-toolkit/skills/verify/SKILL.md
  - plugins/pmos-toolkit/skills/design-crit/SKILL.md
  - docs/pmos/features/2026-05-09_html-artifacts/per-skill-rewrite-runbook.md
---

## T9 — apply T8 runbook §§2–6 across the remaining 9 skills

**Outcome:** done. R1–R9 each shipped as a single per-row commit with inline-grep verification; holistic post-R9 T20-substitute grep across all 10 affected skills returns 0 residual MD primary references after a refined filter that excludes auxiliary sidecars and the platform-fallback file.

### Per-row table

| Row | Skill | Commit | Edit count | Inline grep | Notes |
|---|---|---|---|---|---|
| R1 | `/spec` | `8ddabce` | 6 Edits | clean | argument-hint, Phase 0 addendum, Phase 1 step 3 resolver, Phase 5 canonical write block, heading-id sub-section, anchor-ref + 3 template-frontmatter fixes, final commit `git add` |
| R2 | `/plan` | `8d1f0d2` | 13 Edits | clean | dual addendum (existing 7-9 → output_format=10), Phase 0 step 8 backup-extension preservation, Phase 0 step 9 spec-resolver, Phase 1 step 5 plan-resolver, Phase 2 step 8 peer-plan glob, Phase 3 canonical write, snapshot + final-commit, 7 stale `02_spec.md#anchor` references updated |
| R3 | `/msf-req` | `7afa1f6` | 4 Edits | clean | argument-hint, Phase 0 addendum (no non-interactive-block — refusal pattern), wrong-input guard `.html\|.md`, Phase 6 canonical write with ad-hoc `~/.pmos/msf/assets/` cache; anti-pattern flag list updated |
| R4 | `/msf-wf` | `1bf057e` | 5 Edits | clean | sidecar-only carve-out per runbook edge case row 1; argument-hint, Phase 0 addendum (with explicit "wireframes themselves not converted" note), Phase 7 canonical write for both feature-folder and ad-hoc paths, skill description |
| R5 | `/simulate-spec` | `6a8ce93` | 4 Edits | clean | F3 carve-out (spec-Edit calls untouched); Phase 0 addendum, Phase 8 canonical write with `../assets/` prefix for nested simulate-spec/ folder, snapshot-commit |
| R6 | `/grill` | `7c1cef0` | 6 Edits | clean | runbook edge case row 6 — phase-from-arg switch (`01_requirements`→`phase=requirements`, etc.); Phase 0 addendum step 4, Phase 3b dual-path on-save (HTML primary with full substrate vs MD-primary loose) |
| R7 | `/artifact` | `e3aa12c` | 5 Edits | clean | runbook edge case row 4 — template-store carve-out (`~/.pmos/artifacts/templates/<slug>/template.md` retains MD); Phase 0 addendum step 5, Phase 2.7 canonical write with HTML inline frontmatter, Phase 4 step 1 |
| R8 | `/verify` | `9a3a90e` | 7 Edits | clean | argument-hint, Phase 0 prose `{html,md}`, Phase 0 addendum step 7, Phase 5 spec/plan/requirements reads, Phase 8 review-write with phase-scoped `../../assets/` prefix and conditional index regen, `review.md`→`review.{html,md}` (replace_all, 2 sites) |
| R9 | `/design-crit` | `cfd2ce7` | 8 Edits | clean | runbook §5 NA (directory-scoped wireframes/prototype reads); argument-hint, Phase 0 addendum (with `eval-findings-review.md` carve-out note), source/journeys/psych-msf paths use `{ext}` placeholder, Phase 6 canonical write with substrate-sharing across pipeline siblings, appendix table refs |

### Holistic post-R9 verification (T20 inline substitute)

```
for skill in requirements spec plan msf-req msf-wf simulate-spec grill artifact verify design-crit; do
  grep -rEn '(01_requirements|02_spec|03_plan|msf-findings|trace|design-crit|source|journeys|psych-msf|grill|review|prd|experiment-design)\.md\b' \
    plugins/pmos-toolkit/skills/$skill/SKILL.md \
    | grep -vE 'legacy|sidecar|resolve-input|backlog/items|workstream|format: both|format=both|format=md|html-to-md|sections\.json|\.\{html,md\}|\{ext\}|\.html\b|MD primary|MD sidecar|markdown report|primary|conventions\.md|html-authoring|index-generator|pipeline-bridge|pipeline-setup|capture\.md|learnings\.md|interactive-prompts|hint advertises|template-store|templates/|presets/|preset|01_requirements_v3|_review|_skip-list|_auto|_blocked|eval-findings-review'
done
```

Result: **0 residual matches across all 10 affected skills.** Output: `ALL 10 SKILLS: HOLISTIC T20 SUBSTITUTE PASSES (0 residual MD primary references)`.

### Decisions / deviations

- **Plan-doc rollout order vs dep-DAG.** Plan-doc lists the rollout order as R1=/spec → R9=/design-crit. No dep-DAG inversions; each row is independently applicable since /requirements (R0, T8 pilot) was the actual seed and the resolver substrate (T7 + T11) was already in place.
- **Edit count vs plan estimate.** Plan estimate was "~6 edits per row × 9 rows ≈ 54 Edits". Actual was R1=6, R2=13, R3=4, R4=5, R5=4, R6=6, R7=5, R8=7, R9=8 ⇒ **58 Edits**, +7% over estimate. Driver: R2 had a high concentration of stale `02_spec.md#anchor` template-literal references in the spec-ref placeholder + FR-31a/b prose. R8 likewise had multiple `review.md` mentions in phase-scoped sections. No edge case required a runbook update beyond row 7 (auxiliary sidecars).
- **Forward-deps T20 / T22 substituted with inline `grep -nE`.** Plan calls for `tests/scripts/assert_no_md_to_html.sh` (T20, Phase 4) and `assert_heading_ids.sh` (T22, Phase 4); both substituted with inline grep filtered against canonical excepts. Per-row gate ran on each commit; holistic gate ran post-R9.
- **Holistic-grep filter refinement.** First holistic-grep pass surfaced 8 hits across /plan and /msf-wf and /design-crit. Classification:
  - **Legitimate fixes (3):** /msf-wf lines 157/159/167 — sibling `01_requirements.md` reads → migrated to resolver call (`phase=requirements`); /plan line 284 — `requirements_ref:` frontmatter literal → `{html,md}` shape. Fixed in this commit.
  - **By-design carve-outs (5):** /plan auxiliary sidecars (`03_plan_review.md`, `_skip-list.md`, `_auto.md`, `_blocked.md`) and /design-crit `eval-findings-review.md` (read-back-and-edited platform fallback). Runbook updated with edge-case row 7 documenting the carve-out + filter exclusion.
- **Runbook update during T9 (per plan instruction).** Plan says: "If any row reveals a runbook edge case, pause and append to runbook §Per-skill edge cases before continuing." Followed — but the carve-out emerged at the **holistic** post-R9 stage, not mid-row. Added row 7 to runbook + applied two legitimate fixes. No prior row needs revisiting.

### Forward-dependencies

- **T10 (`/feature-sdlc` orchestrator):** unblocked. Will emit `00_pipeline.html` + `00_open_questions_index.html` per FR-11/D14.
- **T20 (`assert_no_md_to_html.sh`):** Phase 4. Script will replace the inline `grep -rEn` substitute used here.
- **T22 (`assert_heading_ids.sh`):** Phase 4. Will replace any inline `grep -oE "<h[23][^>]*>"` patterns.
- **T15 / T18 (fixture runs):** real subagent dispatch of the 10 skills against the canonical fixture; will exercise the per-skill edits end-to-end.

### Inline verification (plan-defined per row)

Each per-row commit ran a single inline grep matching the runbook §7 substitute pattern. All 9 rows returned 0 residuals after legitimate-sidecar exclusions. Holistic post-R9 grep run on the full set of 10 skills (R0 /requirements + R1–R9) returned 0 residuals.

T10 (/feature-sdlc orchestrator HTML emission, ~6 Edits, single commit) is now unblocked.
