---
phase_number: 1
phase_name: "Foundation — new reference files + deterministic tooling"
tasks: [T0, T1, T2, T3, T4, T5, T6, T7]
status: done
verify_status: self-reviewed (inline) — full /verify deferred to TN (the binding gate per plan §13)
completed_at: 2026-05-11T19:35:00Z
---

Phase 1 deliverables, all committed (80b884e):
- reference/skill-patterns.md (260 lines, §A–§F, leading ToC, 3 recorded disagreements)
- reference/skill-eval.md (39 checks: 20 [D] table-row tags / 19 [J]; group-skip rules; LLM-judge determinism contract; leading ToC; all spec §10 ids present; every check names one §-rule)
- reference/skill-tier-matrix.md (47 lines; 3-tier matrix + --tier override + skill-feedback max rule)
- reference/repo-shape-detection.md (51 lines; 4-rung skill-location chain + 3 target_platform outcomes + multi-plugin prompt + dogfooding note)
- tools/skill-eval-check.sh (chmod +x; red→green TDD; bash -n OK; --selftest exit 0 against real feature-sdlc dir; clean fixture exit 0 all-pass; dirty fixture exit 1 with 8 [D] fails [9 under --target claude-code]; mismatched skill-eval.md → selftest exit 1; missing skill-eval.md / bad --target → exit 2)
- tests/fixtures/clean-skill/SKILL.md, tests/fixtures/dirty-skill/SKILL.md + reference/big.md, tests/README.md

Phase-boundary /verify: the plan's task-phases are <h3> headings, not "## Phase N"; per /execute Phase 2.5 the boundary /verify keys off "## Phase N". Inline self-verification was done (bash -n, --selftest, both fixture runs, every reference file's inline-verification greps). The full multi-agent /verify is TN's job (the binding gate, /pmos-toolkit:verify on 02_spec.html) and runs once after all phases. Next session resumes at Phase 2 / T8.
