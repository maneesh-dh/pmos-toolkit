---
task_number: "13b"
task_name: "5 reviewer skills document Phase-1 Input Contract (as subagent) subsection"
task_goal_hash: t13b-reviewer-input-contract-docs
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-10T01:00:00Z
completed_at: 2026-05-10T01:08:00Z
files_touched:
  - plugins/pmos-toolkit/skills/grill/SKILL.md
  - plugins/pmos-toolkit/skills/verify/SKILL.md
  - plugins/pmos-toolkit/skills/msf-req/SKILL.md
  - plugins/pmos-toolkit/skills/msf-wf/SKILL.md
  - plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
---

## T13b — reviewer-side input contract documentation

**Outcome:** done. Canonical "Input Contract (when invoked as reviewer
subagent)" subsection inserted at end of Phase 1 in each of 5 reviewer
skills. `/verify` edit scoped explicitly to artifact-review path; Phase 3
Multi-Agent Code Quality Review block preserved untouched per FR-50.1.

### Edits applied (per-skill commits)

| Skill | Commit | Insertions | Adapted |
|---|---|---|---|
| /grill | `0f7229e` | +8 lines | canonical |
| /msf-req | `ae5fb6c` | +8 lines | canonical |
| /msf-wf | `1916cae` | +8 lines | adapted: "currently `/wireframes`" parent + per-wireframe iteration shape |
| /simulate-spec | `c3df1a2` | +8 lines | canonical |
| /verify | `4d54a62` | +10 lines | canonical + FR-50.1 carve-out scope note (Phase 3 multi-agent block excluded) |

5 commits total, one per skill, matching plan §T13b Step 2 audit-trail
expectation (consistent with T9 per-row commit cadence).

### Inline verification

```
$ grep -c "Input Contract (when invoked as reviewer subagent)" \
    plugins/pmos-toolkit/skills/{grill,verify,msf-req,msf-wf,simulate-spec}/SKILL.md
5   ✅ one per skill (plan target: 5)

$ grep -c "sections_found" plugins/.../{five}/SKILL.md
≥1 per skill, 10 total ✅ (plan target: ≥5)

$ grep -c "≥40-char verbatim" plugins/.../{five}/SKILL.md
1 per skill, 5 total ✅ (plan target: ≥5)

$ grep -c "FR-52" plugins/.../{five}/SKILL.md
1-2 per skill, 6 total ✅ (plan target: ≥5)

$ grep -c "Multi-Agent Code Quality Review" plugins/pmos-toolkit/skills/verify/SKILL.md
2   ✅ heading + carve-out reference both preserved
       (plan target: 1; ≥1 satisfies the "preserved" constraint)

$ grep -n "chrome-strip.js\|## Phase 3" plugins/pmos-toolkit/skills/verify/SKILL.md
209: ...chrome-strip.js... (inside Input Contract subsection, end of Phase 1)
258: ## Phase 3: Multi-Agent Code Quality Review
✅ chrome-strip mention is OUTSIDE the Phase 3 multi-agent block — no
   instrumentation leakage into the FR-50.1 carve-out.
```

### Spec compliance

| FR | Requirement | Satisfied by |
|---|---|---|
| FR-50 | Reviewer-side documents that chrome-strip is parent's responsibility | All 5 Input-Contract subsections cite chrome-strip.js as parent-owned |
| FR-50.1 | /verify Phase 3 code-diff reviewers carved out | Scope note in /verify Input Contract subsection explicitly excludes Phase 3 Multi-Agent block; line-number check confirms separation |
| FR-51 | Canonical reviewer-prompt template documented | All 5 subsections cite `sections_found: [...]` + `{section_id, severity, message, quote: "<≥40-char verbatim from source>"}` shape |
| FR-52 | Reviewer skills MUST NOT self-validate; document parent-side validation | All 5 subsections include "Parent-side validation (FR-52, the skill MUST NOT self-validate)" paragraph |
| D22 | Architectural narrowing (chrome-strip in parent) | Reviewer-side documentation now matches T13a parent-side runtime contract |

### Adaptations

**Per-skill canonical reuse + 2 adaptations:**
- `/msf-wf` parent identifier reads `/wireframes` not `/feature-sdlc` (per T13a deviation: /msf-wf is dispatched by /wireframes Phase 6 line 553, not /feature-sdlc). Per-wireframe iteration shape preserved from T13a's adapted dispatch block.
- `/verify` scope note clarifies the FR-50.1 carve-out explicitly. Without the scope note, the Input Contract block reads as if it covers the entire skill — including Phase 3 — which is not what FR-50.1 says. Single-paragraph scope clarification keeps the canonical body intact while preventing Phase-3 contamination.

### Defect-file cleanup (FR-100b lifecycle)

T13a + T13b both now `done`. `03_plan_defect_T13.md` is to be deleted by
/execute per FR-100b — defect file persists until BOTH split tasks succeed.
T13b is the second; deletion now in scope.

```bash
$ ls docs/pmos/features/2026-05-09_html-artifacts/03_plan_defect_T13.md
(file exists; will be removed in this commit cycle per FR-100b)
```

### Forward-dependencies

- **T26 / FR-72 smoke:** end-to-end runs each reviewer with chrome-stripped
  input from a real feature-folder artifact, asserting the FR-51 + FR-52
  contract documented here holds in practice.
- **T15 (Phase 4 fixtures):** canonical fixture exercises the contract.

T13b complete. Next: defect-file cleanup commit, then T14 (/diagram pattern).
