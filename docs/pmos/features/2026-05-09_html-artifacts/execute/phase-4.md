---
phase: 4
phase_name: "Test fixtures + assert scripts"
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
status: verified
started_at: 2026-05-10T01:55:00Z
completed_at: 2026-05-10T02:30:00Z
verified_at: 2026-05-10T03:00:00Z
tasks: [T15, T16, T17, T18, T19, T20, T21, T22, T23]
verify_outcome: PASS
verify_review_path: docs/pmos/features/2026-05-09_html-artifacts/verify/2026-05-10-phase-4/review.md
---

## Plan-Phase 4 — Test fixtures + assert scripts

**Outcome:** 9/9 tasks complete + holistic green sweep. /verify --scope
phase 4 dispatch pending.

### Tasks

| Task | Description | Status | Commit |
|---|---|---|---|
| T15 | fixture feature folder seed (19 files) | done | bf0398b |
| T16 | assert_resolve_input.sh + 4 sub-fixtures + harness | done | (T16 commit) |
| T17 | assert_sections_contract.sh | done | (T17 commit) |
| T18 | assert_format_flag.sh — static-check harness (OQ-3 resolved) | done | (T18 commit) |
| T19 | assert_unsupported_format.sh — static-check harness (OQ-3 resolved) | done | (T19 commit) |
| T20 | assert_no_md_to_html.sh | done | (T20 commit) |
| T21 | lint-no-modules-in-viewer.sh + assert wrapper | done | (T21 commit) |
| T22 | assert_heading_ids.sh | done | (T22 commit) |
| T23 | assert_cross_doc_anchors.sh | done | (T23 commit) |

### Holistic green sweep (post-fanout)

```
assert_resolve_input.sh         → PASS (4 cases)
assert_sections_contract.sh     → PASS (5 sections.json files)
assert_format_flag.sh           → PASS (10 skills)
assert_unsupported_format.sh    → PASS (10 skills)
assert_no_md_to_html.sh         → PASS (zero converter hits)
assert_no_es_modules_in_viewer  → PASS (viewer.js classic-script)
assert_heading_ids.sh           → PASS (5 fixture HTMLs, 0 missing)
assert_cross_doc_anchors.sh     → PASS (4 anchors resolve)
```

### OQ-3 resolution (T18 + T19)

OQ-3 was the open question about the per-skill harness shape for live
runtime testing of `--format` and invalid-`output_format` flows. Plan
Phase 4 surfaced two paths:

1. **Live runtime invocation** — impossible from bash; skills are
   Claude-Code Skill-tool invocations, not shell-callable.
2. **Static-check harness** — verify each affected SKILL.md documents
   the contract (output_format resolution gate, `both` mode branch,
   substrate substrate path, valid-values enumeration).

Path 2 adopted, consistent with the inline-grep substitutes accepted
in Phase-2 verify. Live end-to-end runtime coverage deferred to FR-72
smoke (T26 in Phase 5).

### Discovered advisories (non-blocking)

- **ADV-T19** (pre-existing): `msf-req/SKILL.md` missing the canonical
  `<!-- non-interactive-block -->` contract. Not introduced by Phase 4.
  Recommend Phase-5 cleanup pass.
- **ADV-T21** (Phase-4 polish): `lint-no-modules-in-viewer.sh` not yet
  wired into a multi-lint runner (none currently exists). Tool +
  wrapper-assert pair callable independently.

### Pipeline status post-Phase-4

Plan-Phase 4 (T15-T23) tasks done. Phase 2.5 /verify --scope phase 4
fires next. Phase 5 (T24-T26: manifest version sync + final
feature-scope verify) blocked on Phase 4 verify outcome.
