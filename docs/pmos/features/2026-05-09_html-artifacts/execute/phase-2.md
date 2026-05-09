---
phase_number: 2
phase_name: "Per-skill HTML rewrites + orchestrator HTML emission"
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
verify_status: passed
verify_evidence: "docs/pmos/features/2026-05-09_html-artifacts/verify/2026-05-09-phase-2/"
verify_review: "docs/pmos/features/2026-05-09_html-artifacts/verify/2026-05-09-phase-2/review.md"
phase_tasks: [T7, T8, T9, T10, T11]
started_at: 2026-05-09T20:46:00Z
completed_at: 2026-05-09T23:35:00Z
---

## Phase 2 — Per-skill HTML rewrites + orchestrator HTML emission

### Outcome

All 5 tasks complete and verified. `/verify --scope phase 2` passed with 2 review-gate fixes landed — both runbook documentation polish (no SKILL.md changes). 11 SKILL.md files migrated to HTML-primary; runbook + 2 substrate docs authored. Holistic post-fix grep gate clean across all 11 affected skills.

### Tasks

| Task | Commit | Status |
|---|---|---|
| T7 — `_shared/resolve-input.md` resolver contract | `940691f` | done |
| T11 — `_shared/html-authoring/index-generator.md` algorithm | `956c680` | done (ran before T8 per dep DAG; plan-doc order is informational) |
| T8 — Per-skill rewrite runbook + /requirements pilot + W01 ⌘K removal | `411521e` | done |
| T9 — Runbook fanout R1-R9 + post-R9 follow-ups | `8ddabce` `250e008` `4259151` `a13ee57` `6823571` `a900b62` `078fcb4` `4af4b64` `3a276c7` `d3abec1` (10 commits) | done |
| T10 — /feature-sdlc orchestrator HTML emission (FR-11/D14) | `1d646e2` | done |

### Verify-pass fixes landed (this seal commit)

1. **Runbook §7 grep filter expansion (conf 95).** §7 inline-substitute grep gate was missing 5 carve-out exclusions (`_review|_skip-list|_auto|_blocked|eval-findings-review`) that the holistic-gate filter from T9 already used. Without them the gate would have produced false positives on /plan auxiliary sidecars and /design-crit's `eval-findings-review.md` platform fallback. Filter expanded; comment block above the grep documents each carve-out class so the T20 implementer mirrors the same exclusion set in `assert_no_md_to_html.sh`.
2. **Runbook §2 doubly-nested asset-prefix clause (conf 80).** §2 covered top-level (`./assets/`) and one-level-nested (`../assets/`) but didn't name the doubly-nested case used by /verify phase-scoped runs (`verify/<YYYY-MM-DD>-phase-<N>/review.html` → `../../assets/`). /verify SKILL.md emits the deeper prefix correctly per T9 R8; only the runbook prose was incomplete. Explicit doubly-nested clause added.

### Multi-agent reviewer triage (Phase 5/Phase 3)

| # | Reviewer | Outcome | Acted? |
|---|---|---|---|
| R1 | FR-10 substrate compliance | PASS | n/a |
| R2 | FR-33 resolver + FR-22/41 index regen | PASS | n/a |
| R3 | FR-03.1 heading-IDs + FR-12 sidecar | PASS | n/a |
| R4 | Runbook fidelity + edge-case rows | 1 BLOCKER + 1 advisory | YES — both fixes landed |
| R5 | Cross-file consistency + non-interactive contract | PASS | n/a |
| R6 | CLAUDE.md compliance + per-skill anti-patterns | PASS | n/a |

### Test surface (Phase 2 — closed)

- Per-row inline-grep gates on each T9 commit (R1-R9).
- Holistic post-R9 grep gate across all 10 skills (T9 follow-up commit).
- Holistic post-T10 grep gate including orchestrator (T10 commit).
- Holistic post-fix grep gate this verify pass (0 residual hits across all 11 affected skills).

Forward-deps T20 (`assert_no_md_to_html.sh`) and T22 (`assert_heading_ids.sh`) substituted with inline grep until Plan-Phase 4 lands the canonical scripts.

### Open follow-ups (deferred to Plan-Phase 3/4)

- T15 / T18 — end-to-end runs of all 10 skills against canonical fixture (Plan-Phase 3).
- T20 — `assert_no_md_to_html.sh` script with the expanded §7 exclusion set as its specification (Plan-Phase 4).
- T22 — `assert_heading_ids.sh` script (Plan-Phase 4).

### Phase 3 entry-readiness

Plan-Phase 3 (T12-T15) consumes:
- All 10 skills' updated authoring sections (canonical write blocks already in place).
- `_shared/resolve-input.md` resolver contract.
- `_shared/html-authoring/index-generator.md` algorithm.
- `_shared/html-authoring/assets/*` substrate (verified Phase 1).
- Per-skill-rewrite-runbook with the post-verify §7 exclusion set + §2 doubly-nested clause.

Phase 3 is ready to start. /feature-sdlc resume cursor will land on Plan-Phase 3 (T12 — substrate fixtures).
