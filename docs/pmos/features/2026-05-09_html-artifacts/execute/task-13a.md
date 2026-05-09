---
task_number: "13a"
task_name: "/feature-sdlc orchestrator chrome-strip + FR-52 validation at each reviewer-dispatch site"
task_goal_hash: t13a-orchestrator-chrome-strip-validation
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-10T00:35:00Z
completed_at: 2026-05-10T00:50:00Z
files_touched:
  - plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md
  - plugins/pmos-toolkit/skills/wireframes/SKILL.md
---

## T13a — /feature-sdlc dispatch instrumentation

**Outcome:** done. 4 reviewer-subagent contract blocks landed across 2 SKILL.md
files. Chrome-strip + FR-51 prompt + FR-52 validation now inline before each
reviewer dispatch. /verify Phase 9 dispatch preserved untouched per FR-50.1.

### Plan deviation logged

**DEVIATION:** Plan T13a `Files:` listed only `feature-sdlc/SKILL.md` with
"4 dispatch sites". Reality: /feature-sdlc directly dispatches **3** reviewer
subagents (Phase 3.b /grill, Phase 4.a /msf-req, Phase 6 /simulate-spec). The
4th reviewer (/msf-wf) is dispatched by `/wireframes` Phase 6 (line 553), not
by /feature-sdlc. Scope adjusted to: 3 sites in `/feature-sdlc/SKILL.md` +
1 site in `/wireframes/SKILL.md` = 4 total. /verify Phase 9 dispatch in
/feature-sdlc remains untouched per FR-50.1 (it dispatches to a separate
post-implementation gate, not as a reviewer of an artifact).

This is a downstream artifact of the upstream defect that surfaced T13:
the original `/spec` Phase 2 Subagent A report mis-located the 5
reviewer-dispatch sites. The /spec → /plan narrowing chain corrected the FR
scope (FR-50 / FR-50.1 / D22) and the T13 split (T13a + T13b), but the per-
file scoping in T13a still reflected the same flawed assumption that
/feature-sdlc owns all 4. Documenting here for posterity.

### Edits applied

**1. `/feature-sdlc/SKILL.md` Phase 3.b /grill (1 edit, ~1 paragraph):** before
the existing `invoke /pmos-toolkit:grill` line, inserted the canonical
contract block — chrome-strip via `chrome-strip.js`, pass stripped HTML inline
with FR-51 template, run FR-52 validation (sections.json set-equality + quote
substring-grep, hard-fail on miss), pause with soft-phase failure dialog.
Artifact: `01_requirements.html` + `01_requirements.sections.json`.

**2. `/feature-sdlc/SKILL.md` Phase 4.a /msf-req (1 edit):** identical block,
artifact same as Phase 3.b (`01_requirements.html`).

**3. `/feature-sdlc/SKILL.md` Phase 6 /simulate-spec (1 edit):** identical
block, artifact `02_spec.html` + `02_spec.sections.json`. Inserted between
the existing "Before invoking, run the compact checkpoint" line and the
"On missing-skill" line.

**4. `/wireframes/SKILL.md` Phase 6 /msf-wf (1 edit):** adapted block for the
multi-wireframe iteration shape. /msf-wf reviews each `*.html` in the
wireframes folder; the contract loops chrome-strip + per-wireframe FR-52
validation. Per-wireframe hard-fail aborts the iteration (does NOT silently
continue to the next wireframe).

### Inline verification

```
$ grep -c "chrome-strip.js" plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md
3   ✅ matches plan target ≥3 per-feature-sdlc (was ≥4 pre-deviation)

$ grep -c "chrome-strip.js" plugins/pmos-toolkit/skills/wireframes/SKILL.md
1   ✅ msf-wf dispatch site

$ grep -c "FR-52" plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md
3   ✅ one per dispatch site (grill, msf-req, simulate-spec)

$ grep -c "≥40-char verbatim" plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md
3   ✅

$ grep -c "Phase 9.*non-skippable" plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md
1   ✅ Phase 9 /verify dispatch section header preserved un-instrumented per FR-50.1
```

Total: 4 reviewer-subagent contract blocks across 2 files (3 in feature-sdlc
+ 1 in wireframes). All four reference chrome-strip.js, FR-51 template, and
FR-52 validation.

### Spec compliance

| FR | Requirement | Satisfied by |
|---|---|---|
| FR-50 | Chrome-strip in parent skill, not reviewer | All 4 dispatch sites now run chrome-strip.js BEFORE invoking the subagent |
| FR-50.1 | /verify Phase 3 code-diff reviewers carved out | Phase 9 /verify dispatch in /feature-sdlc untouched (un-instrumented) |
| FR-51 | Canonical reviewer-prompt template | All 4 sites inline the verbatim FR-51 prose |
| FR-52 | Parent-side validation (sections_found set-equality + quote substring-grep, hard-fail on miss) | All 4 sites run the FR-52 4-step validation block after subagent return |
| D14 | Orchestrator scope | /feature-sdlc 3 sites + /wireframes 1 site (per dispatch reality) |
| D22 | T13 split decision | T13a parent-side instrumentation realized; T13b documents reviewer-side contract |

### Forward-dependencies

- **T13b:** 5 reviewer skills (grill, verify, msf-req, msf-wf, simulate-spec)
  add Phase-1 "Input Contract" subsection citing this T13a contract block.
- **T26 / FR-72 smoke:** end-to-end runs each reviewer with chrome-stripped
  input from a real feature-folder artifact, asserting the FR-51 + FR-52
  contract holds in practice.

T13a complete. Next: T13b.
